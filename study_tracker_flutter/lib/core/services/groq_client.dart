import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../data/repositories/settings_repository.dart';

/// Shared Groq client for AI completions.
class GroqClient {
  final SettingsRepository _settings;

  GroqClient(this._settings);

  /// Perform a chat completion.
  /// Centralizes: API key read from SettingsRepository, model 'openai/gpt-oss-120b', endpoint, headers, error swallow, and preferArabic language directive.
  Future<String?> chatCompletion({
    required String prompt,
    String? systemPrompt,
    bool jsonMode = false,
    int maxTokens = 400,
    int timeoutMs = 30000,
    bool preferArabic = false,
  }) async {
    final apiKey = await _settings.get('groqApiKey');
    if (apiKey == null || apiKey.isEmpty) return null;

    final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final langHint = preferArabic ? 'Respond only in Arabic (MSA).' : 'Respond only in English.';
    final effectiveSystem = [
      if (systemPrompt != null && systemPrompt.trim().isNotEmpty) systemPrompt.trim(),
      langHint,
    ].join('\n\n');

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': effectiveSystem},
      {'role': 'user', 'content': prompt},
    ];

    try {
      final client = HttpClient();
      client.connectionTimeout = Duration(milliseconds: timeoutMs);
      final request = await client.postUrl(uri);
      request.headers.set('Authorization', 'Bearer $apiKey');
      request.headers.set('Content-Type', 'application/json');
      request.add(utf8.encode(jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': maxTokens,
        if (jsonMode) 'response_format': {'type': 'json_object'},
      })));

      final response = await request.close().timeout(Duration(milliseconds: timeoutMs));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('Groq API Error: Status ${response.statusCode}');
        client.close(force: true);
        return null;
      }

      final text = await utf8.decodeStream(response).timeout(Duration(milliseconds: timeoutMs));
      client.close(force: true);
      final data = jsonDecode(text) as Map<String, dynamic>;
      final content = (((data['choices'] as List?)?.first as Map?)?['message'] as Map?)?['content'];
      return content as String?;
    } catch (e) {
      debugPrint('Groq Network Error: $e');
      return null;
    }
  }
}