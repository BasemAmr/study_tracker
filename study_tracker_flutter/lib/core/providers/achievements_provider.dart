import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/ai_challenge_service.dart';
import '../../data/repositories/ai_challenge_repository.dart';
import '../../data/repositories/ai_challenge_history_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/repositories/settings_repository.dart';
import 'settings_provider.dart';
import '../../domain/domain.dart';
import '../../features/achievements/award_definitions.dart';

enum AchievementTab { awards, missions }

enum BadgeStatus { unlocked, inProgress, locked }

enum BadgeCategory { daily, weekly, monthly, statusAndTiers, secret }

class BadgeDef {
  final String id;
  final String title;
  final String description;
  final String icon;
  final BadgeCategory category;
  final BadgeStatus status;
  final int progress;
  final String requirementLabel;
  final String? unlockedDate;
  final String? tier;
  final bool repeatable;
  final int? completions;

  const BadgeDef({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.status,
    required this.progress,
    required this.requirementLabel,
    this.unlockedDate,
    this.tier,
    this.repeatable = false,
    this.completions,
  });
}

class AiMissionView {
  final AiChallenge challenge;
  final AiChallengeProgress progress;

  const AiMissionView({required this.challenge, required this.progress});
}

class AchievementsProvider extends ChangeNotifier {
  static const int _xpPerLevel = 300;
  static const Map<String, int> _awardXpById = {
    'daily_starter': 12,
    'deep_work_daily': 18,
    'sprint_daily': 25,
    'pomo_5_daily': 28,
    'midnight_oil': 14,
    'early_riser': 14,
    'subject_explorer': 18,
    'no_zero_day': 8,
    'task_finisher': 16,
    'perfect_week': 45,
    'weekend_warrior': 28,
    'time_investor_weekly': 52,
    'monthly_master': 95,
    'forty_hour_club': 100,
    'sessions_bronze': 130,
    'sessions_silver': 190,
    'sessions_gold': 250,
    'sessions_legend': 340,
    'hours_bronze': 140,
    'streak_week': 90,
    'phoenix': 40,
    'triple_threat': 55,
    'overkill': 65,
  };

  final SessionRepository _sessionRepo;
  final AiChallengeRepository _challengeRepo;
  final AiChallengeHistoryRepository _historyRepo;
  final AiChallengeService _aiService;
  final SettingsRepository _settingsRepo;
  StreamSubscription<List<StudySession>>? _sessionsSubscription;
  StreamSubscription<List<AiChallenge>>? _challengesSubscription;
  Timer? _refreshDebounce;
  bool _needsChallengeRefresh = false;
  bool _disposed = false;

  AchievementsProvider(
    this._sessionRepo,
    this._challengeRepo,
    this._historyRepo,
    this._aiService,
    this._settingsRepo,
  ) {
    _sessionsSubscription = _sessionRepo.watchAllSessions().listen((_) {
      _scheduleRefresh(refreshChallenges: false);
    });
    _challengesSubscription = _challengeRepo.watchAll().listen((_) {
      _scheduleRefresh(refreshChallenges: false);
    });
  }

  AchievementTab _activeTab = AchievementTab.awards;
  AchievementTab get activeTab => _activeTab;

  BadgeCategory _activeCategory = BadgeCategory.daily;
  BadgeCategory get activeCategory => _activeCategory;

  bool isLoading = false;
  bool isRefreshingMissions = false;
  String? error;

  List<BadgeDef> badges = const [];
  List<AiMissionView> missions = const [];
  List<AiMissionView> completedMissions = const [];
  String? activePinnedMissionId;

  /// Per-tier slot error (empty mission + Try again).
  Map<AiChallengeTier, AiChallengeError?> tierFailures = const {};

  List<AiChallengeHistoryEntry> missionHistory = const [];
  bool pastMissionsExpanded = false;

  /// Latest active row per tier (may be time-expired but still `status=active`).
  List<AiChallenge> slotChallenges = const [];

  AiChallenge? slotForTier(AiChallengeTier tier) {
    try {
      return slotChallenges.firstWhere((c) => c.tier == tier);
    } catch (_) {
      return null;
    }
  }

  void setPastMissionsExpanded(bool v) {
    pastMissionsExpanded = v;
    notifyListeners();
  }

  /// T5: run when AI Missions tab becomes visible; returns toast lines for API failures.
  Future<List<String>> onAiMissionsTabOpened() async {
    final lines = await _aiService.processExpiredMissionsOnTabOpen();
    await fetchDataWithOptions(refreshChallenges: false, showGlobalLoading: false);
    return lines;
  }

  String currentRank = 'Novice';
  int currentLevel = 1;
  int currentXp = 0;
  int nextLevelXp = _xpPerLevel;

  bool aiEnabled = false;
  bool hasApiKey = false;

  String? missionActionError;

  int get unlockedCount => badges.where((b) => b.status == BadgeStatus.unlocked).length;
  int get inProgressCount => badges.where((b) => b.status == BadgeStatus.inProgress).length;
  int get lockedCount => badges.where((b) => b.status == BadgeStatus.locked).length;
  int get totalBadges => badges.length;
  int get xpPerLevel => _xpPerLevel;
  int get currentLevelStartXp => (currentLevel - 1) * _xpPerLevel;
  int get xpIntoCurrentLevel => (currentXp - currentLevelStartXp).clamp(0, _xpPerLevel);
  int get xpToNextLevel => (nextLevelXp - currentXp).clamp(0, 1 << 30);
  double get levelProgress => _xpPerLevel <= 0 ? 0.0 : xpIntoCurrentLevel / _xpPerLevel;

  List<BadgeDef> get filteredBadges => badges.where((b) => b.category == _activeCategory).toList();

  void setTab(AchievementTab tab) {
    _activeTab = tab;
    notifyListeners();
  }

  void setCategory(BadgeCategory category) {
    _activeCategory = category;
    notifyListeners();
  }

  Future<void> fetchData() async {
    return fetchDataWithOptions(refreshChallenges: true);
  }

  Future<void> fetchDataWithOptions({
    required bool refreshChallenges,
    bool showGlobalLoading = true,
  }) async {
    if (showGlobalLoading) {
      isLoading = true;
      error = null;
      if (!_disposed) {
        notifyListeners();
      }
    }

    try {
      final settings = await _settingsRepo.getStructured();
      aiEnabled = settings.aiChallengesEnabled;
      final key = settings.groqApiKey?.trim() ?? '';
      hasApiKey = key.startsWith('gsk_') || (key.startsWith('sk-') && !key.startsWith('sk-xxxx'));

      if (refreshChallenges) {
        await _aiService.checkAndRefreshChallenges();
      }

      final allSessions = await _sessionRepo.getAll();
      badges = await _buildBadges(allSessions);

      final allChallenges = await _challengeRepo.getAll();
      final awardBonusXp = _calculateAwardBonusXp(badges);
      final challengeBonusXp = _calculateCompletedMissionXp(allChallenges);

      currentXp = allSessions.fold(0, (sum, s) => sum + s.durationMinutes) + awardBonusXp + challengeBonusXp;
      currentLevel = (currentXp ~/ _xpPerLevel) + 1;
      nextLevelXp = currentLevel * _xpPerLevel;
      currentRank = _rankFromXp(currentXp);

      final slotList = <AiChallenge>[];
      for (final tier in AiChallengeTier.values) {
        final row = allChallenges.where((c) {
          return c.tier == tier &&
              !c.completed &&
              c.status == AiChallengeStatus.active;
        }).toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        if (row.isNotEmpty) slotList.add(row.first);
      }
      slotChallenges = slotList;
      missions = await _mapMissionViews(slotList);

      final tf = <AiChallengeTier, AiChallengeError?>{};
      for (final t in AiChallengeTier.values) {
        tf[t] = await _aiService.getTierFailure(t);
      }
      tierFailures = tf;

      final hist = <AiChallengeHistoryEntry>[];
      for (final t in AiChallengeTier.values) {
        hist.addAll(await _historyRepo.getRecent(t, limit: 50));
      }
      hist.sort((a, b) => b.closedAt.compareTo(a.closedAt));
      missionHistory = hist;

      final done = allChallenges.where((c) => c.completed).toList();
      completedMissions = await _mapMissionViews(done);

      activePinnedMissionId = await _aiService.getActiveAiMissionId();
    } catch (e) {
      error = e.toString();
    } finally {
      if (showGlobalLoading) {
        isLoading = false;
      }
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  void _scheduleRefresh({required bool refreshChallenges}) {
    if (_disposed) return;
    _needsChallengeRefresh = _needsChallengeRefresh || refreshChallenges;
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 160), () async {
      if (_disposed) return;
      final shouldRefreshChallenges = _needsChallengeRefresh;
      _needsChallengeRefresh = false;
      await fetchDataWithOptions(refreshChallenges: shouldRefreshChallenges, showGlobalLoading: true);
    });
  }

  Future<void> refreshAiMissions() async {
    if (isRefreshingMissions) return;
    isRefreshingMissions = true;
    notifyListeners();

    try {
      debugPrint('[Achievements] Refresh surprise-only requested');
      final result = await _aiService.refreshTierNow(AiChallengeTier.surprise);
      if (result is AiChallengeFailure) {
        missionActionError = formatAiChallengeErrorToast(result.error);
      } else {
        missionActionError = null;
      }
      await fetchDataWithOptions(refreshChallenges: false, showGlobalLoading: false);
    } finally {
      isRefreshingMissions = false;
      notifyListeners();
    }
  }

  Future<void> refreshMissionTier(AiChallengeTier tier) async {
    if (isRefreshingMissions) return;
    isRefreshingMissions = true;
    notifyListeners();

    try {
      debugPrint('[Achievements] Refresh tier requested: ${tier.name}');
      final result = await _aiService.refreshTierNow(tier);
      if (result is AiChallengeFailure) {
        missionActionError = formatAiChallengeErrorToast(result.error);
      } else {
        missionActionError = null;
      }
      await fetchDataWithOptions(refreshChallenges: false, showGlobalLoading: false);
    } finally {
      isRefreshingMissions = false;
      notifyListeners();
    }
  }

  Future<void> togglePin(String missionId) async {
    if (activePinnedMissionId == missionId) {
      await _aiService.clearActiveAiMissionId();
      activePinnedMissionId = null;
    } else {
      await _aiService.setActiveAiMissionId(missionId);
      activePinnedMissionId = missionId;
    }
    notifyListeners();
  }

  Future<List<AiMissionView>> _mapMissionViews(List<AiChallenge> source) async {
    final result = <AiMissionView>[];
    for (final challenge in source) {
      final progress = await _aiService.calculateProgress(challenge);
      result.add(AiMissionView(challenge: challenge, progress: progress));
    }
    return result;
  }

  Future<List<BadgeDef>> _buildBadges(List<StudySession> sessions) async {
    final built = <BadgeDef>[];
    for (final def in awardDefinitions) {
      final result = def.check(sessions);
      final persistedUnlock = await _resolveUnlockDate(def.id, null, result.unlocked);
      built.add(
        BadgeDef(
          id: def.id,
          title: def.title,
          description: def.description,
          icon: def.icon,
          category: _mapCategory(def.category),
          status: result.unlocked
              ? BadgeStatus.unlocked
              : (result.progress > 0 ? BadgeStatus.inProgress : BadgeStatus.locked),
          progress: (result.progress * 100).round().clamp(0, 100),
          requirementLabel: '${(result.progress * 100).round()}%',
          unlockedDate: persistedUnlock?.toIso8601String().split('T').first,
          tier: def.tier?.name,
          repeatable: def.repeatable,
          completions: result.completions,
        ),
      );
    }
    return built;
  }

  BadgeCategory _mapCategory(AwardCategory category) {
    switch (category) {
      case AwardCategory.daily:
        return BadgeCategory.daily;
      case AwardCategory.weekly:
        return BadgeCategory.weekly;
      case AwardCategory.monthly:
        return BadgeCategory.monthly;
      case AwardCategory.allTime:
        return BadgeCategory.statusAndTiers;
      case AwardCategory.secret:
        return BadgeCategory.secret;
    }
  }

  Future<DateTime?> _resolveUnlockDate(String id, DateTime? candidate, bool unlocked) async {
    // Keys are profile-scoped so creating a new profile starts XP from zero.
    final profileId = await _settingsRepo.getCurrentProfileId();
    final key = 'achievement.unlock.$profileId.$id';
    final stored = await _settingsRepo.get(key);
    final storedDate = DateTime.tryParse(stored ?? '');
    if (storedDate != null) return storedDate;

    if (!unlocked) return null;

    final value = candidate ?? DateTime.now();
    await _settingsRepo.set(key, value.toIso8601String());
    return value;
  }

  String _rankFromXp(int xp) {
    if (xp >= 20000) return 'Master';
    if (xp >= 10000) return 'Scholar';
    if (xp >= 5000) return 'Adept';
    if (xp >= 2000) return 'Learner';
    return 'Novice';
  }

  int _calculateAwardBonusXp(List<BadgeDef> source) {
    var total = 0;
    for (final badge in source) {
      // Unlock date persists once, so this grants each award XP exactly once.
      if (badge.unlockedDate == null) continue;
      total += _awardXpById[badge.id] ?? 10;
    }
    return total;
  }

  int _calculateCompletedMissionXp(List<AiChallenge> source) {
    var total = 0;
    for (final challenge in source) {
      if (!challenge.completed) continue;
      total += _aiService.xpForCompletedChallenge(challenge);
    }
    return total;
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshDebounce?.cancel();
    _sessionsSubscription?.cancel();
    _challengesSubscription?.cancel();
    super.dispose();
  }
}

final achievementsProvider = ChangeNotifierProvider<AchievementsProvider>((ref) {
  ref.watch(settingsProvider.select((s) => s.currentProfileId));
  ref.watch(settingsProvider.select((s) => s.settings.groqApiKey));
  ref.watch(settingsProvider.select((s) => s.settings.aiChallengesEnabled));
  return AchievementsProvider(
    ref.watch(sessionRepositoryProvider),
    ref.watch(aiChallengeRepositoryProvider),
    ref.watch(aiChallengeHistoryRepositoryProvider),
    ref.watch(aiChallengeServiceProvider),
    ref.watch(settingsRepositoryProvider),
  )..fetchDataWithOptions(refreshChallenges: true);
});
