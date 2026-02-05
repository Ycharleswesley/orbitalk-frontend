import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/translation_config.dart'; // Use centralized config

class TranslationService {
  // Use the Backend URL (HTTP) instead of Azure
  // Replace 'wss://' with 'https://' from the config
  String get _backendUrl => TranslationConfig.websocketServerUrl.replaceFirst('wss://', 'https://');

  Future<String?> translateText(
    String text, {
    required String toLang,
    String fromLang = '',
  }) async {
    try {
      final uri = Uri.parse('$_backendUrl/translate');
      
      print('TranslationService: Translating via Backend: "$text" -> $toLang');
      
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': text,
          'targetLang': toLang,
          'sourceLang': fromLang.isNotEmpty ? fromLang : null,
        }),
      );
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final translatedText = body['translation'];
        print('TranslationService: Success - "$translatedText"');
        return translatedText;
      } else {
        print('TranslationService: Error ${response.statusCode} - ${response.body}');
        return null; // Don't throw, just return null so original shows
      }
    } catch (e) {
      print('TranslationService: Network Error: $e');
      return null;
    }
  }
}
