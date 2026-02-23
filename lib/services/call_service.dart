import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/call_model.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'websocket_service.dart';
import 'audio_processor_service.dart';
import 'transcript_service.dart';
import 'notification_service.dart';
import '../config/translation_config.dart';
import '../main.dart';
import '../screens/incoming_call_screen.dart';
import 'local_storage_service.dart'; // Added



class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final WebSocketService _webSocketService = WebSocketService();
  final AudioProcessorService _audioProcessorService = AudioProcessorService();
  final TranscriptService _transcriptService = TranscriptService();

  bool _isCallActive = false;
  bool _isUserMuted = false;
  StreamSubscription? _audioDataSubscription;
  StreamSubscription? _incomingCallSubscription;
  StreamSubscription? _callEndedSubscription;
  Timer? _ttsUnmuteTimer;

  // Track Local Service Init State (Audio/WS/etc)
  final ValueNotifier<bool> isServicesInitialized = ValueNotifier(false);

  // Getters
  WebSocketService get webSocketService => _webSocketService;
  TranscriptService get transcriptService => _transcriptService;
  AudioProcessorService get audioProcessor => _audioProcessorService;

  Future<bool> requestMicrophonePermission() async {
    try {
      debugPrint('CallService: Requesting microphone permission');
      final status = await Permission.microphone.request();
      
      if (status.isGranted) {
        debugPrint('CallService: Microphone permission granted');
        return true;
      } else if (status.isDenied) {
        debugPrint('CallService: Microphone permission denied');
        return false;
      } else if (status.isPermanentlyDenied) {
        debugPrint('CallService: Microphone permission permanently denied');
        await openAppSettings();
        return false;
      }
      return false;
    } catch (e) {
      debugPrint('CallService: Error requesting microphone permission: $e');
      return false;
    }
  }

  Future<String> initiateCall({
    required String callerId,
    required String callerName,
    required String callerAvatar,
    required String receiverId,
    required String receiverName,
    required String receiverAvatar,
    bool enableTranslation = true,
  }) async {
    try {
      debugPrint('CallService: Initiating call from $callerName to $receiverName');
      
      final hasPermission = await requestMicrophonePermission();
      if (!hasPermission) {
        throw Exception('Microphone permission is required');
      }

      // Fetch Profile Colors
      int callerColor = await LocalStorageService().getProfileColor();
      int receiverColor = 0;
      String receiverFcmToken = '';
      try {
        final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
        if (receiverDoc.exists && receiverDoc.data() != null) {
           receiverColor = receiverDoc.data()!['profileColor'] ?? 0;
           receiverFcmToken = receiverDoc.data()!['fcmToken'] ?? '';
        }
      } catch (e) {
        debugPrint('CallService: Error fetching receiver color: $e');
      }

      // Handle Not Logged In / No FCM Token
      if (receiverFcmToken.isEmpty) {
        debugPrint('CallService: Receiver has no FCM token. Logging as missed.');
        final callId = _firestore.collection('calls').doc().id;
        final channelId = 'call_$callId';
        
        final callData = CallModel(
          callId: callId,
          callerId: callerId,
          callerName: callerName,
          callerAvatar: callerAvatar,
          receiverId: receiverId,
          receiverName: receiverName,
          receiverAvatar: receiverAvatar,
          callType: CallType.outgoing,
          callStatus: CallStatus.missed, // Mark as missed immediately
          timestamp: DateTime.now(),
          channelId: channelId,
          callerProfileColor: callerColor,
          receiverProfileColor: receiverColor,
        );

        await _firestore.collection('calls').doc(callId).set(callData.toMap());
        
        _showDebugToast('User is currently offline or not logged in.');
        
        return callId; // Return so the caller's UI can stop loading/initiating
      }

      final callId = _firestore.collection('calls').doc().id;
      final channelId = 'call_$callId';
      
      final callData = CallModel(
        callId: callId,
        callerId: callerId,
        callerName: callerName,
        callerAvatar: callerAvatar,
        receiverId: receiverId,
        receiverName: receiverName,
        receiverAvatar: receiverAvatar,
        callType: CallType.outgoing,
        callStatus: CallStatus.ringing,
        timestamp: DateTime.now(),
        channelId: channelId,
        callerProfileColor: callerColor,     // Added
        receiverProfileColor: receiverColor, // Added
      );

      await _firestore.collection('calls').doc(callId).set(callData.toMap());
      
      // Send notification immediately so receiver gets the call event
      await _notificationService.sendCallNotification(
        receiverId: receiverId,
        callerId: callerId,
        callerName: callerName,
        callId: callId,
        receiverToken: receiverFcmToken,
        callerAvatar: callerAvatar,
        callerColor: callerColor,
      );

      // Start translation/audio services in background (don't block UI/Signaling)
      if (enableTranslation) {
        // Pre-connect WebSocket IMMEDIATELY to reduce latency
        _preConnectWebSocket(
           callId: callId, 
           callerId: callerId, 
           receiverId: receiverId, 
           currentUserId: callerId
        ).then((_) => debugPrint('CallService: Pre-connect initiated'));

        // CHANGED: Defer initialization until the call is actually answered (status == ongoing)
        // This prevents the Caller from hearing audio/noise/echo before the connection is established.
        _startMonitoringOutgoingCall(
           callId: callId,
           callerId: callerId,
           receiverId: receiverId,
           currentUserId: callerId,
        );
      }

      return callId;
    } catch (e) {
      debugPrint('CallService: Error initiating call: $e');
      rethrow;
    }
  }

  Future<void> joinCall({
    required String callId,
    required String userId,
    required String userName,
    bool enableTranslation = true,
  }) async {
    try {
      debugPrint('CallService: User $userName joining call $callId');
      
      final callDoc = await _firestore.collection('calls').doc(callId).get();
      if (!callDoc.exists) throw Exception('Call not found');

      final callData = CallModel.fromMap(callDoc.data()!);

      if (enableTranslation) {
        await _initializeCallServices(
          callId: callId,
          callerId: callData.callerId,
          receiverId: callData.receiverId,
          currentUserId: userId,
        );
      }

      await _firestore.collection('calls').doc(callId).update({
        'callStatus': CallStatus.ongoing.name,
      });
      
      
      debugPrint('CallService: Successfully joined call');
    } catch (e) {
      debugPrint('CallService: Error joining call: $e');
      rethrow;
    }
  }

  // --- Call Control Methods (Restored) ---

  Future<void> cancelCall(String callId) async {
    try {
      debugPrint('CallService: Cancelling call $callId');
      
      // Send WebSocket Cancel Signal (Speed up UX for others)
      if (_webSocketService.isConnected) {
         _webSocketService.sendCallControlMessage('cancel_call');
      }

      stopRinging();
      await _notificationService.cancelCallNotification(callId);
      await _firestore.collection('calls').doc(callId).update({
        'callStatus': CallStatus.cancelled.name,
      });
      // Force stop local services
      await _stopCallServices();
    } catch (e) {
      debugPrint('CallService: Error cancelling call: $e');
      rethrow;
    }
  }

  Future<void> declineCall(String callId) async {
    try {
      debugPrint('CallService: Declining call $callId');
      stopRinging();
      await _notificationService.cancelCallNotification(callId);
      await _firestore.collection('calls').doc(callId).update({
        'callStatus': CallStatus.declined.name,
      });
    } catch (e) {
      debugPrint('CallService: Error declining call: $e');
      rethrow;
    }
  }

  Future<void> answerCall(String callId, String currentUserId, String currentUserName) async {
    try {
      debugPrint('CallService: Answering call $callId');
      _isCallActive = true; // LOCK STATE IMMEDIATELY to prevent race condition
      stopRinging();
      await _notificationService.cancelCallNotification(callId);
      
      // Fetch Call Data to get IDs
      final callDoc = await _firestore.collection('calls').doc(callId).get();
      if (!callDoc.exists) throw Exception('Call not found');
      final callData = CallModel.fromMap(callDoc.data()!);

      // Update status to ongoing
      await _firestore.collection('calls').doc(callId).update({
        'callStatus': CallStatus.ongoing.name,
      });

      // Join the call (Initialize services)
      // Note: We use the caller/receiver IDs from the call data
      await _initializeCallServices(
        callId: callId,
        callerId: callData.callerId,
        receiverId: callData.receiverId,
        currentUserId: currentUserId, 
      );
      
    } catch (e) {
      debugPrint('CallService: Error answering call: $e');
      rethrow;
    }
  }

  Future<void> endCall(String callId, [int? duration]) async {
    try {
      debugPrint('CallService: Ending call $callId');
      
      // Send WebSocket End Signal
      if (_webSocketService.isConnected) {
         _webSocketService.sendCallControlMessage('end_call');
      }

      stopRinging();
      await _stopCallServices();
      await _firestore.collection('calls').doc(callId).update({
        'callStatus': CallStatus.ended.name,
        if (duration != null) 'duration': duration,
      });
    } catch (e) {
      debugPrint('CallService: Error ending call: $e');
      // Don't rethrow, just log, as we want to ensure UI closes
    }
  }



  // Monitor outgoing call to start services only when answered
  void _startMonitoringOutgoingCall({
    required String callId,
    required String callerId,
    required String receiverId,
    required String currentUserId,
  }) {
    debugPrint('CallService: Monitoring outgoing call $callId for ANSWER...');
    
    // Cancel any existing subscription for safety
    _incomingCallSubscription?.cancel(); 
    // Re-purpose the subscription variable or create a new one? 
    // _incomingCallSubscription is used for "List of calls". 
    // Let's use a temporary ephemeral listener or store it in a map if multiple calls supported.
    // Since we support 1 active call, we can use a new variable or reused one, but strictly speaking
    // we should track this specific subscription.
    // For now, let's use a specific variable for this monitoring phase.
    
    StreamSubscription<DocumentSnapshot>? monitorSub;
    
    monitorSub = _firestore.collection('calls').doc(callId).snapshots().listen((snapshot) {
      if (!snapshot.exists) {
        monitorSub?.cancel();
        return;
      }

      final data = snapshot.data();
      if (data == null) return;
      
      final statusStr = data['callStatus'];
      
      if (statusStr == CallStatus.ongoing.name) {
         if (!_isCallActive) {
            debugPrint('CallService: Call ANSWERED! Initializing services NOW.');
            _initializeCallServices(
              callId: callId,
              callerId: callerId,
              receiverId: receiverId,
              currentUserId: currentUserId,
            );
         }
         // Stop monitoring once connected (or keep monitoring for end? _initializeCallServices does that)
         // Actually _initializeCallServices sets up _callEndedSubscription
          // So we can cancel this "Start Monitor" once we start.
         monitorSub?.cancel();
      } else if (statusStr == CallStatus.ended.name || 
                 statusStr == CallStatus.declined.name || 
                 statusStr == CallStatus.cancelled.name) {
         debugPrint('CallService: Call ended/declined before answer. Stopping monitor & services.');
         _stopCallServices(); // Cleanup pre-connected socket
         monitorSub?.cancel();
         _callEndedSubscription?.cancel(); // Cancel the WS listener if we added one
      }
    });

    // NEW: Listen for WebSocket "call_ended" signal during ringing phase
    // This handles the case where Peer cancels/declines via WebSocket before answering
    if (_webSocketService.isConnected) {
        _setupRingingCallEndListener(callId, monitorSub);
    } else {
       // Wait for connection
       StreamSubscription? connSub;
       connSub = _webSocketService.connectionStatusStream.listen((isConnected) {
          if (isConnected) {
             // CRITICAL: Only setup listener if we are STILL in ringing phase (not answered yet)
             if (!_isCallActive) {
                _setupRingingCallEndListener(callId, monitorSub);
             }
             connSub?.cancel();
          }
       });
    }
  }

  void _setupRingingCallEndListener(String callId, StreamSubscription<DocumentSnapshot>? monitorSub) {
     debugPrint('CallService: Setting up WS End Call Listener for ringing phase...');
     _callEndedSubscription?.cancel();
     _callEndedSubscription = _webSocketService.callEndedStream.listen((_) {
         debugPrint('CallService: WebSocket signaled Call End during ringing.');
         _stopCallServices();
         monitorSub?.cancel();
         
         // Update Firestore to ensure UI closes
         _firestore.collection('calls').doc(callId).update({
            'callStatus': CallStatus.ended.name
         });
         
         // Force Navigation Pop if applicable
         if (navigatorKey.currentState != null && navigatorKey.currentState!.canPop()) {
             navigatorKey.currentState!.pop();
         }
     });
  }

  // Common initialization logic for both Caller and Receiver
  Future<void> _initializeCallServices({
    required String callId,
    required String callerId,
    required String receiverId,
    required String currentUserId,
  }) async {
    try {
      debugPrint('CallService: Initializing services for $currentUserId');
      _showDebugToast('Init Services: Fetching Users...');
      
      // 1. Get Languages
      final callerDoc = await _firestore.collection('users').doc(callerId).get();
      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      
      final callerLang = callerDoc.data()?['language'] ?? 'en';
      final receiverLang = receiverDoc.data()?['language'] ?? 'en';
      
      // Determine My Lang vs Their Lang
      final String myLang;
      final String theirLang;
      
      if (currentUserId == callerId) {
        myLang = callerLang;
        theirLang = receiverLang;
      } else {
        myLang = receiverLang;
        theirLang = callerLang;
      }
      
      final sourceLang = TranslationConfig.getLanguageCode(myLang);
      final targetLang = TranslationConfig.getLanguageCode(theirLang);

      _showDebugToast('Connecting WS ($sourceLang -> $targetLang)...');

      // 2. Connect WebSocket
      await _webSocketService.connect(
        serverUrl: TranslationConfig.websocketServerUrl,
        roomId: callId,
        sourceLang: sourceLang,
        targetLang: targetLang,
      );

      _showDebugToast('WS Connected! Starting Mic...');

      // 3. WebRTC removed — translation-only audio pipeline

      // 4. Hybrid Mode: Start Audio Processor for Translation (Capture + Playback for TTS)
      try {
        await _audioProcessorService.startCaptureOnly();
        await _audioProcessorService.startPlayback();

        _audioDataSubscription?.cancel();
        _audioDataSubscription = _webSocketService.audioDataStream.listen((audioData) {
          final pcmData = _stripWavHeader(audioData);
          if (pcmData.isEmpty) return;

          final durationMs = _estimateDurationMs(pcmData.length);
          _temporarilyMuteForTts(durationMs);

          _audioProcessorService.playAudio(pcmData);
        });
      } catch (e) {
        debugPrint('CallService: Hybrid Capture/Playback Failed: $e');
      }

      _transcriptService.clearTranscripts();
      _isCallActive = true;
      isServicesInitialized.value = true; // Signal UI that we are READY
      _showDebugToast('WebRTC Active! Talking to ${theirLang}');

      // 5. Listen for Remote End Call Signal (Store subscription to cancel later)
      _callEndedSubscription?.cancel();
      _callEndedSubscription = _webSocketService.callEndedStream.listen((_) {
         debugPrint('CallService: Remote peer disconnected. Ending call.');
         _showDebugToast('Peer disconnected. Call ended.');
         
         // End call logically (stops services)
         _stopCallServices();
         
         // Update Firestore (Fast update)
         _firestore.collection('calls').doc(callId).update({
           'callStatus': CallStatus.ended.name,
         });

         // Navigate Back IMMEDIATELY (Reduce latency to 0.1s)
         if (navigatorKey.currentState != null && navigatorKey.currentState!.canPop()) {
            navigatorKey.currentState!.pop();
         }
      });

    } catch (e) {
      debugPrint('CallService: Error initializing services: $e');
      _showDebugToast('Init Failed: $e');
      _isCallActive = false;
    }
  }

  Future<void> _stopCallServices() async {
    try {
      await _audioDataSubscription?.cancel();
      _audioDataSubscription = null;
      _ttsUnmuteTimer?.cancel();
      _ttsUnmuteTimer = null;

      await _callEndedSubscription?.cancel();
      _callEndedSubscription = null;
      
      await _audioProcessorService.stop(); // Ensure old service is off
      await _webSocketService.disconnect();
      
      await _webSocketService.disconnect();
      
      _isCallActive = false;
      isServicesInitialized.value = false; // Reset
      debugPrint('CallService: Services stopped');
    } catch (e) {
      debugPrint('CallService: Error stopping services: $e');
    }
  }

  Uint8List _stripWavHeader(Uint8List data) {
    // WAV header is 44 bytes and starts with "RIFF"
    if (data.length > 44 &&
        data[0] == 0x52 && // R
        data[1] == 0x49 && // I
        data[2] == 0x46 && // F
        data[3] == 0x46) { // F
      return Uint8List.sublistView(data, 44);
    }
    if (data.length <= 44 &&
        data.length >= 4 &&
        data[0] == 0x52 &&
        data[1] == 0x49 &&
        data[2] == 0x46 &&
        data[3] == 0x46) {
      return Uint8List(0);
    }
    return data;
  }

  int _estimateDurationMs(int pcmBytes) {
    // 16kHz * 16-bit * mono = 32000 bytes/sec
    return ((pcmBytes / 32000) * 1000).ceil();
  }

  void _temporarilyMuteForTts(int durationMs) {
    if (_isUserMuted) return;
    _audioProcessorService.toggleMute(true);
    _ttsUnmuteTimer?.cancel();
    _ttsUnmuteTimer = Timer(Duration(milliseconds: durationMs + 100), () {
      if (_isUserMuted) return;
      _audioProcessorService.toggleMute(false);
    });
  }

  // Pre-connect WebSocket during ringing to eliminate start-up delay
  Future<void> _preConnectWebSocket({
    required String callId,
    required String callerId,
    required String receiverId,
    required String currentUserId,
  }) async {
    try {
      debugPrint('CallService: Pre-connecting WebSocket...');
      
      // Fetch Languages
      final callerDoc = await _firestore.collection('users').doc(callerId).get();
      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      
      final callerLang = callerDoc.data()?['language'] ?? 'en';
      final receiverLang = receiverDoc.data()?['language'] ?? 'en';
      
      final String myLang;
      final String theirLang;
      
      if (currentUserId == callerId) {
        myLang = callerLang;
        theirLang = receiverLang;
      } else {
        myLang = receiverLang;
        theirLang = callerLang;
      }
      
      final sourceLang = TranslationConfig.getLanguageCode(myLang);
      final targetLang = TranslationConfig.getLanguageCode(theirLang);

      // Connect
      await _webSocketService.connect(
        serverUrl: TranslationConfig.websocketServerUrl,
        roomId: callId,
        sourceLang: sourceLang,
        targetLang: targetLang,
      );
      debugPrint('CallService: WebSocket Pre-connected!');
    } catch (e) {
      debugPrint('CallService: Pre-connect warning: $e');
      // Non-fatal, real init will retry
    }
  }

  Stream<CallModel> getCallStream(String callId) {
    return _firestore.collection('calls').doc(callId).snapshots().map((snapshot) {
      if (!snapshot.exists) throw Exception('Call not found');
      return CallModel.fromMap(snapshot.data()!);
    });
  }

  // Modified to remove composite index requirement
  Stream<QuerySnapshot> getIncomingCalls(String userId) {
    return _firestore.collection('calls')
        .where('receiverId', isEqualTo: userId)
        .snapshots();
  }

  // Track active incoming call to prevent duplicate navigation
  String? _currentIncomingCallId;
  String? get currentIncomingCallId => _currentIncomingCallId; // EXPOSED GETTER

  void setIncomingCallId(String id) {
     _currentIncomingCallId = id;
  }

  // Direct Navigation Handler
  void _handleIncomingCall(CallModel callData, {int retryCount = 0}) {
    debugPrint('CallService: Handling Incoming Call Attempt ${retryCount + 1}: ${callData.callId}');

    if (_currentIncomingCallId == callData.callId) {
      debugPrint('CallService: Incoming Call Screen already active for ${callData.callId}. Skipping nav.');
      return;
    }
    
    // Check Lifecycle State
    final state = WidgetsBinding.instance.lifecycleState;
    debugPrint('CallService: App Lifecycle State: $state');
    
    if (navigatorKey.currentState != null && navigatorKey.currentContext != null) {
      debugPrint('CallService: Navigator state found, pushing IncomingCallScreen...');
      _currentIncomingCallId = callData.callId; // Mark as active
      
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => IncomingCallScreen(
            callId: callData.callId,
            callerId: callData.callerId, 
            callerName: callData.callerName,
            callerAvatar: callData.callerAvatar,
            callerProfileColor: callData.callerProfileColor,
          ),
        ),
      ).then((_) {
         debugPrint('CallService: IncomingCallScreen popped for ${callData.callId}');
         // Reset when popped
         if (_currentIncomingCallId == callData.callId) {
            _currentIncomingCallId = null;
         }
      }).catchError((e) {
         debugPrint('CallService: Navigation error: $e');
         _currentIncomingCallId = null;
      });
    } else {
      debugPrint('CallService WARNING: Navigator State is null (Attempt ${retryCount + 1})');
      
      if (retryCount < 10) { // Increased retries from 5 to 10
        // Retry after a longer delay (UI might still be initializing or context switching)
        debugPrint('CallService: Retrying navigation in 800ms...');
        Future.delayed(const Duration(milliseconds: 800), () {
          _handleIncomingCall(callData, retryCount: retryCount + 1);
        });
      } else {
        debugPrint('CallService ERROR: Navigator State remained null after 10 attempts.');
        _showDebugToast('Critical: Could not show call interface (Navigator missing)');
        // Fallback: Show Notification so user can at least tap it to enter app
        try {
          _notificationService.showIncomingCallNotification(
            callId: callData.callId,
            callerId: callData.callerId,
            callerName: callData.callerName,
            callerAvatar: callData.callerAvatar,
          );
        } catch (e) {
          debugPrint('CallService: Error showing fallback notification: $e');
        }
      }
    }
  }

  // Debug Helper: Simulate Incoming Call to test UI Navigation
  void simulateIncomingCall() {
    _showDebugToast('Simulating Fake Call...');
    final dummyCall = CallModel(
      callId: 'test_${DateTime.now().millisecondsSinceEpoch}',
      callerId: 'test_caller',
      callerName: 'Test Simulation',
      callerAvatar: '',
      receiverId: 'me',
      receiverName: 'Me',
      receiverAvatar: '', // Added missing parameter
      callType: CallType.incoming,
      callStatus: CallStatus.ringing,
      timestamp: DateTime.now(),
    );
    _handleIncomingCall(dummyCall);
  }

  // Debug Helper
  void _showDebugToast(String message) {
    debugPrint('CallService Debug: $message');
    try {
      if (navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF0141B5), // Theme Blue
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            behavior: SnackBarBehavior.fixed, // fixed = full width coverage
          ),
        );
      }
    } catch (e) {
      debugPrint('Error showing debug toast: $e');
    }
  }

  bool _isRinging = false; // Debounce flag
  bool get isRinging => _isRinging; // Public getter

  void startRinging() {
    if (_isCallActive) return; // Prevent ringing if in call
    if (_isRinging) return;
    
    // BACKROUND CHECK: If not in foreground, rely on Notification Sound (v6)
    // This prevents Double Audio when App is Active-Backgrounded
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (lifecycleState != null && lifecycleState != AppLifecycleState.resumed) {
       debugPrint('CallService: App is not RESUMED. Skipping App Ringtone to avoid overlap with Notification Sound.');
       return;
    }

    debugPrint('CallService: Starting DEFAULT SYSTEM ringtone');
    _isRinging = true;
    
    // Use System Ringtone as requested
    FlutterRingtonePlayer().playRingtone(
      looping: true, 
      volume: 1.0, 
      asAlarm: false,
    );
  }

  void stopRinging() {
    debugPrint('CallService: Stopping ringtone');
    _isRinging = false;
    FlutterRingtonePlayer().stop();
  }

  bool _isListening = false;
  bool get isListening => _isListening;
  String? _listeningUserId;

  void startListeningForIncomingCalls(String userId) {
    _showDebugToast('Started listening for calls ($userId)');
    debugPrint('CallService: STARTING to listen for calls for user: $userId');
    
    // Avoid re-subscribing if already listening for the same user
    if (_isListening && _listeningUserId == userId) {
      debugPrint('CallService: Already listening for user $userId. Skipping restart.');
      return;
    }

    // Cancel existing subscription to avoid duplicates
    if (_incomingCallSubscription != null) {
      _incomingCallSubscription!.cancel();
      _isListening = false;
    }

    _isListening = true; // Flag as Active Listener
    _listeningUserId = userId;

    _incomingCallSubscription = getIncomingCalls(userId).listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          try {
            final data = change.doc.data() as Map<String, dynamic>;
            
            // FIX: Ghost Calls (Ignore old calls > 5 min)
            if (data['timestamp'] != null) {
               final ts = (data['timestamp'] as Timestamp).toDate();
               if (DateTime.now().difference(ts).inSeconds > 300) {
                  debugPrint('CallService: Ignoring Ghost Call ${change.doc.id} (Age: ${DateTime.now().difference(ts).inSeconds}s)');
                  continue;
               }
            }

            final callData = CallModel.fromMap(data);
            
            // Local Filtering
            if (callData.callStatus == CallStatus.ringing) {
               // FIX: Prevent firing twice if Firestore sends 'added' then 'modified'
               if (_currentIncomingCallId == callData.callId) {
                 debugPrint('CallService: Ignoring duplicate ring event for same Call ID: ${callData.callId}');
                 continue;
               }
               
               if (_isCallActive) continue; // Ignore if we are already in a call

               // Don't set currentIncomingCallId yet; _handleIncomingCall will set it
               // only when navigation actually happens. This avoids blocking the first UI push.

               _showDebugToast('INCOMING CALL: ${callData.callerName}');
               debugPrint('CallService: DETECTED INCOMING CALL: ${callData.callId} from ${callData.callerName}');
               

               // 1. Play System Ringtone
               try {
                 startRinging();
               } catch (e) {
                 debugPrint('CallService: Error starting ringtone: $e');
               }
               
               // 2. CHECK APP STATE: If we are in foreground, push the screen.
               // If we are not resumed (background), rely on the full-screen notification instead.
               final lifecycleState = WidgetsBinding.instance.lifecycleState;
               // Treat null as foreground to avoid missing UI on some devices
               final isForeground = lifecycleState == null || lifecycleState == AppLifecycleState.resumed;

               if (isForeground) {
                 try {
                   _handleIncomingCall(callData);
                 } catch (e) {
                   debugPrint('CallService: Error handling incoming call UI: $e');
                 }
               } else {
                 try {
                   _notificationService.showIncomingCallNotification(
                     callId: callData.callId,
                     callerId: callData.callerId,
                     callerName: callData.callerName,
                     callerAvatar: callData.callerAvatar,
                   );
                 } catch (e) {
                   debugPrint('CallService: Error showing notification: $e');
                 }
               }
            } else if (callData.callStatus == CallStatus.declined || 
                       callData.callStatus == CallStatus.cancelled || 
                       callData.callStatus == CallStatus.ended ||
                       callData.callStatus == CallStatus.busy) {
               // Stop ringing if call is cancelled/ended remotely
               stopRinging();
               _notificationService.cancelCallNotification(callData.callId);
               if (_currentIncomingCallId == callData.callId) {
                 _currentIncomingCallId = null;
               }
            }
          } catch (e) {
            debugPrint('CallService: Error processing document change: $e');
          }
        }
      }
    }, onError: (e) {
      _showDebugToast('Error listening: $e');
      debugPrint('CallService: Error listening for calls: $e');
    });
  }

  Future<void> toggleMicrophone(bool mute) async {
    try {
      debugPrint('CallService: ${mute ? "Muting" : "Unmuting"} microphone');
      _isUserMuted = mute;
      _audioProcessorService.toggleMute(mute);
    } catch (e) {
      debugPrint('CallService: Error toggling microphone: $e');
    }
  }

  Future<void> toggleSpeaker(bool useSpeaker) async {
    try {
      debugPrint('CallService: Setting speaker enabled: $useSpeaker');
      await _audioProcessorService.toggleSpeaker(useSpeaker);
    } catch (e) {
      debugPrint('CallService: Error toggling speaker: $e');
    }
  }

  Stream<List<CallModel>> getCallHistory(String userId) {
    // Create a stream that emits immediately, then every 5 seconds
    final controller = StreamController<List<CallModel>>();
    
    Future<void> fetch() async {
      try {
        final callerSnapshot = await _firestore.collection('calls').where('callerId', isEqualTo: userId).get();
        final receiverSnapshot = await _firestore.collection('calls').where('receiverId', isEqualTo: userId).get();
        final allCalls = <CallModel>[];
        
        for (var doc in callerSnapshot.docs) allCalls.add(CallModel.fromMap(doc.data()));
        for (var doc in receiverSnapshot.docs) allCalls.add(CallModel.fromMap(doc.data()));
        
        allCalls.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        if (!controller.isClosed) {
          controller.add(allCalls.take(50).toList());
        }
      } catch (e) {
        debugPrint('Error getting call history: $e');
        if (!controller.isClosed) controller.add([]);
      }
    }

    // Initial fetch
    fetch();
    
    // Periodic timer
    final timer = Timer.periodic(const Duration(seconds: 5), (_) => fetch());
    
    controller.onCancel = () {
      timer.cancel();
      controller.close();
    };
    
    return controller.stream;
  }


}
