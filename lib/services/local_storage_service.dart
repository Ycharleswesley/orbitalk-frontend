import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // Force reload from disk (Fix for Tablets/Old Androids caching stale data)
  Future<void> sync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
  }

  // Keys
  static const String _keyUserId = 'user_id';
  static const String _keyUserName = 'user_name';
  static const String _keyPhoneNumber = 'phone_number';
  static const String _keyProfilePicture = 'profile_picture';
  static const String _keyLanguage = 'language';
  static const String _keyIsAuthenticated = 'is_authenticated';
  static const String _keyEncryptionKey = 'encryption_key';
  static const String _keyBio = 'bio';

  // Auth State
  Future<void> saveAuthState(bool isAuthenticated) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsAuthenticated, isAuthenticated);
  }

  Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsAuthenticated) ?? false;
  }

  // User ID
  Future<void> saveUserId(String userId) async {
    await _secureStorage.write(key: _keyUserId, value: userId);
  }

  Future<String?> getUserId() async {
    return await _secureStorage.read(key: _keyUserId);
  }

  // User Name
  Future<void> saveUserName(String userName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, userName);
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  // Phone Number
  Future<void> savePhoneNumber(String phoneNumber) async {
    await _secureStorage.write(key: _keyPhoneNumber, value: phoneNumber);
  }

  Future<String?> getPhoneNumber() async {
    return await _secureStorage.read(key: _keyPhoneNumber);
  }

  // Profile Picture
  Future<void> saveProfilePicture(String profilePicture) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfilePicture, profilePicture);
  }

  Future<String?> getProfilePicture() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyProfilePicture);
  }

  // Language
  Future<void> saveLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, language);
  }

  Future<String?> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguage);
  }

  // Bio
  Future<void> saveBio(String bio) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBio, bio);
  }

  Future<String?> getBio() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBio);
  }

  // Encryption Key
  Future<void> saveEncryptionKey(String key) async {
    await _secureStorage.write(key: _keyEncryptionKey, value: key);
  }

  Future<String?> getEncryptionKey() async {
    return await _secureStorage.read(key: _keyEncryptionKey);
  }

  // Clear Auth State
  Future<void> clearAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _secureStorage.deleteAll();
  }

  // Contact Nicknames
  Future<void> saveContactNickname(String userId, String nickname) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nickname_$userId', nickname);
  }

  Future<String?> getContactNickname(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('nickname_$userId');
  }

  // Profile Color ID
  Future<void> saveProfileColor(int colorId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('profile_color_id', colorId);
  }

  Future<int> getProfileColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('profile_color_id') ?? 0; // Default to 0 (Blue) 
  }
}
