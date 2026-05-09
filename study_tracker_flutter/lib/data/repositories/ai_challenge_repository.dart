import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database.dart' as db;
import '../db/database_provider.dart';
import '../../domain/domain.dart' as domain;

class AiChallengeRepository {
  final db.AppDatabase _db;

  AiChallengeRepository(this._db);

  Future<int> _activeProfileId() async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals('currentProfileId')))
        .getSingleOrNull();
    return int.tryParse(row?.value ?? '1') ?? 1;
  }

  Future<List<domain.AiChallenge>> getAll() async {
    final profileId = await _activeProfileId();
    final rows = await (_db.select(_db.aiChallenges)
          ..where((t) => t.profileId.equals(profileId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_mapRow).toList();
  }

  Stream<List<domain.AiChallenge>> watchAll() {
    final profile = _db.select(_db.appSettings)..where((t) => t.key.equals('currentProfileId'));
    return profile
        .watchSingleOrNull()
        .map((row) => int.tryParse(row?.value ?? '1') ?? 1)
        .distinct()
        .asyncExpand((profileId) {
      final query = _db.select(_db.aiChallenges)
        ..where((t) => t.profileId.equals(profileId))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
      return query.watch().map((rows) => rows.map(_mapRow).toList());
    });
  }

  Future<domain.AiChallenge?> getById(String id) async {
    final profileId = await _activeProfileId();
    final row = await (_db.select(_db.aiChallenges)
          ..where((t) => t.id.equals(id) & t.profileId.equals(profileId)))
        .getSingleOrNull();
    if (row == null) return null;
    return _mapRow(row);
  }

  Future<domain.AiChallenge?> getActiveByTier(domain.AiChallengeTier tier) async {
    final profileId = await _activeProfileId();
    final nowIso = DateTime.now().toIso8601String();
    final row = await (_db.select(_db.aiChallenges)
          ..where((t) =>
              t.profileId.equals(profileId) &
              t.tier.equals(tier.name) &
              t.completed.equals(false) &
              t.status.equals('active') &
              t.expiresAt.isBiggerThanValue(nowIso))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    return _mapRow(row);
  }

  Future<void> create(domain.AiChallenge challenge) async {
    final profileId = await _activeProfileId();
    final trimmedId = challenge.id.trim();
    final baseId = trimmedId.isEmpty
        ? '${challenge.tier.name}_${DateTime.now().millisecondsSinceEpoch}'
        : trimmedId;

    var attempt = 0;
    while (true) {
      final candidateId = attempt == 0
          ? baseId
          : 'p${profileId}_${baseId}_${DateTime.now().microsecondsSinceEpoch}_$attempt';

      try {
        await _db.into(_db.aiChallenges).insert(
              db.AiChallengesCompanion.insert(
                id: candidateId,
                profileId: Value(profileId),
                tier: challenge.tier.name,
                title: challenge.title,
                description: challenge.description,
                icon: challenge.icon,
                metric: challenge.metric.name,
                target: challenge.target,
                expiresAt: challenge.expiresAt.toIso8601String(),
                difficulty: challenge.difficulty.name,
                rewardBadgeName: challenge.rewardBadgeName,
                rewardBadgeIcon: challenge.rewardBadgeIcon,
                completed: Value(challenge.completed),
                rawResponse: Value(challenge.rawResponse),
                subTargetsJson: Value(challenge.subTargets?.toJsonString()),
                unitMinMinutes: Value(challenge.unitMinMinutes),
                status: Value(challenge.status.name),
              ),
            );
        return;
      } catch (e) {
        if (_isAiChallengeIdConflict(e) && attempt < 4) {
          attempt++;
          continue;
        }
        rethrow;
      }
    }
  }

  bool _isAiChallengeIdConflict(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('unique constraint failed') && msg.contains('ai_challenges.id');
  }

  Future<void> markCompleted(String id) async {
    final profileId = await _activeProfileId();
    await (_db.update(_db.aiChallenges)
          ..where((t) => t.id.equals(id) & t.profileId.equals(profileId)))
        .write(
      db.AiChallengesCompanion(
        completed: const Value(true),
        status: const Value('completed'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<domain.AiChallenge?> getSlotChallengeForTier(domain.AiChallengeTier tier) async {
    final profileId = await _activeProfileId();
    final row = await (_db.select(_db.aiChallenges)
          ..where((t) =>
              t.profileId.equals(profileId) &
              t.tier.equals(tier.name) &
              t.completed.equals(false) &
              t.status.equals('active'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    return _mapRow(row);
  }

  Future<void> setChallengeStatus(String id, domain.AiChallengeStatus status) async {
    final profileId = await _activeProfileId();
    await (_db.update(_db.aiChallenges)
          ..where((t) => t.id.equals(id) & t.profileId.equals(profileId)))
        .write(
      db.AiChallengesCompanion(
        status: Value(status.name),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

    /// Marks every still-active row in this tier as replaced (user refresh path).
    Future<void> deleteActiveByTier(domain.AiChallengeTier tier) async {
      final profileId = await _activeProfileId();
      await (_db.update(_db.aiChallenges)
            ..where((t) =>
                t.profileId.equals(profileId) &
                t.tier.equals(tier.name) &
                t.status.equals('active')))
          .write(
        db.AiChallengesCompanion(
          status: const Value('replaced'),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }

  domain.AiChallenge _mapRow(db.AiChallengeRow row) {
    return domain.AiChallenge(
      id: row.id,
      tier: domain.AiChallengeTier.fromDb(row.tier),
      title: row.title,
      description: row.description,
      icon: row.icon,
      metric: domain.AiChallengeMetric.fromDb(row.metric),
      target: row.target,
      expiresAt: DateTime.parse(row.expiresAt),
      difficulty: domain.AiChallengeDifficulty.fromDb(row.difficulty),
      rewardBadgeName: row.rewardBadgeName,
      rewardBadgeIcon: row.rewardBadgeIcon,
      completed: row.completed,
      rawResponse: row.rawResponse,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      subTargets: domain.AiMissionSubTargets.tryParse(row.subTargetsJson),
      unitMinMinutes: row.unitMinMinutes,
      status: domain.AiChallengeStatus.fromDb(row.status),
    );
  }
}

final aiChallengeRepositoryProvider = Provider<AiChallengeRepository>(
  (ref) => AiChallengeRepository(ref.watch(databaseProvider)),
);
