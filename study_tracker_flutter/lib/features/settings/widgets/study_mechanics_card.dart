import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/widgets/settings_widgets.dart';
import '../../../l10n/app_localizations.dart';

class StudyMechanicsSection extends ConsumerWidget {
  const StudyMechanicsSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final provider = ref.watch(settingsProvider);
    final settings = provider.settings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsHeader(title: l10n.studyMechanicsTitle),
        SettingsGroup(
          children: [
            SettingsStepperRow(
              label: l10n.dailyTargetLabel,
              value: (settings.dailyGoalMinutes / 60).round(),
              unit: l10n.hoursUnit,
              onChanged: (val) {
                if (val >= 0) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(settingsProvider).updateField(dailyGoalHours: val);
                  });
                }
              },
            ),
            SettingsStepperRow(
              label: l10n.focusBlockLabel,
              value: settings.focusMinutes,
              unit: l10n.minutesUnit,
              onChanged: (val) {
                if (val >= 1) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(settingsProvider).updateField(focusMinutes: val);
                  });
                }
              },
            ),
            SettingsStepperRow(
              label: l10n.shortBreakLabel,
              value: settings.breakMinutes,
              unit: l10n.minutesUnit,
              onChanged: (val) {
                if (val >= 1) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(settingsProvider).updateField(breakMinutes: val);
                  });
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
