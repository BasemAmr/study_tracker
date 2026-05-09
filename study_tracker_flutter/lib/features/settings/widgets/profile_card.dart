import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/widgets/settings_widgets.dart';
import '../../../domain/entities.dart';
import '../../../l10n/app_localizations.dart';

class ResearcherProfileSection extends ConsumerWidget {
  const ResearcherProfileSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final provider = ref.watch(settingsProvider);
    final settings = provider.settings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsHeader(title: l10n.profileCardTitle),
        SettingsGroup(
          children: [
            SettingsInputRow(
              label: l10n.displayNameLabel,
              value: settings.displayName ?? '',
              onChanged: (val) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(settingsProvider).updateField(displayName: val);
                });
              },
            ),
            _AcademicLevelRow(
              label: l10n.academicLevelLabel,
              value: (settings.academicLevel ?? 'undergraduate').toLowerCase(),
              onChanged: (val) {
                if (val != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(settingsProvider).updateField(academicLevel: val);
                  });
                }
              },
            ),
            _LanguageRow(
              label: l10n.languageLabel,
              value: settings.languageCode,
              onChanged: (val) {
                if (val == null) return;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(settingsProvider).updateField(languageCode: val);
                  ref.read(settingsProvider).saveSettings();
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildProfilesSection(context, ref, provider, l10n),
      ],
    );
  }

  Widget _buildProfilesSection(BuildContext context, WidgetRef ref, SettingsProvider provider, AppLocalizations l10n) {
    final switching = provider.isSwitchingProfile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l10n.scholarProfilesLabel,
            style: AppTypography.textTheme.labelMedium?.copyWith(
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        SettingsGroup(
          children: [
            ...provider.profiles.map((profile) {
              final isCurrent = profile.id == provider.currentProfileId;
              return SettingsRow(
                label: profile.name,
                description: isCurrent ? 'Active Profile' : null,
                onTap: isCurrent || switching
                    ? null
                    : () => WidgetsBinding.instance.addPostFrameCallback((_) {
                        ref.read(settingsProvider).switchProfile(profile.id ?? 1);
                      }),
                control: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCurrent)
                      const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                    if (switching && provider.switchingToProfileId == profile.id)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              );
            }),
            SettingsActionRow(
              label: '+ ' + l10n.addScholar,
              onTap: () => _showProfileDialog(context, provider),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showProfileDialog(
    BuildContext context,
    SettingsProvider provider, {
    Profile? profile,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: profile?.name ?? '');
    var selectedLevel = (profile?.academicLevel ?? 'undergraduate').toLowerCase();
    if (!['undergraduate', 'postgraduate', 'doctoralCandidate', 'lifelongLearner'].contains(selectedLevel)) {
      selectedLevel = 'undergraduate';
    }

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(profile == null ? l10n.addScholarTitle : l10n.editScholarTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: l10n.displayNameField),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedLevel,
                  items: [
                    DropdownMenuItem(value: 'undergraduate', child: Text(l10n.undergraduate)),
                    DropdownMenuItem(value: 'postgraduate', child: Text(l10n.postgraduate)),
                    DropdownMenuItem(value: 'doctoralCandidate', child: Text(l10n.doctoralCandidate)),
                    DropdownMenuItem(value: 'lifelongLearner', child: Text(l10n.lifelongLearner)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => selectedLevel = value);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
              FilledButton(
                onPressed: () async {
                  if (profile == null) {
                    await provider.addProfile(name: nameController.text, academicLevel: selectedLevel);
                  } else {
                    await provider.updateProfile(id: profile.id ?? 1, name: nameController.text, academicLevel: selectedLevel);
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(l10n.save),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AcademicLevelRow extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String?> onChanged;

  const _AcademicLevelRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = {
      'undergraduate': l10n.undergraduate,
      'postgraduate': l10n.postgraduate,
      'doctoralCandidate': l10n.doctoralCandidate,
      'lifelongLearner': l10n.lifelongLearner,
    };

    return SettingsRow(
      label: label,
      control: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          onChanged: onChanged,
          items: labels.entries.map((e) {
            return DropdownMenuItem(value: e.key, child: Text(e.value, style: AppTypography.textTheme.bodyMedium));
          }).toList(),
        ),
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String?> onChanged;

  const _LanguageRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      label: label,
      control: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          onChanged: onChanged,
          items: const [
            DropdownMenuItem(value: 'en', child: Text('English', style: TextStyle(fontSize: 14))),
            DropdownMenuItem(value: 'ar', child: Text('العربية', style: TextStyle(fontSize: 14))),
          ],
        ),
      ),
    );
  }
}
