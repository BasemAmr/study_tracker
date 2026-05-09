import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/widgets/settings_widgets.dart';
import '../../../l10n/app_localizations.dart';

class DangerZoneSection extends ConsumerWidget {
  const DangerZoneSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final provider = ref.watch(settingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 24, bottom: 8, right: 16),
          child: Text(
            'منطقة الخطر', // Red small header
            style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        SettingsGroup(
          children: [
            SettingsActionRow(
              label: l10n.exportData,
              onTap: () async {
                // Export is not implemented in Flutter yet
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Export functionality is coming soon to mobile.')),
                );
              },
            ),
            SettingsActionRow(
              label: l10n.resetProgress,
              isDestructive: true,
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l10n.resetProgress),
                    content: Text(l10n.wipeDataConfirmation),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(l10n.wipeDataAction, style: const TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await provider.wipeDatabase();
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
