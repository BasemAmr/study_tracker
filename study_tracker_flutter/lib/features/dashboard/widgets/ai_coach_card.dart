import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/ai_providers.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../l10n/app_localizations.dart';

/// Dismissible AI Coach card on the dashboard (near streak).
/// Hidden when coach toggle is off. "Connect AI" when toggle on but no API key.
/// Generated text is plain (no emoji in copy); icon is decorative only.
class AiCoachCard extends ConsumerStatefulWidget {
  const AiCoachCard({super.key});

  @override
  ConsumerState<AiCoachCard> createState() => _AiCoachCardState();
}

class _AiCoachCardState extends ConsumerState<AiCoachCard> {
  // State for dismissal
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
  }



  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final aiAsync = ref.watch(aiFeatureSettingsMapProvider);

    final apiKey = ref.watch(aiGroqApiKeyProvider);
    final hasRealKey = apiKey != null && 
                      apiKey.isNotEmpty && 
                      !apiKey.startsWith('sk-xxxx') && 
                      !apiKey.startsWith('gsk_xxxx');

    return aiAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (ai) {
        if (!aiRowBool(ai, 'coach_enabled')) return const SizedBox.shrink();

        if (!hasRealKey) {
          return _wrapDismissible(
            child: _connectCard(context, l10n),
          );
        }

        final msgAsync = ref.watch(aiCoachTodayProvider);
        return msgAsync.when(
          loading: () => _wrapDismissible(child: _loadingCard(l10n)),
          error: (_, __) => _wrapDismissible(child: _connectCard(context, l10n)),
          data: (message) {
            if (message == null || message.isEmpty) {
              return _wrapDismissible(child: _connectCard(context, l10n));
            }
            return _wrapDismissible(child: _messageCard(context, l10n, message));
          },
        );
      },
    );
  }

  Widget _wrapDismissible({required Widget child}) {
    return Dismissible(
      key: const ValueKey('ai_coach_card'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => setState(() => _dismissed = true),
      child: child,
    );
  }

  bool _expanded = false;

  Widget _messageCard(BuildContext context, AppLocalizations l10n, String message) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.ai_coach_title,
                    style: AppTypography.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.onSurfaceVariant),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 12),
            Text(
              message,
              style: AppTypography.textTheme.bodyMedium,
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              message.split('\n')[0],
              style: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _connectCard(BuildContext context, AppLocalizations l10n) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.link, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.ai_coach_connect,
              style: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingCard(AppLocalizations l10n) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              l10n.ai_debrief_loading,
              style: AppTypography.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
