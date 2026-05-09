import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../db/database.dart' as db;
import '../db/database_provider.dart';

class AiCacheRepository {
  final db.AppDatabase _db;

  AiCacheRepository(this._db);

  Future<int> _activeProfileId() async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals('currentProfileId')))
        .getSingleOrNull();
    return int.tryParse(row?.value ?? '1') ?? 1;
  }

  Future<Map<String, dynamic>?> get(String feature, String cacheKey) async {
    final profileId = await _activeProfileId();
    final row = await _db.customSelect(
      'SELECT payload_json, updated_at FROM ai_cache WHERE profile_id = ? AND feature = ? AND cache_key = ? LIMIT 1',
      variables: [drift.Variable(profileId), drift.Variable(feature), drift.Variable(cacheKey)],
    ).getSingleOrNull();
    return row?.data;
  }

  Future<void> set(String feature, String cacheKey, String payloadJson) async {
    final profileId = await _activeProfileId();
    await _db.customStatement(
      'INSERT OR REPLACE INTO ai_cache (profile_id, feature, cache_key, payload_json, updated_at) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)',
      [profileId, feature, cacheKey, payloadJson],
    );
  }

  Future<void> delete(String feature, String cacheKey) async {
    final profileId = await _activeProfileId();
    await _db.customStatement('DELETE FROM ai_cache WHERE profile_id = ? AND feature = ? AND cache_key = ?', [profileId, feature, cacheKey]);
  }
}

final aiCacheRepositoryProvider = Provider<AiCacheRepository>(
  (ref) => AiCacheRepository(ref.watch(databaseProvider)),
);
