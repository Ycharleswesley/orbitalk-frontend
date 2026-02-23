import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/call_model.dart';
import '../services/call_service.dart';
import '../services/local_storage_service.dart';
import '../services/auth_service.dart'; // Added
import '../widgets/country_code_picker.dart';
import '../utils/app_colors.dart'; // Unified
import 'outgoing_call_screen.dart';
import 'profile_view_screen.dart';
import '../widgets/curved_header.dart';
import '../widgets/user_avatar.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeletons.dart'; // Added Import

class CallsScreen extends StatefulWidget {
  const CallsScreen({Key? key}) : super(key: key);

  @override
  State<CallsScreen> createState() => CallsScreenState();
}

class CallsScreenState extends State<CallsScreen> with AutomaticKeepAliveClientMixin {
  final CallService _callService = CallService();
  final LocalStorageService _localStorage = LocalStorageService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? _currentUserId;
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  bool get wantKeepAlive => true; // Keep state alive

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    // Priority 1: Firebase Auth (Sync)
    String? userId = AuthService().currentUserId;
    
    // Priority 2: Local Storage (Async Fallback)
    userId ??= await _localStorage.getUserId();

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(
            'New Call',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter phone number to make a call',
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
                await _searchAndCall(numberToUse);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0141B5), // Theme Blue
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    super.build(context); // IMPORTANT
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColor = isDark ? const Color(0xFF0141B5) : const Color(0xFF001133);
    
    return Scaffold(
      backgroundColor: Colors.transparent, // Transparent to show MainScreen Mesh
      body: Stack(
        children: [
          // Calls List / Content
          ClipRect(
            child: _currentUserId == null
                ? ChatListSkeleton(isDark: isDark)
                : StreamBuilder<List<CallModel>>(
                  stream: _callService.getCallHistory(_currentUserId!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                        return ChatListSkeleton(isDark: isDark);
                    }
                    if (snapshot.hasError) {
                       return Center(child: Text('Error loading calls'));
                    }
                    


// ...

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return EmptyStateWidget(
                          isDark: isDark,
                          icon: Icons.phone_callback_rounded,
                          title: 'No Calls Yet',
                          subtitle: 'Connect with your loved ones instantly with clear voice calls.',
                          quote: 'A simple hello can change someone\'s day.',
                          buttonText: 'Start Call',
                          onButtonPressed: () {
                             showNewCallDialog();
                          },
                        );
                    }

                    final allCalls = snapshot.data!;
                    final calls = _searchQuery.isEmpty ? allCalls : allCalls.where((c) {
                        final name = c.receiverId == _currentUserId ? c.callerName : c.receiverName;
                        return (name ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
                    }).toList();

                    return ListView.builder(
                       // Matches ContactsScreen
                      padding: const EdgeInsets.only(top: 210, bottom: 120),
                      itemCount: calls.length,
                      itemBuilder: (context, index) {
                        final call = calls[index];
                        final isIncoming = call.receiverId == _currentUserId;
                        final isViewed = isIncoming ? call.receiverViewed : call.callerViewed;
                        final contactId = isIncoming ? call.callerId : call.receiverId;
                        final contactName = isIncoming ? (call.callerName ?? 'Unknown') : (call.receiverName ?? 'Unknown');
                        final contactAvatar = isIncoming ? (call.callerAvatar ?? '') : (call.receiverAvatar ?? '');
                        final contactColorId = isIncoming ? call.callerProfileColor : call.receiverProfileColor;

                        return _buildCallItem(
                            context,
                            call,
                            contactId,
                            contactName,
                            contactAvatar,
                            contactColorId,
                            isIncoming,
                            isDark,
                          );
                      },
                    );
                  }
              ),
          ),
          
          // Header (Top Layer)
          Positioned(
            top: 0, left: 0, right: 0,
            child: CurvedHeader(
              showBack: false,
              titleWidget: Text(
                'Voice Call',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              bottomChild: Container(
                  height: 40,
                  margin: const EdgeInsets.only(bottom: 0, top: 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    autofocus: false,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10), // Adjusted vertical padding for centering
                      suffixIcon: _searchQuery.isNotEmpty 
                           ? IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                              onPressed: () {
                                 setState(() {
                                   _searchQuery = '';
                                 });
                              },
                           )
                           : null
                    ),
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
          ),
          ),
        ],
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
    
    // Dynamic Theme Color for Icons
    final themeColor = isDark ? const Color(0xFF0141B5) : const Color(0xFF001133);

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
      iconColor = Colors.green; // Incoming = Green
    } else {
      callIcon = Icons.call_made;
      iconColor = const Color(0xFF0141B5); // Outgoing = Blue
    }
    final isViewed = isIncoming ? call.receiverViewed : call.callerViewed;
    return ListTile(
      leading: GestureDetector(
        onTap: () {
           _viewProfile(context, contactId);
        },
        child: UserAvatar(
            name: contactName,
            profilePicture: contactAvatar,
            size: 50,
            colorId: contactColorId,
        ),
      ),
      title: Text(
        contactName,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: (isMissed && !isViewed) ? FontWeight.bold : FontWeight.w500,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Row(
        children: [
          Icon(callIcon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Text(
            _formatCallTime(call.timestamp),
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontWeight: (isMissed && !isViewed) ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.call, color: Colors.green),
        onPressed: () {
          _initiateCallToContact(contactId, contactName, contactAvatar, contactColorId); 
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

  // _buildAvatar REMOVED

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
