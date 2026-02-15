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

class _SplashScreenState extends State<SplashScreen> {
  double _opacity = 0.0;
  final AuthService _authService = AuthService();
  final LocalStorageService _localStorage = LocalStorageService();
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _startFlow();
  }

  Future<void> _startFlow() async {
    // 1. Check for Fast Track first
    final isCall = await _checkFastTrack();
    if (isCall) return;

    // Wait a frame to ensure widget is mounted before animating
    await Future.delayed(const Duration(milliseconds: 100));

    // 2. Fade In
    if (mounted) {
      setState(() {
        _opacity = 1.0;
      });
    }

    // 3. Load Resources while holding (Minimum 2.3 seconds)
    final minHold = Future.delayed(const Duration(milliseconds: 2300));

    // 3. Load Resources with Timeout Protection
    debugPrint('SplashScreen: Starting resource load...');
    try {
      // Use a timeout to prevent hanging forever
      await Future.any([
        _checkAuthAndNavigate(simulate: true),
        Future.delayed(const Duration(seconds: 10)).then((_) => throw Exception('Resource load timeout')),
      ]);
    } catch (e) {
      debugPrint('SplashScreen: Resource load error or timeout: $e');
      // Continue anyway, fallbacks will handle it
    }

    await minHold;
    debugPrint('SplashScreen: Min hold time completed');

    // 4. Stay Visible (Do NOT Fade Out)
    // The navigation replacement will handle the transition
    
    // 5. Navigate with final check
    await _checkAuthAndNavigate(simulate: false);
  }

  void _replaceWith(Widget page) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  // ... (Keep existing methods until _checkAuthAndNavigate) ...

  Future<void> _checkAuthAndNavigate({bool simulate = false}) async {
    NotificationService().initialize();
    EncryptionService().initialize();
    await _localStorage.sync();
    await _settingsService.loadSettings();
    
    if (simulate) return;
    
    if (!mounted) return;
    
    try {
      final isFirstLaunch = await _settingsService.isFirstLaunch();
      final User? currentUser = _authService.currentUser;
      final bool isLocallyAuthenticated = await _authService.isAuthenticated();

      debugPrint('SplashScreen: isFirstLaunch = $isFirstLaunch');
      debugPrint('SplashScreen: currentUser = ${currentUser?.uid}');
      debugPrint('SplashScreen: isLocallyAuthenticated = $isLocallyAuthenticated');
      
      if (isFirstLaunch) {
        debugPrint('SplashScreen: Navigating to PermissionScreen');
        if (mounted) _replaceWith(const PermissionScreen());
      } else {
        if (currentUser != null && isLocallyAuthenticated) {
          debugPrint('SplashScreen: Navigating to MainScreen');
          if (mounted) _replaceWith(const MainScreen());
        } else {
          debugPrint('SplashScreen: Navigating to LoginScreen');
          if (mounted) _replaceWith(const LoginScreen());
        }
      }
    } catch (e) {
      debugPrint('Error in splash navigation: $e');
      if (mounted) _replaceWith(const LoginScreen());
    }
  }

  Future<bool> _checkFastTrack() async {
    // Simple implementation for now to fix build
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: Stack(
          children: [
            // Center content
            Center(
              child: AnimatedOpacity(
                duration: const Duration(seconds: 1), // Fade in duration
                opacity: _opacity,
                curve: Curves.easeOut,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     // Logo
                     Image.asset(
                       'assets/orbitalkLogo.png', 
                       height: 120, // Adjusted size
                       width: 120,
                     ),
                     const SizedBox(height: 20),
                     Text(
                       'UTELO',
                       style: GoogleFonts.outfit(
                         fontSize: 40,
                         fontWeight: FontWeight.bold,
                         color: Colors.white,
                         letterSpacing: 2.0,
                       ),
                     ),
                  ],
                ),
              ),
            ),

            // Footer
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 800),
                opacity: _opacity,
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
                    const SizedBox(height: 12),
                    Image.asset(
                      'assets/linkupLogo.png',
                      height: 70, 
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Linkup Communication Pvt. Ltd.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
