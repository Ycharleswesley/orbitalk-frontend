import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji;
import 'package:image_picker/image_picker.dart';
import '../services/chat_service.dart';
import '../services/local_storage_service.dart';
import '../services/encryption_service.dart';
import '../services/storage_service.dart';
import '../services/call_service.dart';
import '../services/notification_service.dart';
import 'image_viewer_screen.dart';
import 'video_viewer_screen.dart';
import 'profile_view_screen.dart';
import 'outgoing_call_screen.dart';
import '../services/translation_service.dart';
import '../config/translation_config.dart';
import '../utils/app_colors.dart';

class ChatDetailScreen extends StatefulWidget {
  final String contactName;
  final String contactAvatar;
  final String contactId;

  const ChatDetailScreen({
    Key? key,
    required this.contactName,
    this.contactAvatar = '',
    required this.contactId,
  }) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final LocalStorageService _localStorage = LocalStorageService();
  final ScrollController _scrollController = ScrollController();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EncryptionService _encryption = EncryptionService();
  final CallService _callService = CallService();
  
  String? _currentUserId;
  String? _chatRoomId;
  bool _isLoading = true;
  Map<String, dynamic>? _contactData;
  String? _errorMessage;
  bool _showEmojiPicker = false;
  final ValueNotifier<bool> _hasTextNotifier = ValueNotifier<bool>(false);
  String? _contactLanguage;
  String? _nickname;
  bool _isSending = false; // Prevent double sends
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _loadContactData();
    
    // Listen to text changes without causing full rebuild
    _messageController.addListener(_onTextChanged);
    _loadNickname();
  }

  Future<void> _loadNickname() async {
    final nickname = await _localStorage.getContactNickname(widget.contactId);
    if (mounted && nickname != null) {
      setState(() {
        _nickname = nickname;
      });
    }
  }

  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (_hasTextNotifier.value != hasText) {
      _hasTextNotifier.value = hasText;
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
    if (_showEmojiPicker) {
      FocusScope.of(context).unfocus();
    }
  }

  void _onEmojiSelected(emoji.Emoji selectedEmoji) {
    _messageController.text += selectedEmoji.emoji;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  Future<void> _pickMediaFromGallery() async {
    try {
      final XFile? media = await _imagePicker.pickMedia(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (media != null) {
        final File mediaFile = File(media.path);

        // Check if it's a video or image based on file extension
        final String extension = media.path.split('.').last.toLowerCase();
        final bool isVideo = [
          'mp4', 'mov', 'avi', 'mkv', 'wmv', 'flv', 'webm', 'm4v', '3gp', 'mpg', 'mpeg'
        ].contains(extension);

        debugPrint('Selected file extension: $extension');
        debugPrint('Is video: $isVideo');

        if (isVideo) {
          await _sendVideoMessageImmediately(mediaFile);
        } else {
          await _sendImageMessageImmediately(mediaFile);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking media: ${e.toString()}')),
        );
      }
    }
  }

  void _showCameraOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.photo_camera, color: Colors.blue.shade700),
              ),
              title: Text(
                'Take Photo',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromCamera();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.videocam, color: Colors.red.shade700),
              ),
              title: Text(
                'Record Video',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickVideoFromCamera();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVideoFromCamera() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 30), // Limit to 30 seconds for chat
      );

      if (video != null) {
        await _sendVideoMessage(File(video.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording video: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _sendImageMessageImmediately(File imageFile) async {
    if (_chatRoomId == null || _currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat not initialized')),
      );
      return;
    }

    try {
      // Generate message ID for the pending message
      final messageId = _encryption.generateMessageId();

      // Create pending message data
      final pendingMessageData = {
        'messageId': messageId,
        'senderId': _currentUserId!,
        'receiverId': widget.contactId,
        'imageUrl': '', // Will be updated after upload
        'message': '',
        'type': 'image',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'isDelivered': false,
        'isUploading': true, // Custom field for upload status
        'uploadProgress': 0.0,
      };

      // Add pending message to chat room immediately
      await _firestore
          .collection('chatRooms')
          .doc(_chatRoomId!)
          .collection('messages')
          .doc(messageId)
          .set(pendingMessageData);

      // Update last message in chat room
      await _firestore.collection('chatRooms').doc(_chatRoomId!).update({
        'lastMessage': '📷 Photo',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': _currentUserId!,
      });

      // Scroll to bottom immediately
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      // Upload image in background
      _uploadImageInBackground(imageFile, messageId);

    } catch (e) {
      debugPrint('Error sending image message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending image: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _sendVideoMessageImmediately(File videoFile) async {
    if (_chatRoomId == null || _currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat not initialized')),
      );
      return;
    }

    try {
      // Generate message ID for the pending message
      final messageId = _encryption.generateMessageId();

      // Create pending message data
      final pendingMessageData = {
        'messageId': messageId,
        'senderId': _currentUserId!,
        'receiverId': widget.contactId,
        'videoUrl': '', // Will be updated after upload
        'message': '',
        'type': 'video',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'isDelivered': false,
        'isUploading': true, // Custom field for upload status
        'uploadProgress': 0.0,
      };

      // Add pending message to chat room immediately
      await _firestore
          .collection('chatRooms')
          .doc(_chatRoomId!)
          .collection('messages')
          .doc(messageId)
          .set(pendingMessageData);

      // Update last message in chat room
      await _firestore.collection('chatRooms').doc(_chatRoomId!).update({
        'lastMessage': '🎥 Video',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': _currentUserId!,
      });

      // Scroll to bottom immediately
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      // Upload video in background
      _uploadVideoInBackground(videoFile, messageId);

    } catch (e) {
      debugPrint('Error sending video message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending video: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _uploadImageInBackground(File imageFile, String messageId) async {
    try {
      debugPrint('Starting background image upload for message: $messageId');

      // Upload image to Firebase Storage
      final imageUrl = await _storageService.uploadChatImage(
        imageFile,
        _chatRoomId!,
      );

      if (imageUrl != null) {
        debugPrint('Image uploaded successfully: $imageUrl');

        // Update the message with the uploaded URL
        await _firestore
            .collection('chatRooms')
            .doc(_chatRoomId!)
            .collection('messages')
            .doc(messageId)
            .update({
          'imageUrl': imageUrl,
          'isUploading': false,
          'uploadProgress': 1.0,
          // isDelivered will be set when recipient opens the chat
        });

        // Send push notification
        await _chatService.sendMessageNotification(
          receiverId: widget.contactId,
          senderId: _currentUserId!,
          message: '📷 Sent a photo',
        );

        debugPrint('Image message updated successfully');
      } else {
        debugPrint('Image upload failed - null URL');
        // Mark as failed
        await _firestore
            .collection('chatRooms')
            .doc(_chatRoomId!)
            .collection('messages')
            .doc(messageId)
            .update({
          'isUploading': false,
          'uploadProgress': -1.0, // Error state
        });
      }
    } catch (e) {
      debugPrint('Error in background image upload: $e');
      // Mark as failed
      try {
        await _firestore
            .collection('chatRooms')
            .doc(_chatRoomId!)
            .collection('messages')
            .doc(messageId)
            .update({
          'isUploading': false,
          'uploadProgress': -1.0, // Error state
        });
      } catch (updateError) {
        debugPrint('Error updating failed message: $updateError');
      }
    }
  }

  Future<void> _uploadVideoInBackground(File videoFile, String messageId) async {
    try {
      debugPrint('Starting background video upload for message: $messageId');

      // Check file size
      final fileSize = await videoFile.length();
      if (fileSize > 100 * 1024 * 1024) { // 100MB limit
        debugPrint('Video file too large: ${fileSize} bytes');
        await _firestore
            .collection('chatRooms')
            .doc(_chatRoomId!)
            .collection('messages')
            .doc(messageId)
            .update({
          'isUploading': false,
          'uploadProgress': -1.0, // Error state
        });
        return;
      }

      // Upload video to Firebase Storage
      final videoUrl = await _storageService.uploadChatVideo(
        videoFile,
        _chatRoomId!,
      );

      if (videoUrl != null) {
        debugPrint('Video uploaded successfully: $videoUrl');

        // Update the message with the uploaded URL
        await _firestore
            .collection('chatRooms')
            .doc(_chatRoomId!)
            .collection('messages')
            .doc(messageId)
            .update({
          'videoUrl': videoUrl,
          'isUploading': false,
          'uploadProgress': 1.0,
          // isDelivered will be set when recipient opens the chat
        });

        // Send push notification
        await _chatService.sendMessageNotification(
          receiverId: widget.contactId,
          senderId: _currentUserId!,
          message: '🎥 Sent a video',
        );

        debugPrint('Video message updated successfully');
      } else {
        debugPrint('Video upload failed - null URL');
        // Mark as failed
        await _firestore
            .collection('chatRooms')
            .doc(_chatRoomId!)
            .collection('messages')
            .doc(messageId)
            .update({
          'isUploading': false,
          'uploadProgress': -1.0, // Error state
        });
      }
    } catch (e) {
      debugPrint('Error in background video upload: $e');
      // Mark as failed
      try {
        await _firestore
            .collection('chatRooms')
            .doc(_chatRoomId!)
            .collection('messages')
            .doc(messageId)
            .update({
          'isUploading': false,
          'uploadProgress': -1.0, // Error state
        });
      } catch (updateError) {
        debugPrint('Error updating failed message: $updateError');
      }
    }
  }

  Future<void> _sendImageMessage(File imageFile) async {
    if (_chatRoomId == null || _currentUserId == null) return;

    try {
      // Upload image to Firebase Storage
      final imageUrl = await _storageService.uploadChatImage(
        imageFile,
        _chatRoomId!,
      );

      if (imageUrl != null) {
        // Send image message
        await _chatService.sendImageMessage(
          chatRoomId: _chatRoomId!,
          senderId: _currentUserId!,
          receiverId: widget.contactId,
          imageUrl: imageUrl,
        );

        // Scroll to bottom (reverse list -> offset 0)
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending image: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _sendVideoMessage(File videoFile) async {
    if (_chatRoomId == null || _currentUserId == null) return;

    try {
      // Upload video to Firebase Storage
      final videoUrl = await _storageService.uploadChatVideo(
        videoFile,
        _chatRoomId!,
      );

      if (videoUrl != null) {
        // Send video message
        await _chatService.sendVideoMessage(
          chatRoomId: _chatRoomId!,
          senderId: _currentUserId!,
          receiverId: widget.contactId,
          videoUrl: videoUrl,
        );

        // Scroll to bottom (reverse list -> offset 0)
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending video: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        await _sendImageMessage(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        await _sendImageMessage(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking photo: ${e.toString()}')),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.photo_library, color: Colors.purple.shade700),
              ),
              title: Text(
                'Gallery',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Photos and videos',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickMediaFromGallery();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.camera_alt, color: Colors.blue.shade700),
              ),
              title: Text(
                'Camera',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Take photo or video',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromCamera();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadContactData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.contactId)
          .get();
      if (mounted && doc.exists) {
        setState(() {
          _contactData = doc.data();
          _contactLanguage = _contactData?['language'] ?? _contactData?['preferredLanguage'] ?? 'en';
        });
      }
    } catch (e) {
      debugPrint('Error loading contact data: $e');
    }
  }

  Future<void> _initializeChat() async {
    // Prevent re-initialization if already initialized
    if (_chatRoomId != null && _currentUserId != null) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final userId = await _localStorage.getUserId();
      if (userId == null) {
        throw Exception('User not logged in');
      }
      
      final chatRoomId = await _chatService.getOrCreateChatRoom(
        userId,
        widget.contactId,
      );
      
      // Suppress notifications for this chat room
      NotificationService().setCurrentChatRoomId(chatRoomId);
      
      if (mounted) {
        setState(() {
          _currentUserId = userId;
          _chatRoomId = chatRoomId;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('Error initializing chat: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending) return; // Prevent double taps

    final message = _messageController.text.trim();
    if (message.isEmpty || _chatRoomId == null || _currentUserId == null) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      // Optimistic Clear: Clear input immediately to give feedback "it went"
      _messageController.clear(); 

      await _chatService.sendMessage(
        chatRoomId: _chatRoomId!,
        senderId: _currentUserId!,
        receiverId: widget.contactId,
        message: message,
      );
      
      // Scroll to bottom (reverse list -> offset 0)
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      // Restore text if failed (optional, but good UX)
      // _messageController.text = message; 
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _initiateCall() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to initiate call. Please try again.')),
      );
      return;
    }

    try {
      debugPrint('ChatDetailScreen: Initiating call to ${widget.contactName}');
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final userName = await _localStorage.getUserName();
      final userDoc = await _firestore.collection('users').doc(_currentUserId).get();
      final userAvatar = userDoc.data()?['profilePicture'] ?? '';
      
      // Fetch contact color
      final contactDoc = await _firestore.collection('users').doc(widget.contactId).get();
      final contactColor = contactDoc.data()?['profileColor'] ?? 0;

      final callId = await _callService.initiateCall(
        callerId: _currentUserId!,
        callerName: userName ?? 'User',
        callerAvatar: userAvatar,
        receiverId: widget.contactId,
        receiverName: widget.contactName,
        receiverAvatar: widget.contactAvatar,
      );

      if (mounted) {
        Navigator.of(context).pop();
        
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => OutgoingCallScreen(
              callId: callId,
              contactId: widget.contactId, // Now required
              contactName: widget.contactName,
              contactAvatar: widget.contactAvatar,
              contactProfileColor: contactColor,
            ),
          ),
        );
      }
      
      debugPrint('ChatDetailScreen: Call initiated with ID: $callId');
    } catch (e) {
      debugPrint('ChatDetailScreen: Error initiating call: $e');
      
      if (mounted) {
        Navigator.of(context).pop();
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Call Failed', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: Text(e.toString().replaceAll('Exception: ', ''), style: GoogleFonts.poppins()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: GoogleFonts.poppins(color: const Color(0xFFB64166))),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _hasTextNotifier.dispose();
    super.dispose();
  }

  Widget _buildAvatar(String name, String? profilePicture) {
    if (profilePicture != null && profilePicture.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey.shade200,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: profilePicture,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
            errorWidget: (context, url, error) => _buildDefaultAvatar(name),
          ),
        ),
      );
    }
    return _buildDefaultAvatar(name);
  }

  Widget _buildDefaultAvatar(String name) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];

    final colorIndex = name.codeUnitAt(0) % colors.length;

    return CircleAvatar(
      radius: 20,
      backgroundColor: colors[colorIndex],
      child: Text(
        name[0].toUpperCase(),
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFE3F2FD),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileViewScreen(
                      userId: widget.contactId,
                      contactName: widget.contactName,
                      contactAvatar: widget.contactAvatar,
                    ),
                  ),
                );
              },
              child: _buildAvatar(widget.contactName, _contactData?['profilePicture']),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileViewScreen(
                        userId: widget.contactId,
                        contactName: widget.contactName,
                        contactAvatar: widget.contactAvatar,
                      ),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nickname ?? widget.contactName, // Show nickname if set
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (_contactData != null)
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.contactId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox.shrink();
                          final data = snapshot.data!.data() as Map<String, dynamic>?;
                          final isOnline = data?['isOnline'] ?? false;
                          final lastSeen = data?['lastSeen'] as Timestamp?;
                          
                          // Smart Online Check (90s buffer)
                          bool showOnline = isOnline;
                          if (isOnline && lastSeen != null) {
                             final diff = DateTime.now().difference(lastSeen.toDate());
                             if (diff.inSeconds > 90) showOnline = false;
                          }

                          String statusText = 'Offline';
                          if (showOnline) {
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
                            } else {
                              statusText = 'Last seen ${difference.inDays}d ago';
                            }
                          }
                          
                          return Text(
                            statusText,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: isOnline ? Colors.green : Colors.grey.shade600,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.call, color: isDark ? Colors.white : Colors.black87),
            onPressed: _initiateCall,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: isDark ? Colors.white : Colors.black87),
            onSelected: (value) {
              if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileViewScreen(
                      userId: widget.contactId,
                      contactName: widget.contactName,
                      contactAvatar: widget.contactAvatar,
                    ),
                  ),
                );
              } else if (value == 'clear') {
                // Clear Chat Logic (Optional)
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Clear Chat feature coming soon'))
                );
              } else if (value == 'nickname') {
                _showEditNicknameDialog();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'profile',
                child: Text('View Profile'),
              ),
              const PopupMenuItem<String>(
                value: 'clear',
                child: Text('Clear Chat'),
              ),
              const PopupMenuItem<String>(
                value: 'nickname',
                child: Text('Edit Nickname'),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background pattern
          // Background pattern (Dynamic)
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(widget.contactId).snapshots(),
            builder: (context, snapshot) {
               int profileColor = 0;
               if (snapshot.hasData && snapshot.data!.exists) {
                   final data = snapshot.data!.data() as Map<String, dynamic>;
                   profileColor = data['profileColor'] ?? 0;
               }
               
               return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                       AppColors.getGradientColors(profileColor)[0].withOpacity(0.15), // Very light version
                       AppColors.getGradientColors(profileColor)[1].withOpacity(0.05),
                    ],
                  ),
                  image: DecorationImage(
                    image: const AssetImage('assets/orbitalkLogo.png'),
                    fit: BoxFit.none,
                    repeat: ImageRepeat.repeat,
                    opacity: 0.05,
                  ),
                ),
              );
            },
          ),
          
          // Messages list
          Column(
            children: [
              Expanded(
                child: _isLoading && _chatRoomId == null
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 80,
                                    color: Colors.red.shade300,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Failed to load chat',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: _initializeChat,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFB64166),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _chatRoomId == null
                            ? const Center(child: Text('Unable to create chat'))
                            : StreamBuilder<QuerySnapshot>(
                        stream: _chatService.getMessages(_chatRoomId!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error loading messages',
                                style: GoogleFonts.poppins(color: Colors.red),
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
                                    'No messages yet',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Send a message to start chatting',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          // Filter out messages deleted by me
                          final messages = snapshot.data!.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final deletedBy = (data['deletedBy'] as List<dynamic>?)?.cast<String>() ?? [];
                            return !deletedBy.contains(_currentUserId);
                          }).toList();

                          return ListView.builder(
                            reverse: true,
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final messageDoc = messages[index];
                              final messageData = messageDoc.data() as Map<String, dynamic>;
                              final senderId = messageData['senderId'] ?? '';
                              final isSentByMe = senderId == _currentUserId;

                              // Mark as read if it's an incoming, unread message
                              if (!isSentByMe && (messageData['isRead'] != true) && _chatRoomId != null) {
                                final msgId = messageData['messageId'] as String?;
                                if (msgId != null) {
                                  _chatService.markMessageAsRead(_chatRoomId!, msgId);
                                }
                              }

                              // Mark as delivered if it's an outgoing, undelivered message
                              if (isSentByMe && (messageData['isDelivered'] != true) && _chatRoomId != null) {
                                final msgId = messageData['messageId'] as String?;
                                if (msgId != null) {
                                  _chatService.markMessageAsDelivered(_chatRoomId!, msgId);
                                }
                              }

                              final messageId = messageData['messageId'] ?? '';
                              return GestureDetector(
                                onLongPress: () => _showMessageOptions(context, messageDoc.id, messageData, isSentByMe),
                                child: MessageBubble(
                                  key: ValueKey(messageId),
                                  messageData: messageData,
                                  isSentByMe: isSentByMe,
                                  currentUserId: _currentUserId,
                                  contactLanguage: _contactLanguage,
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
              
              // Message input area
              ChatInputArea(
                messageController: _messageController,
                hasTextNotifier: _hasTextNotifier,
                showEmojiPicker: _showEmojiPicker,
                onToggleEmojiPicker: _toggleEmojiPicker,
                onSendMessage: _sendMessage,
                onShowAttachmentOptions: _showAttachmentOptions,
                onPickImageFromCamera: _pickImageFromCamera,
                onEmojiSelected: _onEmojiSelected,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(BuildContext context, String docId, Map<String, dynamic> messageData, bool isSentByMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              ListTile(
                leading: const Icon(Icons.copy, color: Colors.teal),
                title: Text('Copy', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: messageData['message'] ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied')),
                  );
                },
              ),
              
              if (isSentByMe && messageData['type'] == 'text')
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: Text('Edit Message', style: GoogleFonts.poppins()),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDialog(docId, messageData['message']);
                  },
                ),
                
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.orange),
                title: Text('Delete for Me', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _chatService.deleteMessageForMe(_chatRoomId!, docId, _currentUserId!);
                },
              ),
              
              if (isSentByMe)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete for Everyone', style: GoogleFonts.poppins(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _chatService.deleteMessage(_chatRoomId!, docId);
                  },
                ),
                
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(String docId, String currentText) {
    final editController = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Message', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: editController,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          minLines: 1,
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () {
              if (editController.text.trim().isNotEmpty) {
                _chatService.editMessage(_chatRoomId!, docId, editController.text.trim());
                Navigator.pop(context);
              }
            },
            child: Text('Save', style: GoogleFonts.poppins(color: const Color(0xFFB64166))),
          ),
        ],
      ),
    );
  }

  void _showEditNicknameDialog() {
    final nicknameController = TextEditingController(text: _nickname ?? widget.contactName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Nickname', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: nicknameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nickname',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () async {
              final newNickname = nicknameController.text.trim();
              if (newNickname.isNotEmpty) {
                await _localStorage.saveContactNickname(widget.contactId, newNickname);
                if (mounted) {
                  setState(() {
                    _nickname = newNickname;
                  });
                  Navigator.pop(context);
                }
              }
            },
            child: Text('Save', style: GoogleFonts.poppins(color: const Color(0xFFB64166))),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatefulWidget {
  final Map<String, dynamic> messageData;
  final bool isSentByMe;
  final String? currentUserId;
  final String? contactLanguage;

  const MessageBubble({
    Key? key,
    required this.messageData,
    required this.isSentByMe,
    required this.currentUserId,
    this.contactLanguage,
  }) : super(key: key);

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> with AutomaticKeepAliveClientMixin {
  final TranslationService _translationService = TranslationService();
  final LocalStorageService _localStorage = LocalStorageService();
  
  @override
  bool get wantKeepAlive => true;

  String? _translatedText;
  String _targetLangCode = 'en';
  bool _showOriginal = false;
  bool _isTranslating = false;
  bool _translationFailed = false;

  @override
  void initState() {
    super.initState();
    // Sender-Side Translation ONLY: 
    // We strictly rely on the sender to provide the translated 'message'.
    // No local auto-translation safety net. 
  }

  // Removed _handleSafetyNetTranslation to ensure strict sender-side logic.


  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      return DateFormat('HH:mm').format(timestamp.toDate());
    }
    return ''; // Handle other formats if needed
  }

  Widget _buildStatusIcon(Map<String, dynamic> data) {
    if (!widget.isSentByMe) return const SizedBox.shrink();

    final isRead = data['isRead'] == true;
    final isDelivered = data['isDelivered'] == true;

    if (isRead) {
      return const Icon(Icons.done_all, size: 16, color: Colors.blueAccent); // Blue Tick for Read
    } else if (isDelivered) {
      return const Icon(Icons.done_all, size: 16, color: Colors.white70); // White Double Tick for Delivered
    } else {
      return const Icon(Icons.check, size: 16, color: Colors.white70); // Single Tick for Sent
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final messageType = widget.messageData['type'] ?? 'text';
    final messageText = widget.messageData['message'] ?? '';
    final messageId = widget.messageData['messageId'] ?? '';
    final imageUrl = widget.messageData['imageUrl'] ?? '';
    final videoUrl = widget.messageData['videoUrl'] ?? '';
    final isUploading = widget.messageData['isUploading'] == true;
    final uploadProgress = (widget.messageData['uploadProgress'] ?? 0.0).toDouble();

    if (messageType == 'image') {
      return _buildImageContent(imageUrl, messageText, isUploading, uploadProgress);
    } else if (messageType == 'video') {
       return _buildVideoContent(videoUrl, messageText, isUploading, uploadProgress);
    } else {
       return _buildTextContent(messageText, messageId);
    }
  }

  Widget _buildTextContent(String messageText, String messageId) {
    // REFINED LOGIC (Iter 13):
    
    final isMe = widget.isSentByMe;
    
    // 1. GREEN BUBBLE (Sent by Me)
    // Goal: Show TRANSLATED (message) by default. Toggle to ORIGINAL (original_message).
    String? originalMessageInfo;
    bool showToggle = false;
    String displayedText = messageText; // Default: What they see (Translated)

    if (isMe) {
        final original = widget.messageData['original_message'] as String?;
        if (original != null && original.isNotEmpty && original != messageText) {
             showToggle = true;
             // Logic: _showOriginal == true -> Show 'original_message'
             //        _showOriginal == false -> Show 'message' (Translated)
             if (_showOriginal) {
                 displayedText = original;
             }
        }
    } 
    // 2. BLUE BUBBLE (Received)
    // Goal: Strictly show what was received ('message').
    // If sender translated it, good. If not, we show raw.
    else {
         // No overrides. displayedText = messageText;
    }


    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF4CAF50) : const Color(0xFF2196F3),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end, // Align to end for Time+Tick
          mainAxisSize: MainAxisSize.min, // Wrap content
          children: [
            Column( // Text Content Column
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // MAIN TEXT DISPLAY
                Text(
                  displayedText,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 4),

                // TOGGLE (Only for Green Bubbles)
                if (showToggle)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _showOriginal = !_showOriginal;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        _showOriginal ? "Show translation" : "Show original",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
             // Timestamp & Status Row
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(widget.messageData['timestamp']),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.white70,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildStatusIcon(widget.messageData),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContent(String imageUrl, String messageText, bool isUploading, double uploadProgress) {
    return Align(
      alignment: widget.isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Stack(
          children: [
            GestureDetector(
              onTap: isUploading ? null : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImageViewerScreen(
                      imageUrl: imageUrl,
                      caption: messageText,
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: isUploading
                    ? Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        height: 200,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: MediaQuery.of(context).size.width * 0.6,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: MediaQuery.of(context).size.width * 0.6,
                          height: 200,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: MediaQuery.of(context).size.width * 0.6,
                          height: 200,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.error, color: Colors.red),
                        ),
                      ),
              ),
            ),
            if (isUploading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            // Timestamp & Status Overlay
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(widget.messageData['timestamp']),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                    if (widget.isSentByMe) ...[
                      const SizedBox(width: 4),
                      _buildStatusIcon(widget.messageData),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContent(String videoUrl, String messageText, bool isUploading, double uploadProgress) {
    return Align(
      alignment: widget.isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Stack(
          children: [
            GestureDetector(
              onTap: isUploading ? null : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoViewerScreen(
                      videoUrl: videoUrl,
                      caption: messageText,
                    ),
                  ),
                );
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width * 0.6,
                    height: 200,
                    decoration: BoxDecoration(
                      color: isUploading ? Colors.grey.shade300 : Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isUploading
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : const Icon(
                            Icons.play_circle_outline,
                            size: 64,
                            color: Colors.white,
                          ),
                  ),
                  if (!isUploading)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.videocam, size: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Video',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isUploading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            // Timestamp & Status Overlay
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(widget.messageData['timestamp']),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                    if (widget.isSentByMe) ...[
                      const SizedBox(width: 4),
                      _buildStatusIcon(widget.messageData),
                    ],
                  ],
                ),
              ),
            ),
            // Timestamp & Status Overlay
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(widget.messageData['timestamp']),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                    if (widget.isSentByMe) ...[
                      const SizedBox(width: 4),
                      _buildStatusIcon(widget.messageData),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentContent(String? fileName, int? fileSize) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isSentByMe ? Colors.white.withOpacity(0.3) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.isSentByMe ? Colors.white.withOpacity(0.4) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.insert_drive_file,
              color: widget.isSentByMe ? Colors.black87 : Colors.grey.shade700,
              size: 32,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName ?? 'Document',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: widget.isSentByMe ? Colors.black87 : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (fileSize != null)
                  Text(
                    _formatFileSize(fileSize),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: widget.isSentByMe ? Colors.black87.withOpacity(0.7) : Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class ChatInputArea extends StatelessWidget {
  final TextEditingController messageController;
  final ValueNotifier<bool> hasTextNotifier;
  final bool showEmojiPicker;
  final VoidCallback onToggleEmojiPicker;
  final VoidCallback onSendMessage;
  final VoidCallback onShowAttachmentOptions;
  final VoidCallback onPickImageFromCamera;
  final Function(emoji.Emoji) onEmojiSelected;

  const ChatInputArea({
    Key? key,
    required this.messageController,
    required this.hasTextNotifier,
    required this.showEmojiPicker,
    required this.onToggleEmojiPicker,
    required this.onSendMessage,
    required this.onShowAttachmentOptions,
    required this.onPickImageFromCamera,
    required this.onEmojiSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.only(
            left: 8,
            right: 8,
            top: 8,
            bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  showEmojiPicker
                      ? Icons.keyboard
                      : Icons.emoji_emotions_outlined,
                  color: showEmojiPicker
                      ? const Color(0xFFB64166)
                      : Colors.grey,
                ),
                onPressed: onToggleEmojiPicker,
              ),
              Expanded(
                child: TextField(
                  controller: messageController,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Message',
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onSubmitted: (_) => onSendMessage(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.attach_file, color: Colors.grey),
                onPressed: onShowAttachmentOptions,
              ),
              IconButton(
                icon: const Icon(Icons.camera_alt, color: Colors.grey),
                onPressed: onPickImageFromCamera,
              ),
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF00C853), // Vibrant Green (Android Green Accent)
                  shape: BoxShape.circle,
                ),
                child: ValueListenableBuilder<bool>(
                  valueListenable: hasTextNotifier,
                  builder: (context, hasText, child) {
                    return IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                      ),
                      onPressed: hasText ? onSendMessage : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        if (showEmojiPicker)
          SizedBox(
            height: 250,
            child: emoji.EmojiPicker(
              onEmojiSelected: (category, selectedEmoji) {
                onEmojiSelected(selectedEmoji);
              },
              config: emoji.Config(
                height: 256,
                checkPlatformCompatibility: true,
                emojiViewConfig: emoji.EmojiViewConfig(
                  columns: 7,
                  emojiSizeMax: 28,
                  verticalSpacing: 0,
                  horizontalSpacing: 0,
                  gridPadding: EdgeInsets.zero,
                  backgroundColor: isDark ? const Color(0xFF232323) : const Color(0xFFF2F2F2),
                  buttonMode: emoji.ButtonMode.MATERIAL,
                  recentsLimit: 28,
                  noRecents: Text(
                    'No Recents',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      color: Colors.black26,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                skinToneConfig: const emoji.SkinToneConfig(),
                categoryViewConfig: const emoji.CategoryViewConfig(),
                bottomActionBarConfig: const emoji.BottomActionBarConfig(),
                searchViewConfig: const emoji.SearchViewConfig(),
              ),
            ),
          ),
      ],
    );
  }
}
