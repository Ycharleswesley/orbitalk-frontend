import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/mesh_gradient_background.dart'; // Updated
import '../widgets/glassmorphic_card.dart'; // Updated
import '../services/settings_service.dart';
import 'splash_screen.dart';
import 'login_screen.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({Key? key}) : super(key: key);

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  final SettingsService _settingsService = SettingsService();
  bool _isLoading = false;
  
  // Permission statuses (Granted or Denied)
  Map<Permission, bool> _permissionStatus = {
    Permission.camera: false,
    Permission.microphone: false,
    Permission.notification: false,
    Permission.contacts: false,
    Permission.photos: false,
  };

  // User Selection for Requesting
  Map<Permission, bool> _selectionStatus = {
    Permission.camera: false,
    Permission.microphone: false,
    Permission.notification: false,
    Permission.contacts: false,
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
    final contacts = await Permission.contacts.isGranted;
    final photos = await Permission.photos.isGranted;
    
    if (mounted) {
      setState(() {
        _permissionStatus = {
          Permission.camera: camera,
          Permission.microphone: microphone,
          Permission.notification: notification,
          Permission.contacts: contacts,
          Permission.photos: photos,
        };

        // If granted, mark as selected (visual consistency)
        // If not granted, leave as false (user must opt-in)
        _selectionStatus.forEach((key, value) {
          if (_permissionStatus[key] == true) {
            _selectionStatus[key] = true;
          }
        });
      });
    }
  }

  void _togglePermission(Permission permission, bool? value) {
    if (_permissionStatus[permission] == true) return; // Cannot toggle if already granted
    
    setState(() {
      _selectionStatus[permission] = value ?? false;
    });
  }

  void _toggleAll(bool value) {
    setState(() {
      _selectionStatus.forEach((key, _) {
        if (_permissionStatus[key] == false) {
          _selectionStatus[key] = value;
        }
      });
    });
  }

  Future<void> _requestSelectedPermissions() async {
    // If no permissions are selected to be requested (and none are already granted),
    // treat this as a "Skip" action.
    final permissionsToRequest = _selectionStatus.entries
        .where((entry) => entry.value == true && _permissionStatus[entry.key] == false)
        .map((entry) => entry.key)
        .toList();

    if (permissionsToRequest.isEmpty) {
      _finishPermissionFlow();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      for (var permission in permissionsToRequest) {
        await permission.request();
      }
      
      // Update statuses after requests
      await _checkCurrentPermissions();
      
      // Finish
      _finishPermissionFlow();

    } catch (e) {
      debugPrint('PermissionScreen: Error requesting permissions: $e');
      _finishPermissionFlow();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _finishPermissionFlow() async {
    await _settingsService.setFirstLaunchComplete();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SplashScreen()),
      );
    }
  }

  Future<void> _skipPermissions() async {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if all ungranted permissions are selected
    bool areAllSelected = true;
    bool hasUngranted = false;
    
    _permissionStatus.forEach((key, isGranted) {
      if (!isGranted) {
        hasUngranted = true;
        if (_selectionStatus[key] == false) {
          areAllSelected = false;
        }
      }
    });
    
    if (!hasUngranted) areAllSelected = true;

    return Scaffold(
      body: MeshGradientBackground(
        isDark: false, // Force Light Mode
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              
              // Header
              Text(
                'APP PERMISSIONS',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'To provide the best experience, we need a few permissions.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
              ),
              
              const SizedBox(height: 20), // Reduced spacing

              // Select All - Integrated nicely
              if (hasUngranted)
                 Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), // Standard padding (wider)
                   child: GlassmorphicCard(
                     borderRadius: 12,
                     color: Colors.white,
                     opacity: 0.5,
                     child: InkWell(
                       onTap: () => _toggleAll(!areAllSelected),
                       borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Tighter padding
                         child: Row(
                           mainAxisSize: MainAxisSize.max, // Take full width
                           mainAxisAlignment: MainAxisAlignment.spaceBetween, // Spread text and icon
                           children: [
                             Text(
                               'Select All',
                               style: GoogleFonts.poppins(
                                 fontSize: 16,
                                 fontWeight: FontWeight.w600,
                                 color: Colors.black87,
                               ),
                             ),
                             Icon(
                               areAllSelected ? Icons.check_circle : Icons.circle_outlined,
                               color: areAllSelected ? const Color(0xFF00C853) : Colors.grey,
                             ),
                           ],
                         ),
                       ),
                     ),
                   ),
                 ),

              const SizedBox(height: 10),

              // Permission List with Fade Effect
              Expanded(
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.purple, Colors.transparent, Colors.transparent, Colors.purple],
                      stops: [0.0, 0.05, 0.95, 1.0],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstOut,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    children: [
                      _buildPermissionItem(
                        permission: Permission.camera,
                        icon: Icons.camera_alt,
                        title: 'Camera',
                        description: 'Take photos and record videos.',
                        color: Colors.blueAccent,
                      ),
                      _buildPermissionItem(
                        permission: Permission.microphone,
                        icon: Icons.mic,
                        title: 'Microphone',
                        description: 'Make voice calls and audio.',
                        color: Colors.orangeAccent,
                      ),
                      _buildPermissionItem(
                        permission: Permission.notification,
                        icon: Icons.notifications,
                        title: 'Notifications',
                        description: 'Stay updated with messages.',
                        color: Colors.purpleAccent,
                      ),
                      _buildPermissionItem(
                        permission: Permission.contacts,
                        icon: Icons.contacts,
                        title: 'Contacts',
                        description: 'Find friends easily on UTELO.',
                        color: Colors.pinkAccent,
                      ),
                      _buildPermissionItem(
                        permission: Permission.photos,
                        icon: Icons.photo_library,
                        title: 'Storage',
                        description: 'Share photos and videos.',
                        color: const Color(0xFFE91E63), // Pink/Red for storage to differentiate from Green action
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 40),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _requestSelectedPermissions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C853), // Green for Action
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                          shadowColor: const Color(0xFF00C853).withOpacity(0.4),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                _selectionStatus.values.any((v) => v) ? 'ALLOW ACCESS' : 'SKIP',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 2.0,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required Permission permission,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    final isGranted = _permissionStatus[permission] ?? false;
    final isSelected = _selectionStatus[permission] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: isGranted ? null : () => _togglePermission(permission, !isSelected),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: isSelected && !isGranted
                ? Border.all(color: const Color(0xFF00C853), width: 2) // Green Border
                : Border.all(color: Colors.transparent, width: 2),
          ),
          child: GlassmorphicCard(
            borderRadius: 18, 
            color: Colors.white,
            opacity: 0.7,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Icon Circle
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  
                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.black54,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Selection Indicator
                  if (isGranted)
                     const Icon(Icons.check_circle, color: Colors.green, size: 24)
                  else if (isSelected)
                     const Icon(Icons.check_circle, color: Color(0xFF00C853), size: 24) // Green Check
                  else
                     const Icon(Icons.circle_outlined, color: Colors.grey, size: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
