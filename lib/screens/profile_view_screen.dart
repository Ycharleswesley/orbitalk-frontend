import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/call_model.dart';
import '../widgets/mesh_gradient_background.dart';
import '../widgets/user_avatar.dart';
import '../services/call_service.dart';
import '../services/local_storage_service.dart';
import 'image_viewer_screen.dart';
import 'chat_detail_screen.dart';
import 'subscription_screen.dart';
class ProfileViewScreen extends StatefulWidget {
  final String userId;
  final String? contactName;
  final String? contactAvatar;

  const ProfileViewScreen({
    Key? key,
    required this.userId,
    this.contactName,
    this.contactAvatar,
  }) : super(key: key);

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  final CallService _callService = CallService();
  final LocalStorageService _localStorage = LocalStorageService();
  List<CallModel> _callHistory = [];
  String? _currentUserId;

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
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      _currentUserId = await _localStorage.getUserId();
      
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (mounted) {
        if (doc.exists) {
            _userData = doc.data();
        }
        await _loadCallHistory();
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCallHistory() async {
      if (_currentUserId == null) {
          setState(() => _isLoading = false);
          return;
      }
      
      // Load ALL calls then filter (Simple but effective for now)
      // Ideally should query by participants.
      final allCallsMock = _callService.getCallHistory(_currentUserId!);
      allCallsMock.listen((calls) {
          if (mounted) {
              setState(() {
                  _callHistory = calls.where((c) => 
                    c.callerId == widget.userId || c.receiverId == widget.userId
                  ).toList();
                  _isLoading = false;
              });
          }
      });
  }

  Widget _buildProfileImage() {
    final profilePicture = _userData?['profilePicture'] ?? widget.contactAvatar;
    final name = _userData?['name'] ?? widget.contactName ?? 'User';

    return Center(
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: UserAvatar(
          name: name,
          profilePicture: profilePicture,
          size: 150,
          isOnline: _isUserOnline(_userData),
          onTap: () {
            if (profilePicture != null && profilePicture.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ImageViewerScreen(
                    imageUrl: profilePicture,
                    preventScreenshots: true,
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    final name = _userData?['name'] ?? widget.contactName ?? 'Unknown User';
    final phoneNumber = _userData?['phoneNumber'] ?? '';
    final lastSeen = _userData?['lastSeen'] as Timestamp?;
    final isOnline = _isUserOnline(_userData);

    String statusText = 'Offline';
    if (isOnline) {
      statusText = 'Online';
    } else if (lastSeen != null) {
      final lastSeenTime = lastSeen.toDate();
      final now = DateTime.now();
      final difference = now.difference(lastSeenTime);

      if (difference.inMinutes < 1) {
        statusText = 'Last seen just now';
      } else if (difference.inHours < 1) {
        statusText = 'Last seen ${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        statusText = 'Last seen ${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        statusText = 'Last seen ${difference.inDays}d ago';
      } else {
        statusText = 'Last seen ${DateFormat('MMM d').format(lastSeenTime)}';
      }
    }

    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Column(
          children: [
            // Name
            Text(
              name,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            // Status
            Column(
              children: [
                Text(
                  statusText,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isOnline ? Colors.green : Colors.grey.shade600,
                    fontWeight: isOnline ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
                if (_userData?['isLoggedOut'] == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🚫', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          'User not logged in',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            if (phoneNumber.isNotEmpty) ...[
              const SizedBox(height: 24),

              // Phone section
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phone',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            phoneNumber,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.call, color: Colors.green, size: 20),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Calling $name')),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.message, color: Colors.blue, size: 20),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatDetailScreen(
                                  contactName: _userData?['name'] ?? widget.contactName ?? 'User',
                                  contactAvatar: _userData?['profilePicture'] ?? widget.contactAvatar ?? '',
                                  contactId: widget.userId,
                                ),
                              ),
                            );
                          },
                        ),
                        InkWell(
                          onTap: () {
                             Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset('assets/images/crown_icon.png', width: 16, height: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'PREMIUM',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Contact Info',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        actions: [

          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: isDark ? Colors.white : Colors.black87),
            onSelected: (value) {
               // Placeholder Actions
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action: $value')));
            },
            itemBuilder: (context) => [
               PopupMenuItem(
                 value: 'edit',
                 child: Row(children: [Icon(Icons.edit, size: 20, color: Colors.grey), SizedBox(width: 8), Text('Edit Name')]),
               ),
               PopupMenuItem(
                 value: 'block',
                 child: Row(children: [Icon(Icons.block, size: 20, color: Colors.grey), SizedBox(width: 8), Text('Block')]),
               ),
               PopupMenuItem(
                 value: 'delete',
                 child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('Delete Contact', style: TextStyle(color: Colors.red))]),
               ),
            ],
          ),
        ],
      ),
      body: MeshGradientBackground(
        isDark: isDark,
        child: SafeArea(
          child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _userData == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData && snapshot.data!.exists) {
            _userData = snapshot.data!.data() as Map<String, dynamic>;
          }

          return SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 32),

                  // Profile Image
                  _buildProfileImage(),

                  const SizedBox(height: 24),

                  // User Info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildUserInfo(),
                  ),

                  const SizedBox(height: 24),

                  // Call History
                  _buildCallHistory(isDark),

                  const SizedBox(height: 32),
                ],
              ),
            );
        },
      ),
    ),
    ),
    );
  }
  
  Widget _buildCallHistory(bool isDark) {
    if (_callHistory.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _callHistory.length,
        itemBuilder: (context, index) {
          final call = _callHistory[index];
          final isIncoming = call.receiverId == _currentUserId;
          
          return ListTile(
            leading: Icon(
              isIncoming ? Icons.call_received : Icons.call_made,
              color: call.callStatus == CallStatus.missed ? Colors.red : (isIncoming ? Colors.green : Colors.blue),
              size: 20,
            ),
            title: Text(
              call.callStatus == CallStatus.missed ? 'Missed Call' : (isIncoming ? 'Incoming Call' : 'Outgoing Call'),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              DateFormat('MMM d, h:mm a').format(call.timestamp),
               style: GoogleFonts.poppins(
                color: isDark ? Colors.white60 : Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          );
        },
      ),
    );
  }
}
