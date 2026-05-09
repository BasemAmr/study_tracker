import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/providers/dashboard_provider.dart';

class TodaySignalBanner extends StatelessWidget {
  final DashboardData data;

  const TodaySignalBanner({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String signalText;
    Color iconColor;

    switch (data.currentState) {
      case WellbeingState.burnout:
        signalText = 'Needs rest — High fatigue · Watch >360m';
        iconColor = AppColors.error;
        break;
      case WellbeingState.flow:
        signalText = 'In the zone — Optimal focus · Flow ≥120m';
        iconColor = AppColors.primary;
        break;
      case WellbeingState.proud:
        signalText = 'Consistent — Strong momentum';
        iconColor = AppColors.secondary;
        break;
      case WellbeingState.idle:
      default:
        signalText = 'Gentle nudge — Ready to ignite';
        iconColor = AppColors.primary;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '✦ $signalText',
              style: AppTypography.textTheme.labelMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
