import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/typography.dart';
import '../core/providers/settings_provider.dart';
import '../core/sync/sync_service.dart';
import '../domain/enums.dart';
import '../data/repositories/settings_repository.dart';
import '../core/services/ai_coach_service.dart';
import '../core/notifications/deep_link_router.dart';
import '../core/notifications/notification_providers.dart';

/// Root application widget.
///
/// Initializes the database on first build via an [AsyncValue] guard,
/// then renders the shell with go_router navigation.
class StudyTrackerApp extends ConsumerStatefulWidget {
  const StudyTrackerApp({super.key});

  @override
  ConsumerState<StudyTrackerApp> createState() => _StudyTrackerAppState();
}

class _StudyTrackerAppState extends ConsumerState<StudyTrackerApp> with WidgetsBindingObserver {
  bool _primedCoach = false;
  bool _primedNotifications = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _rescheduleNotifications();
    }
  }

  Future<void> _rescheduleNotifications() async {
    try {
      final profileId = await ref.read(settingsRepositoryProvider).getCurrentProfileId();
      final dispatcher = await ref.read(notificationDispatcherProvider.future);
      await dispatcher.rescheduleAll(profileId);
    } catch (_) {
      // Best-effort
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final settingsState = ref.watch(settingsProvider);

    ref.read(syncServiceProvider).init();

    if (!_primedCoach) {
      _primedCoach = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final profileId = await ref.read(settingsRepositoryProvider).getCurrentProfileId();
          await ref.read(aiCoachServiceProvider).ensureTodaysMessage(profileId);
        } catch (_) {
          // Coach warm-up is best-effort; failures are handled inside the service.
        }
      });
    }

    if (!_primedNotifications) {
      _primedNotifications = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        NotificationRouterScope.bind(ref.read(routerProvider));
        try {
          final details =
              await studyTrackerNotificationsPlugin.getNotificationAppLaunchDetails();
          if (details?.didNotificationLaunchApp ?? false) {
            NotificationRouterScope.handlePayload(
              details!.notificationResponse?.payload,
            );
          }
        } catch (_) {
          // Launch-details / navigation is best-effort.
        }
        _rescheduleNotifications();
      });
    }

    final locale = Locale(settingsState.settings.languageCode);
    final isArabic = settingsState.settings.languageCode == 'ar';
    AppTypography.setLocale(isArabic: isArabic);
    final themeMode = switch (settingsState.settings.themeMode) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.system => ThemeMode.system,
    };

    return MaterialApp.router(
      title: 'StudyTracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(isArabic: isArabic),
      darkTheme: AppTheme.dark(isArabic: isArabic),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
