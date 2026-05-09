/// Streak ladder math for the dashboard status hub (milestones 3–7–14–30–90).
/// Localized copy lives in ARB files; see `wellbeing_status_hub.dart` helpers.

class StreakHudProgress {
  final int currentStreak;
  final int personalBest;
  /// 0–1 toward next milestone, or 1 at max ladder
  final double progress01;
  final int? nextCheckpointDays;
  final int? daysToNext;

  const StreakHudProgress({
    required this.currentStreak,
    required this.personalBest,
    required this.progress01,
    required this.nextCheckpointDays,
    required this.daysToNext,
  });
}

const List<int> streakHudTargets = [3, 7, 14, 30, 90];

int? streakHudNextTarget(int streak) {
  for (final t in streakHudTargets) {
    if (streak < t) return t;
  }
  return null;
}

int streakHudPrevTarget(int streak) {
  var p = 0;
  for (final t in streakHudTargets) {
    if (streak >= t) {
      p = t;
    } else {
      break;
    }
  }
  return p;
}

StreakHudProgress computeStreakHudProgress(
  int currentStreak,
  int personalBest,
) {
  final next = streakHudNextTarget(currentStreak);
  final prev = streakHudPrevTarget(currentStreak);

  final double progress01;
  if (next == null) {
    progress01 = 1;
  } else if (next == prev) {
    progress01 = 0;
  } else {
    progress01 =
        ((currentStreak - prev) / (next - prev)).clamp(0.0, 1.0).toDouble();
  }

  final daysToNext =
      next == null ? null : (next - currentStreak).clamp(0, 9999).toInt();

  return StreakHudProgress(
    currentStreak: currentStreak,
    personalBest: personalBest,
    progress01: progress01,
    nextCheckpointDays: next,
    daysToNext: daysToNext,
  );
}
