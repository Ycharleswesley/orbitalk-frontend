import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'local_storage_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalStorageService _localStorage = LocalStorageService();

  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  Map<String, dynamic>? _cachedProfile; // Added
  Map<String, dynamic>? get cachedProfile => _cachedProfile;

  // Phone Authentication
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) codeSent,
    required Function(String errorMessage) verificationFailed,
    required Function(PhoneAuthCredential credential) verificationCompleted,
    required Function(String verificationId) codeAutoRetrievalTimeout,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: verificationCompleted,
        verificationFailed: (FirebaseAuthException e) {
          String message = e.message ?? 'Verification failed';
          if (e.code == 'too-many-requests') {
            message = 'Too many SMS requests. To protect your account, this device is temporarily blocked. Please try again in 4 hours.';
          }
          verificationFailed(message);
        },
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      );
    } catch (e) {
      verificationFailed(e.toString());
    }
  }

  // Verify OTP and Sign In
  Future<UserCredential?> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // Save user authentication state
      await _localStorage.saveAuthState(true);
      await _localStorage.saveUserId(userCredential.user!.uid);

      // Ensure FCM token is saved immediately after login
      await syncFcmToken();
      
      return userCredential;
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      return null;
    }
  }

  // Create or Update User Profile
  Future<void> createOrUpdateUserProfile({
    required String uid,
    String? phoneNumber,
    String? name,
    String? profilePicture,
    String? bio,
    String? language,
    int? profileColor, // Added
  }) async {
    try {
      final userDoc = _firestore.collection('users').doc(uid);
      final docSnapshot = await userDoc.get();

      final String? fcmToken = await FirebaseMessaging.instance.getToken();

      if (docSnapshot.exists) {
        // Update existing user - only update fields that are provided
        final updateData = <String, dynamic>{
          'lastSeen': FieldValue.serverTimestamp(),
          'isOnline': true,
        };
        
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          updateData['phoneNumber'] = phoneNumber;
        }
        if (name != null) {
          updateData['name'] = name;
        }
        if (profilePicture != null) {
          updateData['profilePicture'] = profilePicture;
        }
        if (bio != null) {
          updateData['bio'] = bio;
        }
        if (language != null) {
          updateData['language'] = language;
        }
        if (profileColor != null) {
          updateData['profileColor'] = profileColor;
        }
        
        await userDoc.update(updateData);
      } else {
        // Create new user - phoneNumber is required for new users
        final newPhoneNumber = phoneNumber ?? '';
        await userDoc.set({
          'uid': uid,
          'phoneNumber': newPhoneNumber,
          'name': name ?? newPhoneNumber,
          'profilePicture': profilePicture ?? '',
          'bio': bio ?? 'Hey there! I am using UTELO',
          'language': language ?? 'en',
          'profileColor': profileColor ?? 0, // Default 0
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
          'isOnline': true,
          'fcmToken': fcmToken ?? '',
        });
      }

      // Save user data locally
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        await _localStorage.savePhoneNumber(phoneNumber);
      }
      if (name != null) await _localStorage.saveUserName(name);
      if (profilePicture != null) await _localStorage.saveProfilePicture(profilePicture);
      if (language != null) await _localStorage.saveLanguage(language);
      if (profileColor != null) await _localStorage.saveProfileColor(profileColor);
      
      // Update Cache
      if (uid == currentUserId) {
         _cachedProfile = {
            'uid': uid,
            'name': name ?? _cachedProfile?['name'],
            'phoneNumber': phoneNumber ?? _cachedProfile?['phoneNumber'],
            'profilePicture': profilePicture ?? _cachedProfile?['profilePicture'],
            'bio': bio ?? _cachedProfile?['bio'],
            'language': language ?? _cachedProfile?['language'],
            'profileColor': profileColor ?? _cachedProfile?['profileColor'],
         };
      }
    } catch (e) {
      debugPrint('Error creating or updating user profile: $e');
      rethrow;
    }
  }

  // Get User Profile with Caching
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    // If asking for current user and we have cache
    if (uid == currentUserId && _cachedProfile != null) {
      return _cachedProfile;
    }

    try {
      final docSnapshot = await _firestore.collection('users').doc(uid).get();
      final data = docSnapshot.data();
      
      if (uid == currentUserId) {
        _cachedProfile = data;
      }
      
      return data;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  // Update User Profile (name, profilePicture, profileColor)
  Future<void> updateUserProfile({
    required String userId,
    required String name,
    String? profilePicture,
    int? profileColor, // Added
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'name': name,
        if (profilePicture != null) 'profilePicture': profilePicture,
        if (profileColor != null) 'profileColor': profileColor,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _localStorage.saveUserName(name);
      if (profilePicture != null) {
        await _localStorage.saveProfilePicture(profilePicture);
      }
      if (profileColor != null) {
        await _localStorage.saveProfileColor(profileColor);
      }
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    }
  }

  // Update Phone Number Only (Firestore)
  Future<void> updatePhoneNumber({
    required String userId,
    required String phoneNumber,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'phoneNumber': phoneNumber,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      await _localStorage.savePhoneNumber(phoneNumber);
    } catch (e) {
      debugPrint('Error updating phone number: $e');
      rethrow;
    }
  }

  // Update Phone Number in Firebase Auth for Current User
  // This updates the phone number on the existing Firebase Auth account
  // instead of creating a new account
  Future<void> updatePhoneNumberForCurrentUser({
    required String verificationId,
    required String smsCode,
    required String newPhoneNumber,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user is currently signed in');
      }

      // Create credential from the verified OTP
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      // Update the phone number on the current user account
      // This links the new phone number to the existing account
      await currentUser.updatePhoneNumber(credential);

      // Update Firestore with the new phone number
      final userId = currentUser.uid;
      await _firestore.collection('users').doc(userId).update({
        'phoneNumber': newPhoneNumber,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      // Update local storage
      await _localStorage.savePhoneNumber(newPhoneNumber);

      debugPrint('Phone number updated successfully for user: $userId');
    } catch (e) {
      debugPrint('Error updating phone number for current user: $e');
      rethrow;
    }
  }

  // Update User Online Status
  Future<void> updateOnlineStatus(bool isOnline) async {
    try {
      if (currentUserId != null) {
        await _firestore.collection('users').doc(currentUserId).update({
          'isOnline': isOnline,
          'isLoggedOut': false, // Reset flag
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error updating online status: $e');
    }
  }

  // Update FCM Token
  Future<void> updateFCMToken(String token) async {
    try {
      if (currentUserId != null) {
        await _firestore.collection('users').doc(currentUserId).update({
          'fcmToken': token,
        });
      }
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  // Force-refresh and save the latest FCM token (safe to call anytime)
  Future<void> syncFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await updateFCMToken(token);
      } else {
        debugPrint('FCM token is null or empty (sync skipped)');
      }
    } catch (e) {
      debugPrint('Error syncing FCM token: $e');
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      // Don't wait for online status update (fire and forget) to speed up logout
      // MARK AS LOGGED OUT explicitly
      if (currentUserId != null) {
        await _firestore.collection('users').doc(currentUserId).update({
          'isOnline': false,
          'isLoggedOut': true, // Added flag
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
      
      await _localStorage.clearAuthState();
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }

  // Check if user is authenticated locally
  Future<bool> isAuthenticated() async {
    return await _localStorage.isAuthenticated();
  }

  // Delete user account and data from Firestore
  Future<void> deleteUserAccount(String uid) async {
    try {
      // Delete user document
      await _firestore.collection('users').doc(uid).delete();

      // Optionally: Delete other user-related data
      // (e.g. chatRooms, messages, files, etc.)

      // Sign out from Firebase auth
      await signOut();
    } catch (e) {
      debugPrint('Error deleting user account: $e');
      rethrow;
    }
  }
}
