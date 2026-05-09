enum StudySessionMode {
  pomodoro,
  longSession,
  manual
}

extension StudySessionModeExtension on StudySessionMode {
  String get label {
    switch (this) {
      case StudySessionMode.pomodoro:
        return 'Pomodoro';
      case StudySessionMode.longSession:
        return 'Long Session';
      case StudySessionMode.manual:
        return 'Manual';
    }
  }
}
