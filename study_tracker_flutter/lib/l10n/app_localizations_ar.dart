// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'متتبع الدراسة';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsSubtitle => 'نظّم بيئة الدراسة والمواد الدراسية وتفضيلات جلسات التركيز العميق.';

  @override
  String get saveAllSettings => 'حفظ كل الإعدادات';

  @override
  String get settingsSaved => 'تم حفظ الإعدادات بنجاح!';

  @override
  String get maintenanceTitle => 'الصيانة';

  @override
  String get maintenanceSubtitle => 'اضغط قاعدة البيانات المحلية وامسح ملفات التخزين المؤقت المؤقتة.';

  @override
  String get compactDatabase => 'ضغط قاعدة البيانات (VACUUM)';

  @override
  String get clearAppCache => 'مسح ذاكرة التطبيق المؤقتة';

  @override
  String databaseCompacted(Object mb) {
    return 'تم ضغط قاعدة البيانات. تم استرجاع حوالي $mb ميجابايت.';
  }

  @override
  String databaseCompactFailed(Object error) {
    return 'فشل ضغط قاعدة البيانات: $error';
  }

  @override
  String cacheCleared(Object mb) {
    return 'تم مسح الذاكرة المؤقتة. تمت إزالة حوالي $mb ميجابايت.';
  }

  @override
  String cacheClearFailed(Object error) {
    return 'فشل مسح الذاكرة المؤقتة: $error';
  }

  @override
  String get profileCardTitle => 'ملف الباحث';

  @override
  String get displayNameLabel => 'الاسم الظاهر';

  @override
  String get academicLevelLabel => 'المستوى الأكاديمي';

  @override
  String get languageLabel => 'اللغة';

  @override
  String get scholarProfilesLabel => 'ملفات الباحثين';

  @override
  String get switchProfile => 'تبديل';

  @override
  String get addScholar => 'إضافة باحث';

  @override
  String get addScholarTitle => 'إضافة باحث';

  @override
  String get editScholarTitle => 'تعديل الباحث';

  @override
  String get displayNameField => 'الاسم الظاهر';

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String get delete => 'حذف';

  @override
  String get confirmDeleteTitle => 'حذف الجلسة؟';

  @override
  String get confirmDeleteBody => 'لا يمكن التراجع عن هذا الإجراء. هل تريد إزالة هذه الجلسة الدراسية من السجل؟';

  @override
  String get wipeDataConfirmation => 'هل أنت متأكد أنك تريد حذف كل البيانات؟ سيؤدي هذا إلى إزالة جميع الملفات الشخصية والجلسات والإعدادات. لا يمكن التراجع عن هذا.';

  @override
  String get wipeDataAction => 'مسح كل شيء';

  @override
  String get undergraduate => 'بكالوريوس';

  @override
  String get postgraduate => 'دراسات عليا';

  @override
  String get doctoralCandidate => 'مرشح دكتوراه';

  @override
  String get lifelongLearner => 'متعلم مدى الحياة';

  @override
  String get studyMechanicsTitle => 'آليات الدراسة';

  @override
  String get dailyTargetLabel => 'الهدف اليومي';

  @override
  String get focusBlockLabel => 'كتلة التركيز';

  @override
  String get shortBreakLabel => 'استراحة قصيرة';

  @override
  String get hoursUnit => 'س';

  @override
  String get minutesUnit => 'د';

  @override
  String get aiChallengesTitle => 'تحديات الذكاء الاصطناعي';

  @override
  String get aiChallengesSubtitle => 'اختبارات ديناميكية مبنية على ملاحظات الدراسة.';

  @override
  String get groqApiKeyLabel => 'مفتاح GROQ API';

  @override
  String get applyKey => 'تطبيق المفتاح';

  @override
  String get apiKeySaved => 'تم حفظ مفتاح API.';

  @override
  String get statusLabel => 'الحالة:';

  @override
  String get statusReady => 'جاهز';

  @override
  String get curriculumTitle => 'المنهج';

  @override
  String get newGroup => 'مجموعة جديدة';

  @override
  String get newSubject => 'مادة جديدة';

  @override
  String get addSubjectGroup => 'إضافة مجموعة مواد';

  @override
  String get groupName => 'اسم المجموعة';

  @override
  String get create => 'إنشاء';

  @override
  String failedCreateGroup(Object error) {
    return 'فشل إنشاء المجموعة: $error';
  }

  @override
  String get addSubject => 'إضافة مادة';

  @override
  String get subjectName => 'اسم المادة';

  @override
  String get group => 'المجموعة';

  @override
  String failedCreateSubject(Object error) {
    return 'فشل إنشاء المادة: $error';
  }

  @override
  String get editGroup => 'تعديل المجموعة';

  @override
  String get deleteGroupTitle => 'حذف المجموعة؟';

  @override
  String deleteGroupPrompt(Object name) {
    return 'حذف \"$name\" وإلغاء تجميع موادها؟';
  }

  @override
  String get editSubject => 'تعديل المادة';

  @override
  String get deleteSubjectTitle => 'حذف المادة؟';

  @override
  String deleteSubjectPrompt(Object name) {
    return 'حذف \"$name\"؟';
  }

  @override
  String get select => 'اختيار';

  @override
  String get editGroupMenu => 'تعديل المجموعة';

  @override
  String get deleteGroupMenu => 'حذف المجموعة';

  @override
  String get noSubjectsFound => 'لا توجد مواد';

  @override
  String get noSubjectsCreateHint => 'أنشئ مجموعة ثم أضف أول مادة.';

  @override
  String get noSubjectsAddHint => 'أضف مادة إلى هذه المجموعة لبدء التتبع.';

  @override
  String get studySubject => 'مادة دراسية';

  @override
  String get sessionsLabel => 'الجلسات';

  @override
  String get editSubjectMenu => 'تعديل المادة';

  @override
  String get deleteSubjectMenu => 'حذف المادة';

  @override
  String get dataManagementTitle => 'إدارة البيانات';

  @override
  String get exportData => 'تصدير البيانات';

  @override
  String get resetProgress => 'إعادة تعيين التقدم';

  @override
  String get dangerZoneTitle => 'Danger Zone';

  @override
  String get dataWipedSuccess => 'All data has been wiped.';

  @override
  String get ambienceTitle => 'الأجواء';

  @override
  String get library => 'المكتبة';

  @override
  String get forest => 'الغابة';

  @override
  String get focusAudioTitle => 'صوت التركيز';

  @override
  String get lofiBeatsStream => 'بث موسيقى لوفاي';

  @override
  String get volume => 'الصوت';

  @override
  String get navDashboard => 'لوحة التحكم';

  @override
  String get navSessions => 'الجلسات';

  @override
  String get navAnalytics => 'التحليلات';

  @override
  String get navAchievements => 'الإنجازات';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get noMediaPlaying => 'لا يوجد تشغيل صوتي';

  @override
  String get tooltipMinimizePlayer => 'تصغير المشغل';

  @override
  String get tooltipHidePlayer => 'إخفاء المشغل';

  @override
  String get tooltipFocusAudio => 'صوت التركيز';

  @override
  String get dashboardLoadError => 'تعذر تحميل بيانات لوحة التحكم';

  @override
  String get dashboardScholarFallbackName => 'باحث';

  @override
  String dashboardHello(Object name) {
    return 'مرحباً، $name';
  }

  @override
  String dashboardLevelLine(Object level, Object rank, Object xp, Object sessions, Object minutes) {
    return 'المستوى $level $rank · متبقي $xp نقطة خبرة للمستوى التالي (حوالي $sessions جلسات / ما يعادل $minutes دقيقة تركيز).';
  }

  @override
  String get quickStartPomodoro => 'بدء بومودورو سريع';

  @override
  String get quickStartLongSession => 'بدء جلسة طويلة سريعة';

  @override
  String get dashboardMissionRefreshAi => 'تم جلب مهام الذكاء الاصطناعي بنجاح.';

  @override
  String get dashboardMissionRefreshFallback => 'تم تحديث المهام بالاعتماد المحلي البديل.';

  @override
  String get wellbeingFlowTitle => 'حالة التدفق';

  @override
  String get wellbeingFlowSubtitle => 'أداء مثالي';

  @override
  String get wellbeingProudTitle => 'الباحث المثابر';

  @override
  String get wellbeingProudSubtitle => 'سلسلة ثابتة';

  @override
  String get wellbeingBurnoutTitle => 'تحذير إرهاق';

  @override
  String get wellbeingBurnoutSubtitle => 'يوصى بالراحة';

  @override
  String get wellbeingIdleTitle => 'تذكير لطيف';

  @override
  String get wellbeingIdleSubtitle => 'خامل';

  @override
  String get dailyIntelTitle => 'مؤشرات اليوم';

  @override
  String get dailyIntelSubtitle => 'مراجعة العبء الذهني لليوم.';

  @override
  String get dailyIntelDeepWork => 'العمل العميق';

  @override
  String get dailyIntelFocusScore => 'درجة التركيز';

  @override
  String get dailyIntelStreak => 'السلسلة';

  @override
  String get daysLabel => 'أيام';

  @override
  String get dailyObjectiveTitle => 'الهدف الحالي';

  @override
  String get completedLabel => 'مكتمل';

  @override
  String get goalLabel => 'الهدف';

  @override
  String get activeMissionBadge => 'المهمة النشطة';

  @override
  String get activeMissionEta => 'الوقت المتوقع: 45 دقيقة';

  @override
  String get activeMissionRefreshTooltip => 'تحديث المهمة';

  @override
  String get progressLabel => 'التقدم';

  @override
  String get consistencyGridTitle => 'شبكة الاستمرارية';

  @override
  String get consistencyLast14Days => 'آخر 14 يوماً';

  @override
  String get lessLabel => 'أقل';

  @override
  String get moreLabel => 'أكثر';

  @override
  String get historicalContextTitle => 'أنا مقابل نفسي السابقة';

  @override
  String get historicalThisWeek => 'هذا الأسبوع';

  @override
  String get historicalDeepWorkVolume => 'حجم العمل العميق';

  @override
  String get historicalLastWeek => 'الأسبوع الماضي';

  @override
  String get historicalAverageFocusSession => 'متوسط جلسة التركيز';

  @override
  String get historicalCompletionRate => 'معدل الإنجاز';

  @override
  String get weekdayMonShort => 'ن';

  @override
  String get weekdayTueShort => 'ث';

  @override
  String get weekdayWedShort => 'ر';

  @override
  String get weekdayThuShort => 'خ';

  @override
  String get weekdayFriShort => 'ج';

  @override
  String get weekdaySatShort => 'س';

  @override
  String get weekdaySunShort => 'ح';

  @override
  String get sessionsSubtitle => 'جلسات الدراسة';

  @override
  String get logManually => 'تسجيل يدوي';

  @override
  String get filters => 'الفلاتر';

  @override
  String get filtersActive => 'الفلاتر (مفعلة)';

  @override
  String get historyFiltersTitle => 'فلاتر السجل';

  @override
  String get close => 'إغلاق';

  @override
  String get timerTab => 'المؤقت';

  @override
  String get stopwatchTab => 'ساعة الإيقاف';

  @override
  String get historyTab => 'السجل';

  @override
  String get subjectsGroupsTab => 'المواد والمجموعات';

  @override
  String sessionQuickStartStarted(Object mode) {
    return 'تم بدء $mode.';
  }

  @override
  String get sessionModePomodoro => 'بومودورو';

  @override
  String get sessionModeLongSession => 'جلسة طويلة';

  @override
  String get sessionModeManual => 'تسجيل يدوي';

  @override
  String get sessionsLoadError => 'تعذر تحميل الجلسات';

  @override
  String get noSessionsLogged => 'لا توجد جلسات مسجلة بعد';

  @override
  String minutesShortValue(Object minutes) {
    return '$minutesد';
  }

  @override
  String get searchHistory => 'ابحث في السجل';

  @override
  String get subjectsError => 'خطأ في المواد';

  @override
  String get subjectLabel => 'المادة';

  @override
  String get allSubjects => 'كل المواد';

  @override
  String get modeLabel => 'الوضع';

  @override
  String get allModes => 'كل الأوضاع';

  @override
  String filtersFrom(Object value) {
    return 'من $value';
  }

  @override
  String filtersTo(Object value) {
    return 'إلى $value';
  }

  @override
  String get clear => 'مسح';

  @override
  String get anyLabel => 'أي';

  @override
  String get logSessionManuallyTitle => 'تسجيل جلسة يدوياً';

  @override
  String get subjectOptional => 'المادة (اختياري)';

  @override
  String get generalStudy => 'دراسة عامة';

  @override
  String get topicLabel => 'الموضوع';

  @override
  String get moodLabel => 'الحالة';

  @override
  String get moodFocused => 'مركز';

  @override
  String get moodProductive => 'منتج';

  @override
  String get moodCalm => 'هادئ';

  @override
  String get moodTired => 'متعب';

  @override
  String get moodStressed => 'متوتر';

  @override
  String get moodDistracted => 'مشتت';

  @override
  String get durationMinutesLabel => 'المدة (بالدقائق)';

  @override
  String get enterValidDuration => 'أدخل مدة صحيحة';

  @override
  String get notesLabel => 'ملاحظات';

  @override
  String get saving => 'جارٍ الحفظ...';

  @override
  String get analyticsSubtitle => 'راجع قدرة التحمل الذهني ومؤشرات التركيز خلال الدورة الحالية.';

  @override
  String get achievementsPersonalGrowth => 'النمو الشخصي';

  @override
  String get achievementsTabAwards => 'الأوسمة';

  @override
  String get achievementsTabAiMissions => 'مهام الذكاء الاصطناعي';

  @override
  String achievementsTakenAwards(Object count) {
    return 'الأوسمة المكتسبة: $count';
  }

  @override
  String achievementsLevelRank(Object level, Object rank) {
    return 'المستوى $level $rank';
  }

  @override
  String achievementsUnlocked(Object unlocked, Object total) {
    return '$unlocked/$total مفتوح';
  }

  @override
  String achievementsXpProgress(Object current, Object total, Object toGo) {
    return '$current / $total نقطة خبرة في هذا المستوى ($toGo متبقي)';
  }

  @override
  String get achievementsFilterTaken => 'الأوسمة المكتسبة';

  @override
  String get achievementsFilterDaily => 'يومي';

  @override
  String get achievementsFilterWeekly => 'أسبوعي';

  @override
  String get achievementsFilterMonthly => 'شهري';

  @override
  String get achievementsFilterTiers => 'الرتب';

  @override
  String get achievementsProgress => 'التقدم';

  @override
  String get achievementsRankMaster => 'خبير';

  @override
  String get achievementsRankScholar => 'باحث';

  @override
  String get achievementsRankAdept => 'متقدم';

  @override
  String get achievementsRankLearner => 'متعلم';

  @override
  String get achievementsRankNovice => 'مبتدئ';

  @override
  String get achievementsCurrentMissions => 'المهام الحالية';

  @override
  String get achievementsRefreshSurprise => 'تحديث مهمة مفاجئة';

  @override
  String get achievementsGroqDetected => 'تم اكتشاف مفتاح Groq. ستستخدم المهام توليد الذكاء الاصطناعي مع بديل محلي.';

  @override
  String get achievementsNoGroq => 'لم يتم العثور على مفتاح Groq. يتم توليد المهام محلياً؛ يمكنك إضافة أو استبدال المفتاح من الإعدادات في أي وقت.';

  @override
  String get achievementsNoActiveMissions => 'لا توجد مهام نشطة. اضغط تحديث لتوليد مهام جديدة.';

  @override
  String get achievementsCompletedChallenges => 'التحديات المكتملة';

  @override
  String get achievementsNoCompletedMissions => 'لا توجد مهام مكتملة بعد.';

  @override
  String achievementsMissionRefreshed(Object tier) {
    return 'تم تحديث مهمة $tier.';
  }

  @override
  String get achievementsRefreshThisMission => 'تحديث هذه المهمة';

  @override
  String achievementsReward(Object reward) {
    return 'المكافأة: $reward';
  }

  @override
  String get achievementsTierDaily => 'يومي';

  @override
  String get achievementsTierWeekly => 'أسبوعي';

  @override
  String get achievementsTierMonthly => 'شهري';

  @override
  String get achievementsTierSurprise => 'مفاجئ';

  @override
  String get achievementsDifficultyEasy => 'سهل';

  @override
  String get achievementsDifficultyMedium => 'متوسط';

  @override
  String get achievementsDifficultyHard => 'صعب';

  @override
  String get achievementsDifficultyExtreme => 'قاسٍ';

  @override
  String get achievementsMetricSessions => 'جلسات';

  @override
  String get achievementsMetricMinutes => 'دقائق';

  @override
  String get achievementsMetricStreak => 'سلسلة';

  @override
  String get achievementsMetricSubjects => 'مواد';

  @override
  String get achievementsMetricPomodoros => 'بومودورو';

  @override
  String get awardTitleDailyStarter => 'البداية';

  @override
  String get awardDescDailyStarter => 'أكمل أول جلسة لك اليوم';

  @override
  String get awardTitleDeepWorkDaily => 'عمل عميق';

  @override
  String get awardDescDeepWorkDaily => 'ادرس لمدة 60 دقيقة اليوم';

  @override
  String get awardTitleSprintDaily => 'اندفاعة';

  @override
  String get awardDescSprintDaily => 'ادرس لمدة ساعتين اليوم';

  @override
  String get awardTitlePomo5Daily => 'بومو-5';

  @override
  String get awardDescPomo5Daily => 'أكمل 5 جلسات بومودورو اليوم';

  @override
  String get awardTitleMidnightOil => 'زيت منتصف الليل';

  @override
  String get awardDescMidnightOil => 'ادرس بين 12 صباحاً و3 صباحاً';

  @override
  String get awardTitleEarlyRiser => 'استيقاظ مبكر';

  @override
  String get awardDescEarlyRiser => 'ابدأ جلسة قبل 7 صباحاً';

  @override
  String get awardTitleSubjectExplorer => 'مستكشف المواد';

  @override
  String get awardDescSubjectExplorer => 'ادرس مادتين مختلفتين اليوم';

  @override
  String get awardTitleNoZeroDay => 'لا يوم صفري';

  @override
  String get awardDescNoZeroDay => 'سجل دقيقة دراسة واحدة على الأقل';

  @override
  String get awardTitleTaskFinisher => 'منهي المهام';

  @override
  String get awardDescTaskFinisher => 'أكمل كل المهام في جلسة واحدة';

  @override
  String get awardTitlePerfectWeek => 'أسبوع مثالي';

  @override
  String get awardDescPerfectWeek => 'ادرس ساعتين أو أكثر يومياً لمدة أسبوع';

  @override
  String get awardTitleWeekendWarrior => 'مقاتل نهاية الأسبوع';

  @override
  String get awardDescWeekendWarrior => 'ادرس يومي الخميس والجمعة';

  @override
  String get awardTitleTimeInvestorWeekly => 'مستثمر الوقت';

  @override
  String get awardDescTimeInvestorWeekly => 'ادرس 10 ساعات أو أكثر هذا الأسبوع';

  @override
  String get awardTitleMonthlyMaster => 'سيد الشهر';

  @override
  String get awardDescMonthlyMaster => '25 يوماً نشطاً في شهر واحد';

  @override
  String get awardTitleFortyHourClub => 'نادي الأربعين ساعة';

  @override
  String get awardDescFortyHourClub => '40 ساعة أو أكثر في شهر واحد';

  @override
  String get awardTitleSessionsBronze => 'باحث برونزي';

  @override
  String get awardDescSessionsBronze => 'ادرس 100 ساعة إجمالية';

  @override
  String get awardTitleSessionsSilver => 'باحث فضي';

  @override
  String get awardDescSessionsSilver => 'ادرس 300 ساعة إجمالية';

  @override
  String get awardTitleSessionsGold => 'باحث ذهبي';

  @override
  String get awardDescSessionsGold => 'ادرس 500 ساعة إجمالية';

  @override
  String get awardTitleSessionsLegend => 'باحث أسطوري';

  @override
  String get awardDescSessionsLegend => 'ادرس 1000 ساعة إجمالية';

  @override
  String get awardTitleHoursBronze => 'إنجاز 100 ساعة';

  @override
  String get awardDescHoursBronze => 'ادرس 100 ساعة إجمالية';

  @override
  String get awardTitleStreakWeek => 'إيقاع ثابت';

  @override
  String get awardDescStreakWeek => 'سلسلة دراسة 7 أيام مع أيام ساعتين+';

  @override
  String get awardTitlePhoenix => 'العنقاء';

  @override
  String get awardDescPhoenix => 'استأنف الدراسة بعد انقطاع 3 أيام أو أكثر';

  @override
  String get awardTitleTripleThreat => 'التهديد الثلاثي';

  @override
  String get awardDescTripleThreat => 'جلسة + بومودورو + ساعة تركيز في يوم واحد';

  @override
  String get awardTitleOverkill => 'إفراط';

  @override
  String get awardDescOverkill => 'ادرس 5 ساعات أو أكثر في يوم واحد';

  @override
  String get apply => 'تطبيق';

  @override
  String sessionCustomOverlaySaved(Object path) {
    return 'تم حفظ صورة التراكب المخصصة في $path';
  }

  @override
  String get sessionOverlayHueTitle => 'درجة لون التراكب';

  @override
  String sessionHueValue(Object value) {
    return 'الدرجة: $value';
  }

  @override
  String get sessionFullscreen => 'ملء الشاشة';

  @override
  String get sessionExitFullscreen => 'الخروج من ملء الشاشة';

  @override
  String sessionFocusedMinutes(Object minutes) {
    return '$minutes دقيقة تركيز';
  }

  @override
  String sessionFocusBreakLine(Object focus, Object breakMinutes) {
    return '$focusد تركيز · $breakMinutesد استراحة';
  }

  @override
  String get sessionContinuousFocusMode => 'وضع التركيز المستمر';

  @override
  String get sessionAtmosphere => 'الأجواء';

  @override
  String get sessionAtmosphereCityTwilight => 'شفق المدينة';

  @override
  String get sessionAtmosphereCozyCafe => 'مقهى دافئ';

  @override
  String get sessionAtmosphereCustom => 'مخصص';

  @override
  String get sessionAtmosphereOverlay => 'تراكب';

  @override
  String get sessionHideDetails => 'إخفاء تفاصيل الجلسة';

  @override
  String get sessionShowDetails => 'تفاصيل الجلسة';

  @override
  String get sessionStatusReady => 'جاهز';

  @override
  String get sessionStatusFocusing => 'تركيز';

  @override
  String get sessionStatusBreakTime => 'وقت الاستراحة';

  @override
  String get sessionStatusPaused => 'متوقف مؤقتاً';

  @override
  String get sessionStart => 'بدء الجلسة';

  @override
  String get sessionSkipBreak => 'تخطي الاستراحة';

  @override
  String get sessionStopAndSave => 'إيقاف وحفظ';

  @override
  String get sessionPause => 'إيقاف مؤقت';

  @override
  String get sessionResume => 'استئناف';

  @override
  String get stopwatchTitle => 'ساعة الإيقاف';

  @override
  String get stopwatchStart => 'بدء';

  @override
  String get stopwatchLap => 'لفة';

  @override
  String get stopwatchReset => 'إعادة تعيين';

  @override
  String stopwatchLapNumber(Object number) {
    return 'لفة $number';
  }

  @override
  String get analyticsStatTotalTime => 'إجمالي الوقت';

  @override
  String get analyticsStatDailyAvg => 'متوسط يومي';

  @override
  String get analyticsStatPeakSession => 'أفضل جلسة';

  @override
  String get analyticsStatPeakHour => 'أفضل ساعة';

  @override
  String get analyticsAm => 'ص';

  @override
  String get analyticsPm => 'م';

  @override
  String get analyticsDailyTrendTitle => 'الاتجاه اليومي';

  @override
  String get analyticsSessionRatioTitle => 'نسبة الجلسة';

  @override
  String get analyticsSessionRatioSubtitle => 'توازن مثالي بين التركيز والراحة.';

  @override
  String analyticsFocusRatio(Object value) {
    return 'تركيز ($value%)';
  }

  @override
  String analyticsBreakRatio(Object value) {
    return 'استراحة ($value%)';
  }

  @override
  String get analyticsSubjectBreakdownTitle => 'توزيع المواد';

  @override
  String get analyticsNoSubjectBreakdown => 'لا توجد وسوم مضافة للجلسات الأخيرة.';

  @override
  String get analyticsSubjectBreakdownLabel => 'توزيع المواد';

  @override
  String get analyticsStateDistributionTitle => 'توزيع الحالة';

  @override
  String get analyticsNoMoodData => 'لا توجد بيانات حالة متاحة.';

  @override
  String get analyticsMoodDeepFlow => 'تدفق عميق';

  @override
  String get analyticsMoodResistance => 'مقاومة';

  @override
  String get analyticsMoodFatigue => 'إرهاق';

  @override
  String get analyticsRecentOutputTitle => 'المخرجات الأخيرة';

  @override
  String get analyticsViewAll => 'عرض الكل';

  @override
  String get analyticsNoRecentOutput => 'لا توجد مخرجات حديثة.';

  @override
  String get analyticsCompletedPrefix => 'مكتمل';

  @override
  String get analyticsPeakStudyHoursTitle => 'ساعات الدراسة الأعلى';

  @override
  String get analyticsHeatmapTitle => 'خريطة الاستمرارية السنوية';

  @override
  String get analyticsNoSessionsYet => 'لا توجد جلسات بعد';

  @override
  String analyticsStartDay(Object date) {
    return 'يوم البداية: $date';
  }

  @override
  String get statusHubStreakRunway => 'مسار السلسلة';

  @override
  String get statusHubTodaySignal => 'إشارة اليوم';

  @override
  String get statusHubDaysHot => 'أيام متتالية';

  @override
  String get statusHubNextCrest => 'القمة التالية';

  @override
  String statusHubDaysToCrest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يتبقى $count يومًا',
      many: 'يتبقى $count يومًا',
      few: 'يتبقى $count أيام',
      two: 'يتبقى يومان',
      one: 'يتبقى يوم واحد',
      zero: 'لا يتبقى شيء',
    );
    return '$_temp0';
  }

  @override
  String statusHubPersonalBestFull(int days) {
    return 'أفضل سلسلة لك · $days يومًا';
  }

  @override
  String get statusHubLadderClearedTitle => 'اكتمال السلم';

  @override
  String statusHubPersonalBestInline(int days) {
    return 'أفضل سلسلة · $days يومًا';
  }

  @override
  String get statusHubTierColdStart => 'بداية هادئة';

  @override
  String get statusHubTierFirstSpark => 'أول شرارة';

  @override
  String get statusHubTierKindlingClimb => 'صعود الزند';

  @override
  String get statusHubTierScholarPulse => 'نبض المثابر';

  @override
  String get statusHubTierDeepRhythm => 'إيقاع عميق';

  @override
  String get statusHubTierMarathonMind => 'عقل الماراثون';

  @override
  String get statusHubTierHallOfLegends => 'قاعة الأساطير';

  @override
  String get statusHubCkptFlavor3 => 'قمة الزند';

  @override
  String get statusHubCkptFlavor7 => 'نبض العلم والمثابرة';

  @override
  String get statusHubCkptFlavor14 => 'قمة الإيقاع';

  @override
  String get statusHubCkptFlavor30 => 'صهر الشهر';

  @override
  String get statusHubCkptFlavor90 => 'أسطورة الموسم';

  @override
  String get statusHubCkptFlavorGeneric => 'علامة تقدّم';

  @override
  String statusHubChasePeakRunway(int days) {
    return 'أفضل سلسلة سجّلتها: $days يومًا — خُذْ راحتك ثم افتَح تحديًا جديدًا.';
  }

  @override
  String statusHubChaseEncore(int goal) {
    return 'قطعتَ كل القمم على السلم — اجعل الهدف التالي $goal+ يومًا.';
  }

  @override
  String statusHubChaseStartToday(String flavorName, int days) {
    return 'ادرس اليوم — أول قمة لك هي «$flavorName» بعد $days أيام متتالية.';
  }

  @override
  String statusHubChaseCement(String flavorName) {
    return '«$flavorName» قريبة — سجّل اليوم لتثبتها.';
  }

  @override
  String statusHubChaseRemain(int count, String flavorName, int milestone) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تفصلك $count أيام عن «$flavorName» (قمة $milestone يومًا).',
      one: 'يتبقى يوم واحد للوصول إلى «$flavorName» (قمة $milestone يومًا).',
    );
    return '$_temp0';
  }

  @override
  String get statusHubBodyFlow => 'تركيز طويل اليوم — على حافة التحدي دون أن تُثقل نفسك.';

  @override
  String get statusHubBodyProud => 'بُنيت قوة الاستمرار — استمتع بالمجهود واحمِ فترات التعافي.';

  @override
  String get statusHubBodyBurnout => 'حجم عالٍ اليوم — اشرب ماء، قصّر الجولة القادمة، واحرص على النوم.';

  @override
  String get statusHubBodyIdle => 'لا يوجد عمل عميق بعد — جلسة واحدة مركّزة تُشعل وقود السلسلة.';

  @override
  String get statusHubChipOptimalFocus => 'تركيز مثالي';

  @override
  String get statusHubChipStreakCrest => 'قمة السلسلة';

  @override
  String get statusHubChipRestGuarded => 'احمِ راحتك';

  @override
  String get statusHubChipReadyIgnite => 'جاهز للانطلاق';

  @override
  String get statusHubChipFlowRule => 'التدفق: 120 دقيقة فأكثر اليوم';

  @override
  String get statusHubChipFatigueRule => 'تنبيه الإرهاق: أكثر من 360 د باليوم';

  @override
  String notif_prestudy_v1(Object subject) {
    return 'حان وقت دراسة $subject. ابدأ كتلة تركيز.';
  }

  @override
  String notif_prestudy_v2(Object subject) {
    return 'جلسة تركيز $subject تنتظرك الآن.';
  }

  @override
  String notif_prestudy_v3(Object subject) {
    return 'حافظ على الزخم مع $subject.';
  }

  @override
  String notif_streak_body(int count) {
    return 'احمِ سلسلة $count يومًا. سجّل جلسة قبل منتصف الليل.';
  }

  @override
  String notif_weekly_full(int hours, int minutes, int count, String subject) {
    return '$hoursس $minutesد عبر $count جلسات. أكثر مادة: $subject.';
  }

  @override
  String get notif_weekly_empty => 'لا توجد جلسات هذا الأسبوع. ابدأ سلسلة جديدة اليوم.';

  @override
  String notif_goal_behind(int hoursBehind, int daysLeft, Object goalName) {
    return 'أنت متأخر $hoursBehindس عن هدفك في $goalName. $daysLeft أيام متبقية للحاق.';
  }

  @override
  String notif_reengage_short(int days) {
    return 'مرّ $days أيام. هيا لنعود للدراسة.';
  }

  @override
  String get notif_reengage_long => 'نحن نفتقدك! ابدأ جلسة جديدة والعد للطريق الصحيح.';

  @override
  String get notif_settings_title => 'الإشعارات';

  @override
  String get notif_settings_prestudy => 'تذكير ما قبل الدراسة';

  @override
  String notif_settings_prestudy_desc(Object time) {
    return 'الإطلاق في $time · كل يوم';
  }

  @override
  String get notif_settings_streak => 'حماية السلسلة';

  @override
  String get notif_settings_weekly => 'ملخص أسبوعي';

  @override
  String get notif_settings_goal => 'تقدم الهدف';

  @override
  String get notif_settings_reengage => 'إعادة الاشتباك';

  @override
  String notif_settings_reengage_desc(Object time) {
    return 'بعد 3 أيام، في $time';
  }

  @override
  String get notif_settings_quiet_title => 'عدم الإزعاج';

  @override
  String notif_settings_quiet_desc(Object start, Object end) {
    return 'ساعات الهدوء: $start → $end';
  }

  @override
  String get notif_settings_quiet_start => 'بداية وقت الهدوء';

  @override
  String get notif_settings_quiet_end => 'نهاية وقت الهدوء';

  @override
  String get notif_settings_quiet_start_desc => 'لن تصلك إشعارات غير عاجلة بعد هذا الوقت';

  @override
  String get notif_settings_quiet_end_desc => 'ستستأنف الإشعارات بعد هذا الوقت';

  @override
  String get notif_permission_title => 'تفعيل الإشعارات؟';

  @override
  String get notif_permission_body => 'تذكيرات الدراسة تساعدك على البقاء متسقًا. سنرسل لك تحديثات في الوقت المناسب حول تقدمك والسلاسل.';

  @override
  String get notif_permission_enable => 'تفعيل';

  @override
  String get notif_permission_later => 'لاحقًا';

  @override
  String get notif_denied_hint => 'الإشعارات معطلة. افتح إعدادات الجهاز لتفعيلها.';

  @override
  String get notif_settings_streak_desc => 'يُحدَّد وقت التذكير تلقائيًا من نمط سلسلتك (مساءً).';

  @override
  String get notif_settings_goal_desc => 'يُحدَّد وقت التذكير تلقائيًا من تقدم هدفك الأسبوعي.';

  @override
  String notif_settings_weekly_desc(Object day, Object time) {
    return 'كل $day الساعة $time';
  }

  @override
  String get notif_time_fire_at => 'التنبيه عند';

  @override
  String get notif_day_fire_at => 'التنبيه يوم';

  @override
  String get monday => 'الاثنين';

  @override
  String get tuesday => 'الثلاثاء';

  @override
  String get wednesday => 'الأربعاء';

  @override
  String get thursday => 'الخميس';

  @override
  String get friday => 'الجمعة';

  @override
  String get saturday => 'السبت';

  @override
  String get sunday => 'الأحد';

  @override
  String get notif_time_weekly_summary => 'كل أحد في';

  @override
  String get ai_coach_title => 'مدربك الذكي';

  @override
  String get ai_coach_connect => 'الاتصال بالذكاء الاصطناعي';

  @override
  String get ai_debrief_loading => 'التفكير في جلستك…';

  @override
  String get ai_challenge_title => 'تحدي اليوم';

  @override
  String get ai_narrative_title => 'ملخص هذا الأسبوع';

  @override
  String get ai_narrative_button => 'إنشاء تقرير';

  @override
  String get ai_narrative_loading => 'جاري إنشاء تقريرك…';

  @override
  String get ai_difficulty_title => 'تحليل المواد';

  @override
  String get ai_difficulty_button => 'حلل مواديّ';

  @override
  String get ai_difficulty_not_enough => 'تحتاج إلى المزيد من الجلسات للتحليل. استمر في الدراسة!';

  @override
  String get ai_difficulty_error => 'تعذّر تحليل المواد الآن. حاول لاحقًا.';

  @override
  String get ai_settings_title => 'ميزات الذكاء الاصطناعي';

  @override
  String get ai_settings_subtitle => 'اربط Groq مرة واحدة، ثم فعّل الميزات التي تريدها.';

  @override
  String get ai_challenges_master_label => 'التحديات (عام)';

  @override
  String get ai_settings_toggles_heading => 'ذكاء اصطناعي لكل ميزة';

  @override
  String get ai_settings_load_error => 'تعذّر تحميل إعدادات ميزات الذكاء الاصطناعي.';

  @override
  String get ai_settings_api_key => 'مفتاح Groq API';

  @override
  String get ai_settings_api_key_hint => 'الصق مفتاح Groq API الخاص بك هنا';

  @override
  String get ai_settings_connected => 'متصل ✓';

  @override
  String get ai_settings_show_key => 'عرض';

  @override
  String get ai_settings_hide_key => 'إخفاء';

  @override
  String get ai_settings_get_key => 'احصل على مفتاح Groq API مجاني';

  @override
  String get ai_settings_coach => 'المدرب الذكي';

  @override
  String get ai_settings_coach_desc => 'تشجيع شخصي يومي';

  @override
  String get ai_settings_challenges => 'التحديات الذكية';

  @override
  String get ai_settings_challenges_desc => 'اقتراحات دراسة معدلة حسب الصعوبة';

  @override
  String get ai_settings_debrief => 'تقييم الجلسة';

  @override
  String get ai_settings_debrief_desc => 'ملاحظات الذكاء الاصطناعي بعد كل جلسة دراسة';

  @override
  String get ai_settings_narrative => 'السرد الأسبوعي';

  @override
  String get ai_settings_narrative_desc => 'ملخص أسبوع الدراسة الخاص بك';

  @override
  String get ai_settings_difficulty => 'تحليل المواد';

  @override
  String get ai_settings_difficulty_desc => 'حدد أقوى المواد وأضعفها';

  @override
  String get ai_settings_surprise => 'مهام مفاجئة';

  @override
  String get ai_settings_surprise_desc => 'إشعارات عشوائية لمهام تم إنشاؤها بالذكاء الاصطناعي';

  @override
  String ai_settings_surprise_interval(Object hours) {
    return 'تحقق كل $hours ساعة';
  }

  @override
  String get ai_debrief_tap_to_dismiss => 'اضغط للإغلاق';

  @override
  String get ai_copy_narrative_snackbar => 'تم نسخ الملخص الأسبوعي إلى الحافظة';

  @override
  String notifStreakBody(Object streak) {
    return 'سلسلتك $streak أيام متتالية. افتح التطبيق للحفاظ عليها.';
  }

  @override
  String notifGoalBehind(Object hours, Object days, Object name) {
    return 'متأخر حوالي $hours ساعة عن هدفك الأسبوعي لـ $name. بقي $days يوم/أيام للتعويض.';
  }

  @override
  String get notifReengageLong => 'مر وقت طويل — حتى جلسة قصيرة اليوم تساعد على استعادة الزخم.';

  @override
  String notifReengageShort(Object days) {
    return 'لا جلسات منذ $days يوم/أيام. اضغط لتسجيل جلسة سريعة.';
  }

  @override
  String notifPrestudyV1(Object subject) {
    return 'تذكير قبل الدراسة: $subject. راجع خطتك عندما تكون جاهزًا.';
  }

  @override
  String notifPrestudyV2(Object subject) {
    return 'الكتلة التالية: $subject. ضع هدفًا صغيرًا قبل البدء.';
  }

  @override
  String notifPrestudyV3(Object subject) {
    return 'استعد لـ $subject — افتح المؤقت عندما تكون جاهزًا.';
  }

  @override
  String get notifWeeklyEmpty => 'لا جلسات مسجلة هذا الأسبوع بعد.';

  @override
  String notifWeeklyFull(Object hours, Object minutes, Object sessionCount, Object subject) {
    return 'حتى الآن هذا الأسبوع: $hoursس $minutesد عبر $sessionCount جلسة. أبرز مادة: $subject.';
  }

  @override
  String get dashboardDailyProgress => 'التقدم اليومي';

  @override
  String get dashboardLast7Days => 'آخر 7 أيام';

  @override
  String get dashboardToday => 'اليوم';

  @override
  String get dashboardStreak => 'السلسلة';

  @override
  String get dashboardAllTime => 'إجمالي المدة';

  @override
  String get dashboardDaysToNext => 'الأيام حتى الهدف التالي';
}
