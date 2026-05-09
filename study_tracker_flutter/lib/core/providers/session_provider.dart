import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/repositories/subject_repository.dart';
import '../../domain/domain.dart';
import 'settings_provider.dart';

/// All sessions (for analytics) — invalidated after any write.
final allSessionsProvider = StreamProvider.autoDispose<List<StudySession>>((ref) {
  ref.watch(settingsProvider.select((s) => s.currentProfileId));
  return ref.watch(sessionRepositoryProvider).watchAllSessions();
});

/// Session summary for dashboard stats.
final sessionSummaryProvider = StreamProvider.autoDispose<SessionSummary>((ref) {
  ref.watch(settingsProvider.select((s) => s.currentProfileId));
  return ref.watch(sessionRepositoryProvider).watchTodaySummary();
});

/// Recent sessions (last 10).
final recentSessionsProvider = StreamProvider.autoDispose<List<StudySession>>((ref) {
  ref.watch(settingsProvider.select((s) => s.currentProfileId));
  return ref.watch(sessionRepositoryProvider).watchRecentSessions(10);
});

/// Filtered sessions provider — takes a [SessionFilter] as family argument.
final filteredSessionsProvider =
    StreamProvider.autoDispose.family<List<StudySession>, SessionFilter>((ref, filter) {
  ref.watch(settingsProvider.select((s) => s.currentProfileId));
  return ref.watch(sessionRepositoryProvider).watchList(filter);
});

/// Subjects list for sessions filters/manual logging.
final sessionSubjectsProvider = StreamProvider.autoDispose<List<Subject>>((ref) {
  ref.watch(settingsProvider.select((s) => s.currentProfileId));
  return ref.watch(subjectRepositoryProvider).watchAll();
});
