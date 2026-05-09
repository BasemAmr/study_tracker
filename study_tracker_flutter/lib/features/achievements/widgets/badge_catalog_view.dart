import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/achievements_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/icon_resolver.dart';
import '../../../l10n/app_localizations.dart';

enum _AwardsFilter { taken, daily, weekly, monthly, tiers }

class BadgeCatalogView extends ConsumerStatefulWidget {
  const BadgeCatalogView({super.key});

  @override
  ConsumerState<BadgeCatalogView> createState() => _BadgeCatalogViewState();
}

class _BadgeCatalogViewState extends ConsumerState<BadgeCatalogView> {
  _AwardsFilter _filter = _AwardsFilter.taken;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = ref.watch(achievementsProvider);
    final badges = _applyFilter(provider.badges);
    final progressToNext = provider.levelProgress.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _masteryHeader(context, provider, progressToNext),
        const SizedBox(height: 18),
        _filters(context),
        if (_filter == _AwardsFilter.taken) ...[
          const SizedBox(height: 8),
          Text(
            l10n.achievementsTakenAwards(badges.length),
            style: AppTypography.textTheme.labelMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = width >= 900 ? 4 : (width >= 620 ? 3 : 2);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.82,
              ),
              itemCount: badges.length,
              itemBuilder: (context, index) => _tokenCard(badges[index]),
            );
          },
        ),
      ],
    );
  }

  Widget _masteryHeader(BuildContext context, AchievementsProvider provider, double progress) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline, width: 2),
        boxShadow: const [
          BoxShadow(color: AppColors.outline, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              Text(
                l10n.achievementsLevelRank(provider.currentLevel, _rankLabel(provider.currentRank, l10n)),
                style: AppTypography.textTheme.headlineSmall,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.outline, width: 2),
                ),
                child: Text(
                  l10n.achievementsUnlocked(provider.unlockedCount, provider.totalBadges),
                  style: AppTypography.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n.achievementsXpProgress(provider.xpIntoCurrentLevel, provider.xpPerLevel, provider.xpToNextLevel),
            style: AppTypography.textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Container(
            height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.outline, width: 2),
              color: AppColors.surfaceContainer,
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget chip(String label, _AwardsFilter value) {
      final selected = _filter == value;
      return InkWell(
        onTap: () => setState(() => _filter = value),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.outline, width: 2),
          ),
          child: Text(
            label,
            style: AppTypography.textTheme.labelSmall?.copyWith(
              color: selected ? AppColors.onPrimary : AppColors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(l10n.achievementsFilterTaken, _AwardsFilter.taken),
        chip(l10n.achievementsFilterDaily, _AwardsFilter.daily),
        chip(l10n.achievementsFilterWeekly, _AwardsFilter.weekly),
        chip(l10n.achievementsFilterMonthly, _AwardsFilter.monthly),
        chip(l10n.achievementsFilterTiers, _AwardsFilter.tiers),
      ],
    );
  }

  List<BadgeDef> _applyFilter(List<BadgeDef> source) {
    switch (_filter) {
      case _AwardsFilter.taken:
        return source.where((b) => b.status == BadgeStatus.unlocked).toList();
      case _AwardsFilter.daily:
        return source.where((b) => b.category == BadgeCategory.daily).toList();
      case _AwardsFilter.weekly:
        return source.where((b) => b.category == BadgeCategory.weekly).toList();
      case _AwardsFilter.monthly:
        return source.where((b) => b.category == BadgeCategory.monthly).toList();
      case _AwardsFilter.tiers:
        return source
            .where((b) => b.category == BadgeCategory.statusAndTiers || b.category == BadgeCategory.secret)
            .toList();
    }
  }

  Widget _tokenCard(BadgeDef badge) {
    final l10n = AppLocalizations.of(context)!;
    final style = _tokenStyle(badge);

    return GestureDetector(
      onTap: () => _openBadgeModal(badge),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outline, width: 2),
          boxShadow: const [BoxShadow(color: AppColors.outline, offset: Offset(0, 3))],
        ),
        child: Opacity(
          opacity: badge.status == BadgeStatus.locked ? 0.6 : 1,
          child: Column(
            children: [
              SizedBox(
                width: 82,
                height: 82,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 82,
                      height: 82,
                      child: CircularProgressIndicator(
                        value: (badge.progress / 100).clamp(0.0, 1.0),
                        strokeWidth: 4,
                        backgroundColor: style.trackColor,
                        valueColor: AlwaysStoppedAnimation<Color>(style.progressColor),
                      ),
                    ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: style.badgeBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: style.borderColor, width: 2),
                        boxShadow: style.glow,
                      ),
                      child: Icon(iconFromName(badge.icon), color: style.iconColor, size: 30),
                    ),
                    if (badge.status == BadgeStatus.locked)
                      const Positioned(
                        right: 6,
                        bottom: 4,
                        child: Icon(Icons.lock, size: 16, color: AppColors.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _localizedBadgeTitle(badge, l10n),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${badge.progress}%'
                '${badge.repeatable && (badge.completions ?? 0) > 1 ? ' • x${badge.completions}' : ''}',
                style: AppTypography.textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _TokenStyle _tokenStyle(BadgeDef badge) {
    if (badge.status == BadgeStatus.locked) {
      return const _TokenStyle(
        borderColor: AppColors.outlineVariant,
        progressColor: AppColors.outlineVariant,
        trackColor: Color(0x335A7A5A),
        iconColor: AppColors.onSurfaceVariant,
        badgeBg: AppColors.background,
        glow: [],
      );
    }

    switch (badge.category) {
      case BadgeCategory.monthly:
        return const _TokenStyle(
          borderColor: AppColors.secondary,
          progressColor: AppColors.secondary,
          trackColor: Color(0x33D4A373),
          iconColor: AppColors.secondary,
          badgeBg: AppColors.surface,
          glow: [
            BoxShadow(color: Color(0x44D4A373), blurRadius: 10, spreadRadius: 1),
          ],
        );
      case BadgeCategory.statusAndTiers:
      case BadgeCategory.secret:
        return const _TokenStyle(
          borderColor: AppColors.outline,
          progressColor: AppColors.outline,
          trackColor: Color(0x335A7A5A),
          iconColor: AppColors.outline,
          badgeBg: AppColors.surface,
          glow: [
            BoxShadow(color: Color(0x33Fef3c7), blurRadius: 12, spreadRadius: 2),
          ],
        );
      case BadgeCategory.daily:
      case BadgeCategory.weekly:
        return const _TokenStyle(
          borderColor: AppColors.primary,
          progressColor: AppColors.primary,
          trackColor: Color(0x335A7A5A),
          iconColor: AppColors.primary,
          badgeBg: AppColors.surface,
          glow: [],
        );
    }
  }

  void _openBadgeModal(BadgeDef badge) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (context) {
        final maxDialogHeight = MediaQuery.of(context).size.height * 0.82;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.outline, width: 2),
              boxShadow: const [BoxShadow(color: AppColors.outline, offset: Offset(0, 4))],
            ),
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxDialogHeight),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.outline, width: 2),
                      ),
                      child: Icon(iconFromName(badge.icon), size: 42, color: AppColors.primary),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _localizedBadgeTitle(badge, l10n),
                      textAlign: TextAlign.center,
                      style: AppTypography.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _localizedBadgeDescription(badge, l10n),
                      textAlign: TextAlign.center,
                      style: AppTypography.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.outline, width: 2),
                        borderRadius: BorderRadius.circular(10),
                        color: AppColors.surfaceContainer,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(l10n.achievementsProgress, style: AppTypography.textTheme.labelSmall),
                              Text('${badge.progress}%', style: AppTypography.textTheme.labelSmall),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: (badge.progress / 100).clamp(0.0, 1.0),
                            minHeight: 10,
                            color: AppColors.primary,
                            backgroundColor: const Color(0x335A7A5A),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _rankLabel(String rank, AppLocalizations l10n) {
    switch (rank.toLowerCase()) {
      case 'master':
        return l10n.achievementsRankMaster;
      case 'scholar':
        return l10n.achievementsRankScholar;
      case 'adept':
        return l10n.achievementsRankAdept;
      case 'learner':
        return l10n.achievementsRankLearner;
      default:
        return l10n.achievementsRankNovice;
    }
  }

  String _localizedBadgeTitle(BadgeDef badge, AppLocalizations l10n) {
    switch (badge.id) {
      case 'daily_starter':
        return l10n.awardTitleDailyStarter;
      case 'deep_work_daily':
        return l10n.awardTitleDeepWorkDaily;
      case 'sprint_daily':
        return l10n.awardTitleSprintDaily;
      case 'pomo_5_daily':
        return l10n.awardTitlePomo5Daily;
      case 'midnight_oil':
        return l10n.awardTitleMidnightOil;
      case 'early_riser':
        return l10n.awardTitleEarlyRiser;
      case 'subject_explorer':
        return l10n.awardTitleSubjectExplorer;
      case 'no_zero_day':
        return l10n.awardTitleNoZeroDay;
      case 'task_finisher':
        return l10n.awardTitleTaskFinisher;
      case 'perfect_week':
        return l10n.awardTitlePerfectWeek;
      case 'weekend_warrior':
        return l10n.awardTitleWeekendWarrior;
      case 'time_investor_weekly':
        return l10n.awardTitleTimeInvestorWeekly;
      case 'monthly_master':
        return l10n.awardTitleMonthlyMaster;
      case 'forty_hour_club':
        return l10n.awardTitleFortyHourClub;
      case 'sessions_bronze':
        return l10n.awardTitleSessionsBronze;
      case 'sessions_silver':
        return l10n.awardTitleSessionsSilver;
      case 'sessions_gold':
        return l10n.awardTitleSessionsGold;
      case 'sessions_legend':
        return l10n.awardTitleSessionsLegend;
      case 'hours_bronze':
        return l10n.awardTitleHoursBronze;
      case 'streak_week':
        return l10n.awardTitleStreakWeek;
      case 'phoenix':
        return l10n.awardTitlePhoenix;
      case 'triple_threat':
        return l10n.awardTitleTripleThreat;
      case 'overkill':
        return l10n.awardTitleOverkill;
      default:
        return badge.title;
    }
  }

  String _localizedBadgeDescription(BadgeDef badge, AppLocalizations l10n) {
    switch (badge.id) {
      case 'daily_starter':
        return l10n.awardDescDailyStarter;
      case 'deep_work_daily':
        return l10n.awardDescDeepWorkDaily;
      case 'sprint_daily':
        return l10n.awardDescSprintDaily;
      case 'pomo_5_daily':
        return l10n.awardDescPomo5Daily;
      case 'midnight_oil':
        return l10n.awardDescMidnightOil;
      case 'early_riser':
        return l10n.awardDescEarlyRiser;
      case 'subject_explorer':
        return l10n.awardDescSubjectExplorer;
      case 'no_zero_day':
        return l10n.awardDescNoZeroDay;
      case 'task_finisher':
        return l10n.awardDescTaskFinisher;
      case 'perfect_week':
        return l10n.awardDescPerfectWeek;
      case 'weekend_warrior':
        return l10n.awardDescWeekendWarrior;
      case 'time_investor_weekly':
        return l10n.awardDescTimeInvestorWeekly;
      case 'monthly_master':
        return l10n.awardDescMonthlyMaster;
      case 'forty_hour_club':
        return l10n.awardDescFortyHourClub;
      case 'sessions_bronze':
        return l10n.awardDescSessionsBronze;
      case 'sessions_silver':
        return l10n.awardDescSessionsSilver;
      case 'sessions_gold':
        return l10n.awardDescSessionsGold;
      case 'sessions_legend':
        return l10n.awardDescSessionsLegend;
      case 'hours_bronze':
        return l10n.awardDescHoursBronze;
      case 'streak_week':
        return l10n.awardDescStreakWeek;
      case 'phoenix':
        return l10n.awardDescPhoenix;
      case 'triple_threat':
        return l10n.awardDescTripleThreat;
      case 'overkill':
        return l10n.awardDescOverkill;
      default:
        return badge.description;
    }
  }
}

class _TokenStyle {
  final Color borderColor;
  final Color progressColor;
  final Color trackColor;
  final Color iconColor;
  final Color badgeBg;
  final List<BoxShadow> glow;

  const _TokenStyle({
    required this.borderColor,
    required this.progressColor,
    required this.trackColor,
    required this.iconColor,
    required this.badgeBg,
    required this.glow,
  });
}
