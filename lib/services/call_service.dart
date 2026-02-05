import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/call_model.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'websocket_service.dart';
import 'audio_processor_service.dart';
import 'webrtc_service.dart';
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
  final WebRTCService _webRTCService = WebRTCService();
  final TranscriptService _transcriptService = TranscriptService();

  bool _isCallActive = false;
  StreamSubscription? _audioDataSubscription;
  StreamSubscription? _incomingCallSubscription;
  StreamSubscription? _callEndedSubscription;

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
      stopRinging();
      await _notificationService.cancelCallNotification(callId);
      await _firestore.collection('calls').doc(callId).update({
        'callStatus': CallStatus.cancelled.name,
      });
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

      // 3. Start WebRTC (Replacing AudioProcessor)
      await _webRTCService.initialize(
        roomId: callId,
        remoteUserId: currentUserId == callerId ? receiverId : callerId
      );

      // Listen for Signaling Messages (Offer/Answer/Candidate)
      _webSocketService.signalingStream.listen((data) {
         final type = data['type'];
         final payload = data['payload']; // If nested, or directly 'sdp'?
         // My Helper sends {type: signaling, payload: {...}}
         // But wait, the stream returns the inner payload or outer?
         // In WebSocketService: _signalingController.add(data);
         // "data" is the parsed JSON of the message. 
         // But the message structure is: {type: signaling, payload: {type: offer, sdp: ...}}
         
         if (payload != null) {
            final sigType = payload['type'];
            if (sigType == 'offer') {
               _webRTCService.handleOffer(payload['sdp']);
            } else if (sigType == 'answer') {
               _webRTCService.handleAnswer(payload['sdp']);
            } else if (sigType == 'candidate') {
               _webRTCService.handleCandidate(payload['candidate']);
            }
         }
      });

      // If Caller -> Make Offer
      if (currentUserId == callerId) {
         await _webRTCService.makeCall();
      }

      // 4. Hybrid Mode: Start Audio Processor for Translation (Capture Only)
      // This sends audio to Server for STT -> Translation -> Transcript
      try {
        await _audioProcessorService.startCaptureOnly();
      } catch (e) {
        debugPrint('CallService: Hybrid Capture Failed (Mic Busy?): $e');
      }

      // We do NOT listen to _audioDataSubscription for playback to avoid echo/conflict
      // unless we want to hear the TTS. For now, let's prioritize TEXT translation.

      _transcriptService.clearTranscripts();
      _isCallActive = true;
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

      await _callEndedSubscription?.cancel();
      _callEndedSubscription = null;
      
      await _audioProcessorService.stop(); // Ensure old service is off
      await _webRTCService.dispose(); // WebRTC Dispose
      await _webSocketService.disconnect();
      
      _isCallActive = false;
      debugPrint('CallService: Services stopped');
    } catch (e) {
      debugPrint('CallService: Error stopping services: $e');
    }
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
    if (navigatorKey.currentState != null) {
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
      
      if (retryCount < 5) {
        // Retry after a short delay (UI might still be initializing or context switching)
        debugPrint('CallService: Retrying navigation in 500ms...');
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleIncomingCall(callData, retryCount: retryCount + 1);
        });
      } else {
        debugPrint('CallService ERROR: Navigator State remained null after 5 attempts.');
        _showDebugToast('Critical: Could not show call interface (Navigator missing)');
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
            content: Text(message),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.blueAccent,
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
            
            // FIX: Ghost Calls (Ignore old calls > 60s)
            if (data['timestamp'] != null) {
               final ts = (data['timestamp'] as Timestamp).toDate();
               if (DateTime.now().difference(ts).inSeconds > 60) {
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

               // Mark this call as active immediately to prevent re-entry
               setIncomingCallId(callData.callId);

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
      // _audioProcessorService.toggleMute(mute);
      _webRTCService.toggleMute(mute);
    } catch (e) {
      debugPrint('CallService: Error toggling microphone: $e');
    }
  }

  Future<void> toggleSpeaker(bool useSpeaker) async {
    try {
      debugPrint('CallService: Setting speaker enabled: $useSpeaker');
      // _audioProcessorService.toggleSpeaker(useSpeaker);
      _webRTCService.toggleSpeaker(useSpeaker);
    } catch (e) {
      debugPrint('CallService: Error toggling speaker: $e');
    }
  }

  Stream<List<CallModel>> getCallHistory(String userId) {
    return Stream.periodic(const Duration(seconds: 2)).asyncMap((_) async {
      try {
        final callerSnapshot = await _firestore.collection('calls').where('callerId', isEqualTo: userId).get();
        final receiverSnapshot = await _firestore.collection('calls').where('receiverId', isEqualTo: userId).get();
        final allCalls = <CallModel>[];
        
        for (var doc in callerSnapshot.docs) allCalls.add(CallModel.fromMap(doc.data()));
        for (var doc in receiverSnapshot.docs) allCalls.add(CallModel.fromMap(doc.data()));
        
        allCalls.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return allCalls.take(50).toList(); // Limit to 50
      } catch (e) {
        debugPrint('Error getting call history: $e');
        return [];
      }
    });
  }


}
