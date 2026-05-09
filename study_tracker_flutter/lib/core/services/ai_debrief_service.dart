import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/ai_feature_settings_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/domain.dart';
import 'groq_client.dart';

/// Session debrief message — brief AI reaction to a study session.
class DebriefMessage {
  final String text;
  final DateTime generatedAt;

  DebriefMessage({required this.text, required this.generatedAt});
}

class _DebriefMessageNotifier extends StateNotifier<DebriefMessage?> {
  _DebriefMessageNotifier() : super(null);

  void setMessage(DebriefMessage msg) => state = msg;

  void clear() => state = null;
}

final aiDebriefMessageProvider =
    StateNotifierProvider<_DebriefMessageNotifier, DebriefMessage?>((ref) {
  return _DebriefMessageNotifier();
});

/// Fire-and-forget debrief after a session is saved; publishes to [aiDebriefMessageProvider].
class AiDebriefService {
  final Ref _ref;
  final SessionRepository _sessionRepo;
  final SettingsRepository _settingsRepo;
  final GroqClient _groq;

  AiDebriefService({
    required Ref ref,
    required SessionRepository sessionRepo,
    required SettingsRepository settingsRepo,
    required GroqClient groq,
  })  : _ref = ref,
        _sessionRepo = sessionRepo,
        _settingsRepo = settingsRepo,
        _groq = groq;

  Future<void> generateForSession(int sessionId, StudySession session) async {
    try {
      final ai = await _ref.read(aiFeatureSettingsRepositoryProvider).getSettings();
      if (!_rowBool(ai?['debrief_enabled'])) return;

      final preferArabic = (await _settingsRepo.get('languageCode'))?.toLowerCase() == 'ar';

      final persisted = await _sessionRepo.getById(sessionId);
      final effective = persisted ?? session;

      final recent = await _sessionRepo.getRecent(8);
      final streak = await _sessionRepo.getCurrentStreak();
      final summary = await _sessionRepo.getSummary();

      final sessionContext = '''
Session (just saved):
- id: $sessionId
- duration_minutes: ${effective.durationMinutes}
- subject: ${effective.subjectName ?? 'general'}
- mode: ${effective.mode.name}
- mood: ${effective.mood ?? 'not recorded'}
- break_minutes: ${effective.breakMinutes}

Recent context:
- last_sessions_count_returned: ${recent.length}
- current_streak_days: $streak
- lifetime_sessions: ${summary.totalSessions}
- lifetime_avg_session_minutes: ${summary.averageMinutes.toStringAsFixed(0)}
''';

      final system = '''
You write a single-sentence debrief for a study session.
Rules:
- Exactly one sentence.
- No emoji.
- Mention duration and subject (and mood if present).
- Avoid cliché praise; prefer a concrete observation or next-step hint.
''';

      final content = await _groq.chatCompletion(
        prompt: sessionContext,
        systemPrompt: system,
        maxTokens: 120,
        timeoutMs: 15000,
        preferArabic: preferArabic,
      );

      if (content == null || content.trim().isEmpty) return;

      _ref.read(aiDebriefMessageProvider.notifier).setMessage(
            DebriefMessage(text: content.trim(), generatedAt: DateTime.now()),
          );
    } catch (_) {
      // Background path: never surface errors to the user.
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

final aiDebriefServiceProvider = Provider<AiDebriefService>((ref) {
  return AiDebriefService(
    ref: ref,
    sessionRepo: ref.watch(sessionRepositoryProvider),
    settingsRepo: ref.watch(settingsRepositoryProvider),
    groq: GroqClient(ref.watch(settingsRepositoryProvider)),
  );
});
