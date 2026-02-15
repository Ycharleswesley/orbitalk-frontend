import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache for user document streams
  final Map<String, Stream<DocumentSnapshot>> _userStreams = {};

  Stream<DocumentSnapshot> getUserStream(String uid) {
    if (uid.isEmpty) return const Stream.empty();
    return _firestore.collection('users').doc(uid).snapshots();
  }
  
  // Method to clear cache if needed (e.g. on logout)
  void clearCache() {
    _userStreams.clear();
  }
}
