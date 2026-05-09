import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/widgets/settings_widgets.dart';
import 'widgets/profile_card.dart';
import 'widgets/study_mechanics_card.dart';
import 'widgets/ai_features_card.dart';
import 'widgets/notifications_card.dart';
import 'widgets/danger_zone_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final horizontalPadding = MediaQuery.of(context).size.width < 420 ? 16.0 : 24.0;
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(l10n),
              const SizedBox(height: 12),
              const ResearcherProfileSection(),
              const StudyMechanicsSection(),
              const NotificationsSection(),
              const AiFeaturesSection(),
              _buildMaintenanceSection(context, ref),
              const DangerZoneSection(),
              const SizedBox(height: 32),
              _buildSaveButton(context, ref),
              const SizedBox(height: 80), // Padding for bottom nav
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.settingsTitle,
          style: AppTypography.textTheme.headlineMedium?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          l10n.settingsSubtitle,
          style: AppTypography.textTheme.bodySmall?.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final provider = ref.watch(settingsProvider);
    final busy = provider.isLoading || provider.isSwitchingProfile;

    return Container(
      height: 44,
      width: double.infinity,
      child: FilledButton(
        onPressed: busy ? null : () async {
          await ref.read(settingsProvider).saveSettings();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.settingsSaved),
                backgroundColor: AppColors.primary,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.zero,
        ),
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.onPrimary),
                ),
              )
            : Text(
                l10n.saveAllSettings,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildMaintenanceSection(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsHeader(title: l10n.maintenanceTitle),
        SettingsGroup(
          children: [
            SettingsActionRow(
              label: l10n.compactDatabase,
              onTap: () async {
                try {
                  final result = await ref.read(settingsProvider).compactDatabase();
                  if (!context.mounted) return;
                  final reclaimedMb = (result.reclaimedBytes / (1024 * 1024)).toStringAsFixed(2);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.databaseCompacted(reclaimedMb))));
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              },
            ),
            SettingsActionRow(
              label: l10n.clearAppCache,
              onTap: () async {
                try {
                  final bytes = await ref.read(settingsProvider).clearAppCache();
                  if (!context.mounted) return;
                  final mb = (bytes / (1024 * 1024)).toStringAsFixed(2);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.cacheCleared(mb))));
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
