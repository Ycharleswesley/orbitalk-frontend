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

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({Key? key}) : super(key: key);

  @override
  ChatsScreenState createState() => ChatsScreenState();
}

class ChatsScreenState extends State<ChatsScreen> {
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  final LocalStorageService _localStorage = LocalStorageService();
  final EncryptionService _encryptionService = EncryptionService();
  
  String _searchQuery = '';
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final userId = await _localStorage.getUserId();
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
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'New Chat',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter phone number to start chatting',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 16),
              PhoneInputWithCountryCode(
                phoneController: phoneController,
                onFullNumberChanged: (newFullNumber) {
                  fullPhoneNumber = newFullNumber;
                },
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
                backgroundColor: const Color(0xFFB64166),
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

  Widget _buildAvatar(String name, String? profilePicture) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.amber,
      Colors.pink,
    ];
    
    final colorIndex = name.codeUnitAt(0) % colors.length;
    
    if (profilePicture != null && profilePicture.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: profilePicture,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          placeholder: (context, url) => CircleAvatar(
            radius: 25,
            backgroundColor: Colors.grey.shade300,
            child: const Icon(Icons.person, color: Colors.white),
          ),
          errorWidget: (context, url, error) => CircleAvatar(
            radius: 25,
            backgroundColor: colors[colorIndex],
            child: Text(
              name[0].toUpperCase(),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }
    
    return CircleAvatar(
      radius: 25,
      backgroundColor: colors[colorIndex],
      child: Text(
        name[0].toUpperCase(),
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            if (_currentUserId != null)
              Text(
                'ID: ...${_currentUserId!.substring(_currentUserId!.length - 4)}',
                style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ring_volume, color: Colors.orange),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Testing Ring...')),
              );
              CallService().simulateIncomingCall();
            },
            tooltip: 'Simulate Incoming Call',
          )
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: isDark ? Colors.grey.shade500 : Colors.grey,
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF0D0D0D) : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          
          // Chat list
          Expanded(
            child: _currentUserId == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
                    stream: _chatService.getChatRooms(_currentUserId!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        debugPrint('Error loading chats: ${snapshot.error}');
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 60, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading chats',
                                style: GoogleFonts.poppins(
                                  color: Colors.red,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 40),
                                child: Text(
                                  'Please check your Firestore rules and indexes',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 80,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No chats yet',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap + to start a new chat',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final chatRooms = snapshot.data!.docs;
                      
                      // Sort by lastMessageTime (most recent first)
                      chatRooms.sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;
                        final aTime = aData['lastMessageTime'] as Timestamp?;
                        final bTime = bData['lastMessageTime'] as Timestamp?;
                        
                        if (aTime == null && bTime == null) return 0;
                        if (aTime == null) return 1;
                        if (bTime == null) return -1;
                        
                        return bTime.compareTo(aTime);
                      });

                      return ListView.builder(
                        itemCount: chatRooms.length,
                        itemBuilder: (context, index) {
                          final chatRoom = chatRooms[index];
                          final chatData = chatRoom.data() as Map<String, dynamic>;
                          
                          // Get the other user's ID
                          final participants = List<String>.from(chatData['participants'] ?? []);
                          final contactId = participants.firstWhere(
                            (id) => id != _currentUserId,
                            orElse: () => '',
                          );

                          if (contactId.isEmpty) return const SizedBox.shrink();

                          return StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(contactId)
                                .snapshots(),
                            builder: (context, userSnapshot) {
                              if (!userSnapshot.hasData) {
                                return const SizedBox.shrink();
                              }

                              final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                              if (userData == null) return const SizedBox.shrink();

                              final contactName = userData['name'] ?? 'User';
                              final contactAvatar = userData['profilePicture'] ?? '';
                              
                              // Smart Online Check
                              bool isOnline = userData['isOnline'] ?? false;
                              if (isOnline) {
                                final lastSeen = userData['lastSeen'] as Timestamp?;
                                if (lastSeen != null) {
                                   final diff = DateTime.now().difference(lastSeen.toDate());
                                   if (diff.inSeconds > 90) { 
                                     isOnline = false; // Override if stale > 90s
                                   }
                                }
                              }
                              
                              // Filter by search query
                              if (_searchQuery.isNotEmpty &&
                                  !contactName.toLowerCase().contains(_searchQuery.toLowerCase())) {
                                return const SizedBox.shrink();
                              }
                              
                              // Last message (plain text or label like 📷 Image)
                              final String lastMessage = chatData['lastMessage'] ?? '';

                              // Format timestamp
                              final lastMessageTime = chatData['lastMessageTime'] as Timestamp?;
                              String timeString = '';
                              if (lastMessageTime != null) {
                                final now = DateTime.now();
                                final messageDate = lastMessageTime.toDate();
                                final difference = now.difference(messageDate);

                                if (difference.inDays == 0) {
                                  timeString = '${messageDate.hour}:${messageDate.minute.toString().padLeft(2, '0')}';
                                } else if (difference.inDays == 1) {
                                  timeString = 'Yesterday';
                                } else if (difference.inDays < 7) {
                                  timeString = '${difference.inDays}d ago';
                                } else {
                                  timeString = '${messageDate.day}/${messageDate.month}';
                                }
                              }

                              return InkWell(
                                onTap: () {
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
                                },
                                child: Container(
                                  color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      // Avatar
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ProfileViewScreen(
                                                userId: contactId,
                                                contactName: contactName,
                                                contactAvatar: contactAvatar,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Stack(
                                          children: [
                                            _buildAvatar(contactName, contactAvatar),
                                            if (isOnline)
                                              Positioned(
                                                bottom: 0,
                                                right: 0,
                                                child: Container(
                                                  width: 14,
                                                  height: 14,
                                                  decoration: BoxDecoration(
                                                    color: Colors.green,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      
                                      // Chat info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              contactName,
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Time + Unread badge
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          if (timeString.isNotEmpty)
                                            Text(
                                              timeString,
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          const SizedBox(height: 6),
                                          StreamBuilder<QuerySnapshot>(
                                            stream: FirebaseFirestore.instance
                                                .collection('chatRooms')
                                                .doc(chatRoom.id)
                                                .collection('messages')
                                                .where('receiverId', isEqualTo: _currentUserId)
                                                .where('isRead', isEqualTo: false)
                                                .snapshots(),
                                            builder: (context, unreadSnapshot) {
                                              if (!unreadSnapshot.hasData) {
                                                return const SizedBox.shrink();
                                              }
                                              final unread = unreadSnapshot.data!.docs.length;
                                              if (unread == 0) return const SizedBox.shrink();
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.green,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  unread > 99 ? '99+' : '$unread',
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
