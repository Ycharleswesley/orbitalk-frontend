import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  // Pick image from gallery
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  // Pick image from camera
  Future<File?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      debugPrint('Error taking photo: $e');
      return null;
    }
  }

  // Upload profile picture
  Future<String?> uploadProfilePicture(File imageFile, String userId) async {
    try {
      final String fileExtension = path.extension(imageFile.path);
      final String fileName = 'profile_$userId$fileExtension';
      final Reference ref = _storage.ref().child('profile_pictures/$fileName');

      final UploadTask uploadTask = ref.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;

      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      return null;
    }
  }

  // Upload chat image
  Future<String?> uploadChatImage(File imageFile, String chatRoomId) async {
    try {
      final String fileName = '${_uuid.v4()}.${path.extension(imageFile.path)}';
      final Reference ref = _storage.ref().child('chat_images/$chatRoomId/$fileName');

      final UploadTask uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/${path.extension(imageFile.path).replaceAll('.', '')}',
        ),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading chat image: $e');
      return null;
    }
  }

  // Upload chat video
  Future<String?> uploadChatVideo(File videoFile, String chatRoomId) async {
    try {
      debugPrint('StorageService: Starting video upload...');
      debugPrint('Video file path: ${videoFile.path}');
      debugPrint('Video file exists: ${await videoFile.exists()}');
      
      final fileSize = await videoFile.length();
      debugPrint('Video file size: $fileSize bytes');
      
      final String fileName = '${_uuid.v4()}.${path.extension(videoFile.path)}';
      debugPrint('Generated filename: $fileName');
      
      final Reference ref = _storage.ref().child('chat_videos/$chatRoomId/$fileName');
      debugPrint('Storage reference: ${ref.fullPath}');

      final UploadTask uploadTask = ref.putFile(
        videoFile,
        SettableMetadata(
          contentType: 'video/${path.extension(videoFile.path).replaceAll('.', '')}',
        ),
      );

      debugPrint('Upload task created, waiting for completion...');
      final TaskSnapshot snapshot = await uploadTask;
      debugPrint('Upload task completed. Bytes transferred: ${snapshot.bytesTransferred}');

      final String downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('Download URL obtained: $downloadUrl');
      
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading chat video: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  // Delete file from storage
  Future<void> deleteFile(String fileUrl) async {
    try {
      final Reference ref = _storage.refFromURL(fileUrl);
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
  }

  // Upload chat document
  Future<String?> uploadChatDocument(File file, String chatRoomId, String fileName) async {
    try {
      // Create a unique filename while preserving the original name's extension (and maybe name)
      // But to avoid collisions, we should probably prefix unique ID or store in subfolder
      // Let's use uuid + extension, but we need to store the original filename in Firestore metadata if needed.
      // Actually, ChatService sendDocumentMessage takes 'fileName' as an argument.
      // So here we just need a unique path.
      
      final String extension = path.extension(fileName);
      final String uniqueName = '${_uuid.v4()}$extension';
      final Reference ref = _storage.ref().child('chat_documents/$chatRoomId/$uniqueName');

      final UploadTask uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: 'application/octet-stream', // Generic binary, or try to guess mime type
          customMetadata: {'originalName': fileName},
        ),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading chat document: $e');
      return null;
    }
  }

  // Get upload progress stream
  Stream<TaskSnapshot> uploadWithProgress(File file, String storagePath) {
    final Reference ref = _storage.ref().child(storagePath);
    final UploadTask uploadTask = ref.putFile(file);
    
    return uploadTask.snapshotEvents;
  }
}
