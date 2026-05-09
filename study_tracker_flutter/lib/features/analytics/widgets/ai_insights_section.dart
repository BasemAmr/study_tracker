import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/ai_providers.dart';
import '../../../data/repositories/ai_feature_settings_repository.dart';
import '../../../core/services/ai_subject_difficulty_service.dart';
import '../../../core/services/ai_weekly_narrative_service.dart';
import '../../../data/repositories/ai_cache_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../l10n/app_localizations.dart';

/// Weekly narrative + subject difficulty actions (manual); optional weekly auto-run for difficulty.
class AiInsightsSection extends ConsumerStatefulWidget {
  const AiInsightsSection({super.key});

  @override
  ConsumerState<AiInsightsSection> createState() => _AiInsightsSectionState();
}

class _AiInsightsSectionState extends ConsumerState<AiInsightsSection> {
  bool _weeklyBusy = false;
  String? _weeklyText;

  bool _diffBusy = false;
  Map<String, dynamic>? _diffResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeWeeklyDifficultyAuto());
  }

  Future<void> _maybeWeeklyDifficultyAuto() async {
    final ai = await ref.read(aiFeatureSettingsRepositoryProvider).getSettings();
    if (!aiRowBool(ai, 'subject_difficulty_enabled')) return;

    final weekKey = rolling7DayKeyForDate(DateTime.now());
    final marker = await ref.read(aiCacheRepositoryProvider).get('difficulty_auto', weekKey);
    if (marker != null) return;

    final profileId = await ref.read(settingsRepositoryProvider).getCurrentProfileId();
    final map = await ref.read(aiSubjectDifficultyServiceProvider).analyze(profileId);
    if (map != null && map['error'] == null) {
      await ref.read(aiCacheRepositoryProvider).set(
            'difficulty_auto',
            weekKey,
            '{"ran":true}',
          );
      if (mounted) setState(() => _diffResult = map);
    } else {
      await ref.read(aiCacheRepositoryProvider).set('difficulty_auto', weekKey, '{"ran":true}');
    }
  }

  Future<void> _runWeekly({bool forceRefresh = false}) async {
    final ai = await ref.read(aiFeatureSettingsRepositoryProvider).getSettings();
    if (!aiRowBool(ai, 'weekly_narrative_enabled')) return;

    setState(() {
      _weeklyBusy = true;
      _weeklyText = null;
    });
    final profileId = await ref.read(settingsRepositoryProvider).getCurrentProfileId();
    final text = await ref.read(aiWeeklyNarrativeServiceProvider).generateForWeek(
          profileId,
          forceRefresh: forceRefresh,
        );
    if (!mounted) return;
    setState(() {
      _weeklyBusy = false;
      _weeklyText = text;
    });
  }

  Future<void> _runDifficulty({bool forceRefresh = false}) async {
    setState(() {
      _diffBusy = true;
      _diffResult = null;
    });
    final profileId = await ref.read(settingsRepositoryProvider).getCurrentProfileId();
    final map = await ref.read(aiSubjectDifficultyServiceProvider).analyze(
          profileId,
          forceRefresh: forceRefresh,
        );
    if (!mounted) return;
    setState(() {
      _diffBusy = false;
      _diffResult = map;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final aiAsync = ref.watch(aiFeatureSettingsMapProvider);

    return aiAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (ai) {
        final weeklyOn = aiRowBool(ai, 'weekly_narrative_enabled');
        final diffOn = aiRowBool(ai, 'subject_difficulty_enabled');
        if (!weeklyOn && !diffOn) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (weeklyOn) ...[
              Text(l10n.ai_narrative_title, style: AppTypography.textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _weeklyBusy ? null : () => _runWeekly(),
                    icon: _weeklyBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_stories_outlined, size: 20),
                    label: Text(l10n.ai_narrative_button),
                  ),
                  // Refresh icon: bypasses cache and re-generates from Groq.
                  if (_weeklyText != null && !_weeklyBusy) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Refresh narrative',
                      onPressed: () => _runWeekly(forceRefresh: true),
                      icon: const Icon(Icons.refresh, size: 20),
                    ),
                  ],
                ],
              ),
              if (_weeklyText != null && _weeklyText!.isNotEmpty) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onLongPress: () async {
                    await Clipboard.setData(ClipboardData(text: _weeklyText!));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.ai_copy_narrative_snackbar)),
                      );
                    }
                  },
                  child: AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _weeklyText!,
                      style: AppTypography.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
            if (diffOn) ...[
              Text(l10n.ai_difficulty_title, style: AppTypography.textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _diffBusy ? null : () => _runDifficulty(),
                    icon: _diffBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.psychology_outlined, size: 20),
                    label: Text(l10n.ai_difficulty_button),
                  ),
                  // Refresh icon: bypasses today's cache and re-analyzes from Groq.
                  if (_diffResult != null && !_diffBusy) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Refresh analysis',
                      onPressed: () => _runDifficulty(forceRefresh: true),
                      icon: const Icon(Icons.refresh, size: 20),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              _diffBody(l10n),
            ],
          ],
        );

      },
    );
  }

  Widget _diffBody(AppLocalizations l10n) {
    final m = _diffResult;
    if (m == null) return const SizedBox.shrink();
    final err = m['error'] as String?;
    if (err == 'not_enough_data') {
      return Text(
        l10n.ai_difficulty_not_enough,
        style: AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
      );
    }
    if (err != null) {
      return Text(
        l10n.ai_difficulty_error,
        style: AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
      );
    }

    final r = SubjectDifficultyResult.fromJson(m);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r.hardestSubject,
            style: AppTypography.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(r.reason, style: AppTypography.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(r.suggestion, style: AppTypography.textTheme.bodySmall),
        ],
      ),
    );
  }
}
