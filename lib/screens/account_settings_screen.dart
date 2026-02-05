import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import 'change_phone_number_screen.dart';
import 'login_screen.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final AuthService _authService = AuthService();
    final LocalStorageService _localStorage = LocalStorageService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget _buildSettingsItem({
      required IconData icon,
      required String title,
      String? subtitle,
      VoidCallback? onTap,
      Color? iconColor,
    }) {
      return ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (iconColor ?? Colors.purple.shade600).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor ?? Colors.purple.shade600,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              )
            : null,
        trailing: Icon(Icons.chevron_right, color: isDark ? Colors.grey.shade600 : Colors.grey),
        onTap: onTap,
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 0,
        title: Text(
          'Account Settings',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              child: Column(
                children: [
                  _buildSettingsItem(
                    icon: Icons.phone_android,
                    title: 'Change Phone Number',
                    subtitle: 'Update your phone number',
                    iconColor: Colors.blue.shade600,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangePhoneNumberScreen(),
                        ),
                      );
                    },
                  ),
                  _buildSettingsItem(
                    icon: Icons.delete_forever,
                    title: 'Delete Account',
                    subtitle: 'Permanently delete your account',
                    iconColor: Colors.red.shade600,
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(
                            'Delete Account',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          content: Text(
                            'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.',
                            style: GoogleFonts.poppins(),
                          ),
                          actions: [
                            TextButton(
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.poppins(color: Colors.grey),
                              ),
                              onPressed: () => Navigator.of(ctx).pop(false),
                            ),
                            TextButton(
                              child: Text(
                                'Delete',
                                style: GoogleFonts.poppins(color: Colors.red),
                              ),
                              onPressed: () => Navigator.of(ctx).pop(true),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final userId = await _localStorage.getUserId();
                        if (userId != null && userId.isNotEmpty) {
                          try {
                            await _authService.deleteUserAccount(userId);
                            await _localStorage.clearAuthState();
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to delete account: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

