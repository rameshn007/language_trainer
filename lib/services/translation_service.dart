import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final translationServiceProvider = Provider<TranslationService>((ref) {
  return TranslationService();
});

class TranslationService {
  static const String _baseUrl = 'https://api.mymemory.translated.net/get';

  /// Translates [text] between English and Portugal Portuguese.
  /// Set [fromEn] to true to translate English to Portuguese.
  /// Set [fromEn] to false to translate Portuguese to English.
  Future<String?> translate(String text, {required bool fromEn}) async {
    if (text.isEmpty) return null;

    final langPair = fromEn ? 'en|pt-PT' : 'pt-PT|en';
    final url = Uri.parse('$_baseUrl?q=${Uri.encodeComponent(text)}&langpair=$langPair');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final translatedText = data['responseData']['translatedText'] as String?;
        
        if (translatedText != null && translatedText.isNotEmpty) {
          // MyMemory sometimes returns error messages as the translated text if rate limited
          if (translatedText.contains('MYMEMORY WARNING')) {
            return null;
          }
          return _decodeHtmlEntities(translatedText);
        }
      }
    } catch (e) {
      debugPrint('Translation error: $e');
    }

    return null;
  }

  String _decodeHtmlEntities(String text) {
    // Simple decoding for common entities returned by APIs
    return text
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }
}
