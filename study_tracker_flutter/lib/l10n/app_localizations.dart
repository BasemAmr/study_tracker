import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'StudyTracker'**
  String get appTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your study environment, subjects, and preferences for deep work sessions.'**
  String get settingsSubtitle;

  /// No description provided for @saveAllSettings.
  ///
  /// In en, this message translates to:
  /// **'SAVE ALL SETTINGS'**
  String get saveAllSettings;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved successfully!'**
  String get settingsSaved;

  /// No description provided for @maintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get maintenanceTitle;

  /// No description provided for @maintenanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Compact local database and clear temporary cache files.'**
  String get maintenanceSubtitle;

  /// No description provided for @compactDatabase.
  ///
  /// In en, this message translates to:
  /// **'Compact Database (VACUUM)'**
  String get compactDatabase;

  /// No description provided for @clearAppCache.
  ///
  /// In en, this message translates to:
  /// **'Clear App Cache'**
  String get clearAppCache;

  /// No description provided for @databaseCompacted.
  ///
  /// In en, this message translates to:
  /// **'Database compacted. Reclaimed ~{mb} MB.'**
  String databaseCompacted(Object mb);

  /// No description provided for @databaseCompactFailed.
  ///
  /// In en, this message translates to:
  /// **'Database compact failed: {error}'**
  String databaseCompactFailed(Object error);

  /// No description provided for @cacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared. Removed ~{mb} MB.'**
  String cacheCleared(Object mb);

  /// No description provided for @cacheClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Cache clear failed: {error}'**
  String cacheClearFailed(Object error);

  /// No description provided for @profileCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Scholar Profile'**
  String get profileCardTitle;

  /// No description provided for @displayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'DISPLAY NAME'**
  String get displayNameLabel;

  /// No description provided for @academicLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'ACADEMIC LEVEL'**
  String get academicLevelLabel;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get languageLabel;

  /// No description provided for @scholarProfilesLabel.
  ///
  /// In en, this message translates to:
  /// **'SCHOLAR PROFILES'**
  String get scholarProfilesLabel;

  /// No description provided for @switchProfile.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get switchProfile;

  /// No description provided for @addScholar.
  ///
  /// In en, this message translates to:
  /// **'Add Scholar'**
  String get addScholar;

  /// No description provided for @addScholarTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Scholar'**
  String get addScholarTitle;

  /// No description provided for @editScholarTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Scholar'**
  String get editScholarTitle;

  /// No description provided for @displayNameField.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayNameField;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Session?'**
  String get confirmDeleteTitle;

  /// No description provided for @confirmDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this session? This action cannot be undone.'**
  String get confirmDeleteBody;

  /// No description provided for @wipeDataConfirmation.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all your study sessions, profiles, and settings. This action cannot be undone. Are you absolutely sure?'**
  String get wipeDataConfirmation;

  /// No description provided for @wipeDataAction.
  ///
  /// In en, this message translates to:
  /// **'DELETE EVERYTHING'**
  String get wipeDataAction;

  /// No description provided for @undergraduate.
  ///
  /// In en, this message translates to:
  /// **'Undergraduate'**
  String get undergraduate;

  /// No description provided for @postgraduate.
  ///
  /// In en, this message translates to:
  /// **'Postgraduate'**
  String get postgraduate;

  /// No description provided for @doctoralCandidate.
  ///
  /// In en, this message translates to:
  /// **'Doctoral Candidate'**
  String get doctoralCandidate;

  /// No description provided for @lifelongLearner.
  ///
  /// In en, this message translates to:
  /// **'Lifelong Learner'**
  String get lifelongLearner;

  /// No description provided for @studyMechanicsTitle.
  ///
  /// In en, this message translates to:
  /// **'Study Mechanics'**
  String get studyMechanicsTitle;

  /// No description provided for @dailyTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'DAILY TARGET'**
  String get dailyTargetLabel;

  /// No description provided for @focusBlockLabel.
  ///
  /// In en, this message translates to:
  /// **'FOCUS BLOCK'**
  String get focusBlockLabel;

  /// No description provided for @shortBreakLabel.
  ///
  /// In en, this message translates to:
  /// **'SHORT BREAK'**
  String get shortBreakLabel;

  /// No description provided for @hoursUnit.
  ///
  /// In en, this message translates to:
  /// **'hrs'**
  String get hoursUnit;

  /// No description provided for @minutesUnit.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minutesUnit;

  /// No description provided for @aiChallengesTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Challenges'**
  String get aiChallengesTitle;

  /// No description provided for @aiChallengesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Dynamic quizzes based on study notes.'**
  String get aiChallengesSubtitle;

  /// No description provided for @groqApiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'GROQ API KEY'**
  String get groqApiKeyLabel;

  /// No description provided for @applyKey.
  ///
  /// In en, this message translates to:
  /// **'Apply Key'**
  String get applyKey;

  /// No description provided for @apiKeySaved.
  ///
  /// In en, this message translates to:
  /// **'API key saved.'**
  String get apiKeySaved;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status:'**
  String get statusLabel;

  /// No description provided for @statusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get statusReady;

  /// No description provided for @curriculumTitle.
  ///
  /// In en, this message translates to:
  /// **'Curriculum'**
  String get curriculumTitle;

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'NEW GROUP'**
  String get newGroup;

  /// No description provided for @newSubject.
  ///
  /// In en, this message translates to:
  /// **'NEW SUBJECT'**
  String get newSubject;

  /// No description provided for @addSubjectGroup.
  ///
  /// In en, this message translates to:
  /// **'Add Subject Group'**
  String get addSubjectGroup;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @failedCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'Failed to create group: {error}'**
  String failedCreateGroup(Object error);

  /// No description provided for @addSubject.
  ///
  /// In en, this message translates to:
  /// **'Add Subject'**
  String get addSubject;

  /// No description provided for @subjectName.
  ///
  /// In en, this message translates to:
  /// **'Subject name'**
  String get subjectName;

  /// No description provided for @group.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get group;

  /// No description provided for @failedCreateSubject.
  ///
  /// In en, this message translates to:
  /// **'Failed to create subject: {error}'**
  String failedCreateSubject(Object error);

  /// No description provided for @editGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit Group'**
  String get editGroup;

  /// No description provided for @deleteGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Group?'**
  String get deleteGroupTitle;

  /// No description provided for @deleteGroupPrompt.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\" and ungroup its subjects?'**
  String deleteGroupPrompt(Object name);

  /// No description provided for @editSubject.
  ///
  /// In en, this message translates to:
  /// **'Edit Subject'**
  String get editSubject;

  /// No description provided for @deleteSubjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Subject?'**
  String get deleteSubjectTitle;

  /// No description provided for @deleteSubjectPrompt.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteSubjectPrompt(Object name);

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @editGroupMenu.
  ///
  /// In en, this message translates to:
  /// **'Edit Group'**
  String get editGroupMenu;

  /// No description provided for @deleteGroupMenu.
  ///
  /// In en, this message translates to:
  /// **'Delete Group'**
  String get deleteGroupMenu;

  /// No description provided for @noSubjectsFound.
  ///
  /// In en, this message translates to:
  /// **'No Subjects Found'**
  String get noSubjectsFound;

  /// No description provided for @noSubjectsCreateHint.
  ///
  /// In en, this message translates to:
  /// **'Create a group then add your first subject.'**
  String get noSubjectsCreateHint;

  /// No description provided for @noSubjectsAddHint.
  ///
  /// In en, this message translates to:
  /// **'Add a subject to this group to start tracking.'**
  String get noSubjectsAddHint;

  /// No description provided for @studySubject.
  ///
  /// In en, this message translates to:
  /// **'Study subject'**
  String get studySubject;

  /// No description provided for @sessionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessionsLabel;

  /// No description provided for @editSubjectMenu.
  ///
  /// In en, this message translates to:
  /// **'Edit Subject'**
  String get editSubjectMenu;

  /// No description provided for @deleteSubjectMenu.
  ///
  /// In en, this message translates to:
  /// **'Delete Subject'**
  String get deleteSubjectMenu;

  /// No description provided for @dataManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Management'**
  String get dataManagementTitle;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get exportData;

  /// No description provided for @resetProgress.
  ///
  /// In en, this message translates to:
  /// **'Reset Progress'**
  String get resetProgress;

  /// No description provided for @dangerZoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get dangerZoneTitle;

  /// No description provided for @dataWipedSuccess.
  ///
  /// In en, this message translates to:
  /// **'All data has been wiped.'**
  String get dataWipedSuccess;

  /// No description provided for @ambienceTitle.
  ///
  /// In en, this message translates to:
  /// **'Ambience'**
  String get ambienceTitle;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @forest.
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get forest;

  /// No description provided for @focusAudioTitle.
  ///
  /// In en, this message translates to:
  /// **'Focus Audio'**
  String get focusAudioTitle;

  /// No description provided for @lofiBeatsStream.
  ///
  /// In en, this message translates to:
  /// **'Lofi Beats Stream'**
  String get lofiBeatsStream;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get navSessions;

  /// No description provided for @navAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get navAnalytics;

  /// No description provided for @navAchievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get navAchievements;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @noMediaPlaying.
  ///
  /// In en, this message translates to:
  /// **'No media playing'**
  String get noMediaPlaying;

  /// No description provided for @tooltipMinimizePlayer.
  ///
  /// In en, this message translates to:
  /// **'Minimize player'**
  String get tooltipMinimizePlayer;

  /// No description provided for @tooltipHidePlayer.
  ///
  /// In en, this message translates to:
  /// **'Hide player'**
  String get tooltipHidePlayer;

  /// No description provided for @tooltipFocusAudio.
  ///
  /// In en, this message translates to:
  /// **'Focus Audio'**
  String get tooltipFocusAudio;

  /// No description provided for @dashboardLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load dashboard data'**
  String get dashboardLoadError;

  /// No description provided for @dashboardScholarFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Scholar'**
  String get dashboardScholarFallbackName;

  /// No description provided for @dashboardHello.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String dashboardHello(Object name);

  /// No description provided for @dashboardLevelLine.
  ///
  /// In en, this message translates to:
  /// **'Level {level} {rank} · {xp} XP to next level (~{sessions} sessions / ~{minutes} focus min equivalent).'**
  String dashboardLevelLine(Object level, Object rank, Object xp, Object sessions, Object minutes);

  /// No description provided for @quickStartPomodoro.
  ///
  /// In en, this message translates to:
  /// **'Quick Start Pomodoro'**
  String get quickStartPomodoro;

  /// No description provided for @quickStartLongSession.
  ///
  /// In en, this message translates to:
  /// **'Quick Start Long Session'**
  String get quickStartLongSession;

  /// No description provided for @dashboardMissionRefreshAi.
  ///
  /// In en, this message translates to:
  /// **'AI missions fetched successfully.'**
  String get dashboardMissionRefreshAi;

  /// No description provided for @dashboardMissionRefreshFallback.
  ///
  /// In en, this message translates to:
  /// **'Missions refreshed with local fallback.'**
  String get dashboardMissionRefreshFallback;

  /// No description provided for @wellbeingFlowTitle.
  ///
  /// In en, this message translates to:
  /// **'The Flow State'**
  String get wellbeingFlowTitle;

  /// No description provided for @wellbeingFlowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'OPTIMAL PERFORMANCE'**
  String get wellbeingFlowSubtitle;

  /// No description provided for @wellbeingProudTitle.
  ///
  /// In en, this message translates to:
  /// **'The Proud Scholar'**
  String get wellbeingProudTitle;

  /// No description provided for @wellbeingProudSubtitle.
  ///
  /// In en, this message translates to:
  /// **'CONSISTENT STREAK'**
  String get wellbeingProudSubtitle;

  /// No description provided for @wellbeingBurnoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Burnout Warning'**
  String get wellbeingBurnoutTitle;

  /// No description provided for @wellbeingBurnoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'REST RECOMMENDED'**
  String get wellbeingBurnoutSubtitle;

  /// No description provided for @wellbeingIdleTitle.
  ///
  /// In en, this message translates to:
  /// **'Gentle Reminder'**
  String get wellbeingIdleTitle;

  /// No description provided for @wellbeingIdleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'IDLE'**
  String get wellbeingIdleSubtitle;

  /// No description provided for @dailyIntelTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Intel'**
  String get dailyIntelTitle;

  /// No description provided for @dailyIntelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reviewing your cognitive load for today.'**
  String get dailyIntelSubtitle;

  /// No description provided for @dailyIntelDeepWork.
  ///
  /// In en, this message translates to:
  /// **'Deep Work'**
  String get dailyIntelDeepWork;

  /// No description provided for @dailyIntelFocusScore.
  ///
  /// In en, this message translates to:
  /// **'Focus Score'**
  String get dailyIntelFocusScore;

  /// No description provided for @dailyIntelStreak.
  ///
  /// In en, this message translates to:
  /// **'STREAK'**
  String get dailyIntelStreak;

  /// No description provided for @daysLabel.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get daysLabel;

  /// No description provided for @dailyObjectiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Current Objective'**
  String get dailyObjectiveTitle;

  /// No description provided for @completedLabel.
  ///
  /// In en, this message translates to:
  /// **'COMPLETED'**
  String get completedLabel;

  /// No description provided for @goalLabel.
  ///
  /// In en, this message translates to:
  /// **'GOAL'**
  String get goalLabel;

  /// No description provided for @activeMissionBadge.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE MISSION'**
  String get activeMissionBadge;

  /// No description provided for @activeMissionEta.
  ///
  /// In en, this message translates to:
  /// **'ETA: 45 MIN'**
  String get activeMissionEta;

  /// No description provided for @activeMissionRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh mission'**
  String get activeMissionRefreshTooltip;

  /// No description provided for @progressLabel.
  ///
  /// In en, this message translates to:
  /// **'PROGRESS'**
  String get progressLabel;

  /// No description provided for @consistencyGridTitle.
  ///
  /// In en, this message translates to:
  /// **'Consistency Grid'**
  String get consistencyGridTitle;

  /// No description provided for @consistencyLast14Days.
  ///
  /// In en, this message translates to:
  /// **'Last 14 Days'**
  String get consistencyLast14Days;

  /// No description provided for @lessLabel.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get lessLabel;

  /// No description provided for @moreLabel.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreLabel;

  /// No description provided for @historicalContextTitle.
  ///
  /// In en, this message translates to:
  /// **'Me vs. Past Self'**
  String get historicalContextTitle;

  /// No description provided for @historicalThisWeek.
  ///
  /// In en, this message translates to:
  /// **'THIS WEEK'**
  String get historicalThisWeek;

  /// No description provided for @historicalDeepWorkVolume.
  ///
  /// In en, this message translates to:
  /// **'DEEP WORK VOLUME'**
  String get historicalDeepWorkVolume;

  /// No description provided for @historicalLastWeek.
  ///
  /// In en, this message translates to:
  /// **'LAST WEEK'**
  String get historicalLastWeek;

  /// No description provided for @historicalAverageFocusSession.
  ///
  /// In en, this message translates to:
  /// **'AVERAGE FOCUS SESSION'**
  String get historicalAverageFocusSession;

  /// No description provided for @historicalCompletionRate.
  ///
  /// In en, this message translates to:
  /// **'COMPLETION RATE'**
  String get historicalCompletionRate;

  /// No description provided for @weekdayMonShort.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get weekdayMonShort;

  /// No description provided for @weekdayTueShort.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get weekdayTueShort;

  /// No description provided for @weekdayWedShort.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get weekdayWedShort;

  /// No description provided for @weekdayThuShort.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get weekdayThuShort;

  /// No description provided for @weekdayFriShort.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get weekdayFriShort;

  /// No description provided for @weekdaySatShort.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get weekdaySatShort;

  /// No description provided for @weekdaySunShort.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get weekdaySunShort;

  /// No description provided for @sessionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Study sessions'**
  String get sessionsSubtitle;

  /// No description provided for @logManually.
  ///
  /// In en, this message translates to:
  /// **'Log manually'**
  String get logManually;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @filtersActive.
  ///
  /// In en, this message translates to:
  /// **'Filters (active)'**
  String get filtersActive;

  /// No description provided for @historyFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'History Filters'**
  String get historyFiltersTitle;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @timerTab.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get timerTab;

  /// No description provided for @stopwatchTab.
  ///
  /// In en, this message translates to:
  /// **'Stopwatch'**
  String get stopwatchTab;

  /// No description provided for @historyTab.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTab;

  /// No description provided for @subjectsGroupsTab.
  ///
  /// In en, this message translates to:
  /// **'Subjects & Groups'**
  String get subjectsGroupsTab;

  /// No description provided for @sessionQuickStartStarted.
  ///
  /// In en, this message translates to:
  /// **'{mode} started.'**
  String sessionQuickStartStarted(Object mode);

  /// No description provided for @sessionModePomodoro.
  ///
  /// In en, this message translates to:
  /// **'Pomodoro'**
  String get sessionModePomodoro;

  /// No description provided for @sessionModeLongSession.
  ///
  /// In en, this message translates to:
  /// **'Long Session'**
  String get sessionModeLongSession;

  /// No description provided for @sessionModeManual.
  ///
  /// In en, this message translates to:
  /// **'Manual Log'**
  String get sessionModeManual;

  /// No description provided for @sessionsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load sessions'**
  String get sessionsLoadError;

  /// No description provided for @noSessionsLogged.
  ///
  /// In en, this message translates to:
  /// **'No sessions logged yet'**
  String get noSessionsLogged;

  /// No description provided for @minutesShortValue.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String minutesShortValue(Object minutes);

  /// No description provided for @searchHistory.
  ///
  /// In en, this message translates to:
  /// **'Search history'**
  String get searchHistory;

  /// No description provided for @subjectsError.
  ///
  /// In en, this message translates to:
  /// **'Subjects error'**
  String get subjectsError;

  /// No description provided for @subjectLabel.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get subjectLabel;

  /// No description provided for @allSubjects.
  ///
  /// In en, this message translates to:
  /// **'All subjects'**
  String get allSubjects;

  /// No description provided for @modeLabel.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get modeLabel;

  /// No description provided for @allModes.
  ///
  /// In en, this message translates to:
  /// **'All modes'**
  String get allModes;

  /// No description provided for @filtersFrom.
  ///
  /// In en, this message translates to:
  /// **'From {value}'**
  String filtersFrom(Object value);

  /// No description provided for @filtersTo.
  ///
  /// In en, this message translates to:
  /// **'To {value}'**
  String filtersTo(Object value);

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @anyLabel.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get anyLabel;

  /// No description provided for @logSessionManuallyTitle.
  ///
  /// In en, this message translates to:
  /// **'Log session manually'**
  String get logSessionManuallyTitle;

  /// No description provided for @subjectOptional.
  ///
  /// In en, this message translates to:
  /// **'Subject (optional)'**
  String get subjectOptional;

  /// No description provided for @generalStudy.
  ///
  /// In en, this message translates to:
  /// **'General study'**
  String get generalStudy;

  /// No description provided for @topicLabel.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get topicLabel;

  /// No description provided for @moodLabel.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get moodLabel;

  /// No description provided for @moodFocused.
  ///
  /// In en, this message translates to:
  /// **'Focused'**
  String get moodFocused;

  /// No description provided for @moodProductive.
  ///
  /// In en, this message translates to:
  /// **'Productive'**
  String get moodProductive;

  /// No description provided for @moodCalm.
  ///
  /// In en, this message translates to:
  /// **'Calm'**
  String get moodCalm;

  /// No description provided for @moodTired.
  ///
  /// In en, this message translates to:
  /// **'Tired'**
  String get moodTired;

  /// No description provided for @moodStressed.
  ///
  /// In en, this message translates to:
  /// **'Stressed'**
  String get moodStressed;

  /// No description provided for @moodDistracted.
  ///
  /// In en, this message translates to:
  /// **'Distracted'**
  String get moodDistracted;

  /// No description provided for @durationMinutesLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration (minutes)'**
  String get durationMinutesLabel;

  /// No description provided for @enterValidDuration.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid duration'**
  String get enterValidDuration;

  /// No description provided for @notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesLabel;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @analyticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review your cognitive endurance and focus metrics over the current cycle.'**
  String get analyticsSubtitle;

  /// No description provided for @achievementsPersonalGrowth.
  ///
  /// In en, this message translates to:
  /// **'Personal Growth'**
  String get achievementsPersonalGrowth;

  /// No description provided for @achievementsTabAwards.
  ///
  /// In en, this message translates to:
  /// **'Awards'**
  String get achievementsTabAwards;

  /// No description provided for @achievementsTabAiMissions.
  ///
  /// In en, this message translates to:
  /// **'AI Missions'**
  String get achievementsTabAiMissions;

  /// No description provided for @achievementsTakenAwards.
  ///
  /// In en, this message translates to:
  /// **'Taken awards: {count}'**
  String achievementsTakenAwards(Object count);

  /// No description provided for @achievementsLevelRank.
  ///
  /// In en, this message translates to:
  /// **'Lvl {level} {rank}'**
  String achievementsLevelRank(Object level, Object rank);

  /// No description provided for @achievementsUnlocked.
  ///
  /// In en, this message translates to:
  /// **'{unlocked}/{total} unlocked'**
  String achievementsUnlocked(Object unlocked, Object total);

  /// No description provided for @achievementsXpProgress.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total} XP this level ({toGo} to go)'**
  String achievementsXpProgress(Object current, Object total, Object toGo);

  /// No description provided for @achievementsFilterTaken.
  ///
  /// In en, this message translates to:
  /// **'AWARDS I TOOK'**
  String get achievementsFilterTaken;

  /// No description provided for @achievementsFilterDaily.
  ///
  /// In en, this message translates to:
  /// **'DAILY'**
  String get achievementsFilterDaily;

  /// No description provided for @achievementsFilterWeekly.
  ///
  /// In en, this message translates to:
  /// **'WEEKLY'**
  String get achievementsFilterWeekly;

  /// No description provided for @achievementsFilterMonthly.
  ///
  /// In en, this message translates to:
  /// **'MONTHLY'**
  String get achievementsFilterMonthly;

  /// No description provided for @achievementsFilterTiers.
  ///
  /// In en, this message translates to:
  /// **'TIERS'**
  String get achievementsFilterTiers;

  /// No description provided for @achievementsProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get achievementsProgress;

  /// No description provided for @achievementsRankMaster.
  ///
  /// In en, this message translates to:
  /// **'Master'**
  String get achievementsRankMaster;

  /// No description provided for @achievementsRankScholar.
  ///
  /// In en, this message translates to:
  /// **'Scholar'**
  String get achievementsRankScholar;

  /// No description provided for @achievementsRankAdept.
  ///
  /// In en, this message translates to:
  /// **'Adept'**
  String get achievementsRankAdept;

  /// No description provided for @achievementsRankLearner.
  ///
  /// In en, this message translates to:
  /// **'Learner'**
  String get achievementsRankLearner;

  /// No description provided for @achievementsRankNovice.
  ///
  /// In en, this message translates to:
  /// **'Novice'**
  String get achievementsRankNovice;

  /// No description provided for @achievementsCurrentMissions.
  ///
  /// In en, this message translates to:
  /// **'Current Missions'**
  String get achievementsCurrentMissions;

  /// No description provided for @achievementsRefreshSurprise.
  ///
  /// In en, this message translates to:
  /// **'Refresh Surprise'**
  String get achievementsRefreshSurprise;

  /// No description provided for @achievementsGroqDetected.
  ///
  /// In en, this message translates to:
  /// **'Groq key detected. Missions will use AI generation with local fallback.'**
  String get achievementsGroqDetected;

  /// No description provided for @achievementsNoGroq.
  ///
  /// In en, this message translates to:
  /// **'No Groq key found. Missions are generated locally; add or replace your key in Settings anytime.'**
  String get achievementsNoGroq;

  /// No description provided for @achievementsNoActiveMissions.
  ///
  /// In en, this message translates to:
  /// **'No active missions. Tap refresh to generate new missions.'**
  String get achievementsNoActiveMissions;

  /// No description provided for @achievementsCompletedChallenges.
  ///
  /// In en, this message translates to:
  /// **'Completed Challenges'**
  String get achievementsCompletedChallenges;

  /// No description provided for @achievementsNoCompletedMissions.
  ///
  /// In en, this message translates to:
  /// **'No completed missions yet.'**
  String get achievementsNoCompletedMissions;

  /// No description provided for @achievementsMissionRefreshed.
  ///
  /// In en, this message translates to:
  /// **'{tier} mission refreshed.'**
  String achievementsMissionRefreshed(Object tier);

  /// No description provided for @achievementsRefreshThisMission.
  ///
  /// In en, this message translates to:
  /// **'Refresh this mission'**
  String get achievementsRefreshThisMission;

  /// No description provided for @achievementsReward.
  ///
  /// In en, this message translates to:
  /// **'Reward: {reward}'**
  String achievementsReward(Object reward);

  /// No description provided for @achievementsTierDaily.
  ///
  /// In en, this message translates to:
  /// **'DAILY'**
  String get achievementsTierDaily;

  /// No description provided for @achievementsTierWeekly.
  ///
  /// In en, this message translates to:
  /// **'WEEKLY'**
  String get achievementsTierWeekly;

  /// No description provided for @achievementsTierMonthly.
  ///
  /// In en, this message translates to:
  /// **'MONTHLY'**
  String get achievementsTierMonthly;

  /// No description provided for @achievementsTierSurprise.
  ///
  /// In en, this message translates to:
  /// **'SURPRISE'**
  String get achievementsTierSurprise;

  /// No description provided for @achievementsDifficultyEasy.
  ///
  /// In en, this message translates to:
  /// **'EASY'**
  String get achievementsDifficultyEasy;

  /// No description provided for @achievementsDifficultyMedium.
  ///
  /// In en, this message translates to:
  /// **'MEDIUM'**
  String get achievementsDifficultyMedium;

  /// No description provided for @achievementsDifficultyHard.
  ///
  /// In en, this message translates to:
  /// **'HARD'**
  String get achievementsDifficultyHard;

  /// No description provided for @achievementsDifficultyExtreme.
  ///
  /// In en, this message translates to:
  /// **'EXTREME'**
  String get achievementsDifficultyExtreme;

  /// No description provided for @achievementsMetricSessions.
  ///
  /// In en, this message translates to:
  /// **'sessions'**
  String get achievementsMetricSessions;

  /// No description provided for @achievementsMetricMinutes.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get achievementsMetricMinutes;

  /// No description provided for @achievementsMetricStreak.
  ///
  /// In en, this message translates to:
  /// **'streak'**
  String get achievementsMetricStreak;

  /// No description provided for @achievementsMetricSubjects.
  ///
  /// In en, this message translates to:
  /// **'subjects'**
  String get achievementsMetricSubjects;

  /// No description provided for @achievementsMetricPomodoros.
  ///
  /// In en, this message translates to:
  /// **'pomodoros'**
  String get achievementsMetricPomodoros;

  /// No description provided for @awardTitleDailyStarter.
  ///
  /// In en, this message translates to:
  /// **'Starter'**
  String get awardTitleDailyStarter;

  /// No description provided for @awardDescDailyStarter.
  ///
  /// In en, this message translates to:
  /// **'Complete your first session today'**
  String get awardDescDailyStarter;

  /// No description provided for @awardTitleDeepWorkDaily.
  ///
  /// In en, this message translates to:
  /// **'Deep Work'**
  String get awardTitleDeepWorkDaily;

  /// No description provided for @awardDescDeepWorkDaily.
  ///
  /// In en, this message translates to:
  /// **'Study for 60 minutes today'**
  String get awardDescDeepWorkDaily;

  /// No description provided for @awardTitleSprintDaily.
  ///
  /// In en, this message translates to:
  /// **'Sprint'**
  String get awardTitleSprintDaily;

  /// No description provided for @awardDescSprintDaily.
  ///
  /// In en, this message translates to:
  /// **'Study for 2 hours today'**
  String get awardDescSprintDaily;

  /// No description provided for @awardTitlePomo5Daily.
  ///
  /// In en, this message translates to:
  /// **'Pomo-5'**
  String get awardTitlePomo5Daily;

  /// No description provided for @awardDescPomo5Daily.
  ///
  /// In en, this message translates to:
  /// **'Complete 5 Pomodoro sessions today'**
  String get awardDescPomo5Daily;

  /// No description provided for @awardTitleMidnightOil.
  ///
  /// In en, this message translates to:
  /// **'Midnight Oil'**
  String get awardTitleMidnightOil;

  /// No description provided for @awardDescMidnightOil.
  ///
  /// In en, this message translates to:
  /// **'Study between 12 AM and 3 AM'**
  String get awardDescMidnightOil;

  /// No description provided for @awardTitleEarlyRiser.
  ///
  /// In en, this message translates to:
  /// **'Early Riser'**
  String get awardTitleEarlyRiser;

  /// No description provided for @awardDescEarlyRiser.
  ///
  /// In en, this message translates to:
  /// **'Start a session before 7 AM'**
  String get awardDescEarlyRiser;

  /// No description provided for @awardTitleSubjectExplorer.
  ///
  /// In en, this message translates to:
  /// **'Subject Explorer'**
  String get awardTitleSubjectExplorer;

  /// No description provided for @awardDescSubjectExplorer.
  ///
  /// In en, this message translates to:
  /// **'Study 2 different subjects today'**
  String get awardDescSubjectExplorer;

  /// No description provided for @awardTitleNoZeroDay.
  ///
  /// In en, this message translates to:
  /// **'No Zero Day'**
  String get awardTitleNoZeroDay;

  /// No description provided for @awardDescNoZeroDay.
  ///
  /// In en, this message translates to:
  /// **'Log at least 1 minute of study'**
  String get awardDescNoZeroDay;

  /// No description provided for @awardTitleTaskFinisher.
  ///
  /// In en, this message translates to:
  /// **'Task Finisher'**
  String get awardTitleTaskFinisher;

  /// No description provided for @awardDescTaskFinisher.
  ///
  /// In en, this message translates to:
  /// **'Complete all tasks in a session'**
  String get awardDescTaskFinisher;

  /// No description provided for @awardTitlePerfectWeek.
  ///
  /// In en, this message translates to:
  /// **'Perfect Week'**
  String get awardTitlePerfectWeek;

  /// No description provided for @awardDescPerfectWeek.
  ///
  /// In en, this message translates to:
  /// **'Study 2+ hours every day for a week'**
  String get awardDescPerfectWeek;

  /// No description provided for @awardTitleWeekendWarrior.
  ///
  /// In en, this message translates to:
  /// **'Weekend Warrior'**
  String get awardTitleWeekendWarrior;

  /// No description provided for @awardDescWeekendWarrior.
  ///
  /// In en, this message translates to:
  /// **'Study on both Thursday and Friday'**
  String get awardDescWeekendWarrior;

  /// No description provided for @awardTitleTimeInvestorWeekly.
  ///
  /// In en, this message translates to:
  /// **'Time Investor'**
  String get awardTitleTimeInvestorWeekly;

  /// No description provided for @awardDescTimeInvestorWeekly.
  ///
  /// In en, this message translates to:
  /// **'Study for 10+ hours this week'**
  String get awardDescTimeInvestorWeekly;

  /// No description provided for @awardTitleMonthlyMaster.
  ///
  /// In en, this message translates to:
  /// **'Monthly Master'**
  String get awardTitleMonthlyMaster;

  /// No description provided for @awardDescMonthlyMaster.
  ///
  /// In en, this message translates to:
  /// **'25 active days in one month'**
  String get awardDescMonthlyMaster;

  /// No description provided for @awardTitleFortyHourClub.
  ///
  /// In en, this message translates to:
  /// **'Forty Hour Club'**
  String get awardTitleFortyHourClub;

  /// No description provided for @awardDescFortyHourClub.
  ///
  /// In en, this message translates to:
  /// **'40+ hours in one month'**
  String get awardDescFortyHourClub;

  /// No description provided for @awardTitleSessionsBronze.
  ///
  /// In en, this message translates to:
  /// **'Bronze Scholar'**
  String get awardTitleSessionsBronze;

  /// No description provided for @awardDescSessionsBronze.
  ///
  /// In en, this message translates to:
  /// **'Study for 100 total hours'**
  String get awardDescSessionsBronze;

  /// No description provided for @awardTitleSessionsSilver.
  ///
  /// In en, this message translates to:
  /// **'Silver Scholar'**
  String get awardTitleSessionsSilver;

  /// No description provided for @awardDescSessionsSilver.
  ///
  /// In en, this message translates to:
  /// **'Study for 300 total hours'**
  String get awardDescSessionsSilver;

  /// No description provided for @awardTitleSessionsGold.
  ///
  /// In en, this message translates to:
  /// **'Gold Scholar'**
  String get awardTitleSessionsGold;

  /// No description provided for @awardDescSessionsGold.
  ///
  /// In en, this message translates to:
  /// **'Study for 500 total hours'**
  String get awardDescSessionsGold;

  /// No description provided for @awardTitleSessionsLegend.
  ///
  /// In en, this message translates to:
  /// **'Legendary Scholar'**
  String get awardTitleSessionsLegend;

  /// No description provided for @awardDescSessionsLegend.
  ///
  /// In en, this message translates to:
  /// **'Study for 1000 total hours'**
  String get awardDescSessionsLegend;

  /// No description provided for @awardTitleHoursBronze.
  ///
  /// In en, this message translates to:
  /// **'100 Hour Milestone'**
  String get awardTitleHoursBronze;

  /// No description provided for @awardDescHoursBronze.
  ///
  /// In en, this message translates to:
  /// **'Study for 100 total hours'**
  String get awardDescHoursBronze;

  /// No description provided for @awardTitleStreakWeek.
  ///
  /// In en, this message translates to:
  /// **'Steady Rhythm'**
  String get awardTitleStreakWeek;

  /// No description provided for @awardDescStreakWeek.
  ///
  /// In en, this message translates to:
  /// **'7-day study streak with 2+ hour days'**
  String get awardDescStreakWeek;

  /// No description provided for @awardTitlePhoenix.
  ///
  /// In en, this message translates to:
  /// **'Phoenix'**
  String get awardTitlePhoenix;

  /// No description provided for @awardDescPhoenix.
  ///
  /// In en, this message translates to:
  /// **'Resume study after a 3+ day gap'**
  String get awardDescPhoenix;

  /// No description provided for @awardTitleTripleThreat.
  ///
  /// In en, this message translates to:
  /// **'Triple Threat'**
  String get awardTitleTripleThreat;

  /// No description provided for @awardDescTripleThreat.
  ///
  /// In en, this message translates to:
  /// **'Session + Pomodoro + 1h focus in one day'**
  String get awardDescTripleThreat;

  /// No description provided for @awardTitleOverkill.
  ///
  /// In en, this message translates to:
  /// **'Overkill'**
  String get awardTitleOverkill;

  /// No description provided for @awardDescOverkill.
  ///
  /// In en, this message translates to:
  /// **'Study 5+ hours in a single day'**
  String get awardDescOverkill;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @sessionCustomOverlaySaved.
  ///
  /// In en, this message translates to:
  /// **'Custom overlay image saved to {path}'**
  String sessionCustomOverlaySaved(Object path);

  /// No description provided for @sessionOverlayHueTitle.
  ///
  /// In en, this message translates to:
  /// **'Overlay Hue'**
  String get sessionOverlayHueTitle;

  /// No description provided for @sessionHueValue.
  ///
  /// In en, this message translates to:
  /// **'Hue: {value}'**
  String sessionHueValue(Object value);

  /// No description provided for @sessionFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get sessionFullscreen;

  /// No description provided for @sessionExitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit fullscreen'**
  String get sessionExitFullscreen;

  /// No description provided for @sessionFocusedMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} focused'**
  String sessionFocusedMinutes(Object minutes);

  /// No description provided for @sessionFocusBreakLine.
  ///
  /// In en, this message translates to:
  /// **'{focus}m focus · {breakMinutes}m break'**
  String sessionFocusBreakLine(Object focus, Object breakMinutes);

  /// No description provided for @sessionContinuousFocusMode.
  ///
  /// In en, this message translates to:
  /// **'Continuous focus mode'**
  String get sessionContinuousFocusMode;

  /// No description provided for @sessionAtmosphere.
  ///
  /// In en, this message translates to:
  /// **'Atmosphere'**
  String get sessionAtmosphere;

  /// No description provided for @sessionAtmosphereCityTwilight.
  ///
  /// In en, this message translates to:
  /// **'City Twilight'**
  String get sessionAtmosphereCityTwilight;

  /// No description provided for @sessionAtmosphereCozyCafe.
  ///
  /// In en, this message translates to:
  /// **'Cozy Cafe'**
  String get sessionAtmosphereCozyCafe;

  /// No description provided for @sessionAtmosphereCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get sessionAtmosphereCustom;

  /// No description provided for @sessionAtmosphereOverlay.
  ///
  /// In en, this message translates to:
  /// **'Overlay'**
  String get sessionAtmosphereOverlay;

  /// No description provided for @sessionHideDetails.
  ///
  /// In en, this message translates to:
  /// **'Hide session details'**
  String get sessionHideDetails;

  /// No description provided for @sessionShowDetails.
  ///
  /// In en, this message translates to:
  /// **'Session details'**
  String get sessionShowDetails;

  /// No description provided for @sessionStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get sessionStatusReady;

  /// No description provided for @sessionStatusFocusing.
  ///
  /// In en, this message translates to:
  /// **'Focusing'**
  String get sessionStatusFocusing;

  /// No description provided for @sessionStatusBreakTime.
  ///
  /// In en, this message translates to:
  /// **'Break time'**
  String get sessionStatusBreakTime;

  /// No description provided for @sessionStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get sessionStatusPaused;

  /// No description provided for @sessionStart.
  ///
  /// In en, this message translates to:
  /// **'Start session'**
  String get sessionStart;

  /// No description provided for @sessionSkipBreak.
  ///
  /// In en, this message translates to:
  /// **'Skip break'**
  String get sessionSkipBreak;

  /// No description provided for @sessionStopAndSave.
  ///
  /// In en, this message translates to:
  /// **'Stop & Save'**
  String get sessionStopAndSave;

  /// No description provided for @sessionPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get sessionPause;

  /// No description provided for @sessionResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get sessionResume;

  /// No description provided for @stopwatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Stopwatch'**
  String get stopwatchTitle;

  /// No description provided for @stopwatchStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get stopwatchStart;

  /// No description provided for @stopwatchLap.
  ///
  /// In en, this message translates to:
  /// **'Lap'**
  String get stopwatchLap;

  /// No description provided for @stopwatchReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get stopwatchReset;

  /// No description provided for @stopwatchLapNumber.
  ///
  /// In en, this message translates to:
  /// **'Lap {number}'**
  String stopwatchLapNumber(Object number);

  /// No description provided for @analyticsStatTotalTime.
  ///
  /// In en, this message translates to:
  /// **'TOTAL TIME'**
  String get analyticsStatTotalTime;

  /// No description provided for @analyticsStatDailyAvg.
  ///
  /// In en, this message translates to:
  /// **'DAILY AVG'**
  String get analyticsStatDailyAvg;

  /// No description provided for @analyticsStatPeakSession.
  ///
  /// In en, this message translates to:
  /// **'PEAK SESSION'**
  String get analyticsStatPeakSession;

  /// No description provided for @analyticsStatPeakHour.
  ///
  /// In en, this message translates to:
  /// **'PEAK HOUR'**
  String get analyticsStatPeakHour;

  /// No description provided for @analyticsAm.
  ///
  /// In en, this message translates to:
  /// **'AM'**
  String get analyticsAm;

  /// No description provided for @analyticsPm.
  ///
  /// In en, this message translates to:
  /// **'PM'**
  String get analyticsPm;

  /// No description provided for @analyticsDailyTrendTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Trend'**
  String get analyticsDailyTrendTitle;

  /// No description provided for @analyticsSessionRatioTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Ratio'**
  String get analyticsSessionRatioTitle;

  /// No description provided for @analyticsSessionRatioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Optimal balance between focus and rest.'**
  String get analyticsSessionRatioSubtitle;

  /// No description provided for @analyticsFocusRatio.
  ///
  /// In en, this message translates to:
  /// **'Focus ({value}%)'**
  String analyticsFocusRatio(Object value);

  /// No description provided for @analyticsBreakRatio.
  ///
  /// In en, this message translates to:
  /// **'Break ({value}%)'**
  String analyticsBreakRatio(Object value);

  /// No description provided for @analyticsSubjectBreakdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Subject Breakdown'**
  String get analyticsSubjectBreakdownTitle;

  /// No description provided for @analyticsNoSubjectBreakdown.
  ///
  /// In en, this message translates to:
  /// **'No tags assigned to recent sessions.'**
  String get analyticsNoSubjectBreakdown;

  /// No description provided for @analyticsSubjectBreakdownLabel.
  ///
  /// In en, this message translates to:
  /// **'Subject breakdown'**
  String get analyticsSubjectBreakdownLabel;

  /// No description provided for @analyticsStateDistributionTitle.
  ///
  /// In en, this message translates to:
  /// **'State Distribution'**
  String get analyticsStateDistributionTitle;

  /// No description provided for @analyticsNoMoodData.
  ///
  /// In en, this message translates to:
  /// **'No mood data available.'**
  String get analyticsNoMoodData;

  /// No description provided for @analyticsMoodDeepFlow.
  ///
  /// In en, this message translates to:
  /// **'Deep Flow'**
  String get analyticsMoodDeepFlow;

  /// No description provided for @analyticsMoodResistance.
  ///
  /// In en, this message translates to:
  /// **'Resistance'**
  String get analyticsMoodResistance;

  /// No description provided for @analyticsMoodFatigue.
  ///
  /// In en, this message translates to:
  /// **'Fatigue'**
  String get analyticsMoodFatigue;

  /// No description provided for @analyticsRecentOutputTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Output'**
  String get analyticsRecentOutputTitle;

  /// No description provided for @analyticsViewAll.
  ///
  /// In en, this message translates to:
  /// **'VIEW ALL'**
  String get analyticsViewAll;

  /// No description provided for @analyticsNoRecentOutput.
  ///
  /// In en, this message translates to:
  /// **'No recent output found.'**
  String get analyticsNoRecentOutput;

  /// No description provided for @analyticsCompletedPrefix.
  ///
  /// In en, this message translates to:
  /// **'COMPLETED'**
  String get analyticsCompletedPrefix;

  /// No description provided for @analyticsPeakStudyHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'Peak Study Hours'**
  String get analyticsPeakStudyHoursTitle;

  /// No description provided for @analyticsHeatmapTitle.
  ///
  /// In en, this message translates to:
  /// **'One Year Consistency Heatmap'**
  String get analyticsHeatmapTitle;

  /// No description provided for @analyticsNoSessionsYet.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet'**
  String get analyticsNoSessionsYet;

  /// No description provided for @analyticsStartDay.
  ///
  /// In en, this message translates to:
  /// **'Start day: {date}'**
  String analyticsStartDay(Object date);

  /// No description provided for @statusHubStreakRunway.
  ///
  /// In en, this message translates to:
  /// **'STREAK RUNWAY'**
  String get statusHubStreakRunway;

  /// No description provided for @statusHubTodaySignal.
  ///
  /// In en, this message translates to:
  /// **'Today\'s signal'**
  String get statusHubTodaySignal;

  /// No description provided for @statusHubDaysHot.
  ///
  /// In en, this message translates to:
  /// **'days hot'**
  String get statusHubDaysHot;

  /// No description provided for @statusHubNextCrest.
  ///
  /// In en, this message translates to:
  /// **'NEXT CREST'**
  String get statusHubNextCrest;

  /// No description provided for @statusHubDaysToCrest.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Due today} one{# day out} other{# days out}}'**
  String statusHubDaysToCrest(int count);

  /// No description provided for @statusHubPersonalBestFull.
  ///
  /// In en, this message translates to:
  /// **'Personal best streak · {days} days'**
  String statusHubPersonalBestFull(int days);

  /// No description provided for @statusHubLadderClearedTitle.
  ///
  /// In en, this message translates to:
  /// **'LADDER CLEARED'**
  String get statusHubLadderClearedTitle;

  /// No description provided for @statusHubPersonalBestInline.
  ///
  /// In en, this message translates to:
  /// **'Personal best · {days} days'**
  String statusHubPersonalBestInline(int days);

  /// No description provided for @statusHubTierColdStart.
  ///
  /// In en, this message translates to:
  /// **'Cold start'**
  String get statusHubTierColdStart;

  /// No description provided for @statusHubTierFirstSpark.
  ///
  /// In en, this message translates to:
  /// **'First spark'**
  String get statusHubTierFirstSpark;

  /// No description provided for @statusHubTierKindlingClimb.
  ///
  /// In en, this message translates to:
  /// **'Kindling climb'**
  String get statusHubTierKindlingClimb;

  /// No description provided for @statusHubTierScholarPulse.
  ///
  /// In en, this message translates to:
  /// **'Scholar pulse'**
  String get statusHubTierScholarPulse;

  /// No description provided for @statusHubTierDeepRhythm.
  ///
  /// In en, this message translates to:
  /// **'Deep rhythm'**
  String get statusHubTierDeepRhythm;

  /// No description provided for @statusHubTierMarathonMind.
  ///
  /// In en, this message translates to:
  /// **'Marathon mind'**
  String get statusHubTierMarathonMind;

  /// No description provided for @statusHubTierHallOfLegends.
  ///
  /// In en, this message translates to:
  /// **'Hall of legends'**
  String get statusHubTierHallOfLegends;

  /// No description provided for @statusHubCkptFlavor3.
  ///
  /// In en, this message translates to:
  /// **'Kindling crest'**
  String get statusHubCkptFlavor3;

  /// No description provided for @statusHubCkptFlavor7.
  ///
  /// In en, this message translates to:
  /// **'Scholar pulse'**
  String get statusHubCkptFlavor7;

  /// No description provided for @statusHubCkptFlavor14.
  ///
  /// In en, this message translates to:
  /// **'Rhythm crest'**
  String get statusHubCkptFlavor14;

  /// No description provided for @statusHubCkptFlavor30.
  ///
  /// In en, this message translates to:
  /// **'Month forge'**
  String get statusHubCkptFlavor30;

  /// No description provided for @statusHubCkptFlavor90.
  ///
  /// In en, this message translates to:
  /// **'Season legend'**
  String get statusHubCkptFlavor90;

  /// No description provided for @statusHubCkptFlavorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Milestone'**
  String get statusHubCkptFlavorGeneric;

  /// No description provided for @statusHubChasePeakRunway.
  ///
  /// In en, this message translates to:
  /// **'Personal peak: {days}-day runway. Rest, then forge a new saga.'**
  String statusHubChasePeakRunway(int days);

  /// No description provided for @statusHubChaseEncore.
  ///
  /// In en, this message translates to:
  /// **'You\'ve cleared every crest on the ladder. Aim for {goal}+ as your encore.'**
  String statusHubChaseEncore(int goal);

  /// No description provided for @statusHubChaseStartToday.
  ///
  /// In en, this message translates to:
  /// **'Study today — your first crest is {flavorName} at {days} days in a row.'**
  String statusHubChaseStartToday(String flavorName, int days);

  /// No description provided for @statusHubChaseCement.
  ///
  /// In en, this message translates to:
  /// **'{flavorName} is in reach — log today to cement it.'**
  String statusHubChaseCement(String flavorName);

  /// No description provided for @statusHubChaseRemain.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 more day to {flavorName} ({milestone}-day crest).} other{{count} more days to {flavorName} ({milestone}-day crest).}}'**
  String statusHubChaseRemain(int count, String flavorName, int milestone);

  /// No description provided for @statusHubBodyFlow.
  ///
  /// In en, this message translates to:
  /// **'Long focus today — rides the edge of challenge without overwhelm.'**
  String get statusHubBodyFlow;

  /// No description provided for @statusHubBodyProud.
  ///
  /// In en, this message translates to:
  /// **'Streak muscle is forged — savor the grind, shield your recovery windows.'**
  String get statusHubBodyProud;

  /// No description provided for @statusHubBodyBurnout.
  ///
  /// In en, this message translates to:
  /// **'High volume logged — hydrate, shorten the next sprint, defend sleep.'**
  String get statusHubBodyBurnout;

  /// No description provided for @statusHubBodyIdle.
  ///
  /// In en, this message translates to:
  /// **'No deep work tracked yet — a single focused block unlocks streak fuel.'**
  String get statusHubBodyIdle;

  /// No description provided for @statusHubChipOptimalFocus.
  ///
  /// In en, this message translates to:
  /// **'Optimal focus'**
  String get statusHubChipOptimalFocus;

  /// No description provided for @statusHubChipStreakCrest.
  ///
  /// In en, this message translates to:
  /// **'Streak crest'**
  String get statusHubChipStreakCrest;

  /// No description provided for @statusHubChipRestGuarded.
  ///
  /// In en, this message translates to:
  /// **'Rest guarded'**
  String get statusHubChipRestGuarded;

  /// No description provided for @statusHubChipReadyIgnite.
  ///
  /// In en, this message translates to:
  /// **'Ready to ignite'**
  String get statusHubChipReadyIgnite;

  /// No description provided for @statusHubChipFlowRule.
  ///
  /// In en, this message translates to:
  /// **'Flow ≥ 120 min today'**
  String get statusHubChipFlowRule;

  /// No description provided for @statusHubChipFatigueRule.
  ///
  /// In en, this message translates to:
  /// **'Fatigue watch >360m'**
  String get statusHubChipFatigueRule;

  /// No description provided for @notif_prestudy_v1.
  ///
  /// In en, this message translates to:
  /// **'Time to study {subject}. Start a focus block.'**
  String notif_prestudy_v1(Object subject);

  /// No description provided for @notif_prestudy_v2.
  ///
  /// In en, this message translates to:
  /// **'Your {subject} focus block is waiting.'**
  String notif_prestudy_v2(Object subject);

  /// No description provided for @notif_prestudy_v3.
  ///
  /// In en, this message translates to:
  /// **'Keep the momentum going with {subject}.'**
  String notif_prestudy_v3(Object subject);

  /// No description provided for @notif_streak_body.
  ///
  /// In en, this message translates to:
  /// **'Protect your {count}-day streak. Log a session before midnight.'**
  String notif_streak_body(int count);

  /// No description provided for @notif_weekly_full.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m across {count} sessions. Top subject: {subject}.'**
  String notif_weekly_full(int hours, int minutes, int count, String subject);

  /// No description provided for @notif_weekly_empty.
  ///
  /// In en, this message translates to:
  /// **'No sessions this week. Start a new streak today.'**
  String get notif_weekly_empty;

  /// No description provided for @notif_goal_behind.
  ///
  /// In en, this message translates to:
  /// **'You\'re {hoursBehind}h behind on {goalName}. {daysLeft} days left to catch up.'**
  String notif_goal_behind(int hoursBehind, int daysLeft, Object goalName);

  /// No description provided for @notif_reengage_short.
  ///
  /// In en, this message translates to:
  /// **'It\'s been {days} days. Let\'s get back to studying.'**
  String notif_reengage_short(int days);

  /// No description provided for @notif_reengage_long.
  ///
  /// In en, this message translates to:
  /// **'We miss you! Start a new session and get back on track.'**
  String get notif_reengage_long;

  /// No description provided for @notif_settings_title.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notif_settings_title;

  /// No description provided for @notif_settings_prestudy.
  ///
  /// In en, this message translates to:
  /// **'Pre-Study Reminder'**
  String get notif_settings_prestudy;

  /// No description provided for @notif_settings_prestudy_desc.
  ///
  /// In en, this message translates to:
  /// **'Fire at {time} · every day'**
  String notif_settings_prestudy_desc(Object time);

  /// No description provided for @notif_settings_streak.
  ///
  /// In en, this message translates to:
  /// **'Streak Protection'**
  String get notif_settings_streak;

  /// No description provided for @notif_settings_weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly Summary'**
  String get notif_settings_weekly;

  /// No description provided for @notif_settings_goal.
  ///
  /// In en, this message translates to:
  /// **'Goal Progress'**
  String get notif_settings_goal;

  /// No description provided for @notif_settings_reengage.
  ///
  /// In en, this message translates to:
  /// **'Re-engagement'**
  String get notif_settings_reengage;

  /// No description provided for @notif_settings_reengage_desc.
  ///
  /// In en, this message translates to:
  /// **'After 3 days, at {time}'**
  String notif_settings_reengage_desc(Object time);

  /// No description provided for @notif_settings_quiet_title.
  ///
  /// In en, this message translates to:
  /// **'Do Not Disturb'**
  String get notif_settings_quiet_title;

  /// No description provided for @notif_settings_quiet_desc.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours: {start} → {end}'**
  String notif_settings_quiet_desc(Object start, Object end);

  /// No description provided for @notif_settings_quiet_start.
  ///
  /// In en, this message translates to:
  /// **'Quiet Hours Start'**
  String get notif_settings_quiet_start;

  /// No description provided for @notif_settings_quiet_end.
  ///
  /// In en, this message translates to:
  /// **'Quiet Hours End'**
  String get notif_settings_quiet_end;

  /// No description provided for @notif_settings_quiet_start_desc.
  ///
  /// In en, this message translates to:
  /// **'No non-urgent notifications after this time'**
  String get notif_settings_quiet_start_desc;

  /// No description provided for @notif_settings_quiet_end_desc.
  ///
  /// In en, this message translates to:
  /// **'Notifications resume after this time'**
  String get notif_settings_quiet_end_desc;

  /// No description provided for @notif_permission_title.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications?'**
  String get notif_permission_title;

  /// No description provided for @notif_permission_body.
  ///
  /// In en, this message translates to:
  /// **'Study reminders help you stay consistent. We\'ll send you timely updates about your progress and streaks.'**
  String get notif_permission_body;

  /// No description provided for @notif_permission_enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get notif_permission_enable;

  /// No description provided for @notif_permission_later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get notif_permission_later;

  /// No description provided for @notif_denied_hint.
  ///
  /// In en, this message translates to:
  /// **'Notifications are disabled. Open device settings to enable them.'**
  String get notif_denied_hint;

  /// No description provided for @notif_settings_streak_desc.
  ///
  /// In en, this message translates to:
  /// **'Reminder time is chosen automatically from your streak pattern (evening).'**
  String get notif_settings_streak_desc;

  /// No description provided for @notif_settings_goal_desc.
  ///
  /// In en, this message translates to:
  /// **'Reminder time is chosen automatically from your weekly goal progress.'**
  String get notif_settings_goal_desc;

  /// No description provided for @notif_settings_weekly_desc.
  ///
  /// In en, this message translates to:
  /// **'Every {day} at {time}'**
  String notif_settings_weekly_desc(Object day, Object time);

  /// No description provided for @notif_time_fire_at.
  ///
  /// In en, this message translates to:
  /// **'Fire at'**
  String get notif_time_fire_at;

  /// No description provided for @notif_day_fire_at.
  ///
  /// In en, this message translates to:
  /// **'Fire on'**
  String get notif_day_fire_at;

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// No description provided for @notif_time_weekly_summary.
  ///
  /// In en, this message translates to:
  /// **'Every Sunday at'**
  String get notif_time_weekly_summary;

  /// No description provided for @ai_coach_title.
  ///
  /// In en, this message translates to:
  /// **'Your AI Coach'**
  String get ai_coach_title;

  /// No description provided for @ai_coach_connect.
  ///
  /// In en, this message translates to:
  /// **'Connect AI'**
  String get ai_coach_connect;

  /// No description provided for @ai_debrief_loading.
  ///
  /// In en, this message translates to:
  /// **'Reflecting on your session…'**
  String get ai_debrief_loading;

  /// No description provided for @ai_challenge_title.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Challenge'**
  String get ai_challenge_title;

  /// No description provided for @ai_narrative_title.
  ///
  /// In en, this message translates to:
  /// **'This Week\'s Summary'**
  String get ai_narrative_title;

  /// No description provided for @ai_narrative_button.
  ///
  /// In en, this message translates to:
  /// **'Generate Report'**
  String get ai_narrative_button;

  /// No description provided for @ai_narrative_loading.
  ///
  /// In en, this message translates to:
  /// **'Creating your report…'**
  String get ai_narrative_loading;

  /// No description provided for @ai_difficulty_title.
  ///
  /// In en, this message translates to:
  /// **'Subject Analysis'**
  String get ai_difficulty_title;

  /// No description provided for @ai_difficulty_button.
  ///
  /// In en, this message translates to:
  /// **'Analyze My Subjects'**
  String get ai_difficulty_button;

  /// No description provided for @ai_difficulty_not_enough.
  ///
  /// In en, this message translates to:
  /// **'Need more sessions to analyze. Keep studying!'**
  String get ai_difficulty_not_enough;

  /// No description provided for @ai_difficulty_error.
  ///
  /// In en, this message translates to:
  /// **'Could not analyze subjects right now. Try again later.'**
  String get ai_difficulty_error;

  /// No description provided for @ai_settings_title.
  ///
  /// In en, this message translates to:
  /// **'AI Features'**
  String get ai_settings_title;

  /// No description provided for @ai_settings_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect Groq once, then enable the features you want.'**
  String get ai_settings_subtitle;

  /// No description provided for @ai_challenges_master_label.
  ///
  /// In en, this message translates to:
  /// **'Challenges (overall)'**
  String get ai_challenges_master_label;

  /// No description provided for @ai_settings_toggles_heading.
  ///
  /// In en, this message translates to:
  /// **'Per-feature AI'**
  String get ai_settings_toggles_heading;

  /// No description provided for @ai_settings_load_error.
  ///
  /// In en, this message translates to:
  /// **'Could not load AI feature settings.'**
  String get ai_settings_load_error;

  /// No description provided for @ai_settings_api_key.
  ///
  /// In en, this message translates to:
  /// **'Groq API Key'**
  String get ai_settings_api_key;

  /// No description provided for @ai_settings_api_key_hint.
  ///
  /// In en, this message translates to:
  /// **'Paste your Groq API key here'**
  String get ai_settings_api_key_hint;

  /// No description provided for @ai_settings_connected.
  ///
  /// In en, this message translates to:
  /// **'Connected ✓'**
  String get ai_settings_connected;

  /// No description provided for @ai_settings_show_key.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get ai_settings_show_key;

  /// No description provided for @ai_settings_hide_key.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get ai_settings_hide_key;

  /// No description provided for @ai_settings_get_key.
  ///
  /// In en, this message translates to:
  /// **'Get a free Groq API key'**
  String get ai_settings_get_key;

  /// No description provided for @ai_settings_coach.
  ///
  /// In en, this message translates to:
  /// **'AI Coach'**
  String get ai_settings_coach;

  /// No description provided for @ai_settings_coach_desc.
  ///
  /// In en, this message translates to:
  /// **'Daily personalized encouragement'**
  String get ai_settings_coach_desc;

  /// No description provided for @ai_settings_challenges.
  ///
  /// In en, this message translates to:
  /// **'Smart Challenges'**
  String get ai_settings_challenges;

  /// No description provided for @ai_settings_challenges_desc.
  ///
  /// In en, this message translates to:
  /// **'Difficulty-adjusted study suggestions'**
  String get ai_settings_challenges_desc;

  /// No description provided for @ai_settings_debrief.
  ///
  /// In en, this message translates to:
  /// **'Session Debrief'**
  String get ai_settings_debrief;

  /// No description provided for @ai_settings_debrief_desc.
  ///
  /// In en, this message translates to:
  /// **'AI feedback after each study session'**
  String get ai_settings_debrief_desc;

  /// No description provided for @ai_settings_narrative.
  ///
  /// In en, this message translates to:
  /// **'Weekly Narrative'**
  String get ai_settings_narrative;

  /// No description provided for @ai_settings_narrative_desc.
  ///
  /// In en, this message translates to:
  /// **'Summary of your study week'**
  String get ai_settings_narrative_desc;

  /// No description provided for @ai_settings_difficulty.
  ///
  /// In en, this message translates to:
  /// **'Subject Analysis'**
  String get ai_settings_difficulty;

  /// No description provided for @ai_settings_difficulty_desc.
  ///
  /// In en, this message translates to:
  /// **'Identify your strongest and weakest areas'**
  String get ai_settings_difficulty_desc;

  /// No description provided for @ai_settings_surprise.
  ///
  /// In en, this message translates to:
  /// **'Surprise Missions'**
  String get ai_settings_surprise;

  /// No description provided for @ai_settings_surprise_desc.
  ///
  /// In en, this message translates to:
  /// **'Random notifications for AI-generated missions'**
  String get ai_settings_surprise_desc;

  /// No description provided for @ai_settings_surprise_interval.
  ///
  /// In en, this message translates to:
  /// **'Check every {hours} hours'**
  String ai_settings_surprise_interval(Object hours);

  /// No description provided for @ai_debrief_tap_to_dismiss.
  ///
  /// In en, this message translates to:
  /// **'Tap to dismiss'**
  String get ai_debrief_tap_to_dismiss;

  /// No description provided for @ai_copy_narrative_snackbar.
  ///
  /// In en, this message translates to:
  /// **'Weekly narrative copied to clipboard'**
  String get ai_copy_narrative_snackbar;

  /// No description provided for @notifStreakBody.
  ///
  /// In en, this message translates to:
  /// **'You\'re on a {streak}-day study streak. Open StudyTracker to keep it alive.'**
  String notifStreakBody(Object streak);

  /// No description provided for @notifGoalBehind.
  ///
  /// In en, this message translates to:
  /// **'You\'re about {hours}h behind your weekly goal for {name}. {days} day(s) left to catch up.'**
  String notifGoalBehind(Object hours, Object days, Object name);

  /// No description provided for @notifReengageLong.
  ///
  /// In en, this message translates to:
  /// **'It\'s been a while — even a short session today helps rebuild momentum.'**
  String get notifReengageLong;

  /// No description provided for @notifReengageShort.
  ///
  /// In en, this message translates to:
  /// **'Quiet for {days} day(s). Tap to log a quick study session.'**
  String notifReengageShort(Object days);

  /// No description provided for @notifPrestudyV1.
  ///
  /// In en, this message translates to:
  /// **'Upcoming focus: {subject}. Preview your plan when you\'re ready.'**
  String notifPrestudyV1(Object subject);

  /// No description provided for @notifPrestudyV2.
  ///
  /// In en, this message translates to:
  /// **'Next block: {subject}. Set a small goal before you start.'**
  String notifPrestudyV2(Object subject);

  /// No description provided for @notifPrestudyV3.
  ///
  /// In en, this message translates to:
  /// **'Time to warm up for {subject} — open the timer when you\'re set.'**
  String notifPrestudyV3(Object subject);

  /// No description provided for @notifWeeklyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sessions logged yet this week.'**
  String get notifWeeklyEmpty;

  /// No description provided for @notifWeeklyFull.
  ///
  /// In en, this message translates to:
  /// **'This week so far: {hours}h {minutes}m across {sessionCount} sessions. Top subject: {subject}.'**
  String notifWeeklyFull(Object hours, Object minutes, Object sessionCount, Object subject);

  /// No description provided for @dashboardDailyProgress.
  ///
  /// In en, this message translates to:
  /// **'Daily Progress'**
  String get dashboardDailyProgress;

  /// No description provided for @dashboardLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 Days'**
  String get dashboardLast7Days;

  /// No description provided for @dashboardToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dashboardToday;

  /// No description provided for @dashboardStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get dashboardStreak;

  /// No description provided for @dashboardAllTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get dashboardAllTime;

  /// No description provided for @dashboardDaysToNext.
  ///
  /// In en, this message translates to:
  /// **'Days to Next'**
  String get dashboardDaysToNext;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar': return AppLocalizationsAr();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
