import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/achievements_provider.dart';
import '../../../core/services/ai_challenge_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/icon_resolver.dart';
import '../../../domain/domain.dart';
import '../../../l10n/app_localizations.dart';

class _MissionExpiryLines {
  final String primary;
  final String secondary;
  final bool emphasizeHour;
  const _MissionExpiryLines({
    required this.primary,
    required this.secondary,
    required this.emphasizeHour,
  });
}

_MissionExpiryLines _formatMissionExpiry(DateTime expiresAt, AiChallengeTier tier) {
  final now = DateTime.now();
  final ms = expiresAt.difference(now).inMilliseconds;
  final isSurprise = tier == AiChallengeTier.surprise;
  final timeStr =
      '${expiresAt.hour.toString().padLeft(2, '0')}:${expiresAt.minute.toString().padLeft(2, '0')}';
  if (ms <= 0) {
    return _MissionExpiryLines(
      primary: 'Expired',
      secondary: 'Was due at $timeStr',
      emphasizeHour: isSurprise,
    );
  }
  final totalM = (ms / 60000).ceil();
  final d = totalM ~/ (60 * 24);
  final h = (totalM % (60 * 24)) ~/ 60;
  final m = totalM % 60;
  final today = DateTime(now.year, now.month, now.day);
  final expDay = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);
  final sameDay = today == expDay;

  final primary = d > 0 ? '${d}d ${h}h left' : '${h}h ${m}m left';
  final secondary =
      sameDay ? 'expires $timeStr today' : 'expires at $timeStr';

  return _MissionExpiryLines(
    primary: primary,
    secondary: secondary,
    emphasizeHour: isSurprise,
  );
}

String _historyProgressLabel(AiChallengeMetric metric, int progress, int target) {
  switch (metric) {
    case AiChallengeMetric.minutes:
      return 'progress $progress/$target minutes';
    case AiChallengeMetric.sessions:
      return 'progress $progress/$target sessions';
    case AiChallengeMetric.pomodoros:
      return 'progress $progress/$target pomodoros';
    case AiChallengeMetric.subjects:
      return 'progress $progress/$target subjects';
    case AiChallengeMetric.streak:
      return 'progress $progress/$target streak days';
  }
}

class AiMissionsView extends ConsumerWidget {
  const AiMissionsView({super.key});

  Future<void> _confirmAndRefreshTier(
    BuildContext context,
    WidgetRef ref,
    AiChallengeTier tier, {
    required bool isExpired,
  }) async {
    final msg = isExpired
        ? 'This mission expired. Refreshing replaces it and starts progress from zero. Continue?'
        : 'Refreshing will start progress from zero. Continue?';
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Refresh mission'),
            content: Text(msg),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
            ],
          ),
        ) ??
        false;
    if (!ok || !context.mounted) return;

    await ref.read(achievementsProvider).refreshMissionTier(tier);
    if (!context.mounted) return;
    final err = ref.read(achievementsProvider).missionActionError;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.achievementsMissionRefreshed(_tierLabel(tier, AppLocalizations.of(context)!))),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _refreshSurpriseOnly(BuildContext context, WidgetRef ref) async {
    await ref.read(achievementsProvider).refreshAiMissions();
    if (!context.mounted) return;
    final err = ref.read(achievementsProvider).missionActionError;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final provider = ref.watch(achievementsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l10n.achievementsCurrentMissions, style: AppTypography.textTheme.headlineMedium),
            FilledButton.icon(
              onPressed: provider.isRefreshingMissions ? null : () => _refreshSurpriseOnly(context, ref),
              icon: provider.isRefreshingMissions
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              label: Text(l10n.achievementsRefreshSurprise),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.outline, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: provider.hasApiKey ? AppColors.surfaceContainer : AppColors.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.outline, width: 2),
          ),
          child: Text(
            provider.hasApiKey ? l10n.achievementsGroqDetected : l10n.achievementsNoGroq,
            style: AppTypography.textTheme.labelSmall?.copyWith(
              color: provider.hasApiKey ? AppColors.primary : AppColors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final tier in AiChallengeTier.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _tierSlot(context, ref, tier),
          ),
        const SizedBox(height: 8),
        Text(l10n.achievementsCompletedChallenges, style: AppTypography.textTheme.headlineSmall),
        const SizedBox(height: 8),
        if (provider.completedMissions.isEmpty)
          _emptyState(l10n.achievementsNoCompletedMissions)
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: provider.completedMissions.map((m) {
              return Container(
                width: 108,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.outline, width: 2),
                  boxShadow: const [BoxShadow(color: AppColors.outline, offset: Offset(0, 2))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.secondary, width: 2),
                        color: AppColors.secondaryContainer,
                      ),
                      child: Icon(iconFromName(m.challenge.rewardBadgeIcon), color: AppColors.secondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _localizedRewardName(context, m.challenge.rewardBadgeName),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 20),
        _pastMissionsSection(context, ref, provider),
      ],
    );
  }

  Widget _tierSlot(BuildContext context, WidgetRef ref, AiChallengeTier tier) {
    final l10n = AppLocalizations.of(context)!;
    final provider = ref.watch(achievementsProvider);
    final challenge = provider.slotForTier(tier);
    final failure = provider.tierFailures[tier];
    AiMissionView? view;
    for (final m in provider.missions) {
      if (m.challenge.tier == tier) {
        view = m;
        break;
      }
    }

    if (challenge == null && failure != null) {
      return _failureSlot(context, ref, tier, failure, l10n);
    }
    if (challenge == null) {
      return _emptySlot(context, ref, tier, l10n);
    }
    if (view == null) {
      return _emptySlot(context, ref, tier, l10n);
    }

    final now = DateTime.now();
    final timeExpired = challenge.expiresAt.isBefore(now);

    return Stack(
      children: [
        _missionCard(context, ref, view, provider.isRefreshingMissions, tier, l10n),
        if (timeExpired)
          Positioned.fill(
            child: Material(
              color: Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Expired', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: provider.isRefreshingMissions
                        ? null
                        : () => _confirmAndRefreshTier(
                              context,
                              ref,
                              tier,
                              isExpired: true,
                            ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _failureSlot(
    BuildContext context,
    WidgetRef ref,
    AiChallengeTier tier,
    AiChallengeError failure,
    AppLocalizations l10n,
  ) {
    final provider = ref.watch(achievementsProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_tierLabel(tier, l10n)} · empty slot',
            style: AppTypography.textTheme.labelSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Could not load a new mission. ${formatAiChallengeErrorToast(failure)}',
            style: AppTypography.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: provider.isRefreshingMissions
                ? null
                : () => _confirmAndRefreshTier(context, ref, tier, isExpired: false),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _emptySlot(BuildContext context, WidgetRef ref, AiChallengeTier tier, AppLocalizations l10n) {
    final provider = ref.watch(achievementsProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.5), width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '${_tierLabel(tier, l10n)} — no active mission',
              style: AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
          IconButton(
            icon: provider.isRefreshingMissions
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh, size: 18),
            onPressed: provider.isRefreshingMissions
                ? null
                : () => _confirmAndRefreshTier(context, ref, tier, isExpired: false),
            tooltip: 'Refresh mission',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _pastMissionsSection(BuildContext context, WidgetRef ref, AchievementsProvider provider) {
    if (provider.missionHistory.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.outline, width: 2),
      ),
      child: ExpansionTile(
        initiallyExpanded: provider.pastMissionsExpanded,
        onExpansionChanged: provider.setPastMissionsExpanded,
        title: Text(
          'Past Missions (${provider.missionHistory.length})',
          style: AppTypography.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: provider.missionHistory.map((e) => _historyRow(context, e)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyRow(BuildContext context, AiChallengeHistoryEntry e) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.outline, width: 1),
            ),
            child: Text(
              e.tier.name,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title, style: AppTypography.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text(
                  '${_historyProgressLabel(e.metric, e.progressAtClose, e.target)} · ${e.closedAt.split('T').first}',
                  style: AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Chip(
            label: Text(e.closeReason.name, style: const TextStyle(fontSize: 10)),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _missionCard(
    BuildContext context,
    WidgetRef ref,
    AiMissionView mission,
    bool isRefreshing,
    AiChallengeTier tier,
    AppLocalizations l10n,
  ) {
    final provider = ref.watch(achievementsProvider);
    final c = mission.challenge;
    final p = mission.progress;
    final isPinned = provider.activePinnedMissionId == c.id;
    final expiry = _formatMissionExpiry(c.expiresAt, tier);
    final sub = c.subTargets;
    final showMulti = sub != null && sub.mode == 'any-subjects' && (p.subjectBreakdown?.isNotEmpty ?? false);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
          color: isPinned ? AppColors.primary : AppColors.outline,
          width: isPinned ? 2.5 : 2,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: AppColors.outline, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.outline, width: 2),
                ),
                child: Icon(iconFromName(c.icon), color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isPinned) ...[
                          const Icon(Icons.push_pin, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            _localizedMissionTitle(context, c.title),
                            style: AppTypography.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${_tierLabel(c.tier, l10n)} · ${_difficultyLabel(c.difficulty, l10n)}',
                      style: AppTypography.textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 18,
                  color: isPinned ? AppColors.primary : AppColors.onSurfaceVariant,
                ),
                onPressed: isRefreshing ? null : () => provider.togglePin(c.id),
                tooltip: isPinned ? 'Unpin mission' : 'Set as active mission',
              ),
              if (tier != AiChallengeTier.surprise)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: isRefreshing
                      ? null
                      : () => _confirmAndRefreshTier(context, ref, tier, isExpired: c.expiresAt.isBefore(DateTime.now())),
                  tooltip: l10n.achievementsRefreshThisMission,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expiry.primary,
                      style: expiry.emphasizeHour
                          ? AppTypography.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            )
                          : AppTypography.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      expiry.secondary,
                      style: AppTypography.textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(_localizedMissionDescription(context, c)),
          const SizedBox(height: 12),
          if (showMulti) ...[
            for (final row in p.subjectBreakdown!)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            row.subjectName ?? 'Subject ${row.subjectId}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.textTheme.labelSmall,
                          ),
                        ),
                        Text(
                          '${row.minutes}/${sub.minutesPerSubject ?? 1} min',
                          style: AppTypography.textTheme.labelSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: ((sub.minutesPerSubject ?? 1) <= 0
                              ? 0.0
                              : (row.minutes / (sub.minutesPerSubject ?? 1)))
                          .clamp(0.0, 1.0),
                      minHeight: 6,
                      color: row.completed ? AppColors.secondary : AppColors.primary,
                      backgroundColor: const Color(0x335A7A5A),
                    ),
                  ],
                ),
              ),
            Text(
              '${p.current} of ${sub.count} subjects complete',
              style: AppTypography.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: (p.percent / 100).clamp(0.0, 1.0),
              minHeight: 10,
              color: AppColors.primary,
              backgroundColor: const Color(0x335A7A5A),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.achievementsProgress, style: AppTypography.textTheme.labelSmall),
                Text(
                  '${p.current}/${p.target} ${_metricLabel(c.metric, l10n)} · ${p.percent}%',
                  style: AppTypography.textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: (p.percent / 100).clamp(0.0, 1.0),
              minHeight: 10,
              color: AppColors.primary,
              backgroundColor: const Color(0x335A7A5A),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            l10n.achievementsReward(_localizedRewardName(context, c.rewardBadgeName)),
            style: AppTypography.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline, width: 2),
      ),
      child: Text(text, style: AppTypography.textTheme.bodySmall),
    );
  }

  String _tierLabel(AiChallengeTier tier, AppLocalizations l10n) {
    switch (tier) {
      case AiChallengeTier.daily:
        return l10n.achievementsTierDaily;
      case AiChallengeTier.weekly:
        return l10n.achievementsTierWeekly;
      case AiChallengeTier.monthly:
        return l10n.achievementsTierMonthly;
      case AiChallengeTier.surprise:
        return l10n.achievementsTierSurprise;
    }
  }

  String _difficultyLabel(AiChallengeDifficulty difficulty, AppLocalizations l10n) {
    switch (difficulty) {
      case AiChallengeDifficulty.easy:
        return l10n.achievementsDifficultyEasy;
      case AiChallengeDifficulty.medium:
        return l10n.achievementsDifficultyMedium;
      case AiChallengeDifficulty.hard:
        return l10n.achievementsDifficultyHard;
      case AiChallengeDifficulty.extreme:
        return l10n.achievementsDifficultyExtreme;
    }
  }

  String _metricLabel(AiChallengeMetric metric, AppLocalizations l10n) {
    switch (metric) {
      case AiChallengeMetric.sessions:
        return l10n.achievementsMetricSessions;
      case AiChallengeMetric.minutes:
        return l10n.achievementsMetricMinutes;
      case AiChallengeMetric.streak:
        return l10n.achievementsMetricStreak;
      case AiChallengeMetric.subjects:
        return l10n.achievementsMetricSubjects;
      case AiChallengeMetric.pomodoros:
        return l10n.achievementsMetricPomodoros;
    }
  }

  bool _isArabic(BuildContext context) {
    return Localizations.localeOf(context).languageCode.toLowerCase().startsWith('ar');
  }

  String _localizedMissionTitle(BuildContext context, String title) {
    if (!_isArabic(context)) return title;
    const map = {
      'Daily Momentum': 'زخم اليوم',
      'Focused Double': 'تركيز مزدوج',
      'Weekly Deep Work': 'عمل عميق أسبوعي',
      'Seven-Day Rhythm': 'إيقاع سبعة أيام',
      'Subject Explorer': 'مستكشف المواد',
      'Marathon Minutes': 'دقائق الماراثون',
      'Consistency Architect': 'مهندس الاستمرارية',
      'Surprise Sprint': 'اندفاعة مفاجئة',
      'Lightning Focus': 'تركيز خاطف',
      'Focus Ladder': 'سلم التركيز',
      'Pomodoro Pulse': 'نبض البومودورو',
      'Subject Switch': 'تنويع المواد',
      'No Zero Day': 'لا يوم صفري',
      'Session Builder': 'بناء الجلسات',
      'Pomodoro Grid': 'شبكة البومودورو',
      'Active Days Arc': 'قوس الأيام النشطة',
      'Subject Constellation': 'كوكبة المواد',
      'Pomodoro Marathon': 'ماراثون البومودورو',
      'Focus Burst': 'دفعة تركيز',
      'Rapid Relay': 'تناوب سريع',
      'Topic Shuffle': 'تبديل المواضيع',
      'Micro Streak': 'سلسلة قصيرة',
    };
    return map[title] ?? title;
  }

  String _localizedMissionDescription(BuildContext context, AiChallenge challenge) {
    if (!_isArabic(context)) return challenge.description;
    const known = {
      'Complete 2 sessions today to keep your streak alive.': 'أنهِ جلستين اليوم للحفاظ على سلسلة الاستمرارية.',
      'Log two focused blocks before day end.': 'سجّل فترتي تركيز قبل نهاية اليوم.',
      'Reach a focused-minute target before the day ends.': 'حقق هدف دقائق التركيز قبل نهاية اليوم.',
      'Complete a pomodoro chain today.': 'أكمل سلسلة بومودورو اليوم.',
      'Study at least two different subjects today.': 'ادرس مادتين مختلفتين على الأقل اليوم.',
      'Log at least one focused minute before midnight.': 'سجّل دقيقة تركيز واحدة على الأقل قبل منتصف الليل.',
      'Accumulate focused minutes across the week.': 'اجمع دقائق تركيز عبر الأسبوع.',
      'Accumulate a healthy number of sessions this week.': 'اجمع عددًا جيدًا من الجلسات هذا الأسبوع.',
      'Study on at least 5 different days this week.': 'ادرس في 5 أيام مختلفة على الأقل هذا الأسبوع.',
      'Complete a structured pomodoro count this week.': 'أكمل عدد بومودورو منظم هذا الأسبوع.',
      'Study multiple subjects this month for breadth.': 'ادرس عدة مواد هذا الشهر لتوسيع التغطية.',
      'Reach a high monthly minute total with steady pacing.': 'حقق مجموع دقائق شهري مرتفع بوتيرة ثابتة.',
      'Log study activity on many days this month.': 'سجّل نشاطًا دراسيًا في أيام كثيرة هذا الشهر.',
      'Build momentum by studying across many days this month.': 'ابنِ الزخم بالدراسة عبر أيام كثيرة هذا الشهر.',
      'Reach an ambitious pomodoro count this month.': 'حقق عدد بومودورو طموح هذا الشهر.',
      'Complete one pomodoro sprint in the next hours.': 'أكمل جولة بومودورو واحدة خلال الساعات القادمة.',
      'Complete a focused-minute burst before this challenge expires.': 'أكمل دفعة دقائق تركيز قبل انتهاء هذا التحدي.',
      'Complete two sessions in a short challenge window.': 'أكمل جلستين ضمن نافذة تحدٍ قصيرة.',
      'Touch two different subjects before the timer runs out.': 'غطِّ مادتين مختلفتين قبل انتهاء المؤقت.',
      'Log study on two consecutive days starting now.': 'سجّل دراسة في يومين متتاليين بدءًا من الآن.',
    };
    final translated = known[challenge.description];
    if (translated != null) return translated;
    switch (challenge.metric) {
      case AiChallengeMetric.minutes:
        return 'اجمع ${challenge.target} دقيقة تركيز قبل انتهاء التحدي.';
      case AiChallengeMetric.sessions:
        return 'أكمل ${challenge.target} جلسة قبل انتهاء التحدي.';
      case AiChallengeMetric.subjects:
        return 'ادرس ${challenge.target} مادة مختلفة قبل انتهاء التحدي.';
      case AiChallengeMetric.pomodoros:
        return 'أكمل ${challenge.target} جولة بومودورو قبل انتهاء التحدي.';
      case AiChallengeMetric.streak:
        return 'حافظ على سلسلة لمدة ${challenge.target} يوم قبل انتهاء التحدي.';
    }
  }

  String _localizedRewardName(BuildContext context, String rewardName) {
    if (!_isArabic(context)) return rewardName;
    const map = {
      'Daily Catalyst': 'محفز يومي',
      'Rhythm Keeper': 'حافظ الإيقاع',
      'Focus Riser': 'صاعد التركيز',
      'Pulse Keeper': 'حافظ النبض',
      'Context Hopper': 'متنقل السياق',
      'Momentum Spark': 'شرارة الزخم',
      'Deep Worker': 'عامل عميق',
      'Cadence Builder': 'باني الوتيرة',
      'Week Builder': 'باني الأسبوع',
      'Grid Runner': 'عدّاء الشبكة',
      'Breadth Scholar': 'باحث التنوع',
      'Endurance Scholar': 'باحث التحمل',
      'Habit Architect': 'مهندس العادة',
      'Arc Keeper': 'حافظ القوس',
      'Marathon Mind': 'عقل الماراثون',
      'Flash Focus': 'تركيز خاطف',
      'Quick Ignite': 'اشتعال سريع',
      'Relay Spark': 'شرارة التناوب',
      'Shuffle Star': 'نجم التبديل',
      'Streak Seed': 'بذرة السلسلة',
    };
    return map[rewardName] ?? rewardName;
  }
}
