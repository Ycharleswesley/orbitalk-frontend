class TranslationConfig {
  // WebSocket server URL
  // =====================================================================
  // LOCAL TESTING CONFIGURATION
  // =====================================================================
  // For Android Emulator: Use 10.0.2.2 (special alias for host's localhost)
  // For Physical Device: Use your computer's local IP (e.g., 192.168.1.xxx)
  //   - Find your IP: Run 'ipconfig' in Command Prompt (look for IPv4)
  //   - Ensure phone and computer are on the SAME WiFi network
  // =====================================================================
  
  // LOCAL TESTING (Android Emulator)
  // static const String websocketServerUrl = 'ws://10.0.2.2:8080';
  
  // LOCAL TESTING (Physical Device - Your IP: 192.168.88.35)
  // static const String websocketServerUrl = 'ws://192.168.29.65:8080';
  
  // PRODUCTION (Render.com)
  static const String websocketServerUrl = 'wss://orbitalk-backend-final.onrender.com';
  static const String httpServerUrl = 'https://orbitalk-backend-final.onrender.com';

  // static const String websocketServerUrl = 'ws://192.168.88.30:8080';
  // static const String httpServerUrl = 'http://192.168.88.30:8080';
  
  // Audio format constants
  static const int sampleRate = 16000; // 16kHz
  static const int channels = 1; // Mono
  static const int bitDepth = 16; // 16-bit
  
  // Language codes mapping - Only supported languages
  static const Map<String, String> languageCodes = {
    'en': 'en-US', // English
    'hi': 'hi-IN', // Hindi
    'mr': 'mr-IN', // Marathi
    'bn': 'bn-IN', // Bengali
    'ta': 'ta-IN', // Tamil
    'te': 'te-IN', // Telugu
    'ml': 'ml-IN', // Malayalam
    'kn': 'kn-IN', // Kannada
    'pa': 'pa-IN', // Punjabi
    'gu': 'gu-IN', // Gujarati
    'ur': 'ur-IN', // Urdu
  };
  
  // Get language code with fallback
  static String getLanguageCode(String code) {
    return languageCodes[code] ?? 'en-US';
  }

  // Language display names
  static const Map<String, String> languageNames = {
    'en': 'English',
    'hi': 'Hindi',
    'mr': 'Marathi',
    'bn': 'Bengali',
    'ta': 'Tamil',
    'te': 'Telugu',
    'ml': 'Malayalam',
    'kn': 'Kannada',
    'pa': 'Punjabi',
    'gu': 'Gujarati',
    'ur': 'Urdu',
  };

  static String getLanguageName(String code) {
    return languageNames[code] ?? 'English';
  }
}
