import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../l10n/app_localizations.dart';

class ActiveMissionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double progress; // 0.0 to 1.0
  final VoidCallback onPlay;
  final VoidCallback onRefresh;

  const ActiveMissionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.onPlay,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 300;
              return Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.outline, width: 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt,
                            size: 16,
                            color: AppColors.onPrimaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              l10n.activeMissionBadge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.textTheme.labelMedium?.copyWith(
                                color: AppColors.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!compact)
                    Text(
                      l10n.activeMissionEta,
                      style: AppTypography.textTheme.labelMedium?.copyWith(
                        color: AppColors.outline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  IconButton(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: l10n.activeMissionRefreshTooltip,
                    constraints: const BoxConstraints(minHeight: 34, minWidth: 34),
                    padding: EdgeInsets.zero,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: AppTypography.textTheme.headlineMedium?.copyWith(
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AppTypography.textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.progressLabel,
                          style: AppTypography.textTheme.labelMedium,
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: AppTypography.textTheme.labelMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.outline, width: 2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(4),
                            border: const Border(
                              right: BorderSide(color: AppColors.outline, width: 2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              _PlayButton(onTap: onPlay),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatefulWidget {
  final VoidCallback onTap;

  const _PlayButton({required this.onTap});

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final double offset = _isPressed ? 0.0 : 2.0;
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.translationValues(0, _isPressed ? 2.0 : 0, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.secondary,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.outline, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.outline,
              offset: Offset(0, offset),
            ),
          ],
        ),
        child: const Icon(
          Icons.play_arrow,
          color: AppColors.onSurface,
          size: 28,
        ),
      ),
    );
  }
}
