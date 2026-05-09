import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/ai_challenge_history_repository.dart';
import '../../data/repositories/ai_challenge_repository.dart';
import '../../data/repositories/ai_feature_settings_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/domain.dart';
import 'groq_client.dart';

// ─── Failure contract ─────────────────────────────────────────────────────────

enum AiChallengeErrorReason {
  featureDisabled,
  noKey,
  network,
  parse,
  httpError,
}

class AiChallengeError {
  final AiChallengeErrorReason reason;
  final bool aiToggleEnabled;
  final bool apiKeyPresent;
  final int? httpStatusCode;

  const AiChallengeError({
    required this.reason,
    required this.aiToggleEnabled,
    required this.apiKeyPresent,
    this.httpStatusCode,
  });
}

sealed class AiChallengeResult {}

class AiChallengeSuccess extends AiChallengeResult {
  final AiChallenge challenge;
  AiChallengeSuccess(this.challenge);
}

class AiChallengeFailure extends AiChallengeResult {
  final AiChallengeError error;
  AiChallengeFailure(this.error);
}

const Duration _threeHourGrace = Duration(hours: 3);
final Set<String> _renewalInFlight = {};

String formatAiChallengeErrorToast(AiChallengeError e) {
  final t = e.aiToggleEnabled ? 'on' : 'off';
  final k = e.apiKeyPresent ? 'present' : 'missing';
  return 'Mission refresh failed (${e.reason.name}). AI challenges: $t, API key: $k.';
}

// ─── Progress ─────────────────────────────────────────────────────────────────

class SubjectProgressEntry {
  final int subjectId;
  final String? subjectName;
  final int minutes;
  final bool completed;

  const SubjectProgressEntry({
    required this.subjectId,
    this.subjectName,
    required this.minutes,
    required this.completed,
  });
}

class AiChallengeProgress {
  final int current;
  final int target;
  final int percent;
  final List<SubjectProgressEntry>? subjectBreakdown;

  const AiChallengeProgress({
    required this.current,
    required this.target,
    required this.percent,
    this.subjectBreakdown,
  });
}

// ─── Service ──────────────────────────────────────────────────────────────────

class AiChallengeService {
  static const Map<String, List<int>> _targetBounds = {
    'daily:sessions': [1, 6],
    'daily:minutes': [20, 240],
    'daily:streak': [1, 1],
    'daily:subjects': [1, 3],
    'daily:pomodoros': [1, 6],
    'weekly:sessions': [4, 24],
    'weekly:minutes': [120, 1200],
    'weekly:streak': [2, 7],
    'weekly:subjects': [2, 8],
    'weekly:pomodoros': [4, 30],
    'monthly:sessions': [12, 60],
    'monthly:minutes': [480, 3600],
    'monthly:streak': [8, 28],
    'monthly:subjects': [3, 12],
    'monthly:pomodoros': [12, 90],
    'surprise:sessions': [1, 3],
    'surprise:minutes': [15, 90],
    'surprise:streak': [1, 2],
    'surprise:subjects': [1, 2],
    'surprise:pomodoros': [1, 3],
  };

  static const Map<AiChallengeTier, List<int>> _expiresHoursBounds = {
    AiChallengeTier.daily: [8, 36],
    AiChallengeTier.weekly: [96, 240],
    AiChallengeTier.monthly: [480, 960],
    AiChallengeTier.surprise: [3, 16],
  };

  // XP lookup kept for scoring — not related to fallback missions.
  static const Map<String, int> _staticMissionXpByTitle = {
    'Daily Momentum': 24,
    'Focused Double': 20,
    'Weekly Deep Work': 52,
    'Seven-Day Rhythm': 56,
    'Subject Explorer': 88,
    'Marathon Minutes': 96,
    'Consistency Architect': 92,
    'Surprise Sprint': 48,
    'Lightning Focus': 44,
    'Focus Ladder': 22,
    'Pomodoro Pulse': 24,
    'Subject Switch': 20,
    'No Zero Day': 18,
    'Session Builder': 50,
    'Pomodoro Grid': 58,
    'Active Days Arc': 84,
    'Subject Constellation': 90,
    'Pomodoro Marathon': 98,
    'Focus Burst': 42,
    'Rapid Relay': 40,
    'Topic Shuffle': 46,
    'Micro Streak': 38,
  };

  final AiChallengeRepository _challengeRepo;
  final SessionRepository _sessionRepo;
  final SettingsRepository _settingsRepo;
  final AiFeatureSettingsRepository _aiFeatureRepo;
  final AiChallengeHistoryRepository _historyRepo;

  AiChallengeService(
    this._challengeRepo,
    this._sessionRepo,
    this._settingsRepo,
    this._aiFeatureRepo,
    this._historyRepo,
  );

  int xpForCompletedChallenge(AiChallenge challenge) {
    final staticXp = _staticMissionXpByTitle[challenge.title.trim()];
    if (staticXp != null) return staticXp;

    final base = switch (challenge.tier) {
      AiChallengeTier.daily => 24,
      AiChallengeTier.weekly => 52,
      AiChallengeTier.monthly => 92,
      AiChallengeTier.surprise => 40,
    };

    final difficultyMultiplier = switch (challenge.difficulty) {
      AiChallengeDifficulty.easy => 1.0,
      AiChallengeDifficulty.medium => 1.2,
      AiChallengeDifficulty.hard => 1.45,
      AiChallengeDifficulty.extreme => 1.7,
    };

    final bounds = _boundsFor(challenge.tier, challenge.metric);
    final span = max(1, bounds[1] - bounds[0]);
    final normalizedTarget = (challenge.target - bounds[0]) / span;
    final targetMultiplier = 0.85 + normalizedTarget.clamp(0.0, 1.0) * 0.5;

    return (base * difficultyMultiplier * targetMultiplier).round().clamp(12, 140);
  }

  // ── Auto-refresh (silent) ───────────────────────────────────────────────────

  Future<void> checkAndRefreshChallenges() async {
    final settings = await _settingsRepo.getStructured();
    if (!settings.aiChallengesEnabled) return;

    final now = DateTime.now();
    final allSettings = await _settingsRepo.getAll();

    if (_shouldRefresh(allSettings['lastFetchDaily'], now, 24)) {
      await _autoRefreshTier(AiChallengeTier.daily);
      await _settingsRepo.set('lastFetchDaily', now.toIso8601String());
    }

    if (_shouldRefresh(allSettings['lastFetchWeekly'], now, 24 * 7)) {
      await _autoRefreshTier(AiChallengeTier.weekly);
      await _settingsRepo.set('lastFetchWeekly', now.toIso8601String());
    }

    if (_shouldRefresh(allSettings['lastFetchMonthly'], now, 24 * 30)) {
      await _autoRefreshTier(AiChallengeTier.monthly);
      await _settingsRepo.set('lastFetchMonthly', now.toIso8601String());
    }

    final activeSurprise = await _challengeRepo.getActiveByTier(AiChallengeTier.surprise);
    if (activeSurprise == null && Random().nextDouble() < 0.15) {
      await _autoRefreshTier(AiChallengeTier.surprise);
    }
  }

  Future<void> refreshSurpriseNow() async {
    await refreshTierNow(AiChallengeTier.surprise);
  }

  /// Returns user-visible error lines from auto-renew API failures (show as snackbars).
  Future<List<String>> processExpiredMissionsOnTabOpen() async {
    final out = <String>[];
    final all = await _challengeRepo.getAll();
    final now = DateTime.now();

    for (final c in all) {
      if (c.completed || c.status != AiChallengeStatus.active) continue;
      if (!c.expiresAt.isBefore(now)) continue;
      if (now.difference(c.expiresAt) <= _threeHourGrace) continue;
      if (_renewalInFlight.contains(c.id)) continue;
      _renewalInFlight.add(c.id);
      try {
        final progress = await calculateProgress(c);
        await _snapshotToHistory(c, AiChallengeCloseReason.expired, progress.current);
        final result = await _fetchFromGroq(c.tier);
        if (result is AiChallengeSuccess) {
          await _clearTierFailure(c.tier);
          await _challengeRepo.setChallengeStatus(c.id, AiChallengeStatus.expired);
          await _challengeRepo.create(result.challenge);
          await _maybeClearPin(c.id);
        } else {
          final err = (result as AiChallengeFailure).error;
          await _persistTierFailure(c.tier, err);
          await _challengeRepo.setChallengeStatus(c.id, AiChallengeStatus.expired);
          await _maybeClearPin(c.id);
          out.add(formatAiChallengeErrorToast(err));
        }
      } finally {
        _renewalInFlight.remove(c.id);
      }
    }
    return out;
  }

  Future<AiChallengeError?> getTierFailure(AiChallengeTier tier) async {
    return _readTierFailure(tier);
  }

  /// User-initiated per-card refresh with destructive-replace guard.
  /// The previous mission is deleted ONLY after a successful API response.
  Future<AiChallengeResult> refreshTierNow(AiChallengeTier tier) async {
    final existing = await _challengeRepo.getSlotChallengeForTier(tier);
    final result = await _fetchFromGroq(tier);

    if (result is AiChallengeFailure) {
      await _persistTierFailure(tier, result.error);
      return result;
    }
    await _clearTierFailure(tier);

    final payload = (result as AiChallengeSuccess).challenge;

    // API succeeded — snapshot the old mission first, then destroy it.
    if (existing != null) {
      final progress = await calculateProgress(existing);
      await _snapshotToHistory(existing, AiChallengeCloseReason.replaced, progress.current);
      await _challengeRepo.deleteActiveByTier(tier);
    }

    await _challengeRepo.create(payload);
    final created = await _challengeRepo.getActiveByTier(tier);
    return AiChallengeSuccess(created ?? payload);
  }

  /// Calculates progress for a challenge.
  ///
  /// Strict window: only sessions with startAt STRICTLY AFTER challenge.createdAt
  /// are counted. A fresh mission always starts from zero regardless of prior sessions.
  Future<AiChallengeProgress> calculateProgress(AiChallenge challenge) async {
    if (challenge.completed) {
      return AiChallengeProgress(
        current: challenge.target,
        target: challenge.target,
        percent: 100,
      );
    }

    final createdAt = challenge.createdAt ?? challenge.expiresAt;
    final sessions = await _sessionRepo.list(
      SessionFilter(
        startFrom: createdAt,
        startTo: challenge.expiresAt,
        limit: 10000,
      ),
    );

    // Strict: exclude sessions whose startAt is not after createdAt.
    final windowSessions = sessions.where((s) => s.startAt.isAfter(createdAt)).toList();

    final sub = challenge.subTargets;
    if (sub != null && sub.mode == 'any-subjects') {
      return _calcMultiSubjectProgress(windowSessions, sub, challenge.target);
    }

    final unitFloor = challenge.unitMinMinutes;
    int current = 0;

    switch (challenge.metric) {
      case AiChallengeMetric.minutes:
        current = windowSessions.fold(0, (sum, s) => sum + s.durationMinutes);
        break;
      case AiChallengeMetric.sessions:
        current = unitFloor != null
            ? windowSessions.where((s) => s.durationMinutes >= unitFloor).length
            : windowSessions.length;
        break;
      case AiChallengeMetric.subjects:
        current = windowSessions.map((s) => s.subjectId).whereType<int>().toSet().length;
        break;
      case AiChallengeMetric.pomodoros:
        current = windowSessions.where((s) {
          if (s.mode != StudySessionMode.pomodoro) return false;
          return unitFloor == null || s.durationMinutes >= unitFloor;
        }).length;
        break;
      case AiChallengeMetric.streak:
        current = windowSessions
            .map((s) => DateTime(s.startAt.year, s.startAt.month, s.startAt.day))
            .toSet()
            .length;
        break;
    }

    final percent = challenge.target <= 0
        ? 0
        : min(100, ((current / challenge.target) * 100).round());

    if (percent >= 100) {
      await _challengeRepo.markCompleted(challenge.id);
    }

    return AiChallengeProgress(current: current, target: challenge.target, percent: percent);
  }

  // ── Active mission pin ──────────────────────────────────────────────────────

  Future<String?> getActiveAiMissionId() async {
    return _settingsRepo.get('activeAiMissionId');
  }

  Future<void> setActiveAiMissionId(String missionId) async {
    await _settingsRepo.set('activeAiMissionId', missionId);
  }

  Future<void> clearActiveAiMissionId() async {
    await _settingsRepo.delete('activeAiMissionId');
  }

  /// Resolves the pinned mission. Auto-clears the pin when the mission is gone,
  /// expired, or has a non-active status.
  Future<AiChallenge?> resolveActiveMission() async {
    final missionId = await getActiveAiMissionId();
    if (missionId == null || missionId.isEmpty) return null;

    final all = await _challengeRepo.getAll();
    final AiChallenge? mission;
    try {
      mission = all.firstWhere((c) => c.id == missionId);
    } catch (_) {
      await clearActiveAiMissionId();
      return null;
    }

    if (mission.status != AiChallengeStatus.active) {
      await clearActiveAiMissionId();
      return null;
    }

    // Grace: still `active` but past expiresAt — keep pin until >3h after expiry.
    final now = DateTime.now();
    if (mission.expiresAt.isBefore(now) &&
        now.difference(mission.expiresAt) > _threeHourGrace) {
      await clearActiveAiMissionId();
      return null;
    }

    return mission;
  }

  Future<void> _maybeClearPin(String missionId) async {
    final pinned = await getActiveAiMissionId();
    if (pinned == missionId) await clearActiveAiMissionId();
  }

  static const _tierFailurePrefix = 'aiMissionTierFailure.';

  Future<void> _persistTierFailure(AiChallengeTier tier, AiChallengeError e) async {
    await _settingsRepo.set(
      '$_tierFailurePrefix${tier.name}',
      jsonEncode({
        'reason': e.reason.name,
        'aiToggleEnabled': e.aiToggleEnabled,
        'apiKeyPresent': e.apiKeyPresent,
      }),
    );
  }

  Future<void> _clearTierFailure(AiChallengeTier tier) async {
    await _settingsRepo.delete('$_tierFailurePrefix${tier.name}');
  }

  Future<AiChallengeError?> _readTierFailure(AiChallengeTier tier) async {
    final raw = await _settingsRepo.get('$_tierFailurePrefix${tier.name}');
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final r = m['reason'] as String?;
      if (r == null) return null;
      var parsedReason = AiChallengeErrorReason.network;
      for (final v in AiChallengeErrorReason.values) {
        if (v.name == r) {
          parsedReason = v;
          break;
        }
      }
      return AiChallengeError(
        reason: parsedReason,
        aiToggleEnabled: m['aiToggleEnabled'] == true,
        apiKeyPresent: m['apiKeyPresent'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Snapshot helper ─────────────────────────────────────────────────────────

  Future<void> _snapshotToHistory(
    AiChallenge challenge,
    AiChallengeCloseReason reason,
    int progressAtClose,
  ) async {
    final profileId = await _settingsRepo.getCurrentProfileId();
    final now = DateTime.now();
    final entry = NewAiChallengeHistoryEntry(
      profileId: profileId,
      tier: challenge.tier,
      title: challenge.title,
      description: challenge.description,
      metric: challenge.metric,
      target: challenge.target,
      progressAtClose: progressAtClose,
      closeReason: reason,
      closedAt: now.toIso8601String(),
      originalCreatedAt: (challenge.createdAt ?? now).toIso8601String(),
      originalExpiresAt: challenge.expiresAt.toIso8601String(),
      subTargets: challenge.subTargets,
      unitMinMinutes: challenge.unitMinMinutes,
    );
    await _historyRepo.create(entry);
    await _historyRepo.pruneOldestBeyondLimit(challenge.tier, 50);
  }

  // ── Multi-subject progress ──────────────────────────────────────────────────

  AiChallengeProgress _calcMultiSubjectProgress(
    List<StudySession> sessions,
    AiMissionSubTargets sub,
    int overallTarget,
  ) {
    final minutesPerSubject = sub.minutesPerSubject ?? 1;
    final requiredCount = sub.count;

    final bySubject = <int, ({String? name, int minutes})>{};
    for (final s in sessions) {
      if (s.subjectId == null) continue;
      final id = s.subjectId!;
      final existing = bySubject[id];
      bySubject[id] = (
        name: existing?.name ?? s.subjectName,
        minutes: (existing?.minutes ?? 0) + s.durationMinutes,
      );
    }

    final sorted = bySubject.entries.toList()
      ..sort((a, b) => b.value.minutes.compareTo(a.value.minutes));
    final top = sorted.take(requiredCount).toList();

    final breakdown = top
        .map((e) => SubjectProgressEntry(
              subjectId: e.key,
              subjectName: e.value.name,
              minutes: e.value.minutes,
              completed: e.value.minutes >= minutesPerSubject,
            ))
        .toList();

    final completedCount = breakdown.where((e) => e.completed).length;
    final percent = min(100, ((completedCount / requiredCount) * 100).round());

    return AiChallengeProgress(
      current: completedCount,
      target: overallTarget,
      percent: percent,
      subjectBreakdown: breakdown,
    );
  }

  // ── Groq fetch with failure contract ────────────────────────────────────────

  Future<AiChallengeResult> _fetchFromGroq(AiChallengeTier tier) async {
    final settings = await _settingsRepo.getStructured();
    final aiToggleEnabled = settings.aiChallengesEnabled;

    final apiKey = settings.groqApiKey?.trim() ?? '';
    final apiKeyPresent =
        apiKey.isNotEmpty && !apiKey.startsWith('sk-xxxx') && !apiKey.startsWith('gsk_xxxx');

    final smartEnabled = await _isSmartChallengesEnabled();
    if (!aiToggleEnabled || !smartEnabled) {
      return AiChallengeFailure(AiChallengeError(
        reason: AiChallengeErrorReason.featureDisabled,
        aiToggleEnabled: aiToggleEnabled,
        apiKeyPresent: apiKeyPresent,
      ));
    }

    if (!apiKeyPresent) {
      return AiChallengeFailure(AiChallengeError(
        reason: AiChallengeErrorReason.noKey,
        aiToggleEnabled: aiToggleEnabled,
        apiKeyPresent: false,
      ));
    }

    final weakSpotSummary = await _build30DayWeakSpotSummary();
    final preferArabic =
        settings.languageCode.toLowerCase().startsWith('ar');
    final systemPrompt = _buildSystemPrompt(tier, weakSpotSummary, preferArabic);

    final groq = GroqClient(_settingsRepo);
    String? content;
    try {
      content = await groq.chatCompletion(
        prompt: 'Emit the JSON now for tier=${tier.name}.',
        systemPrompt: systemPrompt,
        jsonMode: true,
        maxTokens: 450,
        timeoutMs: 25000,
        preferArabic: preferArabic,
      );
    } catch (_) {
      return AiChallengeFailure(AiChallengeError(
        reason: AiChallengeErrorReason.network,
        aiToggleEnabled: aiToggleEnabled,
        apiKeyPresent: apiKeyPresent,
      ));
    }

    if (content == null) {
      return AiChallengeFailure(AiChallengeError(
        reason: AiChallengeErrorReason.network,
        aiToggleEnabled: aiToggleEnabled,
        apiKeyPresent: apiKeyPresent,
      ));
    }

    AiChallenge? parsed = _parseGroqChallenge(tier, content);

    if (parsed == null) {
      // One retry on parse failure.
      String? retry;
      try {
        retry = await groq.chatCompletion(
          prompt: 'Regenerate tier=${tier.name} JSON.',
          systemPrompt:
              '$systemPrompt\nYour previous reply was not valid JSON — respond with VALID JSON ONLY.',
          jsonMode: true,
          maxTokens: 450,
          timeoutMs: 5000,
          preferArabic: preferArabic,
        );
      } catch (_) {
        return AiChallengeFailure(AiChallengeError(
          reason: AiChallengeErrorReason.parse,
          aiToggleEnabled: aiToggleEnabled,
          apiKeyPresent: apiKeyPresent,
        ));
      }
      parsed = retry != null ? _parseGroqChallenge(tier, retry) : null;
      if (parsed == null) {
        return AiChallengeFailure(AiChallengeError(
          reason: AiChallengeErrorReason.parse,
          aiToggleEnabled: aiToggleEnabled,
          apiKeyPresent: apiKeyPresent,
        ));
      }
    }

    return AiChallengeSuccess(parsed);
  }

  // ── Auto-refresh (silent, no error propagation) ─────────────────────────────

  Future<void> _autoRefreshTier(AiChallengeTier tier) async {
    final existing = await _challengeRepo.getActiveByTier(tier);
    if (existing != null) return;

    final result = await _fetchFromGroq(tier);
    if (result is AiChallengeFailure) return; // silent skip
    await _challengeRepo.create((result as AiChallengeSuccess).challenge);
  }

  String _buildSystemPrompt(
      AiChallengeTier tier, String thirtyDayBlob, bool preferArabic) {
    final outputLanguage = preferArabic ? 'Arabic' : 'English';
    
    // Tier-specific constraints (ENFORCED)
    final tierRules = {
      AiChallengeTier.daily: {
        'expiresInHours': 24,
        'targetMin': 1,
        'targetMax': 5,
        'example': 'Daily: 1-5 targets achievable within one day. Examples: 30-60 min focus, 1-2 sessions, 1-2 subjects.'
      },
      AiChallengeTier.weekly: {
        'expiresInHours': 168,
        'targetMin': 5,
        'targetMax': 20,
        'example': 'Weekly: 5-20 targets span 7 days. Examples: 300-450 min focus, 5-10 sessions, 3-5 subjects.'
      },
      AiChallengeTier.monthly: {
        'expiresInHours': 720,
        'targetMin': 20,
        'targetMax': 100,
        'example': 'Monthly: 20-100 targets span 30 days. Examples: 1500-2500 min focus, 20-40 sessions, 8+ subjects.'
      },
      AiChallengeTier.surprise: {
        'expiresInHours': 8,
        'targetMin': 1,
        'targetMax': 3,
        'example': 'Surprise: 1-3 tiny targets, 8hr expiry. Quick wins. Examples: 1 session, 15 min, 1 subject.'
      }
    };
    
    final rules = tierRules[tier];
    final tierName = tier.name.toUpperCase();
    
    return '''
You are StudyTracker's adaptive challenge designer. Use the behavioural signals literally.

Student 30-day signal block:
$thirtyDayBlob

Design ONE ${tier.name} challenge. Respond ONLY as valid JSON:
{
  "id": "unique_slug",
  "tier": "${tier.name}",
  "title": "Short enticing title",
  "description": "One imperative sentence tying to data",
  "icon": "material_icon_name",
  "metric": "sessions | minutes | streak | subjects | pomodoros",
  "target": number,
  "expiresInHours": number,
  "difficulty": "easy | medium | hard | extreme",
  "reward": { "badgeName": "string", "badgeIcon": "material_icon_name" },
  "subTargets": { "mode": "any-subjects", "count": number, "minutesPerSubject": number } | null,
  "unitMinMinutes": number | null
}

═══════════════════════════════════════════════════════════════════════════════
TIER CONSTRAINTS ($tierName - MUST FOLLOW):
• expiresInHours: MUST be exactly ${rules!['expiresInHours']}
• target: MUST be in range ${rules['targetMin']}-${rules['targetMax']} (not outside this range)
• difficulty: Scale to tier: daily→easy/medium, weekly→medium/hard, monthly→hard/extreme, surprise→easy
• ${rules['example']}

═══════════════════════════════════════════════════════════════════════════════
METRIC CHOICE (CRITICAL - ALWAYS SET):
• MUST use exactly ONE from: sessions, minutes, streak, subjects, or pomodoros
• Do NOT invent metric names. Do NOT omit metric.
• Examples:
  - "Complete 3 pomodoros": metric = "pomodoros"
  - "Study for 90 minutes": metric = "minutes"
  - "Complete 5 study sessions": metric = "sessions"
  - "Study 7 different days": metric = "streak"
  - "Study exactly 3 topics": metric = "subjects"

MULTI-SUBJECT (subTargets) RULE:
• IF description says "study N DIFFERENT SUBJECTS for M MINUTES each":
  - subTargets = { "mode": "any-subjects", "count": N, "minutesPerSubject": M }
  - metric = "minutes" or "sessions" (NOT "subjects")
  - target = N * M (or nearest tier-appropriate value)
  - EXAMPLE: "Study 3 subjects for 30 min each" → metric: "minutes", target: 90, subTargets: {...}

• IF description says "study X different topics/subjects" (no per-subject duration):
  - metric = "subjects"
  - subTargets = null
  - target = number of subjects (scaled to tier)
  - EXAMPLE: "Explore 5 topics" → metric: "subjects", target: 5, subTargets: null

UNIT MINIMUM RULE:
• IF metric is "pomodoros" or "sessions" AND each must minimum duration:
  - unitMinMinutes = duration floor (e.g., 25)
  - description must say it: "Complete 3 pomodoros of at least 25 minutes each"

═══════════════════════════════════════════════════════════════════════════════
DIFFICULTY ALIGNMENT:
• easy: achievable by most, 30-60% of top performers, low friction
• medium: moderate challenge, requires ~1-2 focused efforts, good engagement
• hard: significant push, requires planning/consistency, high satisfaction
• extreme: ambitious goal, requires peak effort/multiple sessions, high reward

FINAL VALIDATION:
✓ expiresInHours = ${rules['expiresInHours']}
✓ target in range ${rules['targetMin']}-${rules['targetMax']}
✓ metric is one of: sessions, minutes, streak, subjects, pomodoros
✓ If subTargets exists, metric is NOT "subjects"
✓ difficulty aligns with target difficulty
✓ Use $outputLanguage for title, description, and reward.badgeName.
✓ Pure JSON only. No markdown. No explanation text.
''';
  }

  // ── Parse & coerce ───────────────────────────────────────────────────────────

  AiChallenge? _parseGroqChallenge(AiChallengeTier tier, String? content) {
    if (content == null || content.trim().isEmpty) return null;

    final Map<String, dynamic>? parsedMap = () {
      try {
        return jsonDecode(content) as Map<String, dynamic>;
      } catch (_) {
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
        if (jsonMatch == null) return null;
        try {
          return jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        } catch (_) {
          return null;
        }
      }
    }();
    if (parsedMap == null) return null;

    try {
      final now = DateTime.now();
      final rawMetricStr = (parsedMap['metric'] as String?) ?? 'sessions';
      final parsedMetric = AiChallengeMetric.fromDb(rawMetricStr);
      
      // Log if metric was missing or not in the valid list
      if (!['sessions', 'minutes', 'streak', 'subjects', 'pomodoros'].contains(rawMetricStr)) {
        debugPrint(
          '[AI Challenge] Groq sent invalid metric: "$rawMetricStr". '
          'Valid: sessions, minutes, streak, subjects, pomodoros. Defaulting to "${parsedMetric.name}".'
        );
      }
      
      final parsedDifficulty =
          AiChallengeDifficulty.fromDb((parsedMap['difficulty'] as String?) ?? 'easy');
      final rawTarget = (parsedMap['target'] as num?)?.toInt() ?? 1;
      final rawExpiresIn = (parsedMap['expiresInHours'] as num?)?.toInt() ?? 24;
      final safeTarget = _clampTarget(tier, parsedMetric, rawTarget);
      final safeExpiresIn = _clampExpiresHours(tier, rawExpiresIn);

      // Parse optional subTargets.
      AiMissionSubTargets? subTargets;
      final rawSub = parsedMap['subTargets'];
      if (rawSub is Map<String, dynamic>) {
        final mode = rawSub['mode'] as String?;
        final count = (rawSub['count'] as num?)?.toInt();
        if (mode != null && count != null) {
          subTargets = AiMissionSubTargets(
            mode: mode,
            count: count,
            minutesPerSubject: (rawSub['minutesPerSubject'] as num?)?.toInt(),
          );
        }
      }

      final rawUnit = parsedMap['unitMinMinutes'];
      final unitMinMinutes =
          rawUnit is num && rawUnit.toInt() > 0 ? rawUnit.toInt() : null;

      return AiChallenge(
        id: (parsedMap['id'] as String?) ?? '${tier.name}_${now.millisecondsSinceEpoch}',
        tier: tier,
        title: (parsedMap['title'] as String?) ?? 'Study Challenge',
        description: (parsedMap['description'] as String?) ?? 'Complete your mission.',
        icon: (parsedMap['icon'] as String?) ?? 'flag',
        metric: parsedMetric,
        target: safeTarget,
        expiresAt: now.add(Duration(hours: safeExpiresIn)),
        difficulty: parsedDifficulty,
        rewardBadgeName:
            ((parsedMap['reward'] as Map?)?['badgeName'] as String?) ?? 'Challenge Winner',
        rewardBadgeIcon:
            ((parsedMap['reward'] as Map?)?['badgeIcon'] as String?) ?? 'emoji_events',
        rawResponse: content,
        subTargets: subTargets,
        unitMinMinutes: unitMinMinutes,
        status: AiChallengeStatus.active,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Utilities ────────────────────────────────────────────────────────────────

  bool _shouldRefresh(String? lastFetchIso, DateTime now, int hoursThreshold) {
    if (lastFetchIso == null || lastFetchIso.isEmpty) return true;
    final last = DateTime.tryParse(lastFetchIso);
    if (last == null) return true;
    return now.difference(last).inHours >= hoursThreshold;
  }

  List<int> _boundsFor(AiChallengeTier tier, AiChallengeMetric metric) {
    return _targetBounds['${tier.name}:${metric.name}'] ?? const [1, 1000];
  }

  int _clampTarget(AiChallengeTier tier, AiChallengeMetric metric, int rawTarget) {
    final bounds = _boundsFor(tier, metric);
    return rawTarget.clamp(bounds[0], bounds[1]);
  }

  int _clampExpiresHours(AiChallengeTier tier, int rawHours) {
    final bounds = _expiresHoursBounds[tier] ?? const [8, 48];
    return rawHours.clamp(bounds[0], bounds[1]);
  }

  Future<bool> _isSmartChallengesEnabled() async {
    try {
      final row = await _aiFeatureRepo.getSettings();
      final v = row?['smart_challenges_enabled'];
      if (v == null) return false;
      if (v is bool) return v;
      if (v is int) return v != 0;
      if (v is String) {
        final s = v.toLowerCase();
        return s == 'true' || s == '1';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<String> _build30DayWeakSpotSummary() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final last30 = await _sessionRepo.list(
        SessionFilter(startFrom: thirtyDaysAgo, limit: 5000),
      );

      if (last30.isEmpty) return 'No sessions in the last 30 days yet.';

      final subjectStats = <String, (int count, int totalMinutes, List<String> moods)>{};
      for (final session in last30) {
        final subject = session.subjectName?.trim().isNotEmpty == true
            ? session.subjectName!.trim()
            : 'Unknown';
        final current = subjectStats[subject] ?? (0, 0, <String>[]);
        final mood = session.mood ?? 'neutral';
        subjectStats[subject] = (
          current.$1 + 1,
          current.$2 + session.durationMinutes,
          [...current.$3, mood],
        );
      }

      final sortedByCount = subjectStats.entries.toList()
        ..sort((a, b) => a.value.$1.compareTo(b.value.$1));

      final hardestSubject = sortedByCount.first.key;
      final mostSubject = sortedByCount.last.key;

      final avgDuration =
          (last30.fold<int>(0, (sum, s) => sum + s.durationMinutes) / last30.length)
              .toStringAsFixed(0);

      final moodCounts = <String, int>{};
      for (final session in last30) {
        final m = session.mood ?? 'neutral';
        moodCounts[m] = (moodCounts[m] ?? 0) + 1;
      }
      final topMood =
          moodCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

      final afterEightCount = last30.where((s) => s.startAt.hour >= 20).length;

      final modeCounts = <String, int>{};
      for (final session in last30) {
        final mode = session.mode.name;
        modeCounts[mode] = (modeCounts[mode] ?? 0) + 1;
      }
      final preferredMode =
          modeCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

      final streakDays = await _sessionRepo.getCurrentStreak();

      return '''
- Least-sessions subject: $hardestSubject (${sortedByCount.first.value.$1} sessions)
- Most-sessions subject: $mostSubject (${sortedByCount.last.value.$1} sessions)
- Avg session duration: $avgDuration minutes (n=${last30.length})
- Dominant mood tag: $topMood
- Sessions starting at or after 20:00 local: $afterEightCount
- Preferred session mode: $preferredMode
- Current streak (days with a session): $streakDays
''';
    } catch (_) {
      return 'Could not analyze recent patterns.';
    }
  }
}

final aiChallengeServiceProvider = Provider<AiChallengeService>((ref) {
  return AiChallengeService(
    ref.watch(aiChallengeRepositoryProvider),
    ref.watch(sessionRepositoryProvider),
    ref.watch(settingsRepositoryProvider),
    ref.watch(aiFeatureSettingsRepositoryProvider),
    ref.watch(aiChallengeHistoryRepositoryProvider),
  );
});
