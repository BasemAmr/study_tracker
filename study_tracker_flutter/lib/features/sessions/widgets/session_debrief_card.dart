import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/ai_debrief_service.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../l10n/app_localizations.dart';

/// Post-session AI debrief: shows when [aiDebriefMessageProvider] is set after save.
/// Auto-dismiss after 6s; tap to dismiss sooner.
class SessionDebriefCard extends ConsumerStatefulWidget {
  const SessionDebriefCard({super.key});

  @override
  ConsumerState<SessionDebriefCard> createState() => _SessionDebriefCardState();
}

class _SessionDebriefCardState extends ConsumerState<SessionDebriefCard> {
  Timer? _dismissTimer;
  DateTime? _lastScheduledFor;

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _restartDismissTimer() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      _clear();
    });
  }

  void _clear() {
    _dismissTimer?.cancel();
    ref.read(aiDebriefMessageProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = ref.watch(settingsProvider).settings.languageCode;
    final rtl = lang.toLowerCase() == 'ar';

    ref.listen<DebriefMessage?>(aiDebriefMessageProvider, (prev, next) {
      if (next != null && next.generatedAt != prev?.generatedAt) {
        _restartDismissTimer();
      }
    });

    final debriefMsg = ref.watch(aiDebriefMessageProvider);
    if (debriefMsg == null) return const SizedBox.shrink();

    if (_lastScheduledFor != debriefMsg.generatedAt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_lastScheduledFor != debriefMsg.generatedAt) {
          _lastScheduledFor = debriefMsg.generatedAt;
          _restartDismissTimer();
        }
      });
    }

    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: GestureDetector(
          onTap: _clear,
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.ai_settings_debrief,
                        style: AppTypography.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _clear,
                      icon: Icon(Icons.close, color: AppColors.onSurfaceVariant, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  debriefMsg.text,
                  style: AppTypography.textTheme.bodyMedium,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: rtl ? Alignment.centerLeft : Alignment.centerRight,
                  child: Text(
                    l10n.ai_debrief_tap_to_dismiss,
                    style: AppTypography.textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
