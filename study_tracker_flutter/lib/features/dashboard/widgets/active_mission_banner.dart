import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';

class ActiveMissionBanner extends StatelessWidget {
  final String title;
  /// Called when the user taps the active mission row (navigates to sessions).
  final VoidCallback onPlay;
  /// Called when the user taps the empty-state CTA (navigates to AI Missions).
  final VoidCallback? onPickMission;

  const ActiveMissionBanner({
    super.key,
    required this.title,
    required this.onPlay,
    this.onPickMission,
  });

  @override
  Widget build(BuildContext context) {
    final hasPin = title.isNotEmpty && title != 'No Active Mission';

    if (hasPin) {
      return InkWell(
        onTap: onPlay,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Text('⚡'),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Active mission: $title',
                  style: AppTypography.textTheme.labelMedium?.copyWith(
                    color: AppColors.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_forward, size: 16, color: AppColors.onSecondaryContainer),
            ],
          ),
        ),
      );
    }

    // Empty/CTA state — directs user to the AI Missions tab.
    return InkWell(
      onTap: onPickMission ?? onPlay,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outline, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.push_pin_outlined, size: 16, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pick an active mission from AI Missions',
                style: AppTypography.textTheme.labelMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_forward, size: 16, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
