import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'encryption_service.dart';
import 'notification_service.dart';
import '../models/message_model.dart';

import 'translation_service.dart';
import 'auth_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EncryptionService _encryption = EncryptionService();
  final NotificationService _notificationService = NotificationService();
  final TranslationService _translationService = TranslationService();
  final AuthService _authService = AuthService();

  // Get or Create Chat Room
  Future<String> getOrCreateChatRoom(String userId1, String userId2) async {
    try {
      final chatRoomId = _encryption.generateChatRoomId(userId1, userId2);
      final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
      
      final docSnapshot = await chatRoomRef.get().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout. Please check your internet connection.');
        },
      );
      
      if (!docSnapshot.exists) {
        await chatRoomRef.set({
          'chatRoomId': chatRoomId,
          'participants': [userId1, userId2],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSenderId': '',
        }).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Connection timeout while creating chat room.');
          },
        );
      }
      
      return chatRoomId;
    } catch (e) {
      debugPrint('Error getting/creating chat room: $e');
      rethrow;
    }
  }

  // Send Text Message
  Future<void> sendMessage({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String message,
    String? replyToMessageId,
  }) async {
    try {
      // 1. Fetch Receiver's Language
      String targetLang = 'en'; // Default
      try {
        final receiverProfile = await _authService.getUserProfile(receiverId);
        if (receiverProfile != null && receiverProfile['language'] != null) {
          targetLang = receiverProfile['language'];
        }
      } catch (e) {
        debugPrint('Error fetching receiver language: $e');
      }

      // 2. Translate Message (Sender-Side)
      String translatedMessage = message; 
      String originalMessage = message;
      String sourceLang = 'auto'; // Or fetch sender's lang
      
      // Only translate if target is different (we assume 'en' vs 'te' etc)
      // Actually, TranslationService handles 'auto' -> target well.
      
      try {
         final translationResult = await _translationService.translateText(message, toLang: targetLang);
         if (translationResult != null) {
           translatedMessage = translationResult;
         }
      } catch (e) {
        debugPrint('Sender-side translation failed: $e');
        // Fallback: send original, let receiver deal with it (or just show original)
      }

      final messageData = {
        'messageId': _encryption.generateMessageId(),
        'senderId': senderId,
        'receiverId': receiverId,
        'message': translatedMessage, // Store TRANSLATED content as main message
        'original_message': originalMessage, // Store RAW content
        'source_lang': sourceLang,
        'target_lang': targetLang,
        'type': 'text',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'isDelivered': false,
        'replyToMessageId': replyToMessageId,
      };

      // Add message to chat room
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .add(messageData);

      // Update last message in chat room
      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'lastMessage': translatedMessage, // Show translated in list logic too
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
      });

      // Send push notification
      await _notificationService.sendMessageNotification(
        receiverId: receiverId,
        senderId: senderId,
        message: message,
      );
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  // Send Image Message
  Future<void> sendImageMessage({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String imageUrl,
    String? caption,
  }) async {
    try {
      final messageData = {
        'messageId': _encryption.generateMessageId(),
        'senderId': senderId,
        'receiverId': receiverId,
        'imageUrl': imageUrl,
        'message': caption ?? '',
        'type': 'image',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'isDelivered': false,
      };

      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .add(messageData);

      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'lastMessage': '📷 Image',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
      });

      await _notificationService.sendMessageNotification(
        receiverId: receiverId,
        senderId: senderId,
        message: '📷 Sent an image',
      );
    } catch (e) {
      debugPrint('Error sending image message: $e');
      rethrow;
    }
  }

  // Send Video Message
  Future<void> sendVideoMessage({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String videoUrl,
    String? caption,
  }) async {
    try {
      final messageData = {
        'messageId': _encryption.generateMessageId(),
        'senderId': senderId,
        'receiverId': receiverId,
        'videoUrl': videoUrl,
        'message': caption ?? '',
        'type': 'video',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'isDelivered': false,
      };

      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .add(messageData);

      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'lastMessage': '🎥 Video',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
      });

      await _notificationService.sendMessageNotification(
        receiverId: receiverId,
        senderId: senderId,
        message: '🎥 Sent a video',
      );
    } catch (e) {
      debugPrint('Error sending video message: $e');
      rethrow;
    }
  }

  // Send Document Message
  Future<void> sendDocumentMessage({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String documentUrl,
    required String fileName,
    required int fileSize,
  }) async {
    try {
      final messageData = {
        'messageId': _encryption.generateMessageId(),
        'senderId': senderId,
        'receiverId': receiverId,
        'documentUrl': documentUrl,
        'fileName': fileName,
        'fileSize': fileSize,
        'message': fileName,
        'type': 'document',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'isDelivered': false,
      };

      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .add(messageData);

      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'lastMessage': '📄 $fileName',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
      });

      await _notificationService.sendMessageNotification(
        receiverId: receiverId,
        senderId: senderId,
        message: '📄 Sent a document',
      );
    } catch (e) {
      debugPrint('Error sending document message: $e');
      rethrow;
    }
  }

  // Send Voice Message (disabled - audio dependencies removed)
  // Future<void> sendVoiceMessage({
  //   required String chatRoomId,
  //   required String senderId,
  //   required String receiverId,
  //   required String voiceUrl,
  //   required int duration,
  // }) async {
  //   try {
  //     final messageData = {
  //       'messageId': _encryption.generateMessageId(),
  //       'senderId': senderId,
  //       'receiverId': receiverId,
  //       'voiceUrl': voiceUrl,
  //       'duration': duration,
  //       'type': 'voice',
  //       'timestamp': FieldValue.serverTimestamp(),
  //       'isRead': false,
  //       'isDelivered': false,
  //     };
  //
  //     await _firestore
  //         .collection('chatRooms')
  //         .doc(chatRoomId)
  //         .collection('messages')
  //         .add(messageData);
  //
  //     await _firestore.collection('chatRooms').doc(chatRoomId).update({
  //       'lastMessage': '🎤 Voice message',
  //       'lastMessageTime': FieldValue.serverTimestamp(),
  //       'lastMessageSenderId': senderId,
  //     });
  //
  //     await _notificationService.sendMessageNotification(
  //       receiverId: receiverId,
  //       senderId: senderId,
  //       message: '🎤 Sent a voice message',
  //     );
  //   } catch (e) {
  //     debugPrint('Error sending voice message: $e');
  //     rethrow;
  //   }
  // }

  // Get Messages Stream
  Stream<QuerySnapshot> getMessages(String chatRoomId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots(includeMetadataChanges: true);
  }

  // Mark Message as Read
  Future<void> markMessageAsRead(String chatRoomId, String messageId) async {
    try {
      final messagesRef = _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages');

      final querySnapshot = await messagesRef
          .where('messageId', isEqualTo: messageId)
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.update({
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error marking message as read: $e');
    }
  }

  // Mark Message as Delivered
  Future<void> markMessageAsDelivered(String chatRoomId, String messageId) async {
    try {
      final messagesRef = _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages');

      final querySnapshot = await messagesRef
          .where('messageId', isEqualTo: messageId)
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.update({
          'isDelivered': true,
          'deliveredAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error marking message as delivered: $e');
    }
  }

  // Delete Message (For Everyone - Hard Delete)
  Future<void> deleteMessage(String chatRoomId, String messageDocId) async {
    try {
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageDocId)
          .delete();
      
      // Update last message if needed (simplified: just leave it or fetch previous)
    } catch (e) {
      debugPrint('Error deleting message: $e');
      rethrow;
    }
  }

  // Delete Message For Me (Soft Delete)
  Future<void> deleteMessageForMe(String chatRoomId, String messageDocId, String userId) async {
    try {
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageDocId)
          .update({
        'deletedBy': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      debugPrint('Error deleting message for me: $e');
      rethrow;
    }
  }

  // Edit Message
  Future<void> editMessage(String chatRoomId, String messageDocId, String newText) async {
    try {
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageDocId)
          .update({
        'message': newText,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error editing message: $e');
      rethrow;
    }
  }

  // Get Chat Rooms for User
  Stream<QuerySnapshot> getUserChatRooms(String userId) {
    // Note: Removed orderBy to avoid requiring Firestore composite index
    // Sorting will be done in the UI instead
    return _firestore
        .collection('chatRooms')
        .where('participants', arrayContains: userId)
        .snapshots();
  }

  // Alias for getUserChatRooms
  Stream<QuerySnapshot> getChatRooms(String userId) {
    return getUserChatRooms(userId);
  }

  // Send message notification (public method)
  Future<void> sendMessageNotification({
    required String receiverId,
    required String senderId,
    required String message,
  }) async {
    await _notificationService.sendMessageNotification(
      receiverId: receiverId,
      senderId: senderId,
      message: message,
    );
  }
}
