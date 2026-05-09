import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/providers/dashboard_provider.dart';
import '../../../core/utils/streak_milestone_hud.dart';
import '../../../l10n/app_localizations.dart';

/// Combined streak ladder + today's energy (copy from ARB — English + Arabic).
class WellbeingStatusHub extends StatelessWidget {
  final WellbeingState state;
  final int currentStreak;
  final StreakHudProgress streakHud;

  const WellbeingStatusHub({
    super.key,
    required this.state,
    required this.currentStreak,
    required this.streakHud,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 520;
        const gutter = 12.0;
        final streakCard = _StreakPanel(
          streak: currentStreak,
          hud: streakHud,
          l10n: l10n,
        );
        final energyCard = _EnergyPanel(
          state: state,
          l10n: l10n,
        );
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.outline, width: 2),
            boxShadow: const [
              BoxShadow(
                color: AppColors.outline,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: wide
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: streakCard),
                      const SizedBox(width: gutter),
                      Expanded(child: energyCard),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    streakCard,
                    const SizedBox(height: gutter),
                    energyCard,
                  ],
                ),
        );
      },
    );
  }
}

class _NeobrutaCard extends StatelessWidget {
  final Widget child;
  final Color bg;

  const _NeobrutaCard({
    required this.child,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline, width: 2),
        boxShadow: const [
          BoxShadow(color: AppColors.outline, offset: Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

String _statusHubCkptFlavor(AppLocalizations l, int milestone) {
  switch (milestone) {
    case 3:
      return l.statusHubCkptFlavor3;
    case 7:
      return l.statusHubCkptFlavor7;
    case 14:
      return l.statusHubCkptFlavor14;
    case 30:
      return l.statusHubCkptFlavor30;
    case 90:
      return l.statusHubCkptFlavor90;
    default:
      return l.statusHubCkptFlavorGeneric;
  }
}

String _statusHubTierTitle(AppLocalizations l, int streak) {
  if (streak <= 0) return l.statusHubTierColdStart;
  if (streak < 3) return l.statusHubTierFirstSpark;
  if (streak < 7) return l.statusHubTierKindlingClimb;
  if (streak < 14) return l.statusHubTierScholarPulse;
  if (streak < 30) return l.statusHubTierDeepRhythm;
  if (streak < 90) return l.statusHubTierMarathonMind;
  return l.statusHubTierHallOfLegends;
}

/// Localized motivational line toward the next streak crest.
String _statusHubChase(AppLocalizations l, StreakHudProgress p) {
  final next = p.nextCheckpointDays;
  final cur = p.currentStreak;
  final best = p.personalBest;
  if (next == null) {
    if (best >= 90) {
      return l.statusHubChasePeakRunway(best);
    }
    final goal = cur > best ? cur : best;
    return l.statusHubChaseEncore(goal);
  }
  final flavor = _statusHubCkptFlavor(l, next);
  if (cur <= 0) {
    return l.statusHubChaseStartToday(flavor, next);
  }
  final delta = next - cur;
  if (delta <= 0) {
    return l.statusHubChaseCement(flavor);
  }
  return l.statusHubChaseRemain(delta, flavor, next);
}

class _StreakPanel extends StatelessWidget {
  final int streak;
  final StreakHudProgress hud;
  final AppLocalizations l10n;

  const _StreakPanel({
    required this.streak,
    required this.hud,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final barPct =
        hud.progress01.isNaN ? 0.0 : hud.progress01.clamp(0.0, 1.0).toDouble();
    final barWidthFactor = math.max(barPct, 0.06);
    final chase = _statusHubChase(l10n, hud);
    final tier = _statusHubTierTitle(l10n, streak);

    return _NeobrutaCard(
      bg: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.statusHubStreakRunway,
                      style: AppTypography.textTheme.labelSmall?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$streak',
                          style:
                              Theme.of(context).textTheme.headlineLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                    letterSpacing: -0.5,
                                  ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            l10n.statusHubDaysHot,
                            style:
                                Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      tier,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.outline, width: 2),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.deepOrange.shade600,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            chase,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurface.withValues(alpha: 0.78),
                  height: 1.35,
                ),
          ),
          if (hud.nextCheckpointDays != null) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.statusHubNextCrest,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.8,
                        color: AppColors.onSurfaceVariant,
                      ),
                ),
                if (hud.daysToNext != null)
                  Flexible(
                    child: Text(
                      l10n.statusHubDaysToCrest(hud.daysToNext!),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: AppColors.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.end,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 10,
              width: double.infinity,
              child: LayoutBuilder(
                builder: (_, constraints) {
                  final wFill = constraints.maxWidth * barWidthFactor;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(
                          color: AppColors.surfaceContainerHighest,
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            height: constraints.maxHeight,
                            width: math.max(wFill, 1),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.secondary,
                                  Colors.deepOrange.shade400,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.statusHubPersonalBestFull(hud.personalBest),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontFamily: 'monospace',
                    color: AppColors.onSurfaceVariant,
                  ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.surfaceContainerHighest,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.statusHubLadderClearedTitle,
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.8,
                                color: AppColors.primary,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.statusHubPersonalBestInline(hud.personalBest),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EnergyPaletteColors {
  final IconData icon;
  final Color bg;
  final Color iconBg;
  final Color iconColor;
  final Color microColor;
  final Color titleColor;
  final Color bodyColor;

  const _EnergyPaletteColors({
    required this.icon,
    required this.bg,
    required this.iconBg,
    required this.iconColor,
    required this.microColor,
    required this.titleColor,
    required this.bodyColor,
  });
}

_EnergyPaletteColors _energyColorsFor(WellbeingState s) {
  switch (s) {
    case WellbeingState.flow:
      return const _EnergyPaletteColors(
        icon: Icons.bolt_rounded,
        bg: AppColors.primary,
        iconBg: AppColors.surface,
        iconColor: AppColors.primary,
        microColor: Color(0xFFD0EBD0),
        titleColor: AppColors.surface,
        bodyColor: Color(0xFFD0EBD0),
      );
    case WellbeingState.proud:
      return const _EnergyPaletteColors(
        icon: Icons.workspace_premium_rounded,
        bg: Color(0xFFFFFAEC),
        iconBg: Color(0xFFFFEDCC),
        iconColor: Color(0xFFC07B2C),
        microColor: Color(0xFF9A6F3A),
        titleColor: AppColors.onSurface,
        bodyColor: Color(0xFF566156),
      );
    case WellbeingState.burnout:
      return const _EnergyPaletteColors(
        icon: Icons.battery_1_bar_rounded,
        bg: Color(0xFFF4F7F5),
        iconBg: AppColors.surface,
        iconColor: Color(0xFF6B766B),
        microColor: AppColors.onSurfaceVariant,
        titleColor: AppColors.onSurface,
        bodyColor: Color(0xFF566156),
      );
    case WellbeingState.idle:
      return const _EnergyPaletteColors(
        icon: Icons.auto_awesome_rounded,
        bg: AppColors.surface,
        iconBg: AppColors.surfaceVariant,
        iconColor: AppColors.primary,
        microColor: AppColors.primary,
        titleColor: AppColors.onSurface,
        bodyColor: Color(0xFF566156),
      );
  }
}

(List<String>, String) _energyTexts(WellbeingState s, AppLocalizations l10n) {
  switch (s) {
    case WellbeingState.flow:
      return (
        [l10n.statusHubChipOptimalFocus, l10n.statusHubChipFlowRule, l10n.statusHubChipFatigueRule],
        l10n.wellbeingFlowTitle,
      );
    case WellbeingState.proud:
      return (
        [l10n.statusHubChipStreakCrest, l10n.statusHubChipFlowRule, l10n.statusHubChipFatigueRule],
        l10n.wellbeingProudTitle,
      );
    case WellbeingState.burnout:
      return (
        [l10n.statusHubChipRestGuarded, l10n.statusHubChipFlowRule, l10n.statusHubChipFatigueRule],
        l10n.wellbeingBurnoutTitle,
      );
    case WellbeingState.idle:
      return (
        [l10n.statusHubChipReadyIgnite, l10n.statusHubChipFlowRule, l10n.statusHubChipFatigueRule],
        l10n.wellbeingIdleTitle,
      );
  }
}

String _energyBody(WellbeingState s, AppLocalizations l10n) {
  switch (s) {
    case WellbeingState.flow:
      return l10n.statusHubBodyFlow;
    case WellbeingState.proud:
      return l10n.statusHubBodyProud;
    case WellbeingState.burnout:
      return l10n.statusHubBodyBurnout;
    case WellbeingState.idle:
      return l10n.statusHubBodyIdle;
  }
}

class _EnergyPanel extends StatelessWidget {
  final WellbeingState state;
  final AppLocalizations l10n;

  const _EnergyPanel({
    required this.state,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final c = _energyColorsFor(state);
    final (chips, title) = _energyTexts(state, l10n);
    final body = _energyBody(state, l10n);
    final lang = Localizations.localeOf(context).languageCode;
    final microLine = lang == 'ar'
        ? l10n.statusHubTodaySignal
        : l10n.statusHubTodaySignal.toUpperCase();

    return _NeobrutaCard(
      bg: c.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.iconBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.outline, width: 2),
                ),
                alignment: Alignment.center,
                child: Icon(c.icon, color: c.iconColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      microLine,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            color: c.microColor,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: c.titleColor,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: c.bodyColor.withValues(
                    alpha: state == WellbeingState.flow ? 0.92 : 0.94,
                  ),
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children:
                chips.map((t) => _miniChip(context, t)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(BuildContext context, String label) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: state == WellbeingState.flow
            ? AppColors.surface.withValues(alpha: 0.22)
            : AppColors.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: state == WellbeingState.flow
              ? AppColors.surface.withValues(alpha: 0.42)
              : AppColors.outlineVariant,
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: state == WellbeingState.flow
                    ? AppColors.surface
                    : AppColors.onSurface,
              ),
        ),
      ),
    );
  }
}
