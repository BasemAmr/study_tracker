/// Session mode — matches the desktop app's SessionMode type.
enum StudySessionMode {
  pomodoro,
  longSession,
  manual;

  /// Label for display in the UI.
  String get label {
    switch (this) {
      case pomodoro:
        return 'Pomodoro';
      case longSession:
        return 'Long Session';
      case manual:
        return 'Manual Log';
    }
  }

  /// Database string value.
  String get dbValue {
    switch (this) {
      case pomodoro:
        return 'pomodoro';
      case longSession:
        return 'long_session';
      case manual:
        return 'manual';
    }
  }

  static StudySessionMode fromDb(String value) {
    switch (value) {
      case 'pomodoro':
        return pomodoro;
      case 'long_session':
        return longSession;
      case 'manual':
        return manual;
      default:
        return pomodoro;
    }
  }
}

/// Theme mode for the app.
enum AppThemeMode {
  light,
  dark,
  system;

  String get dbValue => name;

  static AppThemeMode fromDb(String value) {
    switch (value) {
      case 'dark':
        return dark;
      case 'system':
        return system;
      default:
        return light;
    }
  }
}

/// AI challenge metric type.
enum AiChallengeMetric {
  sessions,
  minutes,
  streak,
  subjects,
  pomodoros;

  static AiChallengeMetric fromDb(String value) {
    return AiChallengeMetric.values.firstWhere(
      (e) => e.name == value,
      orElse: () => sessions,
    );
  }
}

/// AI challenge tier.
enum AiChallengeTier {
  daily,
  weekly,
  monthly,
  surprise;

  static AiChallengeTier fromDb(String value) {
    return AiChallengeTier.values.firstWhere(
      (e) => e.name == value,
      orElse: () => daily,
    );
  }
}

/// AI mission row status on the live challenges table.
enum AiChallengeStatus {
  active,
  completed,
  expired,
  replaced;

  static AiChallengeStatus fromDb(String value) {
    return AiChallengeStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => active,
    );
  }
}

/// Recorded when a mission leaves the live table.
enum AiChallengeCloseReason {
  replaced,
  expired,
  completed;

  static AiChallengeCloseReason fromDb(String value) {
    return AiChallengeCloseReason.values.firstWhere(
      (e) => e.name == value,
      orElse: () => completed,
    );
  }
}

/// AI challenge difficulty.
enum AiChallengeDifficulty {
  easy,
  medium,
  hard,
  extreme;

  static AiChallengeDifficulty fromDb(String value) {
    return AiChallengeDifficulty.values.firstWhere(
      (e) => e.name == value,
      orElse: () => easy,
    );
  }
}
