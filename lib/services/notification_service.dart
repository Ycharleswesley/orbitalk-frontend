import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data'; // Added for Int64List
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../main.dart'; // Import for navigator key
import 'package:firebase_core/firebase_core.dart'; // Added for Firebase.initializeApp()
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../screens/incoming_call_screen.dart';
import '../screens/chat_detail_screen.dart';
import 'call_service.dart'; // Added
import '../config/translation_config.dart';

// Top-level function for background message handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized
  await Firebase.initializeApp();

  debugPrint('Handling background message: \x1B[32m\x1B[1m${message.messageId}\x1B[0m');

  // Check for Call Notification
  final data = message.data;
  final isCall = data['type'] == 'call' || (data['callId'] != null);

  if (isCall) {
     final callId = data['callId'];
     final callerName = data['callerName'] ?? 'Unknown';
     final callerId = data['callerId'] ?? '';
     
     if (callId != null) {
       debugPrint('Background Handler: Showing Incoming Call Notification for $callId');
       
       // Save to SharedPreferences for UI to pick up on resume/launch
       try {
         // We need to use a separate instance since we are in a background isolate? 
         // SharedPreferences usually works fine if we await reload, but let's just write.
         // Note: SharedPreferences.getInstance() might be async heavy in bg.
         // We will try.
         // Check if we can use a platform channel. SharedPreferences is standard.
       } catch (e) {
         debugPrint('Error saving background call pref: $e');
       }
       
       // REMOVED Ringtone Player here to prevent overlap with System Ringtone played by App
       // FlutterRingtonePlayer().play(...) 


       // Show Notification with Actions
       final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
       
       final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'orbitalk_calls_silent_v4', // FORCE NEW CHANNEL for POP UP
        'Incoming Call (Silent v4)',
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true, // CRITICAL: This attempts to launch the app
        category: AndroidNotificationCategory.call,
        actions: [
          AndroidNotificationAction('accept', 'Accept', icon: DrawableResourceAndroidBitmap('ic_call_answer'), showsUserInterface: true, titleColor: Color(0xFF4CAF50)),
          AndroidNotificationAction('decline', 'Decline', icon: DrawableResourceAndroidBitmap('ic_call_decline'), showsUserInterface: false, titleColor: Color(0xFFE53935)),
        ],
        playSound: false, // Handled by RingtonePlayer
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]), // Force Pop-up
        timeoutAfter: 60000, // Auto-cancel after 60s
        visibility: NotificationVisibility.public,
      );
      
      await flutterLocalNotificationsPlugin.show(
        callId.hashCode, 
        'Incoming Call', 
        '$callerName is calling...', 
        NotificationDetails(android: androidDetails),
        payload: 'call_$callId|$callerId',
      );
     }
  } else {
     // Handle Chat Message
     if (message.notification != null) {
       return;
     }
  }
}

// Top-Level background notification action handler
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('notificationTapBackground: ${notificationResponse.actionId}');
  // We don't need to do much here if fullScreenIntent works, except manage decline.
  if (notificationResponse.actionId == 'decline') {
      _handleBackgroundDecline(notificationResponse.payload);
  }
}

Future<void> _handleBackgroundDecline(String? payload) async {
  if (payload != null && payload.startsWith('call_')) {
     final callId = payload.replaceAll('call_', '').split('|')[0];
     await Firebase.initializeApp();
     await FirebaseFirestore.instance.collection('calls').doc(callId).update({
       'callStatus': 'declined'
     });
     FlutterRingtonePlayer().stop();
     final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
     await flutterLocalNotificationsPlugin.cancel(callId.hashCode);
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Initialize notifications
  Future<void> initialize() async {
    try {
      debugPrint('🔄 Initializing Notification Service...');

      // Request permission - MOVED TO PERMISSION SCREEN
      // debugPrint('📱 Requesting FCM permission...');
      // NotificationSettings settings = await _fcm.requestPermission(
      //   alert: true,
      //   announcement: true,
      //   badge: true,
      //   carPlay: false,
      //   criticalAlert: false,
      //   provisional: false,
      //   sound: true,
      // );
      
      // debugPrint('🔐 FCM Permission status: ${settings.authorizationStatus}');

      // Initialize local notifications
      debugPrint('🔔 Initializing local notifications...');
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('🔔 Notification clicked: ${response.payload}, Action: ${response.actionId}');
          
          if (response.actionId == 'decline') {
             _handleDeclineAction(response.payload);
          } else if (response.actionId == 'accept') {
             // Pass autoAnswer = true
             _handleNotificationTap(response.payload, autoAnswer: true);
          } else {
             _handleNotificationTap(response.payload);
          }
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      // Create notification channels
      debugPrint('📢 Creating notification channels...');
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'orbitalk_channel_v3',
        'UTELO Messages',
        description: 'This channel is used for message notifications.',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      const AndroidNotificationChannel callChannel = AndroidNotificationChannel(
        'orbitalk_calls_v3',
        'UTELO Calls',
        description: 'This channel is used for missed call notifications.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      );

      final AndroidNotificationChannel silentCallChannel = AndroidNotificationChannel(
        'orbitalk_calls_silent_v4', // UPDATED ID to force refresh
        'Incoming Call (Silent v4)',
        description: 'Silent channel for incoming calls (Ringtone handled by app)',
        importance: Importance.max,
        playSound: false, // EXPLICITLY FALSE
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
        enableLights: true,
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(channel);
          await androidPlugin.createNotificationChannel(callChannel);
          await androidPlugin.createNotificationChannel(silentCallChannel);
      }
      debugPrint('✅ Notification channels created');

// ... (skipping unchanged lines) ...

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'orbitalk_calls_silent_v4', // Use Silent Channel v4
        'Incoming Call (Silent v4)',
        importance: Importance.max,
      );
      debugPrint('🔑 Getting FCM token (Async)...');
      _fcm.getToken().then((token) async {
         debugPrint('📋 FCM Token retrieved: ${token != null ? 'SUCCESS' : 'NULL'}');
         if (token != null && token.isNotEmpty) {
           debugPrint('🔐 FCM Token: $token');
           await _authService.updateFCMToken(token);
         }
      }).catchError((e) {
         debugPrint('❌ Error getting FCM token: $e');
      });

      // Listen for token refresh
      debugPrint('🔄 Setting up token refresh listener...');
      _fcm.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM Token refreshed: $newToken');
        _authService.updateFCMToken(newToken);
      });

      // Set up foreground notification handler
      debugPrint('📨 Setting up foreground message handler...');
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📨 Got foreground message: ${message.messageId}');
        _handleForegroundMessage(message);
      });

      // Set up background message handler
      debugPrint('📨 Setting up background message handler...');
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Handle notification when app is opened from terminated state
      debugPrint('📨 Checking for initial message...');
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('📨 Handling initial message: ${initialMessage.messageId}');
        _handleNotificationTap(initialMessage.data['chatRoomId']);
      }

      // Handle notification when app is in background and opened
      debugPrint('📨 Setting up message opened app handler...');
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('📨 App opened from notification: ${message.messageId}');
        _handleNotificationTap(message.data['chatRoomId']);
      });

      debugPrint('✅ Notification Service initialization complete!');
    } catch (error) {
      debugPrint('❌ Error initializing Notification Service: $error');
      rethrow;
    }
  }

  String? _currentChatRoomId;

  void setCurrentChatRoomId(String? id) {
    _currentChatRoomId = id;
    debugPrint('NotificationService: Current Chat Room ID set to: $_currentChatRoomId');
  }

  // Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String? groupKey, // Added for grouping
  }) async {
    
    // Create Android Notification Details with Grouping
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'orbitalk_channel',
      'UTELO Messages',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      groupKey: groupKey, // Group notifications by sender/chat
    );

    final NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // Handle foreground messages (decide whether to show notification)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final msgChatRoomId = message.data['chatRoomId'];
    
    // 1. SUPPRESS if user is currently in this chat
    if (_currentChatRoomId != null && msgChatRoomId == _currentChatRoomId) {
      debugPrint('NotificationService: Suppressing notification for active chat: $msgChatRoomId');
      return; 
    }
    // 2. CHECK FOR CALL (Direct Push)
    // FIX: Unconditionally suppress Call Notifications in Foreground.
    // CallService (Firestore Listener) handles the UI.
    // This prevents "Double Screens" and "Double Audio".
    final data = message.data;
    final payload = data['payload'] ?? '';
    
    if (data['type'] == 'call' || data['callId'] != null || payload.toString().startsWith('call_')) {
       debugPrint('NotificationService: Foreground Call Message -> Suppressing (CallService handles UI).');
       return;
    }


    if (message.notification != null) {
      await _showLocalNotification(
        title: message.notification!.title ?? 'New Message',
        body: message.notification!.body ?? '',
        payload: msgChatRoomId,
        groupKey: msgChatRoomId, // Group by Chat Room ID
      );
    }
  }

  // Handle Decline Action
  Future<void> _handleDeclineAction(String? payload) async {
       if (payload != null && payload.startsWith('call_')) {
         final callId = payload.replaceAll('call_', '');
         debugPrint('NotificationService: Declining call $callId via Action Button');
                  // Visual Update FIRST (Optimize perceived speed)
          await _localNotifications.cancel(callId.hashCode);
          FlutterRingtonePlayer().stop();
          
          
          // Logic Update
         try {
            await _firestore.collection('calls').doc(callId).update({
              'callStatus': 'declined'
            });
         } catch (e) {
            debugPrint('Error updating declined call: $e');
         }
       }
  }

  // Handle notification tap (navigate to chat or call)
  void _handleNotificationTap(String? payload, {bool autoAnswer = false}) async {
    if (payload == null) return;
    
    debugPrint('NotificationService: Handling tap with payload: $payload (AutoAnswer: $autoAnswer)');
    
    if (navigatorKey.currentState == null) {
      debugPrint('NotificationService Error: Navigator State is null!');
      return;
    }

    if (payload.startsWith('call_')) {
      final parts = payload.replaceAll('call_', '').split('|');
      final callId = parts[0];
      String callerId = parts.length > 1 ? parts[1] : '';
      
      // STOP Notification Sound Immediately (Non-blocking)
      cancelCallNotification(callId);
      
      // Fetch missing caller info (or verify status)
      String callerName = 'Caller';
      String callerAvatar = '';
      int callerProfileColor = 0;
      try {
        final callDoc = await _firestore.collection('calls').doc(callId).get();
        final callData = callDoc.data();
        if (callDoc.exists && callData != null) {
          final status = callData['callStatus'];
          if (status != 'ringing' && status != 'ongoing') {
            debugPrint('NotificationService: Call $callId not active ($status). Ignoring.');
            return;
          }
          callerId = callerId.isNotEmpty ? callerId : (callData['callerId'] ?? '');
          callerName = callData['callerName'] ?? callerName;
          callerAvatar = callData['callerAvatar'] ?? callerAvatar;
          callerProfileColor = callData['callerProfileColor'] ?? callerProfileColor;
        }
      } catch (e) {
        debugPrint('NotificationService: Error fetching call info: $e');
      }

      if (callerId.isEmpty) {
        debugPrint('NotificationService: Missing callerId for call $callId. Falling back to in-app listener.');
        return;
      }

      // CHECK DUPLICATE: If CallService is already handling this (e.g. Listener fired first), abort.
      if (CallService().currentIncomingCallId == callId) {
         debugPrint('NotificationService: Call $callId is ALREADY ACTIVE in CallService. Skipping duplicate navigation.');
         return;
      }

      // Register call with CallService to prevent duplicate push from Firestore Listener
      CallService().setIncomingCallId(callId);

      // Navigate to Incoming Call Screen (DIRECT - NO ANIMATION)
      navigatorKey.currentState!.push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => IncomingCallScreen(
            callId: callId,
            callerId: callerId, 
            callerName: callerName, 
            callerAvatar: callerAvatar,
            callerProfileColor: callerProfileColor,
            autoAnswer: autoAnswer, 
          ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } else {
      // Assume Chat Room ID
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => ChatDetailScreen(
             contactId: '', 
             contactName: 'Chat',
             contactAvatar: '',
          ),
        ),
      );
    }
  }

  // Handle message when app is opened from notification (legacy method - keeping for compatibility)
  void _handleMessage(RemoteMessage message) {
    debugPrint('Handling message: ${message.messageId}');
    final chatRoomId = message.data['chatRoomId'];
    if (chatRoomId != null) {
      _handleNotificationTap(chatRoomId);
    }
  }

  // Send message notification to specific user
  Future<void> sendMessageNotification({
    required String receiverId,
    required String senderId,
    required String message,
  }) async {
    try {
      // Get receiver's FCM token
      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      final fcmToken = receiverDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('Receiver has no FCM token');
        return;
      }

      // Get sender's name
      final senderDoc = await _firestore.collection('users').doc(senderId).get();
      final senderName = senderDoc.data()?['name'] as String? ?? 'Someone';

      // Note: Sending notifications from client is not recommended in production.
      // Use Firebase Cloud Functions or your backend server to send notifications.
      // This is just for demonstration purposes.
      debugPrint('Would send notification to: $fcmToken');
      debugPrint('From: $senderName');
      debugPrint('Message: $message');
    } catch (e) {
      debugPrint('Error sending message notification: $e');
    }
  }

  // Show Incoming Call Notification with Full Screen Intent (Updated Style)
   Future<void> showIncomingCallNotification({
    required String callId,
    required String callerId,
    required String callerName,
    required String callerAvatar,
  }) async {
    try {
      debugPrint('NotificationService: Showing Full Screen Call Notification');
      
      // REMOVED Audio Trigger: CallService handles audio (System Ringtone)
      // Notification is purely for visual Heads-Up Display
      
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'orbitalk_calls_ringing_v6', // Use Silent Channel v5
        'Incoming Call (Ringing v6)',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.call,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
        playSound: true, // Silent (We use FlutterRingtonePlayer)
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]), // Force Pop-up
        color: Colors.blue, // Blue Theme (App Primary)
        timeoutAfter: 60000, // 60s timeout to match timeout logic
        actions: [
          AndroidNotificationAction('accept', 'Accept', icon: DrawableResourceAndroidBitmap('ic_call_answer'), showsUserInterface: true, titleColor: Color(0xFF4CAF50)),
          AndroidNotificationAction('decline', 'Decline', icon: DrawableResourceAndroidBitmap('ic_call_decline'), showsUserInterface: false, titleColor: Color(0xFFE53935)),
        ],
      );

      final NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

      await _localNotifications.show(
        callId.hashCode,
        'Incoming Call',
        '$callerName is calling...',
        notificationDetails,
        payload: 'call_$callId|$callerId',
      );
    } catch (e) {
      debugPrint('NotificationService: Error showing call notification: $e');
    }
  }

  // Send call notification (Backend Trigger Placeholder)
  Future<void> sendCallNotification({
    required String receiverId,
    required String callerId,
    required String callerName,
    required String callId,
    String? receiverToken,
    String? callerAvatar,
    int? callerColor,
  }) async {
    try {
      if (receiverToken == null || receiverToken.isEmpty) {
        debugPrint('NotificationService: Missing receiver FCM token. Skipping push.');
        return;
      }

      final uri = Uri.parse('${TranslationConfig.httpServerUrl}/notify-call');
      final payload = {
        'token': receiverToken,
        'callId': callId,
        'callerId': callerId,
        'callerName': callerName,
        'callerAvatar': callerAvatar ?? '',
        'callerColor': (callerColor ?? 0).toString(),
      };

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('NotificationService: Push failed (${response.statusCode}) ${response.body}');
      } else {
        debugPrint('NotificationService: Call push sent successfully');
      }
    } catch (e) {
      debugPrint('NotificationService: Error in call notification: $e');
    }
  }

  // Cancel call notification
  Future<void> cancelCallNotification(String callId) async {
    try {
      await _localNotifications.cancel(callId.hashCode);
      debugPrint('NotificationService: Call notification cancelled for $callId');
    } catch (e) {
      debugPrint('NotificationService: Error cancelling call notification: $e');
    }
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }
}
