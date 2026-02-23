import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';

import 'transcript_service.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  final TranscriptService _transcriptService = TranscriptService();
  final Uuid _uuid = const Uuid();

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isCallActive = false;
  bool get isCallActive => _isCallActive;

  String? _currentRoomId;
  String? _sourceLang;
  String? _targetLang;

  final StreamController<String> _translatedTextController =
      StreamController<String>.broadcast();
  Stream<String> get translatedTextStream => _translatedTextController.stream;

  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  // Stream for audio data (WAV bytes for AudioProcessor)
  final StreamController<Uint8List> _audioDataController =
      StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get audioDataStream => _audioDataController.stream;

  final StreamController<int> _userCountController = StreamController<int>.broadcast();
  Stream<int> get userCountStream => _userCountController.stream;

  final StreamController<void> _callEndedController = StreamController<void>.broadcast();
  Stream<void> get callEndedStream => _callEndedController.stream;

  final StreamController<Map<String, dynamic>> _systemMessageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get systemMessageStream => _systemMessageController.stream;

  final StreamController<Map<String, dynamic>> _signalingController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get signalingStream => _signalingController.stream;

  Completer<void>? _connectionCompleter;

  // Connect to WebSocket server
  Future<void> connect({
    required String serverUrl,
    required String roomId,
    required String sourceLang,
    required String targetLang,
  }) async {
    try {
      if (_isConnected && 
          _currentRoomId == roomId && 
          _sourceLang == sourceLang && 
          _targetLang == targetLang) {
         debugPrint('WebSocketService: Already connected to $roomId. Skipping reconnect.');
         return;
      }

      debugPrint('WebSocketService: Connecting to $serverUrl');
      
      _currentRoomId = roomId;
      _sourceLang = sourceLang;
      _targetLang = targetLang;

      // Close existing connection if any
      await disconnect();

      _connectionCompleter = Completer<void>();

      final uri = Uri.parse(serverUrl);
      _channel = WebSocketChannel.connect(uri);

      // Start listening
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDisconnect,
        cancelOnError: false,
      );

      // Wait for Handshake (ACK)
      // This ensures we verify the connection is actually working
      try {
        await _connectionCompleter!.future.timeout(const Duration(seconds: 10));
        
        // Mark connected ONLY after ACK
        _isConnected = true;
        _connectionStatusController.add(true);
        debugPrint('WebSocketService: Handshake successful, Connected!');

        // Send configuration
        sendConfig(roomId: roomId, sourceLang: sourceLang, targetLang: targetLang);

      } catch (e) {
        debugPrint('WebSocketService: Handshake Timeout or Failed - $e');
        disconnect(); // Cleanup
        throw Exception('Connection Timeout: Server did not respond.');
      }

    } catch (e) {
      debugPrint('WebSocketService: Connection error - $e');
      _isConnected = false;
      _connectionStatusController.add(false);
      rethrow;
    }
  }

  // Send configuration to server
  void sendConfig({
    required String roomId,
    required String sourceLang,
    required String targetLang,
  }) {
    // Check _channel not null, but loosen _isConnected check to allow config during setup if needed, 
    // though ideally we are connected now.
    if (_channel == null) return;

    final config = {
      'type': 'config',
      'roomId': roomId,
      'sourceLang': sourceLang,
      'targetLang': targetLang,
    };

    final jsonConfig = jsonEncode(config);
    _channel!.sink.add(jsonConfig);
    debugPrint('WebSocketService: Sent config - $jsonConfig');
  }

  // Send PCM audio data
  void sendAudioData(Uint8List pcmData) {
    if (!_isConnected || _channel == null) return;

    try {
      _channel!.sink.add(pcmData);
      // debugPrint('WebSocketService: Sent PCM data - ${pcmData.length} bytes');
    } catch (e) {
      debugPrint('WebSocketService: Error sending audio data - $e');
    }
  }

  // Handle incoming messages
  void _onMessage(dynamic message) {
    try {
      if (message is String) {
        // Text message
        // debugPrint('WebSocketService: Rx Text: $message');
        
        try {
          final data = jsonDecode(message);
          
          // HANDLE HANDSHAKE
          if (data['type'] == 'connection_ack') {
             debugPrint('WebSocketService: Received ACK');
             if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
               _connectionCompleter!.complete();
             }
             return;
          }

          // HANDLE ROOM UPDATE
          if (data['type'] == 'room_update') {
             final count = data['userCount'] as int;
             debugPrint('WebSocketService: Room Update, Users: $count');
             _userCountController.add(count);
             return;
          }

          if (data['type'] == 'call_ended') {
             debugPrint('WebSocketService: Call Ended Signal Received');
             _callEndedController.add(null);
             return;
          }

          if (data['type'] == 'system') {
             debugPrint('WebSocketService: System Message - ${data['status']}');
             if (data['status'] == 'call_active') {
                _isCallActive = true;
             }
             _systemMessageController.add(data);
             return;
          }

          if (data['type'] == 'signaling') {
             _signalingController.add(data);
             return;
          }

          if (data['type'] == 'transcript') {
            final originalText = data['original'] ?? '';
            final translatedText = data['translated'] ?? '';
            final isLocal = data['isLocal'] ?? false;
            
            debugPrint('WebSocketService: Transcript - Original: $originalText, Translated: $translatedText, IsLocal: $isLocal');
            
            // Add to transcript service
            _transcriptService.addTranscriptText(
              id: _uuid.v4(),
              originalText: originalText,
              translatedText: translatedText,
              isLocal: isLocal,
              speaker: isLocal ? 'user' : 'contact',
            );
            
            _translatedTextController.add(translatedText);
          }
        } catch (e) {
          // If not JSON or failed logic
          debugPrint('WebSocketService: Text Parse Error - $e');
        }
      } else if (message is List) {
        // Binary message - translated audio
        // Ensure it's treated as bytes
        final List<int> bytes = message.cast<int>();
        final audioBytes = Uint8List.fromList(bytes);
        
        // debugPrint('WebSocketService: Rx Audio (${audioBytes.length} bytes)');
        
        // Emit to audio stream
        _audioDataController.add(audioBytes);
      }
    } catch (e) {
      debugPrint('WebSocketService: Error processing message - $e');
    }
  }

  // Send Signaling Data (SDP/Candidates)
  void sendSignalingMessage(Map<String, dynamic> data) {
    if (!_isConnected || _channel == null) return;
    
    // Wrap in standard envelope
    final message = {
      'type': 'signaling',
      'payload': data
    };
    
    try {
      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('WebSocketService: Error sending signaling: $e');
    }
  }

  // Send Call Control Message (cancel/end)
  void sendCallControlMessage(String type, {String? reason}) {
     if (!_isConnected || _channel == null) return;
     
     final message = {
       'type': type,
       'reason': reason ?? 'user_action'
     };
     
     try {
       _channel!.sink.add(jsonEncode(message));
       debugPrint('WebSocketService: Sent control message: $type');
     } catch (e) {
       debugPrint('WebSocketService: Error sending control message: $e');
     }
  }

  // Handle errors
  void _onError(error) {
    debugPrint('WebSocketService: Error - $error');
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
       _connectionCompleter!.completeError(error);
    }
    _isConnected = false;
    _connectionStatusController.add(false);
  }

  // Handle disconnection
  void _onDisconnect() {
    debugPrint('WebSocketService: Disconnected');
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
       _connectionCompleter!.completeError('Disconnected by server');
    }
    _isConnected = false;
    _isCallActive = false;
    _connectionStatusController.add(false);
  }

  // Disconnect Method
  Future<void> disconnect() async {
    try {
      debugPrint('WebSocketService: Disconnecting');
      await _channel?.sink.close();
      _channel = null;
      _isConnected = false;
      _connectionStatusController.add(false);
    } catch (e) {
      debugPrint('WebSocketService: Error disconnecting - $e');
    }
  }

  // Dispose Method
  void dispose() {
    disconnect();
    _translatedTextController.close();
    _connectionStatusController.close();
    _audioDataController.close();
    _systemMessageController.close();
  }
}