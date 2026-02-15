import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/call_service.dart';
import '../services/local_storage_service.dart';
import '../services/encryption_service.dart';
import '../widgets/country_code_picker.dart';
import 'chat_detail_screen.dart';
import 'profile_view_screen.dart';
import '../widgets/curved_header.dart';
import '../widgets/user_avatar.dart';
import '../services/user_service.dart';
import '../widgets/skeletons.dart';
import '../widgets/empty_state.dart'; // Added Import

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({Key? key}) : super(key: key);

  @override
  ChatsScreenState createState() => ChatsScreenState();
}

class ChatsScreenState extends State<ChatsScreen> with AutomaticKeepAliveClientMixin {
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  final LocalStorageService _localStorage = LocalStorageService();
  final EncryptionService _encryptionService = EncryptionService();
  
  String _searchQuery = '';
  String? _currentUserId;

  @override
  bool get wantKeepAlive => true; // Keep state alive

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    // Priority 1: Firebase Auth (Sync)
    String? userId = _authService.currentUserId;
    
    // Priority 2: Local Storage (Async Fallback)
    userId ??= await _localStorage.getUserId();

    if (mounted) {
      setState(() {
        _currentUserId = userId;
      });
      
      // Force start listener when Home Screen loads (Safety Net)
      if (userId != null) {
        debugPrint('ChatsScreen: Forcing listener start for $userId');
        CallService().startListeningForIncomingCalls(userId);
      }
    }
  }

  void showNewChatDialog() {
    final phoneController = TextEditingController();
    String fullPhoneNumber = '+91';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(
            'New Chat',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter phone number to start chatting',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDark ? Colors.grey.shade300 : Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              Theme(
                data: Theme.of(context).copyWith(
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                    hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: isDark ? const Color(0xFF444444) : Colors.grey),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: isDark ? const Color(0xFF444444) : Colors.grey),
                    ),
                  ),
                  textTheme: TextTheme(
                    bodyLarge: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    bodyMedium: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  ),
                ),
                child: PhoneInputWithCountryCode(
                  phoneController: phoneController,
                  onFullNumberChanged: (newFullNumber) {
                    fullPhoneNumber = newFullNumber;
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final phoneNumber = phoneController.text.trim();
                if (phoneNumber.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a phone number')),
                  );
                  return;
                }
                
                // Use the tracked full phone number
                final numberToUse = fullPhoneNumber.isEmpty ? '+91 $phoneNumber' : fullPhoneNumber;
                
                Navigator.pop(context);
                await _searchAndStartChat(numberToUse);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0141B5), // Theme Blue
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Start Chat',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _searchAndStartChat(String phoneNumber) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Search for user by phone number
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      Navigator.pop(context); // Close loading

      if (userDoc.docs.isEmpty) {
        // User not found
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                'User Not Found',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              content: Text(
                'This user is not using UTELO. Invite them to join!',
                style: GoogleFonts.poppins(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'OK',
                    style: GoogleFonts.poppins(color: const Color(0xFFB64166)),
                  ),
                ),
              ],
            ),
          );
        }
        return;
      }

      // User found, navigate to chat
      final userData = userDoc.docs.first.data();
      final contactId = userDoc.docs.first.id;
      final contactName = userData['name'] ?? 'User';
      final contactAvatar = userData['profilePicture'] ?? '';

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              contactName: contactName,
              contactAvatar: contactAvatar,
              contactId: contactId,
            ),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading if still open
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
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
      backgroundColor: Colors.transparent, // Transparent to show MainScreen Mesh
      body: Stack(
        children: [
          // Chat list (Behind header)
          ClipRect(
            child: _currentUserId == null
                ? ChatListSkeleton(isDark: isDark) // Skeleton for Auth Check
                : StreamBuilder<QuerySnapshot>(
                    stream: _chatService.getChatRooms(_currentUserId!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return ChatListSkeleton(isDark: isDark); // Skeleton for Data Fetch
                      }

                      if (snapshot.hasError) {
                         return Center(
                           child: Text('Error loading chats', style: GoogleFonts.poppins(color: Colors.red)),
                         );
                      }



// ...

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return EmptyStateWidget(
                          isDark: isDark,
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'No Chats Yet',
                          subtitle: 'Start a conversation with your friends and family on UTELO.',
                          quote: 'Connecting people, breaking barriers.',
                          buttonText: 'Start Chat',
                          onButtonPressed: () {
                             showNewChatDialog();
                          },
                        );
                      }
                      
                      final chatRooms = snapshot.data!.docs;
                      chatRooms.sort((a, b) {
                         final aTime = (a.data() as Map)['lastMessageTime'] as Timestamp?;
                         final bTime = (b.data() as Map)['lastMessageTime'] as Timestamp?;
                         if (aTime == null && bTime == null) return 0;
                         if (aTime == null) return 1;
                         if (bTime == null) return -1;
                         return bTime.compareTo(aTime);
                      });

                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 240, bottom: 120), // Adjusted top padding
                        itemCount: chatRooms.length,
                        itemBuilder: (context, index) {
                           final chatRoom = chatRooms[index];
                           final chatData = chatRoom.data() as Map<String, dynamic>;
                           final participants = List<String>.from(chatData['participants'] ?? []);
                           final contactId = participants.firstWhere((id) => id != _currentUserId, orElse: () => '');
                           if (contactId.isEmpty) return const SizedBox.shrink();

                            return StreamBuilder<DocumentSnapshot>(
                              stream: UserService().getUserStream(contactId),
                              builder: (context, userSnapshot) {
                                String contactName = 'User'; // Default
                                String contactAvatar = '';
                                
                                if (userSnapshot.hasData && userSnapshot.data!.data() != null) {
                                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                                  contactName = userData['name'] ?? 'User';
                                  contactAvatar = userData['profilePicture'] ?? '';
                                } else if (userSnapshot.connectionState == ConnectionState.waiting) {
                                   // Try to get from UserService internal cache synchronously if possible?
                                   // For now, just show 'User' to avoid the jarring ListTile jump.
                                   contactName = '...'; 
                                }

                                if (_searchQuery.isNotEmpty && !contactName.toLowerCase().contains(_searchQuery.toLowerCase())) {
                                  if (contactName == '...') return const SizedBox.shrink(); // Hide if still loading
                                  return const SizedBox.shrink();
                                }

                               final lastMessage = chatData['lastMessage'] ?? '';
                               
                               return ListTile(
                                 leading: UserAvatar(
                                    name: contactName,
                                    profilePicture: contactAvatar,
                                    size: 50,
                                    isOnline: (userSnapshot.data!.data() as Map<String, dynamic>?)?['isOnline'] ?? false,
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(
                                        builder: (context) => ProfileViewScreen(userId: contactId),
                                      ));
                                    },
                                 ),
                                 title: Text(
                                   contactName,
                                   style: GoogleFonts.poppins(
                                     fontSize: 16,
                                     fontWeight: FontWeight.w600,
                                     color: isDark ? Colors.white : Colors.black87,
                                   ),
                                 ),
                                 subtitle: Text(
                                   lastMessage,
                                   maxLines: 1,
                                   overflow: TextOverflow.ellipsis,
                                   style: GoogleFonts.poppins(
                                     fontSize: 13,
                                     color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                   ),
                                 ),
                                 onTap: () {
                                   Navigator.push(context, MaterialPageRoute(
                                     builder: (context) => ChatDetailScreen(
                                       contactName: contactName,
                                       contactAvatar: contactAvatar, 
                                       contactId: contactId
                                     )
                                   ));
                                 },
                               );
                             }
                           );
                        } 
                      );
                   },
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
                  Image.asset(
                    'assets/orbitalkLogo.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'UTELO',
                    style: GoogleFonts.poppins(
                      fontSize: 23,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (_currentUserId != null)
                   Padding(
                     padding: const EdgeInsets.only(left: 8, top: 4),
                     child: Text(
                      'ID: ...${_currentUserId!.substring(_currentUserId!.length - 4)}',
                      style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70),
                     ),
                   ),
                ],
              ),
            ),
            actions: [],
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
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                      suffixIcon: _searchQuery.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    ),
                  ),
                ),
                // MESSAGES TITLE INSIDE HEADER
                Padding(
                   padding: const EdgeInsets.only(top: 4, bottom: 2, left: 4),
                   child: Text(
                      'Messages',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                   ),
                 ),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }
}
