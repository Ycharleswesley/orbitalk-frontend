import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage app settings with persistence
class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  // Keys
  static const String _keyMessageNotifications = 'message_notifications';
  static const String _keyCallNotifications = 'call_notifications';
  static const String _keyVibrate = 'vibrate';
  static const String _keyAutoDownloadImages = 'auto_download_images';
  static const String _keyAutoDownloadVideos = 'auto_download_videos';
  static const String _keyFirstLaunch = 'first_launch_complete';

  // Notification settings
  bool _messageNotifications = true;
  bool _callNotifications = true;
  bool _vibrate = true;

  // Storage settings
  bool _autoDownloadImages = true;
  bool _autoDownloadVideos = false;

  // First launch flag
  bool _isFirstLaunchComplete = false;

  // Getters
  bool get messageNotifications => _messageNotifications;
  bool get callNotifications => _callNotifications;
  bool get vibrate => _vibrate;
  bool get autoDownloadImages => _autoDownloadImages;
  bool get autoDownloadVideos => _autoDownloadVideos;
  bool get isFirstLaunchComplete => _isFirstLaunchComplete;

  /// Load all settings from SharedPreferences
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _messageNotifications = prefs.getBool(_keyMessageNotifications) ?? true;
      _callNotifications = prefs.getBool(_keyCallNotifications) ?? true;
      _vibrate = prefs.getBool(_keyVibrate) ?? true;
      _autoDownloadImages = prefs.getBool(_keyAutoDownloadImages) ?? true;
      _autoDownloadVideos = prefs.getBool(_keyAutoDownloadVideos) ?? false;
      _isFirstLaunchComplete = prefs.getBool(_keyFirstLaunch) ?? false;
      
      notifyListeners();
      debugPrint('SettingsService: Settings loaded successfully');
    } catch (e) {
      debugPrint('SettingsService: Error loading settings: $e');
    }
  }

  /// Set message notifications
  Future<void> setMessageNotifications(bool value) async {
    _messageNotifications = value;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyMessageNotifications, value);
    } catch (e) {
      debugPrint('SettingsService: Error saving message notifications: $e');
    }
  }

  /// Set call notifications
  Future<void> setCallNotifications(bool value) async {
    _callNotifications = value;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyCallNotifications, value);
    } catch (e) {
      debugPrint('SettingsService: Error saving call notifications: $e');
    }
  }

  /// Set vibrate
  Future<void> setVibrate(bool value) async {
    _vibrate = value;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyVibrate, value);
    } catch (e) {
      debugPrint('SettingsService: Error saving vibrate: $e');
    }
  }

  /// Set auto download images
  Future<void> setAutoDownloadImages(bool value) async {
    _autoDownloadImages = value;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoDownloadImages, value);
    } catch (e) {
      debugPrint('SettingsService: Error saving auto download images: $e');
    }
  }

  /// Set auto download videos
  Future<void> setAutoDownloadVideos(bool value) async {
    _autoDownloadVideos = value;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoDownloadVideos, value);
    } catch (e) {
      debugPrint('SettingsService: Error saving auto download videos: $e');
    }
  }

  /// Mark first launch as complete
  Future<void> setFirstLaunchComplete() async {
    _isFirstLaunchComplete = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyFirstLaunch, true);
      debugPrint('SettingsService: First launch marked as complete');
    } catch (e) {
      debugPrint('SettingsService: Error saving first launch: $e');
    }
  }

  /// Check if this is the first launch
  Future<bool> isFirstLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_keyFirstLaunch) ?? false);
    } catch (e) {
      debugPrint('SettingsService: Error checking first launch: $e');
      return false;
    }
  }
}
