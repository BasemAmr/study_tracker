import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/providers/achievements_provider.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/badge_catalog_view.dart';
import 'widgets/ai_missions_view.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final provider = ref.watch(achievementsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: provider.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, ref, l10n, provider),
                    if (provider.error != null) ...[
                      const SizedBox(height: 16),
                      Text(provider.error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 24),
                    if (provider.activeTab == AchievementTab.awards)
                      const BadgeCatalogView()
                    else
                      const AiMissionsView(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, AppLocalizations l10n, AchievementsProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.navAchievements, style: AppTypography.textTheme.labelMedium?.copyWith(color: AppColors.primary)),
        const SizedBox(height: 4),
        Text(l10n.achievementsPersonalGrowth, style: AppTypography.textTheme.headlineLarge),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outline, width: 2),
            boxShadow: const [
              BoxShadow(color: AppColors.outline, offset: Offset(0, 3)),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _tabBtn(l10n.achievementsTabAwards, provider.activeTab == AchievementTab.awards, () => provider.setTab(AchievementTab.awards)),
                const SizedBox(width: 8),
                _tabBtn(
                  l10n.achievementsTabAiMissions,
                  provider.activeTab == AchievementTab.missions,
                  () async {
                    provider.setTab(AchievementTab.missions);
                    final lines = await ref.read(achievementsProvider).onAiMissionsTabOpened();
                    if (!context.mounted) return;
                    for (final line in lines) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(line), behavior: SnackBarBehavior.floating),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.outline, width: 2),
        ),
        child: Text(
          label,
          style: AppTypography.textTheme.labelMedium?.copyWith(
            color: active ? AppColors.onPrimary : AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
