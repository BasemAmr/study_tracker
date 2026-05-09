import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/ai_feature_settings_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../providers/settings_provider.dart';
import '../services/ai_coach_service.dart';

/// Latest row from [ai_feature_settings] for the active profile (reactive).
final aiFeatureSettingsMapProvider = StreamProvider.autoDispose<Map<String, dynamic>?>((ref) {
  return ref.watch(aiFeatureSettingsRepositoryProvider).watchSettings();
});

bool aiRowBool(Map<String, dynamic>? row, String snakeKey) {
  final v = row?[snakeKey];
  if (v == null) return false;
  if (v is bool) return v;
  if (v is int) return v != 0;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase();
    return s == 'true' || s == '1';
  }
  return false;
}

/// Today's coach message when [coach_enabled] is on; null otherwise or while blocked.
final aiCoachTodayProvider = FutureProvider.autoDispose<String?>((ref) async {
  final aiAsync = ref.watch(aiFeatureSettingsMapProvider);
  final ai = aiAsync.valueOrNull;
  if (!aiRowBool(ai, 'coach_enabled')) return null;

  final apiKey = ref.watch(aiGroqApiKeyProvider);
  if (apiKey == null || apiKey.isEmpty || apiKey.startsWith('sk-xxxx') || apiKey.startsWith('gsk_xxxx')) {
    return null;
  }

  final profileId = ref.watch(settingsProvider.select((s) => s.currentProfileId));
  return ref.watch(aiCoachServiceProvider).ensureTodaysMessage(profileId);
});

/// Reactive API key provider.
final aiGroqApiKeyProvider = Provider.autoDispose<String?>((ref) {
  return ref.watch(settingsProvider.select((s) => s.settings.groqApiKey));
});
