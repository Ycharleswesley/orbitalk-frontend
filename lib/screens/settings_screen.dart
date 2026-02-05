import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import '../services/theme_service.dart';
import '../services/settings_service.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import '../utils/app_colors.dart'; // Added
import 'change_phone_number_screen.dart';
import 'account_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final LocalStorageService _localStorage = LocalStorageService();
  final SettingsService _settingsService = SettingsService();
  
  String _userName = 'Loading...';
  String _phoneNumber = '';
  String _profilePicture = '';
  String _bio = '';
  String _language = 'English';
  bool _isLoading = true;
  String _searchQuery = '';
  bool _isSearching = false;
  
  // Notification settings (loaded from SettingsService)
  bool _messageNotifications = true;
  bool _callNotifications = true;
  bool _vibrate = true;
  
  // Storage settings (loaded from SettingsService)
  bool _autoDownloadImages = true;
  bool _autoDownloadVideos = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSettings();
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
    try {
      final userId = await _localStorage.getUserId();
      if (userId != null) {
        final userData = await _authService.getUserProfile(userId);
        if (userData != null && mounted) {
          setState(() {
            _userName = userData['name'] ?? 'User';
            _phoneNumber = userData['phoneNumber'] ?? '';
            _profilePicture = userData['profilePicture'] ?? '';
            _bio = userData['bio'] ?? 'Hey there! I am using UTELO';
            _language = userData['language'] ?? 'en';
            _isLoading = false;
            // Sync to Local Storage
            _localStorage.saveLanguage(_language);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getLanguageName(String code) {
    const languages = {
      'en': 'English',
      'hi': 'Hindi',
      'mr': 'Marathi',
      'bn': 'Bengali',
      'ta': 'Tamil',
      'te': 'Telugu',
      'ml': 'Malayalam',
      'kn': 'Kannada',
      'pa': 'Punjabi',
      'gu': 'Gujarati',
      'ur': 'Urdu',
    };
    return languages[code] ?? 'English';
  }

  Widget _buildAvatar() {
    // Get profile color from settings or local storage
    // Since we don't store it in a provider locally for this screen, we rely on _loadUserData update or fetch
    // Actually, we should load it. Let's assume we add _profileColorId to state.
    // For now, I'll fetch it properly.
    
    // We need to store profileColor in state.
    
    return FutureBuilder<int>(
      future: _localStorage.getProfileColor(),
      builder: (context, snapshot) {
         final colorId = snapshot.data ?? 0;
         final bgColor = AppColors.getColor(colorId);
         
         if (_profilePicture.isNotEmpty) {
           return ClipOval(
             child: CachedNetworkImage(
               imageUrl: _profilePicture,
               width: 80,
               height: 80,
               fit: BoxFit.cover,
               placeholder: (context, url) => Container(
                 width: 80,
                 height: 80,
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   color: Colors.grey.shade300,
                 ),
                 child: const Icon(Icons.person, size: 40, color: Colors.white),
               ),
               errorWidget: (context, url, error) => Container(
                 width: 80,
                 height: 80,
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   color: bgColor, // Use Dynamic Color
                 ),
                 child: Center(
                   child: Text(
                     _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                     style: const TextStyle(
                       fontSize: 32,
                       fontWeight: FontWeight.bold,
                       color: Colors.white,
                     ),
                   ),
                 ),
               ),
             ),
           );
         }
         
         return Container(
           width: 80,
           height: 80,
           decoration: BoxDecoration(
             shape: BoxShape.circle,
             color: bgColor, // Use Dynamic Color
           ),
           child: Center(
             child: Text(
               _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
               style: const TextStyle(
                 fontSize: 32,
                 fontWeight: FontWeight.bold,
                 color: Colors.white,
               ),
             ),
           ),
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
      onTap: onTap,
    );
  }

  void _showLanguageSelectionSheet(BuildContext context) async {
    const languages = [
      {'name': 'English', 'code': 'en'},
      {'name': 'Hindi', 'code': 'hi'},
      {'name': 'Marathi', 'code': 'mr'},
      {'name': 'Bengali', 'code': 'bn'},
      {'name': 'Tamil', 'code': 'ta'},
      {'name': 'Telugu', 'code': 'te'},
      {'name': 'Malayalam', 'code': 'ml'},
      {'name': 'Kannada', 'code': 'kn'},
      {'name': 'Punjabi', 'code': 'pa'},
      {'name': 'Gujarati', 'code': 'gu'},
      {'name': 'Urdu', 'code': 'ur'},
    ];
    String? selected = _language;
    final userId = await _localStorage.getUserId();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Choose your Preferred Language',
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 18),
                        ...languages.map((lang) => RadioListTile<String>(
                              title: Text(lang['name']!),
                              value: lang['code']!,
                              groupValue: selected,
                              onChanged: (v) async {
                                setModalState(() {
                                  selected = v;
                                });
                                if (v != null && userId != null && userId.isNotEmpty) {
                                  Navigator.of(context).pop(); // Close sheet
                                  setState(() {
                                    _language = v;
                                  });
                                  await _localStorage.saveLanguage(v);
                                  // Only update language, don't touch other fields
                                  await _authService.createOrUpdateUserProfile(
                                    uid: userId,
                                    language: v,
                                  );
                                }
                              },
                            )),
                      ],
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AccountSettingsScreen(),
      ),
    );
  }

  void _showChatSettingsSheet(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
          ? const Color(0xFF232323) 
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Chat Settings',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white 
                      : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Customize your chat experience',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? const Color(0xFF1A1A1A) 
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade600.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      themeService.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      color: Colors.purple.shade600,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    'Theme',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white 
                          : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    themeService.isDarkMode ? 'Dark' : 'Light',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  trailing: Switch(
                    value: themeService.isDarkMode,
                    onChanged: (value) {
                      themeService.toggleTheme();
                    },
                    activeColor: Colors.purple.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  void _showNotificationSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
          ? const Color(0xFF232323) 
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Notifications',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white 
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configure your notification preferences',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildNotificationTile(
                    icon: Icons.message,
                    iconColor: Colors.blue,
                    title: 'Message Notifications',
                    subtitle: 'Receive notifications for new messages',
                    value: _messageNotifications,
                    onChanged: (val) {
                      setModalState(() => _messageNotifications = val);
                      setState(() => _messageNotifications = val);
                      _settingsService.setMessageNotifications(val);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildNotificationTile(
                    icon: Icons.call,
                    iconColor: Colors.orange,
                    title: 'Call Notifications',
                    subtitle: 'Receive notifications for incoming calls',
                    value: _callNotifications,
                    onChanged: (val) {
                      setModalState(() => _callNotifications = val);
                      setState(() => _callNotifications = val);
                      _settingsService.setCallNotifications(val);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildNotificationTile(
                    icon: Icons.vibration,
                    iconColor: Colors.purple,
                    title: 'Vibrate',
                    subtitle: 'Vibrate on notifications',
                    value: _vibrate,
                    onChanged: (val) {
                      setModalState(() => _vibrate = val);
                      setState(() => _vibrate = val);
                      _settingsService.setVibrate(val);
                    },
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xFF1A1A1A) 
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.white 
                : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.purple.shade600,
        ),
      ),
    );
  }

  void _showStorageSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
          ? const Color(0xFF232323) 
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Storage and Data',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white 
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage auto-download and network usage',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Auto-download media',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white 
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStorageTile(
                    icon: Icons.image,
                    iconColor: Colors.green,
                    title: 'Images',
                    subtitle: 'Automatically download images',
                    value: _autoDownloadImages,
                    onChanged: (val) {
                      setModalState(() => _autoDownloadImages = val);
                      setState(() => _autoDownloadImages = val);
                      _settingsService.setAutoDownloadImages(val);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildStorageTile(
                    icon: Icons.videocam,
                    iconColor: Colors.red,
                    title: 'Videos',
                    subtitle: 'Automatically download videos',
                    value: _autoDownloadVideos,
                    onChanged: (val) {
                      setModalState(() => _autoDownloadVideos = val);
                      setState(() => _autoDownloadVideos = val);
                      _settingsService.setAutoDownloadVideos(val);
                    },
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? const Color(0xFF1A1A1A) 
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade600,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Auto-download uses mobile data when Wi-Fi is not available',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStorageTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xFF1A1A1A) 
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.white 
                : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.purple.shade600,
        ),
      ),
    );
  }

  // Helper method to check if a setting matches the search query
  bool _matchesSearch(String title, String? subtitle) {
    if (_searchQuery.isEmpty) return true;
    final query = _searchQuery.toLowerCase();
    return title.toLowerCase().contains(query) ||
        (subtitle?.toLowerCase().contains(query) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 0,
        title: _isSearching
            ? TextField(
                autofocus: true,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Search settings...',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey.shade600,
                  ),
                  border: InputBorder.none,
                ),
              )
            : Text(
                'Settings',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                }
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile section
            Container(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              padding: const EdgeInsets.all(16),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      children: [
                        _buildAvatar(),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userName,
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _phoneNumber,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                  ElevatedButton(
                    onPressed: () async {
                      final userId = await _localStorage.getUserId() ?? '';
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
                      // Reload user data if profile was updated
                      if (result == true) {
                        _loadUserData();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      'Edit Profile',
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
            
            const SizedBox(height: 8),
            
            // Settings items
            Container(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              child: Column(
                children: [
                  if (_matchesSearch('Account', 'Change number, Delete Account'))
                    _buildSettingsItem(
                      icon: Icons.person_outline,
                      title: 'Account',
                      subtitle: 'Change number, Delete Account',
                      onTap: () => _showAccountSettingsSheet(context),
                    ),
                  if (_matchesSearch('Chat Settings', 'Theme'))
                    _buildSettingsItem(
                      icon: Icons.chat_bubble_outline,
                      title: 'Chat Settings',
                      subtitle: 'Theme',
                      onTap: () => _showChatSettingsSheet(context),
                    ),
                  if (_matchesSearch('Notifications', 'Message, group & call tones'))
                    _buildSettingsItem(
                      icon: Icons.notifications_none,
                      title: 'Notifications',
                      subtitle: 'Message, group & call tones',
                      onTap: () => _showNotificationSettingsSheet(context),
                    ),
                  if (_matchesSearch('Help', 'FAQ, contact us, privacy policy'))
                    _buildSettingsItem(
                      icon: Icons.help_outline,
                      title: 'Help',
                      subtitle: 'FAQ, contact us, privacy policy',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Help & Support')),
                        );
                      },
                    ),
                  if (_matchesSearch('Language Settings', _getLanguageName(_language)))
                    _buildSettingsItem(
                      icon: Icons.language,
                      title: 'Language Settings',
                      subtitle: 'Current:  ${_getLanguageName(_language)}',
                      onTap: () => _showLanguageSelectionSheet(context),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Additional settings
            Container(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              child: Column(
                children: [
                  if (_matchesSearch('Storage and Data', 'Network usage, auto-download'))
                    _buildSettingsItem(
                      icon: Icons.storage,
                      title: 'Storage and Data',
                      subtitle: 'Network usage, auto-download',
                      onTap: () => _showStorageSettingsSheet(context),
                    ),
                  if (_matchesSearch('Invite Friends', null))
                    _buildSettingsItem(
                      icon: Icons.group,
                      title: 'Invite Friends',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invite friends')),
                        );
                      },
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // About section
            if (_matchesSearch('About', 'Version 1.0.0'))
              Container(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                child: Column(
                  children: [
                    _buildSettingsItem(
                      icon: Icons.info_outline,
                      title: 'About',
                      subtitle: 'Version 1.0.0',
                      onTap: () {
                        showAboutDialog(
                          context: context,
                          applicationName: 'UTELO',
                          applicationVersion: '1.0.0',
                          applicationIcon: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.orange.shade400,
                                ],
                              ),
                            ),
                            child: const Icon(
                              Icons.language,
                              color: Colors.white,
                            ),
                          ),
                          children: [
                            Text(
                              'UTELO is a multilingual messaging app that breaks language barriers.',
                              style: GoogleFonts.poppins(),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Designed & Developed by PRAMAHASOFT',
                              style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Logout
            Container(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
                title: Text(
                  'Logout',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(
                        'Logout',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      content: Text(
                        'Are you sure you want to logout?',
                        style: GoogleFonts.poppins(),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // Optimistic Logout: Close Dialog & Navigate Immediately
                            Navigator.pop(context);
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                              (route) => false,
                            );
                            
                            // Perform cleanup in background (Fire & Forget)
                            _authService.signOut().catchError((e) {
                               debugPrint('Settings: Error signing out in background: $e');
                            });
                          },
                          child: Text(
                            'Logout',
                            style: GoogleFonts.poppins(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
