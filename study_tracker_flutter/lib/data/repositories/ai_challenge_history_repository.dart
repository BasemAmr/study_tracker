import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart' as db;
import '../db/database_provider.dart';
import '../../domain/domain.dart' as domain;

class AiChallengeHistoryRepository {
  final db.AppDatabase _db;

  AiChallengeHistoryRepository(this._db);

  Future<int> _activeProfileId() async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals('currentProfileId')))
        .getSingleOrNull();
    return int.tryParse(row?.value ?? '1') ?? 1;
  }

  Future<void> create(domain.NewAiChallengeHistoryEntry entry) async {
    final profileId = await _activeProfileId();
    if (entry.profileId != profileId) {
      throw StateError('History entry profileId does not match active profile.');
    }
    await _db.into(_db.aiChallengeHistory).insert(
          db.AiChallengeHistoryCompanion.insert(
            profileId: entry.profileId,
            tier: entry.tier.name,
            title: entry.title,
            description: entry.description,
            metric: entry.metric.name,
            target: entry.target,
            progressAtClose: entry.progressAtClose,
            closeReason: entry.closeReason.name,
            closedAt: entry.closedAt,
            originalCreatedAt: entry.originalCreatedAt,
            originalExpiresAt: entry.originalExpiresAt,
            subTargetsJson: Value(entry.subTargets?.toJsonString()),
            unitMinMinutes: Value(entry.unitMinMinutes),
          ),
        );
  }

  Future<List<domain.AiChallengeHistoryEntry>> getRecent(
    domain.AiChallengeTier tier, {
    int limit = 50,
  }) async {
    final profileId = await _activeProfileId();
    final rows = await (_db.select(_db.aiChallengeHistory)
          ..where((t) => t.profileId.equals(profileId) & t.tier.equals(tier.name))
          ..orderBy([(t) => OrderingTerm.desc(t.closedAt)])
          ..limit(limit))
        .get();
    return rows.map(_mapRow).toList();
  }

  Future<void> pruneOldestBeyondLimit(
    domain.AiChallengeTier tier, [
    int limit = 50,
  ]) async {
    final profileId = await _activeProfileId();
    await _db.customStatement(
      r'''
DELETE FROM ai_challenge_history
WHERE id IN (
  SELECT id FROM (
    SELECT id,
           ROW_NUMBER() OVER (
             PARTITION BY profile_id, tier
             ORDER BY closed_at DESC
           ) AS rn
    FROM ai_challenge_history
    WHERE profile_id = ? AND tier = ?
  ) AS ranked
  WHERE rn > ?
)
''',
      [profileId, tier.name, limit],
    );
  }

  domain.AiChallengeHistoryEntry _mapRow(db.AiChallengeHistoryRow row) {
    return domain.AiChallengeHistoryEntry(
      id: row.id,
      profileId: row.profileId,
      tier: domain.AiChallengeTier.fromDb(row.tier),
      title: row.title,
      description: row.description,
      metric: domain.AiChallengeMetric.fromDb(row.metric),
      target: row.target,
      progressAtClose: row.progressAtClose,
      closeReason: domain.AiChallengeCloseReason.fromDb(row.closeReason),
      closedAt: row.closedAt,
      originalCreatedAt: row.originalCreatedAt,
      originalExpiresAt: row.originalExpiresAt,
      subTargets: domain.AiMissionSubTargets.tryParse(row.subTargetsJson),
      unitMinMinutes: row.unitMinMinutes,
    );
  }
}

final aiChallengeHistoryRepositoryProvider = Provider<AiChallengeHistoryRepository>(
  (ref) => AiChallengeHistoryRepository(ref.watch(databaseProvider)),
);
