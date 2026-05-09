import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/ai_cache_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/domain.dart';
import 'groq_client.dart';

class SubjectDifficultyResult {
  final String hardestSubject;
  final String reason;
  final String suggestion;

  const SubjectDifficultyResult({
    required this.hardestSubject,
    required this.reason,
    required this.suggestion,
  });

  factory SubjectDifficultyResult.fromJson(Map<String, dynamic> j) {
    return SubjectDifficultyResult(
      hardestSubject: (j['hardestSubject'] as String?)?.trim() ?? 'Unknown',
      reason: (j['reason'] as String?)?.trim() ?? '',
      suggestion: (j['suggestion'] as String?)?.trim() ?? '',
    );
  }
}

/// Per-subject difficulty insight from ~30 days of sessions (JSON mode + daily cache).
class AiSubjectDifficultyService {
  static const _cacheFeature = 'difficulty';

  final AiCacheRepository _cache;
  final SessionRepository _sessions;
  final SettingsRepository _settings;
  final GroqClient _groq;

  AiSubjectDifficultyService({
    required AiCacheRepository cache,
    required SessionRepository sessions,
    required SettingsRepository settings,
    required GroqClient groq,
  })  : _cache = cache,
        _sessions = sessions,
        _settings = settings,
        _groq = groq;

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// Returns a structured result, or `{error: not_enough_data}` payload as null + map via [tryAnalyze].
  Future<Map<String, dynamic>?> analyze(int profileId, {bool forceRefresh = false}) async {
    try {
      final active = await _settings.getCurrentProfileId();
      if (active != profileId) return {'error': 'profile_mismatch'};

      final dayKey = _todayKey();
      if (!forceRefresh) {
        final cached = await _cache.get(_cacheFeature, dayKey);
        if (cached != null) {
          final raw = cached['payload_json'] as String?;
          if (raw != null && raw.isNotEmpty) {
            return jsonDecode(raw) as Map<String, dynamic>;
          }
        }
      }

      final apiKey = (await _settings.get('groqApiKey'))?.trim();
      if (apiKey == null || apiKey.isEmpty) return {'error': 'no_api_key'};

      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
      final sessions = await _sessions.list(SessionFilter(startFrom: from, limit: 8000));
      if (sessions.isEmpty) {
        const payload = {'error': 'not_enough_data'};
        await _cache.set(_cacheFeature, dayKey, jsonEncode(payload));
        return payload;
      }

      final ids = sessions.map((s) => s.id).whereType<int>().toList();
      final tasksMap = await _sessions.tasksBySessionIds(ids);

      final agg = <String, _SubAgg>{};
      for (final s in sessions) {
        final name = s.subjectName?.trim().isNotEmpty == true ? s.subjectName!.trim() : 'Unknown';
        if (name == 'Unknown') continue;
        final g = agg.putIfAbsent(name, _SubAgg.create);
        g.sessions += 1;
        g.totalMinutes += s.durationMinutes;
        final mood = s.mood ?? 'neutral';
        g.moods[mood] = (g.moods[mood] ?? 0) + 1;
        final ts = tasksMap[s.id] ?? const <SessionTask>[];
        if (ts.isNotEmpty) {
          g.taskLists += 1;
          g.tasksTotal += ts.length;
          g.tasksDone += ts.where((t) => t.completed).length;
        }
      }

      final qualified = agg.entries.where((e) => e.value.sessions >= 3).toList();
      if (qualified.isEmpty) {
        const payload = {'error': 'not_enough_data'};
        await _cache.set(_cacheFeature, dayKey, jsonEncode(payload));
        return payload;
      }

      final lines = qualified.map((e) {
        final a = e.value;
        final avgMin = (a.totalMinutes / a.sessions).toStringAsFixed(0);
        final moodTop = a.moods.entries.isEmpty
            ? 'n/a'
            : (a.moods.entries.toList()..sort((x, y) => y.value.compareTo(x.value))).first.key;
        final taskRate = a.tasksTotal == 0
            ? 'n/a'
            : '${(100 * a.tasksDone / a.tasksTotal).round()}% tasks done across ${a.taskLists} sessions with tasks';
        return '- ${e.key}: sessions=${a.sessions}, avg_min=$avgMin, top_mood=$moodTop, task_completion=$taskRate';
      }).join('\n');

      final preferArabic = (await _settings.get('languageCode'))?.toLowerCase() == 'ar';

      final system = '''
Return a single JSON object with keys: hardestSubject, reason, suggestion.
hardestSubject must be one of the subject display names from the data (exact spelling).
reason: one or two sentences grounded in the numbers.
suggestion: one actionable sentence referencing that same subject name.
No emoji. No markdown.
''';

      final raw = await _groq.chatCompletion(
        prompt: 'Per-subject 30-day aggregates:\n$lines',
        systemPrompt: system,
        jsonMode: true,
        maxTokens: 400,
        timeoutMs: 25000,
        preferArabic: preferArabic,
      );

      if (raw == null || raw.trim().isEmpty) {
        const payload = {'error': 'ai_failed'};
        return payload;
      }

      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        final m = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
        if (m == null) return {'error': 'parse_failed'};
        parsed = jsonDecode(m.group(0)!) as Map<String, dynamic>;
      }

      await _cache.set(_cacheFeature, dayKey, jsonEncode(parsed));
      return parsed;
    } catch (_) {
      return {'error': 'unknown'};
    }
  }
}

class _SubAgg {
  int sessions = 0;
  int totalMinutes = 0;
  final Map<String, int> moods = {};
  int taskLists = 0;
  int tasksTotal = 0;
  int tasksDone = 0;

  static _SubAgg create() => _SubAgg();
}

final aiSubjectDifficultyServiceProvider = Provider<AiSubjectDifficultyService>((ref) {
  return AiSubjectDifficultyService(
    cache: ref.watch(aiCacheRepositoryProvider),
    sessions: ref.watch(sessionRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    groq: GroqClient(ref.watch(settingsRepositoryProvider)),
  );
});
