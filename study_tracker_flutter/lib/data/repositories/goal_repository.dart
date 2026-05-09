import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../db/database_provider.dart';

/// Minimal goals access for notification scheduling (active goal for N-T-4).
class GoalRepository {
  final AppDatabase _db;

  GoalRepository(this._db);

  /// First active, non-deleted goal for the profile, or null.
  Future<Map<String, dynamic>?> getActiveGoal(int profileId) async {
    final query = _db.select(_db.goals)
      ..where((g) => g.profileId.equals(profileId))
      ..where((g) => g.active.equals(true))
      ..where((g) => g.deletedAt.isNull())
      ..limit(1);
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return {
      'id': row.id,
      'name': row.name,
      'targetMinutes': row.targetMinutes,
    };
  }
}

final goalRepositoryProvider = Provider<GoalRepository>(
  (ref) => GoalRepository(ref.watch(databaseProvider)),
);
