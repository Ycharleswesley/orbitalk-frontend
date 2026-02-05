import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/gradient_background.dart';
import '../services/settings_service.dart';
import 'login_screen.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({Key? key}) : super(key: key);

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  final SettingsService _settingsService = SettingsService();
  bool _isLoading = false;
  
  // Permission statuses
  Map<Permission, bool> _permissionStatus = {
    Permission.camera: false,
    Permission.microphone: false,
    Permission.notification: false,
    Permission.photos: false,
  };

  @override
  void initState() {
    super.initState();
    _checkCurrentPermissions();
  }

  Future<void> _checkCurrentPermissions() async {
    final camera = await Permission.camera.isGranted;
    final microphone = await Permission.microphone.isGranted;
    final notification = await Permission.notification.isGranted;
    final photos = await Permission.photos.isGranted;
    
    if (mounted) {
      setState(() {
        _permissionStatus = {
          Permission.camera: camera,
          Permission.microphone: microphone,
          Permission.notification: notification,
          Permission.photos: photos,
        };
      });
    }
  }

  Future<void> _requestAllPermissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Request permissions one by one
      await Permission.camera.request();
      await Permission.microphone.request();
      await Permission.notification.request();
      await Permission.photos.request();
      
      // Check updated statuses
      await _checkCurrentPermissions();
      
      // Mark first launch as complete
      await _settingsService.setFirstLaunchComplete();
      
      // Navigate to login
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      debugPrint('PermissionScreen: Error requesting permissions: $e');
      
      // Still proceed to login even if error
      await _settingsService.setFirstLaunchComplete();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _skipPermissions() async {
    await _settingsService.setFirstLaunchComplete();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required bool isGranted,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95), // Revert to White
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28), // Icon color
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87, // Revert to Black
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade600, // Revert to Grey
                  ),
                ),
              ],
            ),
          ),
          /* Icon removed as per user request to simplify UI
          Icon(
            isGranted ? Icons.check_circle : Icons.circle_outlined,
            color: isGranted ? Colors.green : Colors.grey.shade400,
            size: 28,
          ),
          */
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                
                // Title
                Text(
                  'App Permissions',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                Text(
                  'UTELO needs these permissions to work properly',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 40),
                
                // Permission items
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildPermissionItem(
                          icon: Icons.camera_alt,
                          title: 'Camera',
                          description: 'Take photos and record videos for sharing',
                          color: Colors.blue,
                          isGranted: _permissionStatus[Permission.camera] ?? false,
                        ),
                        _buildPermissionItem(
                          icon: Icons.mic,
                          title: 'Microphone',
                          description: 'Make voice calls and send voice messages',
                          color: Colors.orange,
                          isGranted: _permissionStatus[Permission.microphone] ?? false,
                        ),
                        _buildPermissionItem(
                          icon: Icons.notifications,
                          title: 'Notifications',
                          description: 'Receive message and call alerts',
                          color: Colors.purple,
                          isGranted: _permissionStatus[Permission.notification] ?? false,
                        ),
                        _buildPermissionItem(
                          icon: Icons.photo_library,
                          title: 'Photos & Storage',
                          description: 'Share and save photos and media',
                          color: Colors.green,
                          isGranted: _permissionStatus[Permission.photos] ?? false,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Grant All Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _requestAllPermissions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600, // Change GRANT to Green
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFB64166),
                            ),
                          )
                        : Text(
                            'Grant All Permissions',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Skip button
                TextButton(
                  onPressed: _isLoading ? null : _skipPermissions,
                  child: Text(
                    'Skip for now',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
