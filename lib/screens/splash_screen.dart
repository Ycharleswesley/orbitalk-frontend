import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Restored
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart'; // Added
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added
import '../widgets/gradient_background.dart';
import '../widgets/utelo_logo.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import '../services/settings_service.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'permission_screen.dart';
import '../services/notification_service.dart';
import '../services/encryption_service.dart';
import '../main.dart'; // Added for navigatorKey
import 'incoming_call_screen.dart'; // Added
import '../services/call_service.dart'; // Added

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override 
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final AuthService _authService = AuthService();
  final LocalStorageService _localStorage = LocalStorageService();
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    // 2.0 seconds total: Fade In/Hold/Fade Out
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _fadeAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 35, // Fade In
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 30, // Hold
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 35, // Fade Out
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.8, end: 1.0),
        weight: 40, 
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 60,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));
    
    _startFlow();
  }

  Future<void> _startFlow() async {
    // 1. Check for Fast Track (Call Notification) immediately
    final isCall = await _checkFastTrack();
    if (isCall) return;

    // 2. Normal Flow: Start animation
    final animationFuture = _controller.forward().then((_) => null);

    // 3. Wait for BOTH: Animation completion AND Auth logic
    await Future.wait([
      animationFuture,
      _checkAuthAndNavigate(),
    ]);
  }

  Future<bool> _checkFastTrack() async {
     try {
       // 1. Check FCM Initial Message (standard push)
       RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
       if (initialMessage != null && initialMessage.data['callId'] != null) {
          debugPrint('Splash: FAST TRACK (FCM) -> Skipping animation.');
          _handleFastTrack(
             callId: initialMessage.data['callId'],
             callerId: initialMessage.data['callerId'],
             callerName: initialMessage.data['callerName'],
             callerAvatar: initialMessage.data['callerAvatar'],
             callerColor: initialMessage.data['callerColor']
          );
          return true;
       }
       
       // 2. Check FlutterLocalNotifications Launch Details (FullScreenIntent)
       final notificationAppLaunchDetails = await FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails();
       if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
          final payload = notificationAppLaunchDetails!.notificationResponse?.payload;
          if (payload != null && payload.startsWith('call_')) {
              debugPrint('Splash: FAST TRACK (LocalNotif) -> Skipping animation with payload: $payload');
              
              final parts = payload.replaceAll('call_', '').split('|');
              final callId = parts[0];
              final callerId = parts.length > 1 ? parts[1] : '';
              
              // We might lack name/avatar in payload, but we can fetch or display placeholder
              _handleFastTrack(
                 callId: callId,
                 callerId: callerId,
                 callerName: 'Caller', // Will update via Stream in screen
                 callerAvatar: '',
                 callerColor: '0'
              );
              return true;
          }
       }
       
     } catch (e) {
       debugPrint('Error checking fast track: $e');
     }
     return false;
  }

  void _handleFastTrack({
    required String? callId,
    required String? callerId,
    required String? callerName,
    required String? callerAvatar,
    required String? callerColor,
  }) async {
      NotificationService().initialize();
      EncryptionService().initialize();
      await _localStorage.sync();
      await _settingsService.loadSettings();

      User? currentUser = _authService.currentUser;
      if (currentUser != null) {
         await _localStorage.saveUserId(currentUser.uid);
         await _authService.updateOnlineStatus(true);
         
         final validCallId = callId ?? '';
         final validCallerId = callerId ?? '';
         
      // Verify Call Status before navigating
      try {
          final callDoc = await FirebaseFirestore.instance.collection('calls').doc(validCallId).get();
          final callData = callDoc.data();
          
          if (callDoc.exists && callData != null) {
             final status = callData['callStatus'];
             final resolvedCallerId = (validCallerId.isNotEmpty)
                 ? validCallerId
                 : (callData['callerId'] ?? '');
             final resolvedCallerName = (callerName != null && callerName.isNotEmpty)
                 ? callerName
                 : (callData['callerName'] ?? 'Caller');
             final resolvedCallerAvatar = (callerAvatar != null && callerAvatar.isNotEmpty)
                 ? callerAvatar
                 : (callData['callerAvatar'] ?? '');
             final resolvedCallerColor = int.tryParse(callerColor ?? '') ??
                 (callData['callerProfileColor'] ?? 0);

             // Only navigate if Active
             if (status == 'ringing' || status == 'ongoing') {
                     if (mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const MainScreen()),
                        );
                        
                        if (resolvedCallerId.isNotEmpty) {
                          // Register with CallService to prevent duplicate push from listener
                          CallService().setIncomingCallId(validCallId);
                          navigatorKey.currentState?.push(
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) => IncomingCallScreen(
                                callId: validCallId,
                                callerId: resolvedCallerId,
                                callerName: resolvedCallerName,
                                callerAvatar: resolvedCallerAvatar,
                                callerProfileColor: resolvedCallerColor,
                              ),
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          );
                        } else {
                          debugPrint('Splash: Fast Track missing callerId. Falling back to MainScreen listener.');
                        }
                     }
                     return;
                } else {
                   debugPrint('Splash: Fast Track aborted. Call status is $status (Not active).');
                   NotificationService().cancelCallNotification(validCallId);
                }
          }
         } catch (e) {
             debugPrint('Splash: Error verifying call status: $e');
         }

         // Fallback: Proceed to Main Screen normally
          if (mounted) {
             Navigator.pushReplacement(
               context,
               MaterialPageRoute(builder: (context) => const MainScreen()),
             );
          }
      } else {
         if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
         }
      }
  }

  Future<void> _checkAuthAndNavigate() async {
    // Fire and forget services (don't block Splash)
    NotificationService().initialize();
    EncryptionService().initialize();
    
    // Force disk read for SharedPreferences (Fix for Tablet Auto-Logout)
    await _localStorage.sync();

    // Run initialization - remove artificial delay to be as fast as possible
    await _settingsService.loadSettings();
    
    if (!mounted) return;
    
    try {
      // Logic for authenticated navigation continues...


      // Check if first launch - show permission screen
      final isFirstLaunch = await _settingsService.isFirstLaunch();
      if (isFirstLaunch) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const PermissionScreen()),
          );
        }
        return;
      }
      
      // 1. Check Firebase User (Source of Truth)
      User? currentUser = _authService.currentUser;
      
      // 2. Check Local Storage (Backup/Intent)
      final isAuthenticatedLocal = await _authService.isAuthenticated();
      
      debugPrint('Splash: Auth Check -> Firebase: ${currentUser?.uid}, Local: $isAuthenticatedLocal');

      // CASE A: Firebase is Ready immediately
      if (currentUser != null) {
         debugPrint('Splash: Valid Firebase Session found. Checking Permissions...');
         // Ensure local state is synced
         if (!isAuthenticatedLocal) {
             await _localStorage.saveAuthState(true);
             await _localStorage.saveUserId(currentUser.uid);
         }
         
         // STRICT PERMISSION CHECK
         // Even if logged in, if permissions are missing (cleared data?), go to Permission Screen.
         final micStatus = await Permission.microphone.status;
         // final notifStatus = await Permission.notification.status; // Android 13+

         if (!micStatus.isGranted) {
             debugPrint('Splash: Permissions missing. Redirecting to PermissionScreen.');
             if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const PermissionScreen()),
                );
             }
             return;
         }

         await _navigateToMain(currentUser.uid);
         return;
      }

      // CASE B: Local says "Logged In" but Firebase is null (Sync lag or Offline)
      if (isAuthenticatedLocal && currentUser == null) {
        debugPrint('Splash: Local auth true but Firebase not ready. Waiting for session restore...');
        try {
           // increased timeout to 15s to be safe
           await _authService.authStateChanges.firstWhere((user) => user != null)
               .timeout(const Duration(seconds: 15));
           
           // Refetch user
           currentUser = _authService.currentUser;
           
           if (currentUser != null) {
               debugPrint('Splash: Session restored successfully.');
               await _navigateToMain(currentUser.uid);
               return;
           }
        } catch (e) {
          debugPrint('Splash: Auth sync timed out: $e');
          // OFFLINE FALLBACK / SLOW CONNECTION
          // If we are locally authenticated, do NOT logout. Proceed to Main.
          final userId = await _localStorage.getUserId();
          if (userId != null && isAuthenticatedLocal) {
               debugPrint('Splash: Timed out but locally auth found ($userId). Proceeding to Main in OFFLINE/Cached mode.');
               await _navigateToMain(userId);
               return; 
          }
        }
      }
      
      // CASE C: No User, No Local (or sync failed) -> Login
      debugPrint('Splash: No valid session. Navigating to Login.');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }

    } catch (e) {
      debugPrint('Error checking auth status: $e');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  Future<void> _navigateToMain(String userId) async {
      // Load vital user data before transition
      final userProfile = await _authService.getUserProfile(userId);
        
      if (userProfile != null) {
          await _localStorage.saveUserId(userId); // Redundant but safe
          
          if (userProfile['name'] != null) await _localStorage.saveUserName(userProfile['name']);
          if (userProfile['profilePicture'] != null) await _localStorage.saveProfilePicture(userProfile['profilePicture']);
          if (userProfile['phoneNumber'] != null) await _localStorage.savePhoneNumber(userProfile['phoneNumber']);
      }
      
      await _authService.updateOnlineStatus(true);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        withOpacity: false,
        child: SafeArea(
          child: Stack(
            children: [
              // Logo and app name in center
              Center(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: const UteloLogo(
                          logoSize: 150,
                          fontSize: 40,
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Bottom section with company info
              Positioned(
                left: 0,
                right: 0,
                bottom: 50,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Designed & Developed by',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Image.asset(
                        'assets/pramahasoftLogo.png',
                        height: 60,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
