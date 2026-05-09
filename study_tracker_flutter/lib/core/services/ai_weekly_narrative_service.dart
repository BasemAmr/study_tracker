import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/ai_cache_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/domain.dart' show SessionFilter;
import 'groq_client.dart';

/// Rolling 7-day key `rolling-7d-YYYY-MM-DD` (study cache keys match user-facing "today").
String rolling7DayKeyForDate(DateTime d) {
  return 'rolling-7d-${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

(DateTime weekStart, DateTime weekEnd) _boundsForRolling7Day(DateTime anchor) {
  final end = DateTime(anchor.year, anchor.month, anchor.day, 23, 59, 59);
  final start = DateTime(anchor.year, anchor.month, anchor.day).subtract(const Duration(days: 7));
  return (start, end);
}

class AiWeeklyNarrativeService {
  static const _cacheFeature = 'weekly_narrative';

  final AiCacheRepository _cache;
  final SessionRepository _sessions;
  final SettingsRepository _settings;
  final GroqClient _groq;

  AiWeeklyNarrativeService({
    required AiCacheRepository cache,
    required SessionRepository sessions,
    required SettingsRepository settings,
    required GroqClient groq,
  })  : _cache = cache,
        _sessions = sessions,
        _settings = settings,
        _groq = groq;

  /// Journal-style narrative for rolling 7-day window; uses cache when present.
  Future<String?> generateForWeek(int profileId, {bool forceRefresh = false}) async {
    final now = DateTime.now();
    final cacheKey = rolling7DayKeyForDate(now);
    try {
      final active = await _settings.getCurrentProfileId();
      if (active != profileId) return null;

      if (!forceRefresh) {
        final cached = await _cache.get(_cacheFeature, cacheKey);
        if (cached != null) {
          final raw = cached['payload_json'] as String?;
          if (raw != null && raw.isNotEmpty) {
            final map = jsonDecode(raw) as Map<String, dynamic>;
            final text = map['narrative'] as String?;
            if (text != null && text.trim().isNotEmpty) return text.trim();
          }
        }
      }

      final apiKey = (await _settings.get('groqApiKey'))?.trim();
      if (apiKey == null || apiKey.isEmpty) return null;

      final (start, end) = _boundsForRolling7Day(now);
      final sessions = await _sessions.list(SessionFilter(
        startFrom: start,
        startTo: end,
        limit: 8000,
      ));

      final totalMin = sessions.fold<int>(0, (a, s) => a + s.durationMinutes);
      final bySubject = <String, int>{};
      for (final s in sessions) {
        final name = s.subjectName?.trim().isNotEmpty == true ? s.subjectName! : 'General';
        bySubject[name] = (bySubject[name] ?? 0) + s.durationMinutes;
      }
      final topSubjects = bySubject.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

      final preferArabic = (await _settings.get('languageCode'))?.toLowerCase() == 'ar';
      final summary = '''
Window: ${start.toIso8601String().split('T').first} .. ${end.toIso8601String().split('T').first} (Rolling 7 days)
- sessions_count: ${sessions.length}
- total_minutes: $totalMin
- top_subjects_by_minutes: ${topSubjects.take(5).map((e) => '${e.key}:${e.value}m').join(', ')}
''';

      final system = '''
You write a short weekly study journal entry for one learner.
Rules:
- 3 or 4 sentences.
- Past tense; no emoji.
- Reference the counts above explicitly.
''';

      final narrative = await _groq.chatCompletion(
        prompt: summary,
        systemPrompt: system,
        maxTokens: 400,
        timeoutMs: 25000,
        preferArabic: preferArabic,
      );

      if (narrative == null || narrative.trim().isEmpty) return null;

      await _cache.set(
        _cacheFeature,
        cacheKey,
        jsonEncode({
          'narrative': narrative.trim(),
          'generatedAt': DateTime.now().toIso8601String(),
          'model': 'llama-3.1-8b-instant',
        }),
      );

      return narrative.trim();
    } catch (_) {
      return null;
    }
  }
}

final aiWeeklyNarrativeServiceProvider = Provider<AiWeeklyNarrativeService>((ref) {
  return AiWeeklyNarrativeService(
    cache: ref.watch(aiCacheRepositoryProvider),
    sessions: ref.watch(sessionRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    groq: GroqClient(ref.watch(settingsRepositoryProvider)),
  );
});
