import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:sound_stream/sound_stream.dart';
import 'package:audio_session/audio_session.dart';
import 'websocket_service.dart';

class AudioProcessorService {
  static final AudioProcessorService _instance = AudioProcessorService._internal();
  factory AudioProcessorService() => _instance;
  AudioProcessorService._internal();

  final WebSocketService _webSocketService = WebSocketService();
  final RecorderStream _recorder = RecorderStream();
  final PlayerStream _player = PlayerStream();

  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isMicMuted = false;
  bool _isOutputEnabled = true; // Controls if we write chunks to player (Mute Output)
  StreamSubscription<List<int>>? _audioSubscription;

  // Debug Stream
  final StreamController<int> _micActivityController = StreamController<int>.broadcast();
  Stream<int> get micActivityStream => _micActivityController.stream;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('AudioProcessorService: Initializing Sound Stream & Audio Session');
      
      // 1. Configure Audio Session for VoIP (Play AND Record)
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker, // Default to Speaker
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));

      // 2. Initialize Streams (16kHz standard)
      try {
        await _recorder.initialize(sampleRate: 16000);
        await _player.initialize(sampleRate: 16000);
        debugPrint('AudioProcessorService: Streams initialized at 16000Hz');
      } catch (e) {
        debugPrint('AudioProcessorService: Failed to init 16k, falling back to default: $e');
        await _recorder.initialize();
        await _player.initialize();
      }
      
      debugPrint('AudioProcessorService: Sound Stream & Session ready');
      _isInitialized = true;
    } catch (e) {
      debugPrint('AudioProcessorService: Initialization error - $e');
      rethrow;
    }
  }

  Future<void> start() async {
    if (!_isInitialized) await initialize();
    if (_isProcessing) return;

    try {
      debugPrint('AudioProcessorService: Starting audio capture/playback');
      
      // Ensure session is active
      final session = await AudioSession.instance;
      await session.setActive(true);

      _audioSubscription = _recorder.audioStream.listen((data) {
        _micActivityController.add(data.length);
        if (_webSocketService.isConnected && !_isMicMuted) {
          _webSocketService.sendAudioData(Uint8List.fromList(data));
        }
      });
      await _recorder.start();
      await _player.start();
      
      _isProcessing = true;
      debugPrint('AudioProcessorService: Audio processing started');
    } catch (e) {
      debugPrint('AudioProcessorService: Error starting - $e');
    }
  }

  // Play audio chunk received from server
  Future<void> playAudio(Uint8List audioData) async {
    if (!_isInitialized || !_isProcessing || !_isOutputEnabled) return;
    try {
      await _player.writeChunk(audioData);
    } catch (e) {
      debugPrint('AudioProcessorService: Error playing audio chunk - $e');
    }
  }

  void toggleMute(bool mute) {
    _isMicMuted = mute;
    debugPrint('AudioProcessorService: Microphone muted: $_isMicMuted');
  }

  Future<void> toggleSpeaker(bool useSpeaker) async {
     // Switch Route Logic
     debugPrint('AudioProcessorService: toggleSpeaker request ($useSpeaker)');
     // _isOutputEnabled = useSpeaker; // OLD BAD LOGIC
     // Real Logic: Reconfigure Session?
     // Changing AudioSession on the fly is tricky.
     // For now, let's just create a new configuration request.
     try {
       final session = await AudioSession.instance;
       await session.configure(AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: useSpeaker 
              ? AVAudioSessionCategoryOptions.defaultToSpeaker 
              : AVAudioSessionCategoryOptions.none, // Earpiece
          avAudioSessionMode: AVAudioSessionMode.voiceChat,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
       ));
     } catch (e) {
        debugPrint('AudioProcessorService: Failed to toggle speaker route: $e');
     }
  }
  
  // New helper to gate output without killing session
  void setOutputEnabled(bool enabled) {
     _isOutputEnabled = enabled;
  }

  // HYBRID MODE: Capture Only (Clone Stream for Translation)
  // This attempts to start the recorder WITHOUT starting the player.
  // This is crucial for P2P Hybrid mode to avoid echo.
  Future<void> startCaptureOnly() async {
    if (!_isInitialized) await initialize();
    if (_isProcessing) return;

    try {
      debugPrint('AudioProcessorService: Starting CAPTURE-ONLY (Hybrid Mode)');
      
      // We rely on the AudioSession potentially already being configured by WebRTC or us.
      // We do NOT call setActive(true) aggressively if WebRTC owns it, but we might need to?
      // Let's try just starting the recorder.
      
      _audioSubscription = _recorder.audioStream.listen((data) {
        // Send to Server for Translation
        if (_webSocketService.isConnected && !_isMicMuted) {
           // debugPrint('AudioProcessorService: Sending Hybrid Chunk (${data.length} bytes)');
           _webSocketService.sendAudioData(Uint8List.fromList(data));
        }
      });
      
      await _recorder.start();
      // await _player.start(); // SKYP THIS
      
      _isProcessing = true;
      debugPrint('AudioProcessorService: Capture-Only started');
    } catch (e) {
      debugPrint('AudioProcessorService: Capture-Only Error (Likely Mic Conflict): $e');
      // If this fails, we just don't get translation, but call continues.
    }
  }

  Future<void> stop() async {
    if (!_isProcessing) return;

    try {
      debugPrint('AudioProcessorService: Stopping');
      
      await _audioSubscription?.cancel();
      _audioSubscription = null;
      
      await _recorder.stop();
      await _player.stop();
      
      _isProcessing = false;
      debugPrint('AudioProcessorService: Stopped successfully');
    } catch (e) {
      debugPrint('AudioProcessorService: Error stopping - $e');
    }
  }
}
