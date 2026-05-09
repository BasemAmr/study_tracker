import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database.dart';

/// Singleton provider for the Drift database.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
