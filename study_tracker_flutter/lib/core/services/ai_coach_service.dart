import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/ai_cache_repository.dart';
import '../../data/repositories/ai_feature_settings_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/repositories/settings_repository.dart';
import 'groq_client.dart';

/// Daily AI coach message service.
/// Generates a personalized message based on 7-day session summary, streak, top subject, goal %, and academic level.
/// Results are cached per day via [AiCacheRepository].
class AiCoachService {
  static const _cacheFeature = 'coach';

  final AiCacheRepository _cacheRepo;
  final AiFeatureSettingsRepository _aiFeatureRepo;
  final SessionRepository _sessionRepo;
  final SettingsRepository _settingsRepo;
  final GroqClient _groq;

  AiCoachService({
    required AiCacheRepository cacheRepo,
    required AiFeatureSettingsRepository aiFeatureRepo,
    required SessionRepository sessionRepo,
    required SettingsRepository settingsRepo,
    required GroqClient groq,
  })  : _cacheRepo = cacheRepo,
        _aiFeatureRepo = aiFeatureRepo,
        _sessionRepo = sessionRepo,
        _settingsRepo = settingsRepo,
        _groq = groq;

  /// Ensure today's AI coach message is generated and cached.
  /// Returns null on missing key, disabled coach toggle, wrong profile id, or any failure (fail-silent).
  Future<String?> ensureTodaysMessage(int profileId) async {
    try {
      final activeId = await _settingsRepo.getCurrentProfileId();
      if (activeId != profileId) return null;

      final ai = await _aiFeatureRepo.getSettings();
      if (!_rowBool(ai?['coach_enabled'])) return null;

      final today = DateTime.now();
      final cacheKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final cached = await _cacheRepo.get(_cacheFeature, cacheKey);
      if (cached != null) {
        final payloadStr = cached['payload_json'] as String?;
        if (payloadStr != null && payloadStr.isNotEmpty) {
          final decoded = jsonDecode(payloadStr) as Map<String, dynamic>;
          final msg = decoded['message'] as String?;
          if (msg != null && msg.trim().isNotEmpty) return msg.trim();
        }
      }

      final apiKey = (await _settingsRepo.get('groqApiKey'))?.trim();
      if (apiKey == null || apiKey.isEmpty) return null;

      final summary = await _buildCoachSummary();
      if (summary == null) return null;

      final preferArabic = (await _settingsRepo.get('languageCode'))?.toLowerCase() == 'ar';
      final system = '''
You are a concise study coach for a tracking app.
Rules:
- Output exactly 2 or 3 short sentences.
- No emoji.
- Reference the provided numbers explicitly (sessions, minutes, streak, goal %, top subject, academic level).
- Be constructive; avoid generic praise with no numbers.
''';

      final message = await _groq.chatCompletion(
        prompt: 'Here is the learner snapshot:\n$summary\n\nWrite the coach message now.',
        systemPrompt: system,
        maxTokens: 200,
        timeoutMs: 20000,
        preferArabic: preferArabic,
      );

      if (message == null || message.trim().isEmpty) return null;

      final payload = jsonEncode({
        'message': message.trim(),
        'generatedAt': DateTime.now().toIso8601String(),
        'model': 'llama-3.1-8b-instant',
      });
      await _cacheRepo.set(_cacheFeature, cacheKey, payload);

      return message.trim();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _buildCoachSummary() async {
    try {
      final summary = await _sessionRepo.getSummaryLast7Days();
      final streak = await _sessionRepo.getCurrentStreak();
      final topSubject = await _sessionRepo.getMostStudiedSubjectLast7Days();
      final academicLevel = await _settingsRepo.get('academicLevel') ?? 'Undergraduate';

      final dailyGoal = int.tryParse(await _settingsRepo.get('dailyGoalMinutes') ?? '') ?? 240;
      final weeklyTarget = dailyGoal * 7;
      final weekMinutes = await _sessionRepo.getTotalMinutesThisWeek();
      final goalPct = weeklyTarget <= 0 ? 0 : ((weekMinutes / weeklyTarget) * 100).clamp(0, 1000).round();

      final totalHours = summary.totalMinutes ~/ 60;
      final totalMinutesRem = summary.totalMinutes % 60;

      return '''
7-day window:
- Sessions: ${summary.totalSessions}
- Total study time: ${totalHours}h ${totalMinutesRem}m
- Current streak: $streak consecutive day(s) with a session
- Most-studied subject (by minutes): ${topSubject ?? 'none logged'}
- Academic level (from profile): $academicLevel
- Weekly goal progress: $goalPct% (this week $weekMinutes min vs target $weeklyTarget min from daily goal $dailyGoal min × 7)
''';
    } catch (_) {
      return null;
    }
  }

  static bool _rowBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase();
      return s == 'true' || s == '1';
    }
    return false;
  }
}

final aiCoachServiceProvider = Provider<AiCoachService>((ref) {
  return AiCoachService(
    cacheRepo: ref.watch(aiCacheRepositoryProvider),
    aiFeatureRepo: ref.watch(aiFeatureSettingsRepositoryProvider),
    sessionRepo: ref.watch(sessionRepositoryProvider),
    settingsRepo: ref.watch(settingsRepositoryProvider),
    groq: GroqClient(ref.watch(settingsRepositoryProvider)),
  );
});
