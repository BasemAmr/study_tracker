import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/ai_providers.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../data/repositories/ai_feature_settings_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/settings_widgets.dart';
import '../../../l10n/app_localizations.dart';

class AiFeaturesSection extends ConsumerStatefulWidget {
  const AiFeaturesSection({super.key});

  @override
  ConsumerState<AiFeaturesSection> createState() => _AiFeaturesSectionState();
}

class _AiFeaturesSectionState extends ConsumerState<AiFeaturesSection> {
  late final TextEditingController _keyController;
  bool _obscure = true;
  bool _expanded = false;
  Map<String, bool> _optimisticToggles = {};

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController();
    // Key will be loaded via build -> settingsProvider.
  }



  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _persistKey() async {
    final newKey = _keyController.text.trim();
    if (!mounted) return;
    
    // Save to provider (which handles repo + notify)
    ref.read(settingsProvider).updateField(groqApiKey: newKey);
    await ref.read(settingsProvider).saveSettings();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!.apiKeySaved),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _setAiToggle(String snakeKey, bool value) async {
    if (!mounted) return;
    setState(() => _optimisticToggles[snakeKey] = value);
    try {
      await ref.read(aiFeatureSettingsRepositoryProvider).upsertSettings({snakeKey: value});
    } catch (e) {
      debugPrint('[AiFeaturesSection] Failed to save toggle $snakeKey: $e');
    }
  }

  Future<void> _setSurpriseInterval(int hours) async {
    if (hours < 1) return;
    try {
      await ref.read(aiFeatureSettingsRepositoryProvider).upsertSettings({'surprise_check_interval_hours': hours});
    } catch (e) {
       debugPrint('[AiFeaturesSection] Failed to save surprise interval: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider).settings;
    final aiSnap = ref.watch(aiFeatureSettingsMapProvider);

    // Sync controller with provider state if it's currently empty (first load)
    if (_keyController.text.isEmpty && settings.groqApiKey != null) {
      _keyController.text = settings.groqApiKey!;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsHeader(title: l10n.ai_settings_title),
        SettingsGroup(
          children: [
            SettingsInputRow(
              label: l10n.ai_settings_api_key,
              value: _keyController.text,
              onChanged: (v) {
                _keyController.text = v;
                setState(() {});
              },
              obscureText: _obscure,
              onObscureToggle: () => setState(() => _obscure = !_obscure),
            ),
            SettingsActionRow(
              label: l10n.applyKey,
              onTap: _persistKey,
            ),
            SettingsToggleRow(
              label: l10n.aiChallengesTitle,
              description: l10n.aiChallengesSubtitle,
              value: settings.aiChallengesEnabled,
              onChanged: (v) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(settingsProvider).updateField(aiChallengesEnabled: v);
                  ref.read(settingsProvider).saveSettings();
                });
              },
            ),
            SettingsRow(
              label: _expanded ? 'إخفاء الإعدادات المتقدمة' : 'إعدادات متقدمة ›',
              onTap: () => setState(() => _expanded = !_expanded),
              control: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 20, color: AppColors.onSurfaceVariant),
            ),
            if (_expanded)
              ...aiSnap.when(
                data: (row) => [
                  _tile(l10n.ai_settings_coach, l10n.ai_settings_coach_desc, 'coach_enabled', row ?? <String, dynamic>{}),
                  _tile(l10n.ai_settings_challenges, l10n.ai_settings_challenges_desc, 'smart_challenges_enabled', row ?? <String, dynamic>{}),
                  _tile(l10n.ai_settings_debrief, l10n.ai_settings_debrief_desc, 'debrief_enabled', row ?? <String, dynamic>{}),
                  _tile(l10n.ai_settings_narrative, l10n.ai_settings_narrative_desc, 'weekly_narrative_enabled', row ?? <String, dynamic>{}),
                  _tile(l10n.ai_settings_difficulty, l10n.ai_settings_difficulty_desc, 'subject_difficulty_enabled', row ?? <String, dynamic>{}),
                  _tile(l10n.ai_settings_surprise, l10n.ai_settings_surprise_desc, 'surprise_notifications_enabled', row ?? <String, dynamic>{}),
                  if (aiRowBool(row, 'surprise_notifications_enabled'))
                    SettingsStepperRow(
                      label: l10n.ai_settings_surprise_interval(row?['surprise_check_interval_hours']?.toString() ?? '3'),
                      value: row?['surprise_check_interval_hours'] ?? 3,
                      unit: '',
                      onChanged: _setSurpriseInterval,
                    ),
                ],
                loading: () => [const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))],
                error: (_, __) => [const SizedBox.shrink()],
              ),
          ],
        ),
      ],
    );
  }

  Widget _tile(String title, String desc, String snake, Map<String, dynamic> row) {
    final val = _optimisticToggles[snake] ?? aiRowBool(row, snake);
    return SettingsToggleRow(
      label: title,
      description: desc,
      value: val,
      onChanged: (v) => _setAiToggle(snake, v),
    );
  }
}
