import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import '../services/theme_service.dart';
import '../services/settings_service.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import '../utils/app_colors.dart';
import 'change_phone_number_screen.dart';
import 'account_settings_screen.dart';
import '../widgets/curved_header.dart'; // Import CurvedHeader
import '../widgets/glassmorphic_card.dart';
import '../widgets/user_avatar.dart'; // Added Import
import 'package:url_launcher/url_launcher.dart'; // Added
import 'subscription_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with AutomaticKeepAliveClientMixin {
  final AuthService _authService = AuthService();
  final LocalStorageService _localStorage = LocalStorageService();
  final SettingsService _settingsService = SettingsService();
  String _userName = 'Loading...';
  String _phoneNumber = '';
  String _profilePicture = '';
  String _bio = '';
  String _language = 'English';
  String _email = '';
  bool _isLoading = true;
  String _searchQuery = '';
  
  // Notification settings
  bool _messageNotifications = true;
  bool _callNotifications = true;
  bool _vibrate = true;
  
  // Storage settings
  bool _autoDownloadImages = true;
  bool _autoDownloadVideos = false;

  Future<void> _inviteFriends() async {
    final Uri smsLaunchUri = Uri(
      scheme: 'sms',
      queryParameters: <String, String>{
        'body': 'Hey! Join me on UTELO using this link: https://utelo.app/download',
      },
    );

    try {
      if (await canLaunchUrl(smsLaunchUri)) {
        await launchUrl(smsLaunchUri);
      } else {
         await launchUrl(smsLaunchUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching SMS: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Could not open messaging app.')),
        );
      }
    }
  }

  @override
  bool get wantKeepAlive => true; // Keep state alive

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSettings();
  }

  @override
  void dispose() {
    super.dispose();
  }
  
  Future<void> _loadSettings() async {
    await _settingsService.loadSettings();
    if (mounted) {
      setState(() {
        _messageNotifications = _settingsService.messageNotifications;
        _callNotifications = _settingsService.callNotifications;
        _vibrate = _settingsService.vibrate;
        _autoDownloadImages = _settingsService.autoDownloadImages;
        _autoDownloadVideos = _settingsService.autoDownloadVideos;
      });
    }
  }

  Future<void> _loadUserData() async {
    // 1. Load from cache first for instant UI
    final cachedName = await _localStorage.getUserName();
    final cachedPhone = await _localStorage.getPhoneNumber();
    final cachedPic = await _localStorage.getProfilePicture();
    final cachedBio = await _localStorage.getBio();
    final cachedLanguage = await _localStorage.getLanguage();
    
    if (mounted) {
      setState(() {
        _userName = cachedName ?? 'User';
        _phoneNumber = cachedPhone ?? '';
        _profilePicture = cachedPic ?? '';
        _bio = cachedBio ?? 'Hey there! I am using UTELO';
        _language = cachedLanguage ?? 'en';
        _isLoading = false; // Set to false initially if cache is available
      });
    }

    // 2. Fetch from Firestore for latest data (including email)
    final userId = _authService.currentUserId; // Use _authService instance
    if (userId != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        if (doc.exists && mounted) {
          final data = doc.data()!;
          final fetchedColorId = data['profileColor'] as int?; // Fetch profile color

          setState(() {
            _userName = data['name'] ?? _userName;
            _phoneNumber = data['phoneNumber'] ?? _phoneNumber;
            _profilePicture = data['profilePicture'] ?? _profilePicture;
            _email = data['email'] ?? ''; 
            _bio = data['bio'] ?? _bio;
            _language = data['language'] ?? _language;
            _isLoading = false;
          });
          
          // Update cache with latest data
          await _localStorage.saveUserName(_userName);
          await _localStorage.savePhoneNumber(_phoneNumber);
          await _localStorage.saveProfilePicture(_profilePicture);
          await _localStorage.saveBio(_bio);
          await _localStorage.saveLanguage(_language);
          
          if (fetchedColorId != null) {
            await _localStorage.saveProfileColor(fetchedColorId);
          }
        } else if (mounted) {
          setState(() => _isLoading = false); 
        }
      } catch (e) {
        debugPrint('Error loading user data from Firestore: $e');
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false); // No user ID, stop loading
    }
  }

  String _getLanguageName(String code) {
    const languages = {
      'en': 'English', 'hi': 'Hindi', 'mr': 'Marathi', 'bn': 'Bengali',
      'ta': 'Tamil', 'te': 'Telugu', 'ml': 'Malayalam', 'kn': 'Kannada',
      'pa': 'Punjabi', 'gu': 'Gujarati', 'ur': 'Urdu',
    };
    return languages[code] ?? 'English';
  }

  Widget _buildAvatar(double size) {
    return FutureBuilder<int>(
      future: _localStorage.getProfileColor(),
      builder: (context, snapshot) {
         final colorId = snapshot.data ?? 0;
         
         return UserAvatar(
           name: _userName,
           profilePicture: _profilePicture,
           size: size,
           colorId: colorId,
           onTap: null, // No action needed here, or could open image viewer
         );
      }
    );
  }
    
  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeBlue = const Color(0xFF0141B5);
    final iconColorToUse = iconColor ?? (isDark ? Colors.blue.shade200 : themeBlue);
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColorToUse.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColorToUse, size: 24),
      ),
      title: Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87)),
      subtitle: subtitle != null ? Text(subtitle, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)) : null,
      onTap: onTap,
    );
  }

  // ... (Keep helper methods: _showLanguageSelectionSheet, _showAccountSettingsSheet, _showChatSettingsSheet, _showNotificationSettingsSheet, _buildNotificationTile, _showStorageSettingsSheet, _buildStorageTile)
  // Re-implementing them briefly to ensure file integrity

  void _showLanguageSelectionSheet(BuildContext context) async {
    const languages = [
      {'name': 'English', 'code': 'en'}, {'name': 'Hindi', 'code': 'hi'},
      {'name': 'Marathi', 'code': 'mr'}, {'name': 'Bengali', 'code': 'bn'},
      {'name': 'Tamil', 'code': 'ta'}, {'name': 'Telugu', 'code': 'te'},
      {'name': 'Malayalam', 'code': 'ml'}, {'name': 'Kannada', 'code': 'kn'},
      {'name': 'Punjabi', 'code': 'pa'}, {'name': 'Gujarati', 'code': 'gu'},
      {'name': 'Urdu', 'code': 'ur'},
    ];
    String? selected = _language;
    final userId = await _localStorage.getUserId();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF232323) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false, initialChildSize: 0.6,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF232323) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                          Text('Choose your Preferred Language', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                          const SizedBox(height: 18),
                          ...languages.map((lang) => RadioListTile<String>(
                                title: Text(lang['name']!, style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87)),
                                value: lang['code']!,
                                groupValue: selected,
                                activeColor: const Color(0xFF0141B5),
                                onChanged: (v) async {
                                  setModalState(() => selected = v);
                                  if (v != null && userId != null) {
                                    Navigator.of(context).pop();
                                    setState(() => _language = v);
                                    await _localStorage.saveLanguage(v);
                                    await _authService.createOrUpdateUserProfile(uid: userId, language: v);
                                  }
                                },
                              )),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showAccountSettingsSheet(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountSettingsScreen()));
  }

  void _showChatSettingsSheet(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF232323) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            Text('Chat Settings', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF0141B5).withOpacity(0.1), shape: BoxShape.circle), child: Icon(themeService.isDarkMode ? Icons.dark_mode : Icons.light_mode, color: const Color(0xFF0141B5), size: 24)),
                title: Text('Theme', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                subtitle: Text(themeService.isDarkMode ? 'Dark' : 'Light', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
                trailing: Switch(value: themeService.isDarkMode, onChanged: (v) => themeService.toggleTheme(), activeColor: const Color(0xFF0141B5)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showNotificationSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF232323) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
             return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  Text('Notifications', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 24),
                  _buildNotificationTile(icon: Icons.message, iconColor: const Color(0xFF0141B5), title: 'Message Notifications', subtitle: 'Receive notifications for new messages', value: _messageNotifications, onChanged: (val) { setModalState(() => _messageNotifications = val); setState(() => _messageNotifications = val); _settingsService.setMessageNotifications(val); }),
                  const SizedBox(height: 12),
                  _buildNotificationTile(icon: Icons.call, iconColor: const Color(0xFF0141B5), title: 'Call Notifications', subtitle: 'Receive notifications for incoming calls', value: _callNotifications, onChanged: (val) { setModalState(() => _callNotifications = val); setState(() => _callNotifications = val); _settingsService.setCallNotifications(val); }),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationTile({required IconData icon, required Color iconColor, required String title, required String subtitle, required bool value, required Function(bool) onChanged}) {
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 24)),
        title: Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
        subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
        trailing: Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF0141B5)),
      ),
    );
  }

  void _showStorageSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF232323) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  Text('Storage and Data', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 24),
                  Text('Auto-download media', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 12),
                  _buildStorageTile(icon: Icons.image, iconColor: const Color(0xFF0141B5), title: 'Images', subtitle: 'Automatically download images', value: _autoDownloadImages, onChanged: (val) { setModalState(() => _autoDownloadImages = val); setState(() => _autoDownloadImages = val); _settingsService.setAutoDownloadImages(val); }),
                  const SizedBox(height: 12),
                  _buildStorageTile(icon: Icons.videocam, iconColor: const Color(0xFF0141B5), title: 'Videos', subtitle: 'Automatically download videos', value: _autoDownloadVideos, onChanged: (val) { setModalState(() => _autoDownloadVideos = val); setState(() => _autoDownloadVideos = val); _settingsService.setAutoDownloadVideos(val); }),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStorageTile({required IconData icon, required Color iconColor, required String title, required String subtitle, required bool value, required Function(bool) onChanged}) {
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 24)),
        title: Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
        subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
        trailing: Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF0141B5)),
      ),
    );
  }

  bool _matchesSearch(String title, String? subtitle) {
    if (_searchQuery.isEmpty) return true;
    final query = _searchQuery.toLowerCase();
    return title.toLowerCase().contains(query) || (subtitle?.toLowerCase().contains(query) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // IMPORTANT
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white; // Unified background color
    
    // Define the contents of the scroll view
    Widget content = Column(
      children: [
        // Profile section
        GlassmorphicCard(
          color: isDark ? const Color(0xFF001133) : const Color(0xFFE3F2FD),
          opacity: 0.6,
          blur: 10,
          borderRadius: 20,
          padding: const EdgeInsets.all(16),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Row(
                children: [
                  _buildAvatar(60), // Smaller avatar (60 instead of 80)
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: GoogleFonts.poppins(
                            fontSize: 18, // Slightly smaller font
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _phoneNumber,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (_email.isNotEmpty)
                          Text(
                            _email,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final userId = _authService.currentUserId ?? '';
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfileScreen(
                            currentName: _userName,
                            currentProfilePicture: _profilePicture,
                            userId: userId,
                          ),
                        ),
                      );
                      if (result == true) _loadUserData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF001133),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(
                      'Edit', // Shorter text for better fit
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
        ),
        
        const SizedBox(height: 16),
        
        // Premium Banner
        GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFDF00), Color(0xFFD4AF37)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset('assets/images/crown_icon.png', width: 32, height: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upgrade to Premium',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Unlock exclusive features & plans',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.black87.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.black87, size: 16),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Settings items
        GlassmorphicCard(
          color: isDark ? const Color(0xFF001133) : const Color(0xFFE3F2FD),
          opacity: 0.6,
          blur: 10,
          borderRadius: 20,
          child: Column(
            children: [
              if (_matchesSearch('Account', 'Change number, Delete Account')) _buildSettingsItem(icon: Icons.person_outline, title: 'Account', subtitle: 'Change number, Delete Account', onTap: () => _showAccountSettingsSheet(context)),
              if (_matchesSearch('Chat Settings', 'Theme')) _buildSettingsItem(icon: Icons.chat_bubble_outline, title: 'Chat Settings', subtitle: 'Theme', onTap: () => _showChatSettingsSheet(context)),
              if (_matchesSearch('Notifications', 'Message, group & call tones')) _buildSettingsItem(icon: Icons.notifications_none, title: 'Notifications', subtitle: 'Message, group & call tones', onTap: () => _showNotificationSettingsSheet(context)),
              if (_matchesSearch('Help', 'FAQ, contact us, privacy policy')) _buildSettingsItem(icon: Icons.help_outline, title: 'Help', subtitle: 'FAQ, contact us, privacy policy', onTap: () => _showTermsDialog(context)),
              if (_matchesSearch('Language Settings', _getLanguageName(_language))) _buildSettingsItem(icon: Icons.language, title: 'Language Settings', subtitle: 'Current: ${_getLanguageName(_language)}', onTap: () => _showLanguageSelectionSheet(context)),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Additional settings
        GlassmorphicCard(
          color: isDark ? const Color(0xFF001133) : const Color(0xFFE3F2FD),
          opacity: 0.6,
          blur: 10,
          borderRadius: 20,
          child: Column(
            children: [
              if (_matchesSearch('Storage and Data', 'Network usage, auto-download')) _buildSettingsItem(icon: Icons.storage, title: 'Storage and Data', subtitle: 'Network usage, auto-download', onTap: () => _showStorageSettingsSheet(context)),
              if (_matchesSearch('Invite Friends', null)) _buildSettingsItem(
                  icon: Icons.group, 
                  title: 'Invite Friends', 
                  onTap: _inviteFriends 
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // About section
        if (_matchesSearch('About', 'Version 1.0.0'))
          GlassmorphicCard(
            color: isDark ? const Color(0xFF001133) : const Color(0xFFE3F2FD),
            opacity: 0.6,
            blur: 10,
            borderRadius: 20,
            child: _buildSettingsItem(icon: Icons.info_outline, title: 'About', subtitle: 'Version 1.0.0', onTap: () {
               showAboutDialog(
                  context: context, applicationName: 'UTELO', applicationVersion: '1.0.0',
                  applicationIcon: Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [const Color(0xFF0141B5), const Color(0xFF00E5FF)])),
                    child: const Icon(Icons.language, color: Colors.white),
                  ),
                  children: [
                    Text('UTELO is a multilingual messaging app that breaks language barriers.', style: GoogleFonts.poppins()),
                    const SizedBox(height: 10),
                    Text('Designed & Developed by PRAMAHASOFT', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ],
                );
            }),
          ),
          
        const SizedBox(height: 16),
        
        // Logout
        GlassmorphicCard(
            color: isDark ? const Color(0xFF001133) : const Color(0xFFE3F2FD),
            opacity: 0.6,
            blur: 10,
            borderRadius: 20,
          child: ListTile(
            leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.logout, color: Colors.red, size: 24)),
            title: Text('Logout', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.red)),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  content: Text('Are you sure you want to logout?', style: GoogleFonts.poppins()),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey))),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                        _authService.signOut().catchError((e) => debugPrint('Settings: Error signing out: $e'));
                      },
                      child: Text('Logout', style: GoogleFonts.poppins(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 100), // Extra padding at bottom
      ],
    );

    return Scaffold(
      backgroundColor: Colors.transparent, // Unified scaffold background
      body: Stack(
        children: [
          // Content Layer with ClipRect
          ClipRect(
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 210),
                child: content,
              ),
            ),
          ),
          
          // Header (Top Layer)
          Positioned(
            top: 0, left: 0, right: 0,
            child: CurvedHeader(
              showBack: false,
              titleWidget: SizedBox(
                height: 32,
                child: Row(
                  children: [
                    const Icon(Icons.settings, color: Colors.white, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Settings',
                      style: GoogleFonts.poppins(
                        fontSize: 23,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              bottomChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 40,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search',
                        prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                        suffixIcon: _searchQuery.isNotEmpty 
                           ? IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 18), onPressed: () => setState(() => _searchQuery = ''))
                           : null
                      ),
                    ),
                  ),
                  // GENERAL TITLE REMOVED FROM HERE
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Terms & Privacy Policy', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Terms of Use', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text('In General\nUTELO (Universal Translation & Easy Language Output), is a product owned by LINKUP COMMUNICATION PVT LTD. This document governs your relationship with UTELO. Access to and use of this UTELO and its services available through Google Play store (collectively, the "Services") are subject to the following terms, conditions and notices (the "Terms of Service"). By using the Services, you are agreeing to all the Terms of Service, as may be updated by us from time to time.\n\nAccess to UTELO is permitted on a temporary basis, and we reserve the right to withdraw or amend the Services without notice. We will not be liable if for any reason this UTELO is unavailable at any time or for any period.', style: GoogleFonts.poppins(fontSize: 12)),
              const SizedBox(height: 12),
              Text('Privacy Policy', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text('Our privacy policy, which sets out how we will use your information, can be found below. By using this UTELO, you consent to the processing described therein and warrant that all data provided by you is accurate.', style: GoogleFonts.poppins(fontSize: 12)),
              const SizedBox(height: 12),
              Text('Prohibitions', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text('You must not misuse UTELO You will not: commit or encourage a criminal offense; transmit or distribute a virus, trojan, worm, logic bomb or any other material which is malicious, technologically harmful, in breach of confidence or in any way offensive or obscene; hack into any aspect of the Service; corrupt data; cause annoyance to other users; infringe upon the rights of any other person\'s proprietary rights; send any unsolicited advertising or promotional material, commonly referred to as "spam".', style: GoogleFonts.poppins(fontSize: 12)),
              const SizedBox(height: 12),
              Text('Intellectual Property', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text('The intellectual property rights in all software and content remains the property of LINKUP COMMUNICATION PVT LTD or its licensors and are protected by copyright laws.', style: GoogleFonts.poppins(fontSize: 12)),
              const SizedBox(height: 12),
              Text('Disclaimer of Liability', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text('The material displayed on UTELO is provided without any guarantees, conditions or warranties as to its accuracy. LINKUP COMMUNICATION PVT LTD expressly excludes all conditions, warranties and other terms which might otherwise be implied by statute, common law or the law of equity.', style: GoogleFonts.poppins(fontSize: 12)),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text('Privacy Policy (Detailed)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text('Privacy Policy governs the way UTELO collects, uses, maintains and discloses information collected from users. This privacy policy applies to the UTELO, and its services offered by LINKUP COMMUNICATION PVT LTD.\n\nUTELO may collect personal identification information from Users in a variety of ways, including, but not limited to, when Users visit our UTELO, register on the UTELO. Users may be asked for, as appropriate, name, email address, phone number. We will collect personal identification information from Users only if they voluntarily submit such information to us.\n\nUTELO may collect and use Users personal information to improve customer service, improve our UTELO, run features, and send periodic emails.\n\nUTELO adopts appropriate data collection, storage and processing practices and security measures to protect again, transaction information and data stored on our UTELO. Sensitive and private data exchange happens over an SSL secured communication channel.', style: GoogleFonts.poppins(fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.poppins(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
