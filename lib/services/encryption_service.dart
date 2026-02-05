import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'local_storage_service.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final LocalStorageService _localStorage = LocalStorageService();
  encrypt.Key? _key;
  encrypt.IV? _iv;

  // Initialize encryption with stored or new key
  Future<void> initialize() async {
    String? storedKey = await _localStorage.getEncryptionKey();
    
    if (storedKey == null) {
      // Generate new key
      _key = encrypt.Key.fromSecureRandom(32);
      _iv = encrypt.IV.fromSecureRandom(16);
      
      // Store the key securely
      await _localStorage.saveEncryptionKey(_key!.base64);
    } else {
      // Use stored key
      _key = encrypt.Key.fromBase64(storedKey);
      _iv = encrypt.IV.fromSecureRandom(16);
    }
  }

  // Encrypt text message
  String encryptText(String plainText) {
    if (_key == null) {
      throw Exception('Encryption not initialized');
    }

    final encrypter = encrypt.Encrypter(encrypt.AES(_key!));
    final encrypted = encrypter.encrypt(plainText, iv: _iv);
    
    return encrypted.base64;
  }

  // Decrypt text message
  String decryptText(String encryptedText) {
    if (_key == null) {
      throw Exception('Encryption not initialized');
    }

    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_key!));
      final decrypted = encrypter.decrypt64(encryptedText, iv: _iv);
      
      return decrypted;
    } catch (e) {
      // Return encrypted text if decryption fails
      return encryptedText;
    }
  }

  // Hash user ID for chat room ID
  String generateChatRoomId(String userId1, String userId2) {
    List<String> users = [userId1, userId2];
    users.sort(); // Ensure consistent ordering
    
    String combined = users.join('_');
    var bytes = utf8.encode(combined);
    var digest = sha256.convert(bytes);
    
    return digest.toString();
  }

  // Generate message ID
  String generateMessageId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = encrypt.Key.fromSecureRandom(16).base64;
    
    var bytes = utf8.encode('$timestamp$random');
    var digest = sha256.convert(bytes);
    
    return digest.toString();
  }

  // Encrypt file data
  Uint8List encryptFile(Uint8List fileData) {
    if (_key == null) {
      throw Exception('Encryption not initialized');
    }

    final encrypter = encrypt.Encrypter(encrypt.AES(_key!));
    final encrypted = encrypter.encryptBytes(fileData, iv: _iv);
    
    return encrypted.bytes;
  }

  // Decrypt file data
  Uint8List decryptFile(Uint8List encryptedData) {
    if (_key == null) {
      throw Exception('Encryption not initialized');
    }

    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_key!));
      final encrypted = encrypt.Encrypted(encryptedData);
      final decrypted = encrypter.decryptBytes(encrypted, iv: _iv);
      
      return Uint8List.fromList(decrypted);
    } catch (e) {
      // Return original data if decryption fails
      return encryptedData;
    }
  }
}
