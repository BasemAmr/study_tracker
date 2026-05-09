import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'app/app.dart';
import 'core/notifications/deep_link_router.dart';
import 'core/notifications/notification_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.smart.studytracker.focus_audio',
      androidNotificationChannelName: 'Focus Audio Playback',
      androidNotificationOngoing: false,
    );
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('JustAudioBackground init failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  tz.initializeTimeZones();
  try {
    final zoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zoneName));
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('Timezone detection failed, using UTC: $e');
      debugPrintStack(stackTrace: st);
    }
    tz.setLocalLocation(tz.UTC);
  }

  await studyTrackerNotificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      NotificationRouterScope.handlePayload(response.payload);
    },
  );

  runApp(
    const ProviderScope(
      child: StudyTrackerApp(),
    ),
  );
}
