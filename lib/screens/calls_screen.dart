import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/call_model.dart';
import '../services/call_service.dart';
import '../services/local_storage_service.dart';
import '../widgets/country_code_picker.dart';
import '../utils/app_colors.dart'; // Unified
import 'outgoing_call_screen.dart';
import 'profile_view_screen.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({Key? key}) : super(key: key);

  @override
  State<CallsScreen> createState() => CallsScreenState();
}

class CallsScreenState extends State<CallsScreen> {
  final CallService _callService = CallService();
  final LocalStorageService _localStorage = LocalStorageService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? _currentUserId;
  String _searchQuery = '';
  bool _isSearching = false;

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
    }
    debugPrint('CallsScreen: Loaded user ID: $userId');
  }

  // Public method to show new call dialog (called from MainScreen FAB)
  void showNewCallDialog() {
    final phoneController = TextEditingController();
    String fullPhoneNumber = '+91';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'New Call',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter phone number to make a call',
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
                await _searchAndCall(numberToUse);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB64166),
              ),
              child: Text(
                'Call',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _searchAndCall(String phoneNumber) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Search for user by phone number
      final userDoc = await _firestore
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

      // User found, initiate call
      final userData = userDoc.docs.first.data();
      final contactId = userDoc.docs.first.id;
      final contactName = userData['name'] ?? 'User';
      final contactAvatar = userData['profilePicture'] ?? '';
      final contactColor = userData['profileColor'] ?? 0; // Added

      await _initiateCallToContact(contactId, contactName, contactAvatar, contactColor);
    } catch (e) {
      Navigator.pop(context); // Close loading if still open
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _initiateCallToContact(String contactId, String contactName, String contactAvatar, int contactColor) async { // Added contactColor
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to initiate call. Please try again.')),
      );
      return;
    }

    try {
      debugPrint('CallsScreen: Initiating call to $contactName');
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final userName = await _localStorage.getUserName();
      final userDoc = await _firestore.collection('users').doc(_currentUserId).get();
      final userAvatar = userDoc.data()?['profilePicture'] ?? '';

      final callId = await _callService.initiateCall(
        callerId: _currentUserId!,
        callerName: userName ?? 'User',
        callerAvatar: userAvatar,
        receiverId: contactId,
        receiverName: contactName,
        receiverAvatar: contactAvatar,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close loading
        
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => OutgoingCallScreen(
              callId: callId,
              contactId: contactId, // Passed
              contactName: contactName,
              contactAvatar: contactAvatar,
              contactProfileColor: contactColor, // Use passed color
            ),
          ),
        );
      }
      
      debugPrint('CallsScreen: Call initiated with ID: $callId');
    } catch (e) {
      debugPrint('CallsScreen: Error initiating call: $e');
      
      if (mounted) {
        Navigator.of(context).pop(); // Close loading
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initiate call: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                  hintText: 'Search calls...',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey.shade600,
                  ),
                  border: InputBorder.none,
                ),
              )
            : Text(
                'Calls',
                style: GoogleFonts.poppins(
                  fontSize: 22,
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
      body: _currentUserId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<CallModel>>(
              stream: _callService.getCallHistory(_currentUserId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  debugPrint('CallsScreen: Error loading call history: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 60,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading call history',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.call_outlined,
                          size: 100,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No recent calls',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your call history will appear here',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final allCalls = snapshot.data!;
                
                // Filter calls based on search query
                final calls = _searchQuery.isEmpty
                    ? allCalls
                    : allCalls.where((call) {
                        final isIncoming = call.receiverId == _currentUserId;
                        final contactName = isIncoming 
                            ? (call.callerName ?? 'Unknown') 
                            : (call.receiverName ?? 'Unknown');
                        return contactName.toLowerCase().contains(_searchQuery.toLowerCase());
                      }).toList();
                
                if (calls.isEmpty && _searchQuery.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 60,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No calls found',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                debugPrint('CallsScreen: Displaying ${calls.length} calls');

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Recents',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: calls.length,
                        itemBuilder: (context, index) {
                          if (index >= calls.length) {
                            return const SizedBox.shrink();
                          }
                          
                          final call = calls[index];
                          final isIncoming = call.receiverId == _currentUserId;
                          final contactId = isIncoming ? call.callerId : call.receiverId;
                          final contactName = isIncoming ? (call.callerName ?? 'Unknown') : (call.receiverName ?? 'Unknown');
                          final contactAvatar = isIncoming ? (call.callerAvatar ?? '') : (call.receiverAvatar ?? '');
                          final contactColorId = isIncoming ? call.callerProfileColor : call.receiverProfileColor; // Get Color ID

                          return _buildCallItem(
                            context,
                            call,
                            contactId,
                            contactName,
                            contactAvatar,
                            contactColorId, // Pass Color ID
                            isIncoming,
                            isDark,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildCallItem(
    BuildContext context,
    CallModel call,
    String contactId,
    String contactName,
    String contactAvatar,
    int contactColorId, // Added parameter
    bool isIncoming,
    bool isDark,
  ) {
    IconData callIcon;
    Color iconColor;

    final isMissed = call.callStatus == CallStatus.missed || 
                     (call.callStatus == CallStatus.cancelled && isIncoming);
    
    // Declined calls should appear Red but not Bold (Viewed)
    final isDeclined = call.callStatus == CallStatus.declined;

    if (isMissed) {
      callIcon = Icons.phone_missed; 
      iconColor = Colors.red;
    } else if (isDeclined) {
      callIcon = Icons.cancel_presentation; // Or block/busy
      iconColor = Colors.red; // Red to indicate failure/rejection
    } else if (isIncoming) {
      callIcon = Icons.call_received;
      iconColor = Colors.green;
    } else {
      callIcon = Icons.call_made;
      iconColor = Colors.blue;
    }

    final isViewed = isIncoming ? call.receiverViewed : call.callerViewed;


    return ListTile(
      leading: GestureDetector(
        onTap: () {
           _viewProfile(context, contactId);
        },
        child: _buildAvatar(contactName, contactAvatar, contactColorId), // Pass Color ID
      ),
      title: Text(
        contactName,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: (isMissed && !isViewed) ? FontWeight.bold : FontWeight.normal, 
          // Red if Missed (Unviewed) OR Declined (Failure). Otherwise Theme color.
          color: ((isMissed && !isViewed) || isDeclined) ? Colors.red : (isDark ? Colors.white : Colors.black87),
        ),
      ),
      subtitle: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(contactId).snapshots(),
        builder: (context, snapshot) {
          bool isLoggedOut = false;
          if (snapshot.hasData && snapshot.data!.exists) {
            isLoggedOut = (snapshot.data!.data() as Map<String, dynamic>)['isLoggedOut'] ?? false;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    callIcon,
                    size: 14,
                    color: iconColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatCallTime(call.timestamp),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: (!isViewed) ? FontWeight.w600 : FontWeight.normal,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              if (isLoggedOut)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      const Text('🚫', style: TextStyle(fontSize: 10)),
                      const SizedBox(width: 4),
                      Text(
                        'User not logged in',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        }
      ),
      trailing: IconButton(
        icon: const Icon(
            Icons.call,
            color: Colors.green, 
          ),
        onPressed: () {
          _markAsViewed(call);
          _initiateCallToContact(contactId, contactName, contactAvatar, contactColorId); // Pass color
        },
      ),
      onTap: () {
        _markAsViewed(call);
      },
      onLongPress: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete Call Log?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: Text('Remove this call from your history?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
              ),
              TextButton(
                 onPressed: () async {
                   Navigator.pop(context);
                   await FirebaseFirestore.instance.collection('calls').doc(call.callId).delete();
                 },
                 child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar(String name, String? profilePicture, int colorId) {
    final bgColor = AppColors.getColor(colorId);
    
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
            backgroundColor: bgColor,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
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
      backgroundColor: bgColor,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatCallTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return DateFormat('h:mm a').format(timestamp);
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${DateFormat('h:mm a').format(timestamp)}';
    } else if (difference.inDays < 7) {
      return '${DateFormat('EEEE').format(timestamp)}, ${DateFormat('h:mm a').format(timestamp)}';
    } else {
      return DateFormat('d MMMM, h:mm a').format(timestamp);
    }
  }

  void _markAsViewed(CallModel call) {
    // Only update if not already viewed to save writes
    final isIncoming = call.receiverId == _currentUserId;
    if (isIncoming && !call.receiverViewed) {
       _firestore.collection('calls').doc(call.callId).update({'receiverViewed': true});
    } else if (!isIncoming && !call.callerViewed) {
       _firestore.collection('calls').doc(call.callId).update({'callerViewed': true});
    }
  }

  void _viewProfile(BuildContext context, String userId) {
    if (userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileViewScreen(userId: userId),
      ),
    );
  }
}
