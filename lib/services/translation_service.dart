import 'dart:convert';

import 'package:http/http.dart' as http;

class TranslationResult {
  final String translatedText;
  final String sourceLanguage;

  const TranslationResult({
    required this.translatedText,
    required this.sourceLanguage,
  });
}

class TranslationService {
  final http.Client _client;

  TranslationService({http.Client? client}) : _client = client ?? http.Client();

  Future<TranslationResult?> translate({
    required String text,
    required String targetLanguage,
  }) async {
    final source = text.trim();
    if (source.isEmpty) {
      return null;
    }

    final uri = Uri.https(
      'translate.googleapis.com',
      '/translate_a/single',
      {
        'client': 'gtx',
        'sl': 'auto',
        'tl': targetLanguage,
        'dt': 't',
        'q': source,
      },
    );

    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('Translation failed (${response.statusCode}).');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List || decoded.isEmpty || decoded.first is! List) {
      throw Exception('Unexpected translation response format.');
    }

    final chunks = decoded.first as List<dynamic>;
    final buffer = StringBuffer();
    for (final chunk in chunks) {
      if (chunk is List && chunk.isNotEmpty && chunk.first != null) {
        buffer.write(chunk.first.toString());
      }
    }

    final translated = buffer.toString().trim();
    if (translated.isEmpty) {
      return null;
    }

    final sourceLanguage = decoded.length > 2 && decoded[2] != null
        ? decoded[2].toString()
        : 'auto';

    return TranslationResult(
      translatedText: translated,
      sourceLanguage: sourceLanguage,
    );
  }
}
