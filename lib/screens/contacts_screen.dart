import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/contact_service.dart';
import '../widgets/curved_header.dart';
import 'chat_detail_screen.dart';
import 'profile_view_screen.dart';
import 'package:flutter/services.dart';
import '../widgets/user_avatar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({Key? key}) : super(key: key);

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> with AutomaticKeepAliveClientMixin {
  final ContactService _contactService = ContactService();
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _registeredUsers = [];
  List<Contact> _unregisteredContacts = [];
  List<Map<String, dynamic>> _filteredRegistered = [];
  List<Contact> _filteredUnregistered = [];
  String _searchQuery = '';
  String? _errorMessage;

  bool _isUserOnline(Map<String, dynamic>? data) {
    if (data == null) return false;
    final isOnline = data['isOnline'] == true;
    if (!isOnline) return false;
    
    final lastSeen = data['lastSeen'] as Timestamp?;
    if (lastSeen == null) return false;

    // Use a 5-minute timeout window
    final now = DateTime.now();
    final difference = now.difference(lastSeen.toDate());
    return difference.inMinutes < 5;
  }

  @override
  bool get wantKeepAlive => true; // Keep state alive

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts({bool force = false}) async {
    if (!force && (_registeredUsers.isNotEmpty || _unregisteredContacts.isNotEmpty)) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final contacts = await _contactService.fetchDeviceContacts();
      if (contacts.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final result = await _contactService.matchContactsWithUsers(contacts);

      if (mounted) {
        setState(() {
          _registeredUsers = List<Map<String, dynamic>>.from(result['registered'] ?? []);
          _unregisteredContacts = List<Contact>.from(result['unregistered'] ?? []);
          _filteredRegistered = _registeredUsers;
          _filteredUnregistered = _unregisteredContacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading contacts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load contacts. Please try again.';
        });
      }
    }
  }

  void _filterContacts(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredRegistered = _registeredUsers;
        _filteredUnregistered = _unregisteredContacts;
      } else {
        final lowerQuery = query.toLowerCase();
        
        _filteredRegistered = _registeredUsers.where((user) {
          final name = (user['name'] ?? '').toLowerCase();
          final phone = (user['phoneNumber'] ?? '').toLowerCase();
          return name.contains(lowerQuery) || phone.contains(lowerQuery);
        }).toList();

        _filteredUnregistered = _unregisteredContacts.where((contact) {
          final name = contact.displayName.toLowerCase();
          final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
          return name.contains(lowerQuery) || phone.contains(lowerQuery);
        }).toList();
      }
    });
  }

  Future<void> _inviteContact(String phoneNumber) async {
    final Uri smsLaunchUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: <String, String>{
        'body': 'Hey! Join me on UTELO using this link: https://utelo.app/download', // Placeholder link
      },
    );

    try {
      if (await canLaunchUrl(smsLaunchUri)) {
        await launchUrl(smsLaunchUri);
      } else {
        // Fallback for some devices/simulators
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
  Widget build(BuildContext context) {
    super.build(context); // IMPORTANT
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColor = isDark ? const Color(0xFF0141B5) : const Color(0xFF001133);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Content
          // Use CustomScrollView to handle slivers and padding correctly behind header
          _isLoading 
              ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(themeColor)))
              : _errorMessage != null
                  ? Center(child: Text(_errorMessage!, style: GoogleFonts.poppins(color: Colors.red)))
                  : RefreshIndicator(
                      onRefresh: _loadContacts,
                      child: ListView(
                        // Fixed: Top padding adjusted to start exactly after header (Header is approx 180 + SafeArea)
                        // Fixed: Bottom padding added for Nav Bar
                        padding: const EdgeInsets.only(top: 210, bottom: 120), 
                        children: [
                           // SECTION 1: REGISTERED USERS
                           if (_filteredRegistered.isNotEmpty) ...[
                             Padding(
                               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                               child: Text(
                                 'On UTELO',
                                 style: GoogleFonts.poppins(
                                   fontSize: 14, 
                                   fontWeight: FontWeight.w600,
                                   color: isDark ? Colors.grey.shade400 : Colors.grey.shade700
                                 ),
                               ),
                             ),
                             ..._filteredRegistered.map((user) {
                                final name = user['name'] ?? 'Unknown';
                                final avatar = user['profilePicture'];
                                final uid = user['uid'];
                                final bio = user['bio'] ?? 'Hey there! I am using UTELO';
                                
                                 return StreamBuilder<DocumentSnapshot>(
                                   stream: UserService().getUserStream(uid),
                                   builder: (context, snapshot) {
                                     final userData = snapshot.data?.data() as Map<String, dynamic>?;
                                     final isOnline = _isUserOnline(userData);
                                     final profileColor = userData?['profileColor'];

                                     return ListTile(
                                       leading: UserAvatar(
                                         name: name,
                                         profilePicture: avatar,
                                         size: 50,
                                         isOnline: isOnline,
                                         colorId: profileColor,
                                         onTap: () {
                                           Navigator.push(context, MaterialPageRoute(
                                              builder: (context) => ProfileViewScreen(userId: uid),
                                           ));
                                         },
                                       ),
                                       title: Text(
                                         name,
                                         style: GoogleFonts.poppins(
                                           fontSize: 16,
                                           fontWeight: FontWeight.w600,
                                           color: isDark ? Colors.white : Colors.black87,
                                         ),
                                       ),
                                       subtitle: Text(
                                         bio,
                                         maxLines: 1,
                                         overflow: TextOverflow.ellipsis,
                                         style: GoogleFonts.poppins(
                                           fontSize: 13,
                                           color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                         ),
                                       ),
                                       trailing: Row(
                                         mainAxisSize: MainAxisSize.min,
                                         children: [
                                           IconButton(
                                             icon: const Icon(Icons.chat_bubble_outline),
                                             color: themeColor,
                                             onPressed: () {
                                               Navigator.push(context, MaterialPageRoute(
                                                 builder: (context) => ChatDetailScreen(
                                                   contactName: name,
                                                   contactAvatar: avatar ?? '',
                                                   contactId: uid,
                                                 ),
                                               ));
                                             },
                                           ),
                                           IconButton(
                                             icon: const Icon(Icons.call_outlined),
                                             color: Colors.green,
                                             onPressed: () {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                   const SnackBar(content: Text('Starting call...')),
                                                );
                                             },
                                           ),
                                         ],
                                       ),
                                     );
                                   }
                                 );
                             }).toList(),
                             const Divider(height: 32),
                           ],

                           // SECTION 2: UNREGISTERED CONTACTS
                           if (_filteredUnregistered.isNotEmpty) ...[
                             Padding(
                               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                               child: Text(
                                 'Invite to UTELO',
                                 style: GoogleFonts.poppins(
                                   fontSize: 14, 
                                   fontWeight: FontWeight.w600,
                                   color: isDark ? Colors.grey.shade400 : Colors.grey.shade700
                                 ),
                               ),
                             ),
                             ..._filteredUnregistered.map((contact) {
                                final name = contact.displayName;
                                final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
                                
                                return ListTile(
                                  leading: UserAvatar(
                                    name: name,
                                    size: 50,
                                    // Random color is handled by UserAvatar
                                  ),
                                  title: Text(
                                    name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16, 
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  subtitle: Text(
                                    phone,
                                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                                  ),
                                  trailing: ElevatedButton(
                                    onPressed: () => _inviteContact(phone),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDark ? Colors.white : themeColor,
                                      foregroundColor: isDark ? themeColor : Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      minimumSize: const Size(0, 0),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add, 
                                          size: 16, 
                                          color: isDark ? themeColor : Colors.white,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Invite',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12, 
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? themeColor : Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                             }).toList(),
                           ],
                           
                           if (_filteredRegistered.isEmpty && _filteredUnregistered.isEmpty && !_isLoading)
                             Center(
                               child: Padding(
                                 padding: const EdgeInsets.only(top: 50),
                                 child: Text(
                                   'No contacts found',
                                   style: GoogleFonts.poppins(color: Colors.grey),
                                 ),
                               ),
                             ),
                        ],
                      ),
                    ),
          
          // Header
          Positioned(
            top: 0, left: 0, right: 0,
            child: CurvedHeader(
              showBack: false,
              titleWidget: Text(
                'Contacts',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              actions: [
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/subscription');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset(
                      'assets/images/crown_icon.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
              bottomChild: Container(
                  height: 40,
                  margin: const EdgeInsets.only(bottom: 0, top: 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    onChanged: _filterContacts,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Search contacts',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    ),
                  ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
