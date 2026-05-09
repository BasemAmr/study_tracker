// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'StudyTracker';

  @override
  String get settingsTitle => 'Configuration';

  @override
  String get settingsSubtitle => 'Manage your study environment, subjects, and preferences for deep work sessions.';

  @override
  String get saveAllSettings => 'SAVE ALL SETTINGS';

  @override
  String get settingsSaved => 'Settings saved successfully!';

  @override
  String get maintenanceTitle => 'Maintenance';

  @override
  String get maintenanceSubtitle => 'Compact local database and clear temporary cache files.';

  @override
  String get compactDatabase => 'Compact Database (VACUUM)';

  @override
  String get clearAppCache => 'Clear App Cache';

  @override
  String databaseCompacted(Object mb) {
    return 'Database compacted. Reclaimed ~$mb MB.';
  }

  @override
  String databaseCompactFailed(Object error) {
    return 'Database compact failed: $error';
  }

  @override
  String cacheCleared(Object mb) {
    return 'Cache cleared. Removed ~$mb MB.';
  }

  @override
  String cacheClearFailed(Object error) {
    return 'Cache clear failed: $error';
  }

  @override
  String get profileCardTitle => 'Scholar Profile';

  @override
  String get displayNameLabel => 'DISPLAY NAME';

  @override
  String get academicLevelLabel => 'ACADEMIC LEVEL';

  @override
  String get languageLabel => 'LANGUAGE';

  @override
  String get scholarProfilesLabel => 'SCHOLAR PROFILES';

  @override
  String get switchProfile => 'Switch';

  @override
  String get addScholar => 'Add Scholar';

  @override
  String get addScholarTitle => 'Add Scholar';

  @override
  String get editScholarTitle => 'Edit Scholar';

  @override
  String get displayNameField => 'Display name';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get confirmDeleteTitle => 'Delete Session?';

  @override
  String get confirmDeleteBody => 'Are you sure you want to delete this session? This action cannot be undone.';

  @override
  String get wipeDataConfirmation => 'This will permanently delete all your study sessions, profiles, and settings. This action cannot be undone. Are you absolutely sure?';

  @override
  String get wipeDataAction => 'DELETE EVERYTHING';

  @override
  String get undergraduate => 'Undergraduate';

  @override
  String get postgraduate => 'Postgraduate';

  @override
  String get doctoralCandidate => 'Doctoral Candidate';

  @override
  String get lifelongLearner => 'Lifelong Learner';

  @override
  String get studyMechanicsTitle => 'Study Mechanics';

  @override
  String get dailyTargetLabel => 'DAILY TARGET';

  @override
  String get focusBlockLabel => 'FOCUS BLOCK';

  @override
  String get shortBreakLabel => 'SHORT BREAK';

  @override
  String get hoursUnit => 'hrs';

  @override
  String get minutesUnit => 'min';

  @override
  String get aiChallengesTitle => 'AI Challenges';

  @override
  String get aiChallengesSubtitle => 'Dynamic quizzes based on study notes.';

  @override
  String get groqApiKeyLabel => 'GROQ API KEY';

  @override
  String get applyKey => 'Apply Key';

  @override
  String get apiKeySaved => 'API key saved.';

  @override
  String get statusLabel => 'Status:';

  @override
  String get statusReady => 'Ready';

  @override
  String get curriculumTitle => 'Curriculum';

  @override
  String get newGroup => 'NEW GROUP';

  @override
  String get newSubject => 'NEW SUBJECT';

  @override
  String get addSubjectGroup => 'Add Subject Group';

  @override
  String get groupName => 'Group name';

  @override
  String get create => 'Create';

  @override
  String failedCreateGroup(Object error) {
    return 'Failed to create group: $error';
  }

  @override
  String get addSubject => 'Add Subject';

  @override
  String get subjectName => 'Subject name';

  @override
  String get group => 'Group';

  @override
  String failedCreateSubject(Object error) {
    return 'Failed to create subject: $error';
  }

  @override
  String get editGroup => 'Edit Group';

  @override
  String get deleteGroupTitle => 'Delete Group?';

  @override
  String deleteGroupPrompt(Object name) {
    return 'Delete \"$name\" and ungroup its subjects?';
  }

  @override
  String get editSubject => 'Edit Subject';

  @override
  String get deleteSubjectTitle => 'Delete Subject?';

  @override
  String deleteSubjectPrompt(Object name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get select => 'Select';

  @override
  String get editGroupMenu => 'Edit Group';

  @override
  String get deleteGroupMenu => 'Delete Group';

  @override
  String get noSubjectsFound => 'No Subjects Found';

  @override
  String get noSubjectsCreateHint => 'Create a group then add your first subject.';

  @override
  String get noSubjectsAddHint => 'Add a subject to this group to start tracking.';

  @override
  String get studySubject => 'Study subject';

  @override
  String get sessionsLabel => 'Sessions';

  @override
  String get editSubjectMenu => 'Edit Subject';

  @override
  String get deleteSubjectMenu => 'Delete Subject';

  @override
  String get dataManagementTitle => 'Data Management';

  @override
  String get exportData => 'Export Data';

  @override
  String get resetProgress => 'Reset Progress';

  @override
  String get dangerZoneTitle => 'Danger Zone';

  @override
  String get dataWipedSuccess => 'All data has been wiped.';

  @override
  String get ambienceTitle => 'Ambience';

  @override
  String get library => 'Library';

  @override
  String get forest => 'Forest';

  @override
  String get focusAudioTitle => 'Focus Audio';

  @override
  String get lofiBeatsStream => 'Lofi Beats Stream';

  @override
  String get volume => 'Volume';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navSessions => 'Sessions';

  @override
  String get navAnalytics => 'Analytics';

  @override
  String get navAchievements => 'Achievements';

  @override
  String get navSettings => 'Settings';

  @override
  String get noMediaPlaying => 'No media playing';

  @override
  String get tooltipMinimizePlayer => 'Minimize player';

  @override
  String get tooltipHidePlayer => 'Hide player';

  @override
  String get tooltipFocusAudio => 'Focus Audio';

  @override
  String get dashboardLoadError => 'Unable to load dashboard data';

  @override
  String get dashboardScholarFallbackName => 'Scholar';

  @override
  String dashboardHello(Object name) {
    return 'Hello, $name';
  }

  @override
  String dashboardLevelLine(Object level, Object rank, Object xp, Object sessions, Object minutes) {
    return 'Level $level $rank · $xp XP to next level (~$sessions sessions / ~$minutes focus min equivalent).';
  }

  @override
  String get quickStartPomodoro => 'Quick Start Pomodoro';

  @override
  String get quickStartLongSession => 'Quick Start Long Session';

  @override
  String get dashboardMissionRefreshAi => 'AI missions fetched successfully.';

  @override
  String get dashboardMissionRefreshFallback => 'Missions refreshed with local fallback.';

  @override
  String get wellbeingFlowTitle => 'The Flow State';

  @override
  String get wellbeingFlowSubtitle => 'OPTIMAL PERFORMANCE';

  @override
  String get wellbeingProudTitle => 'The Proud Scholar';

  @override
  String get wellbeingProudSubtitle => 'CONSISTENT STREAK';

  @override
  String get wellbeingBurnoutTitle => 'Burnout Warning';

  @override
  String get wellbeingBurnoutSubtitle => 'REST RECOMMENDED';

  @override
  String get wellbeingIdleTitle => 'Gentle Reminder';

  @override
  String get wellbeingIdleSubtitle => 'IDLE';

  @override
  String get dailyIntelTitle => 'Daily Intel';

  @override
  String get dailyIntelSubtitle => 'Reviewing your cognitive load for today.';

  @override
  String get dailyIntelDeepWork => 'Deep Work';

  @override
  String get dailyIntelFocusScore => 'Focus Score';

  @override
  String get dailyIntelStreak => 'STREAK';

  @override
  String get daysLabel => 'Days';

  @override
  String get dailyObjectiveTitle => 'Current Objective';

  @override
  String get completedLabel => 'COMPLETED';

  @override
  String get goalLabel => 'GOAL';

  @override
  String get activeMissionBadge => 'ACTIVE MISSION';

  @override
  String get activeMissionEta => 'ETA: 45 MIN';

  @override
  String get activeMissionRefreshTooltip => 'Refresh mission';

  @override
  String get progressLabel => 'PROGRESS';

  @override
  String get consistencyGridTitle => 'Consistency Grid';

  @override
  String get consistencyLast14Days => 'Last 14 Days';

  @override
  String get lessLabel => 'Less';

  @override
  String get moreLabel => 'More';

  @override
  String get historicalContextTitle => 'Me vs. Past Self';

  @override
  String get historicalThisWeek => 'THIS WEEK';

  @override
  String get historicalDeepWorkVolume => 'DEEP WORK VOLUME';

  @override
  String get historicalLastWeek => 'LAST WEEK';

  @override
  String get historicalAverageFocusSession => 'AVERAGE FOCUS SESSION';

  @override
  String get historicalCompletionRate => 'COMPLETION RATE';

  @override
  String get weekdayMonShort => 'M';

  @override
  String get weekdayTueShort => 'T';

  @override
  String get weekdayWedShort => 'W';

  @override
  String get weekdayThuShort => 'T';

  @override
  String get weekdayFriShort => 'F';

  @override
  String get weekdaySatShort => 'S';

  @override
  String get weekdaySunShort => 'S';

  @override
  String get sessionsSubtitle => 'Study sessions';

  @override
  String get logManually => 'Log manually';

  @override
  String get filters => 'Filters';

  @override
  String get filtersActive => 'Filters (active)';

  @override
  String get historyFiltersTitle => 'History Filters';

  @override
  String get close => 'Close';

  @override
  String get timerTab => 'Timer';

  @override
  String get stopwatchTab => 'Stopwatch';

  @override
  String get historyTab => 'History';

  @override
  String get subjectsGroupsTab => 'Subjects & Groups';

  @override
  String sessionQuickStartStarted(Object mode) {
    return '$mode started.';
  }

  @override
  String get sessionModePomodoro => 'Pomodoro';

  @override
  String get sessionModeLongSession => 'Long Session';

  @override
  String get sessionModeManual => 'Manual Log';

  @override
  String get sessionsLoadError => 'Unable to load sessions';

  @override
  String get noSessionsLogged => 'No sessions logged yet';

  @override
  String minutesShortValue(Object minutes) {
    return '${minutes}m';
  }

  @override
  String get searchHistory => 'Search history';

  @override
  String get subjectsError => 'Subjects error';

  @override
  String get subjectLabel => 'Subject';

  @override
  String get allSubjects => 'All subjects';

  @override
  String get modeLabel => 'Mode';

  @override
  String get allModes => 'All modes';

  @override
  String filtersFrom(Object value) {
    return 'From $value';
  }

  @override
  String filtersTo(Object value) {
    return 'To $value';
  }

  @override
  String get clear => 'Clear';

  @override
  String get anyLabel => 'Any';

  @override
  String get logSessionManuallyTitle => 'Log session manually';

  @override
  String get subjectOptional => 'Subject (optional)';

  @override
  String get generalStudy => 'General study';

  @override
  String get topicLabel => 'Topic';

  @override
  String get moodLabel => 'Mood';

  @override
  String get moodFocused => 'Focused';

  @override
  String get moodProductive => 'Productive';

  @override
  String get moodCalm => 'Calm';

  @override
  String get moodTired => 'Tired';

  @override
  String get moodStressed => 'Stressed';

  @override
  String get moodDistracted => 'Distracted';

  @override
  String get durationMinutesLabel => 'Duration (minutes)';

  @override
  String get enterValidDuration => 'Enter a valid duration';

  @override
  String get notesLabel => 'Notes';

  @override
  String get saving => 'Saving...';

  @override
  String get analyticsSubtitle => 'Review your cognitive endurance and focus metrics over the current cycle.';

  @override
  String get achievementsPersonalGrowth => 'Personal Growth';

  @override
  String get achievementsTabAwards => 'Awards';

  @override
  String get achievementsTabAiMissions => 'AI Missions';

  @override
  String achievementsTakenAwards(Object count) {
    return 'Taken awards: $count';
  }

  @override
  String achievementsLevelRank(Object level, Object rank) {
    return 'Lvl $level $rank';
  }

  @override
  String achievementsUnlocked(Object unlocked, Object total) {
    return '$unlocked/$total unlocked';
  }

  @override
  String achievementsXpProgress(Object current, Object total, Object toGo) {
    return '$current / $total XP this level ($toGo to go)';
  }

  @override
  String get achievementsFilterTaken => 'AWARDS I TOOK';

  @override
  String get achievementsFilterDaily => 'DAILY';

  @override
  String get achievementsFilterWeekly => 'WEEKLY';

  @override
  String get achievementsFilterMonthly => 'MONTHLY';

  @override
  String get achievementsFilterTiers => 'TIERS';

  @override
  String get achievementsProgress => 'Progress';

  @override
  String get achievementsRankMaster => 'Master';

  @override
  String get achievementsRankScholar => 'Scholar';

  @override
  String get achievementsRankAdept => 'Adept';

  @override
  String get achievementsRankLearner => 'Learner';

  @override
  String get achievementsRankNovice => 'Novice';

  @override
  String get achievementsCurrentMissions => 'Current Missions';

  @override
  String get achievementsRefreshSurprise => 'Refresh Surprise';

  @override
  String get achievementsGroqDetected => 'Groq key detected. Missions will use AI generation with local fallback.';

  @override
  String get achievementsNoGroq => 'No Groq key found. Missions are generated locally; add or replace your key in Settings anytime.';

  @override
  String get achievementsNoActiveMissions => 'No active missions. Tap refresh to generate new missions.';

  @override
  String get achievementsCompletedChallenges => 'Completed Challenges';

  @override
  String get achievementsNoCompletedMissions => 'No completed missions yet.';

  @override
  String achievementsMissionRefreshed(Object tier) {
    return '$tier mission refreshed.';
  }

  @override
  String get achievementsRefreshThisMission => 'Refresh this mission';

  @override
  String achievementsReward(Object reward) {
    return 'Reward: $reward';
  }

  @override
  String get achievementsTierDaily => 'DAILY';

  @override
  String get achievementsTierWeekly => 'WEEKLY';

  @override
  String get achievementsTierMonthly => 'MONTHLY';

  @override
  String get achievementsTierSurprise => 'SURPRISE';

  @override
  String get achievementsDifficultyEasy => 'EASY';

  @override
  String get achievementsDifficultyMedium => 'MEDIUM';

  @override
  String get achievementsDifficultyHard => 'HARD';

  @override
  String get achievementsDifficultyExtreme => 'EXTREME';

  @override
  String get achievementsMetricSessions => 'sessions';

  @override
  String get achievementsMetricMinutes => 'minutes';

  @override
  String get achievementsMetricStreak => 'streak';

  @override
  String get achievementsMetricSubjects => 'subjects';

  @override
  String get achievementsMetricPomodoros => 'pomodoros';

  @override
  String get awardTitleDailyStarter => 'Starter';

  @override
  String get awardDescDailyStarter => 'Complete your first session today';

  @override
  String get awardTitleDeepWorkDaily => 'Deep Work';

  @override
  String get awardDescDeepWorkDaily => 'Study for 60 minutes today';

  @override
  String get awardTitleSprintDaily => 'Sprint';

  @override
  String get awardDescSprintDaily => 'Study for 2 hours today';

  @override
  String get awardTitlePomo5Daily => 'Pomo-5';

  @override
  String get awardDescPomo5Daily => 'Complete 5 Pomodoro sessions today';

  @override
  String get awardTitleMidnightOil => 'Midnight Oil';

  @override
  String get awardDescMidnightOil => 'Study between 12 AM and 3 AM';

  @override
  String get awardTitleEarlyRiser => 'Early Riser';

  @override
  String get awardDescEarlyRiser => 'Start a session before 7 AM';

  @override
  String get awardTitleSubjectExplorer => 'Subject Explorer';

  @override
  String get awardDescSubjectExplorer => 'Study 2 different subjects today';

  @override
  String get awardTitleNoZeroDay => 'No Zero Day';

  @override
  String get awardDescNoZeroDay => 'Log at least 1 minute of study';

  @override
  String get awardTitleTaskFinisher => 'Task Finisher';

  @override
  String get awardDescTaskFinisher => 'Complete all tasks in a session';

  @override
  String get awardTitlePerfectWeek => 'Perfect Week';

  @override
  String get awardDescPerfectWeek => 'Study 2+ hours every day for a week';

  @override
  String get awardTitleWeekendWarrior => 'Weekend Warrior';

  @override
  String get awardDescWeekendWarrior => 'Study on both Thursday and Friday';

  @override
  String get awardTitleTimeInvestorWeekly => 'Time Investor';

  @override
  String get awardDescTimeInvestorWeekly => 'Study for 10+ hours this week';

  @override
  String get awardTitleMonthlyMaster => 'Monthly Master';

  @override
  String get awardDescMonthlyMaster => '25 active days in one month';

  @override
  String get awardTitleFortyHourClub => 'Forty Hour Club';

  @override
  String get awardDescFortyHourClub => '40+ hours in one month';

  @override
  String get awardTitleSessionsBronze => 'Bronze Scholar';

  @override
  String get awardDescSessionsBronze => 'Study for 100 total hours';

  @override
  String get awardTitleSessionsSilver => 'Silver Scholar';

  @override
  String get awardDescSessionsSilver => 'Study for 300 total hours';

  @override
  String get awardTitleSessionsGold => 'Gold Scholar';

  @override
  String get awardDescSessionsGold => 'Study for 500 total hours';

  @override
  String get awardTitleSessionsLegend => 'Legendary Scholar';

  @override
  String get awardDescSessionsLegend => 'Study for 1000 total hours';

  @override
  String get awardTitleHoursBronze => '100 Hour Milestone';

  @override
  String get awardDescHoursBronze => 'Study for 100 total hours';

  @override
  String get awardTitleStreakWeek => 'Steady Rhythm';

  @override
  String get awardDescStreakWeek => '7-day study streak with 2+ hour days';

  @override
  String get awardTitlePhoenix => 'Phoenix';

  @override
  String get awardDescPhoenix => 'Resume study after a 3+ day gap';

  @override
  String get awardTitleTripleThreat => 'Triple Threat';

  @override
  String get awardDescTripleThreat => 'Session + Pomodoro + 1h focus in one day';

  @override
  String get awardTitleOverkill => 'Overkill';

  @override
  String get awardDescOverkill => 'Study 5+ hours in a single day';

  @override
  String get apply => 'Apply';

  @override
  String sessionCustomOverlaySaved(Object path) {
    return 'Custom overlay image saved to $path';
  }

  @override
  String get sessionOverlayHueTitle => 'Overlay Hue';

  @override
  String sessionHueValue(Object value) {
    return 'Hue: $value';
  }

  @override
  String get sessionFullscreen => 'Fullscreen';

  @override
  String get sessionExitFullscreen => 'Exit fullscreen';

  @override
  String sessionFocusedMinutes(Object minutes) {
    return '$minutes focused';
  }

  @override
  String sessionFocusBreakLine(Object focus, Object breakMinutes) {
    return '${focus}m focus · ${breakMinutes}m break';
  }

  @override
  String get sessionContinuousFocusMode => 'Continuous focus mode';

  @override
  String get sessionAtmosphere => 'Atmosphere';

  @override
  String get sessionAtmosphereCityTwilight => 'City Twilight';

  @override
  String get sessionAtmosphereCozyCafe => 'Cozy Cafe';

  @override
  String get sessionAtmosphereCustom => 'Custom';

  @override
  String get sessionAtmosphereOverlay => 'Overlay';

  @override
  String get sessionHideDetails => 'Hide session details';

  @override
  String get sessionShowDetails => 'Session details';

  @override
  String get sessionStatusReady => 'Ready';

  @override
  String get sessionStatusFocusing => 'Focusing';

  @override
  String get sessionStatusBreakTime => 'Break time';

  @override
  String get sessionStatusPaused => 'Paused';

  @override
  String get sessionStart => 'Start session';

  @override
  String get sessionSkipBreak => 'Skip break';

  @override
  String get sessionStopAndSave => 'Stop & Save';

  @override
  String get sessionPause => 'Pause';

  @override
  String get sessionResume => 'Resume';

  @override
  String get stopwatchTitle => 'Stopwatch';

  @override
  String get stopwatchStart => 'Start';

  @override
  String get stopwatchLap => 'Lap';

  @override
  String get stopwatchReset => 'Reset';

  @override
  String stopwatchLapNumber(Object number) {
    return 'Lap $number';
  }

  @override
  String get analyticsStatTotalTime => 'TOTAL TIME';

  @override
  String get analyticsStatDailyAvg => 'DAILY AVG';

  @override
  String get analyticsStatPeakSession => 'PEAK SESSION';

  @override
  String get analyticsStatPeakHour => 'PEAK HOUR';

  @override
  String get analyticsAm => 'AM';

  @override
  String get analyticsPm => 'PM';

  @override
  String get analyticsDailyTrendTitle => 'Daily Trend';

  @override
  String get analyticsSessionRatioTitle => 'Session Ratio';

  @override
  String get analyticsSessionRatioSubtitle => 'Optimal balance between focus and rest.';

  @override
  String analyticsFocusRatio(Object value) {
    return 'Focus ($value%)';
  }

  @override
  String analyticsBreakRatio(Object value) {
    return 'Break ($value%)';
  }

  @override
  String get analyticsSubjectBreakdownTitle => 'Subject Breakdown';

  @override
  String get analyticsNoSubjectBreakdown => 'No tags assigned to recent sessions.';

  @override
  String get analyticsSubjectBreakdownLabel => 'Subject breakdown';

  @override
  String get analyticsStateDistributionTitle => 'State Distribution';

  @override
  String get analyticsNoMoodData => 'No mood data available.';

  @override
  String get analyticsMoodDeepFlow => 'Deep Flow';

  @override
  String get analyticsMoodResistance => 'Resistance';

  @override
  String get analyticsMoodFatigue => 'Fatigue';

  @override
  String get analyticsRecentOutputTitle => 'Recent Output';

  @override
  String get analyticsViewAll => 'VIEW ALL';

  @override
  String get analyticsNoRecentOutput => 'No recent output found.';

  @override
  String get analyticsCompletedPrefix => 'COMPLETED';

  @override
  String get analyticsPeakStudyHoursTitle => 'Peak Study Hours';

  @override
  String get analyticsHeatmapTitle => 'One Year Consistency Heatmap';

  @override
  String get analyticsNoSessionsYet => 'No sessions yet';

  @override
  String analyticsStartDay(Object date) {
    return 'Start day: $date';
  }

  @override
  String get statusHubStreakRunway => 'STREAK RUNWAY';

  @override
  String get statusHubTodaySignal => 'Today\'s signal';

  @override
  String get statusHubDaysHot => 'days hot';

  @override
  String get statusHubNextCrest => 'NEXT CREST';

  @override
  String statusHubDaysToCrest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# days out',
      one: '# day out',
      zero: 'Due today',
    );
    return '$_temp0';
  }

  @override
  String statusHubPersonalBestFull(int days) {
    return 'Personal best streak · $days days';
  }

  @override
  String get statusHubLadderClearedTitle => 'LADDER CLEARED';

  @override
  String statusHubPersonalBestInline(int days) {
    return 'Personal best · $days days';
  }

  @override
  String get statusHubTierColdStart => 'Cold start';

  @override
  String get statusHubTierFirstSpark => 'First spark';

  @override
  String get statusHubTierKindlingClimb => 'Kindling climb';

  @override
  String get statusHubTierScholarPulse => 'Scholar pulse';

  @override
  String get statusHubTierDeepRhythm => 'Deep rhythm';

  @override
  String get statusHubTierMarathonMind => 'Marathon mind';

  @override
  String get statusHubTierHallOfLegends => 'Hall of legends';

  @override
  String get statusHubCkptFlavor3 => 'Kindling crest';

  @override
  String get statusHubCkptFlavor7 => 'Scholar pulse';

  @override
  String get statusHubCkptFlavor14 => 'Rhythm crest';

  @override
  String get statusHubCkptFlavor30 => 'Month forge';

  @override
  String get statusHubCkptFlavor90 => 'Season legend';

  @override
  String get statusHubCkptFlavorGeneric => 'Milestone';

  @override
  String statusHubChasePeakRunway(int days) {
    return 'Personal peak: $days-day runway. Rest, then forge a new saga.';
  }

  @override
  String statusHubChaseEncore(int goal) {
    return 'You\'ve cleared every crest on the ladder. Aim for $goal+ as your encore.';
  }

  @override
  String statusHubChaseStartToday(String flavorName, int days) {
    return 'Study today — your first crest is $flavorName at $days days in a row.';
  }

  @override
  String statusHubChaseCement(String flavorName) {
    return '$flavorName is in reach — log today to cement it.';
  }

  @override
  String statusHubChaseRemain(int count, String flavorName, int milestone) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more days to $flavorName ($milestone-day crest).',
      one: '1 more day to $flavorName ($milestone-day crest).',
    );
    return '$_temp0';
  }

  @override
  String get statusHubBodyFlow => 'Long focus today — rides the edge of challenge without overwhelm.';

  @override
  String get statusHubBodyProud => 'Streak muscle is forged — savor the grind, shield your recovery windows.';

  @override
  String get statusHubBodyBurnout => 'High volume logged — hydrate, shorten the next sprint, defend sleep.';

  @override
  String get statusHubBodyIdle => 'No deep work tracked yet — a single focused block unlocks streak fuel.';

  @override
  String get statusHubChipOptimalFocus => 'Optimal focus';

  @override
  String get statusHubChipStreakCrest => 'Streak crest';

  @override
  String get statusHubChipRestGuarded => 'Rest guarded';

  @override
  String get statusHubChipReadyIgnite => 'Ready to ignite';

  @override
  String get statusHubChipFlowRule => 'Flow ≥ 120 min today';

  @override
  String get statusHubChipFatigueRule => 'Fatigue watch >360m';

  @override
  String notif_prestudy_v1(Object subject) {
    return 'Time to study $subject. Start a focus block.';
  }

  @override
  String notif_prestudy_v2(Object subject) {
    return 'Your $subject focus block is waiting.';
  }

  @override
  String notif_prestudy_v3(Object subject) {
    return 'Keep the momentum going with $subject.';
  }

  @override
  String notif_streak_body(int count) {
    return 'Protect your $count-day streak. Log a session before midnight.';
  }

  @override
  String notif_weekly_full(int hours, int minutes, int count, String subject) {
    return '${hours}h ${minutes}m across $count sessions. Top subject: $subject.';
  }

  @override
  String get notif_weekly_empty => 'No sessions this week. Start a new streak today.';

  @override
  String notif_goal_behind(int hoursBehind, int daysLeft, Object goalName) {
    return 'You\'re ${hoursBehind}h behind on $goalName. $daysLeft days left to catch up.';
  }

  @override
  String notif_reengage_short(int days) {
    return 'It\'s been $days days. Let\'s get back to studying.';
  }

  @override
  String get notif_reengage_long => 'We miss you! Start a new session and get back on track.';

  @override
  String get notif_settings_title => 'Notifications';

  @override
  String get notif_settings_prestudy => 'Pre-Study Reminder';

  @override
  String notif_settings_prestudy_desc(Object time) {
    return 'Fire at $time · every day';
  }

  @override
  String get notif_settings_streak => 'Streak Protection';

  @override
  String get notif_settings_weekly => 'Weekly Summary';

  @override
  String get notif_settings_goal => 'Goal Progress';

  @override
  String get notif_settings_reengage => 'Re-engagement';

  @override
  String notif_settings_reengage_desc(Object time) {
    return 'After 3 days, at $time';
  }

  @override
  String get notif_settings_quiet_title => 'Do Not Disturb';

  @override
  String notif_settings_quiet_desc(Object start, Object end) {
    return 'Quiet hours: $start → $end';
  }

  @override
  String get notif_settings_quiet_start => 'Quiet Hours Start';

  @override
  String get notif_settings_quiet_end => 'Quiet Hours End';

  @override
  String get notif_settings_quiet_start_desc => 'No non-urgent notifications after this time';

  @override
  String get notif_settings_quiet_end_desc => 'Notifications resume after this time';

  @override
  String get notif_permission_title => 'Enable Notifications?';

  @override
  String get notif_permission_body => 'Study reminders help you stay consistent. We\'ll send you timely updates about your progress and streaks.';

  @override
  String get notif_permission_enable => 'Enable';

  @override
  String get notif_permission_later => 'Later';

  @override
  String get notif_denied_hint => 'Notifications are disabled. Open device settings to enable them.';

  @override
  String get notif_settings_streak_desc => 'Reminder time is chosen automatically from your streak pattern (evening).';

  @override
  String get notif_settings_goal_desc => 'Reminder time is chosen automatically from your weekly goal progress.';

  @override
  String notif_settings_weekly_desc(Object day, Object time) {
    return 'Every $day at $time';
  }

  @override
  String get notif_time_fire_at => 'Fire at';

  @override
  String get notif_day_fire_at => 'Fire on';

  @override
  String get monday => 'Monday';

  @override
  String get tuesday => 'Tuesday';

  @override
  String get wednesday => 'Wednesday';

  @override
  String get thursday => 'Thursday';

  @override
  String get friday => 'Friday';

  @override
  String get saturday => 'Saturday';

  @override
  String get sunday => 'Sunday';

  @override
  String get notif_time_weekly_summary => 'Every Sunday at';

  @override
  String get ai_coach_title => 'Your AI Coach';

  @override
  String get ai_coach_connect => 'Connect AI';

  @override
  String get ai_debrief_loading => 'Reflecting on your session…';

  @override
  String get ai_challenge_title => 'Today\'s Challenge';

  @override
  String get ai_narrative_title => 'This Week\'s Summary';

  @override
  String get ai_narrative_button => 'Generate Report';

  @override
  String get ai_narrative_loading => 'Creating your report…';

  @override
  String get ai_difficulty_title => 'Subject Analysis';

  @override
  String get ai_difficulty_button => 'Analyze My Subjects';

  @override
  String get ai_difficulty_not_enough => 'Need more sessions to analyze. Keep studying!';

  @override
  String get ai_difficulty_error => 'Could not analyze subjects right now. Try again later.';

  @override
  String get ai_settings_title => 'AI Features';

  @override
  String get ai_settings_subtitle => 'Connect Groq once, then enable the features you want.';

  @override
  String get ai_challenges_master_label => 'Challenges (overall)';

  @override
  String get ai_settings_toggles_heading => 'Per-feature AI';

  @override
  String get ai_settings_load_error => 'Could not load AI feature settings.';

  @override
  String get ai_settings_api_key => 'Groq API Key';

  @override
  String get ai_settings_api_key_hint => 'Paste your Groq API key here';

  @override
  String get ai_settings_connected => 'Connected ✓';

  @override
  String get ai_settings_show_key => 'Show';

  @override
  String get ai_settings_hide_key => 'Hide';

  @override
  String get ai_settings_get_key => 'Get a free Groq API key';

  @override
  String get ai_settings_coach => 'AI Coach';

  @override
  String get ai_settings_coach_desc => 'Daily personalized encouragement';

  @override
  String get ai_settings_challenges => 'Smart Challenges';

  @override
  String get ai_settings_challenges_desc => 'Difficulty-adjusted study suggestions';

  @override
  String get ai_settings_debrief => 'Session Debrief';

  @override
  String get ai_settings_debrief_desc => 'AI feedback after each study session';

  @override
  String get ai_settings_narrative => 'Weekly Narrative';

  @override
  String get ai_settings_narrative_desc => 'Summary of your study week';

  @override
  String get ai_settings_difficulty => 'Subject Analysis';

  @override
  String get ai_settings_difficulty_desc => 'Identify your strongest and weakest areas';

  @override
  String get ai_settings_surprise => 'Surprise Missions';

  @override
  String get ai_settings_surprise_desc => 'Random notifications for AI-generated missions';

  @override
  String ai_settings_surprise_interval(Object hours) {
    return 'Check every $hours hours';
  }

  @override
  String get ai_debrief_tap_to_dismiss => 'Tap to dismiss';

  @override
  String get ai_copy_narrative_snackbar => 'Weekly narrative copied to clipboard';

  @override
  String notifStreakBody(Object streak) {
    return 'You\'re on a $streak-day study streak. Open StudyTracker to keep it alive.';
  }

  @override
  String notifGoalBehind(Object hours, Object days, Object name) {
    return 'You\'re about ${hours}h behind your weekly goal for $name. $days day(s) left to catch up.';
  }

  @override
  String get notifReengageLong => 'It\'s been a while — even a short session today helps rebuild momentum.';

  @override
  String notifReengageShort(Object days) {
    return 'Quiet for $days day(s). Tap to log a quick study session.';
  }

  @override
  String notifPrestudyV1(Object subject) {
    return 'Upcoming focus: $subject. Preview your plan when you\'re ready.';
  }

  @override
  String notifPrestudyV2(Object subject) {
    return 'Next block: $subject. Set a small goal before you start.';
  }

  @override
  String notifPrestudyV3(Object subject) {
    return 'Time to warm up for $subject — open the timer when you\'re set.';
  }

  @override
  String get notifWeeklyEmpty => 'No sessions logged yet this week.';

  @override
  String notifWeeklyFull(Object hours, Object minutes, Object sessionCount, Object subject) {
    return 'This week so far: ${hours}h ${minutes}m across $sessionCount sessions. Top subject: $subject.';
  }

  @override
  String get dashboardDailyProgress => 'Daily Progress';

  @override
  String get dashboardLast7Days => 'Last 7 Days';

  @override
  String get dashboardToday => 'Today';

  @override
  String get dashboardStreak => 'Streak';

  @override
  String get dashboardAllTime => 'All Time';

  @override
  String get dashboardDaysToNext => 'Days to Next';
}
