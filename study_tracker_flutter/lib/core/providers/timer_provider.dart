import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/domain.dart';
import '../services/timer_service_bridge.dart';
import '../services/ai_debrief_service.dart';
import '../../data/repositories/session_repository.dart';

enum TimerState { idle, running, paused, breakPhase }

class TimerSnapshot {
  final StudySessionMode mode;
  final DateTime startedAt;
  final DateTime endedAt;
  final int elapsedSeconds;
  final int breakSeconds;

  const TimerSnapshot({
    required this.mode,
    required this.startedAt,
    required this.endedAt,
    required this.elapsedSeconds,
    required this.breakSeconds,
  });
}

class TimerProvider extends ChangeNotifier {
  final TimerServiceBridge _bridge;
  final SessionRepository _sessionRepository;
  final AiDebriefService _aiDebriefService;
  StreamSubscription<Map<String, dynamic>>? _stateSubscription;

  TimerProvider(this._bridge, this._sessionRepository, this._aiDebriefService) {
    _subscribeToStateStream();
  }

  TimerState state = TimerState.idle;
  StudySessionMode mode = StudySessionMode.longSession;

  // Metadata for the active session
  int? subjectId;
  String? subjectName;
  String? topic;
  String? notes;
  String? mood;
  String? backgroundImage;
  
  int elapsedSeconds = 0;
  int breakSeconds = 0;
  DateTime? startedAt;
  
  int pomodoroCount = 0;
  int pomodoroFocusMinutes = 25;
  int pomodoroBreakMinutes = 5;
  
  bool isBreakPhase = false;
  int phaseElapsedSeconds = 0;

  // Derived getters
  int get totalSeconds => isBreakPhase ? phaseElapsedSeconds : elapsedSeconds;
  
  String get timerDisplay {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    
    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');
    
    if (hours > 0) return '$hStr:$mStr:$sStr';
    return '$mStr:$sStr';
  }

  bool get isTimerActive => state != TimerState.idle;

  void start(
    StudySessionMode newMode, {
    int focusMinutes = 25,
    int breakMinutes = 5,
    int? subjectId,
    String? subjectName,
    String? topic,
    String? notes,
    String? mood,
    String? backgroundImage,
  }) {
    this.subjectId = subjectId;
    this.subjectName = subjectName;
    this.topic = topic;
    this.notes = notes;
    this.mood = mood;
    this.backgroundImage = backgroundImage;

    pomodoroFocusMinutes = focusMinutes;
    pomodoroBreakMinutes = breakMinutes;
    
    unawaited(_bridge.start(newMode.dbValue, focusMinutes, breakMinutes).catchError((e) {
      debugPrint('[TimerProvider] Bridge start failed: $e');
    }));
  }

  Future<void> _subscribeToStateStream() async {
    try {
      await _stateSubscription?.cancel();
      _stateSubscription = _bridge.stateStream.listen(
        _applyStateFromService,
        onError: (e) {
          debugPrint('[TimerProvider] Stream error: $e');
        }
      );
    } catch (e) {
      debugPrint('[TimerProvider] Failed to subscribe: $e');
    }
  }

  void _applyStateFromService(Map<String, dynamic> raw) {
    try {
      final nextState = _mapTimerState(raw['state'] as String?);
      final nextMode = StudySessionMode.fromDb(
        (raw['mode'] as String?) ?? StudySessionMode.longSession.dbValue,
      );

      final startedEpoch = raw['startedAtEpochMs'];
      final nextStartedAt = startedEpoch is int
          ? DateTime.fromMillisecondsSinceEpoch(startedEpoch)
          : null;

      final prevState = state;
      final prevMode = mode;
      final prevStartedAt = startedAt;
      final prevElapsed = elapsedSeconds;
      final prevBreak = breakSeconds;
      final prevIsBreak = isBreakPhase;

      state = nextState;
      mode = nextMode;
      startedAt = nextStartedAt;
      elapsedSeconds = (raw['elapsedSeconds'] as num?)?.toInt() ?? 0;
      breakSeconds = (raw['breakSeconds'] as num?)?.toInt() ?? 0;
      phaseElapsedSeconds = (raw['phaseElapsedSeconds'] as num?)?.toInt() ?? 0;
      pomodoroCount = (raw['pomodoroCount'] as num?)?.toInt() ?? 0;
      pomodoroFocusMinutes = (raw['focusMinutes'] as num?)?.toInt() ?? pomodoroFocusMinutes;
      pomodoroBreakMinutes = (raw['breakMinutes'] as num?)?.toInt() ?? pomodoroBreakMinutes;
      isBreakPhase = raw['isBreakPhase'] == true;

      // Logic for focus session completion in Pomodoro mode
      if (prevMode == StudySessionMode.pomodoro && !prevIsBreak && isBreakPhase) {
        // Transitioned from Focus to Break -> Save the focus session
        _handleAutoSaveOnFocusEnd(
          snapshotStartedAt: prevStartedAt,
          snapshotElapsed: prevElapsed,
          snapshotMode: prevMode,
        );
      }

      // Detect stop (any -> idle)
      if (prevState != TimerState.idle && nextState == TimerState.idle) {
        _handleAutoSaveOnStop(
          snapshotStartedAt: prevStartedAt,
          snapshotElapsed: prevElapsed,
          snapshotBreak: prevBreak,
          snapshotMode: prevMode,
        );
      }

      notifyListeners();
    } catch (e, st) {
      debugPrint('[TimerProvider] State apply error: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> _handleAutoSaveOnFocusEnd({
    DateTime? snapshotStartedAt,
    int? snapshotElapsed,
    StudySessionMode? snapshotMode,
  }) async {
    final finalStartedAt = snapshotStartedAt ?? startedAt;
    final finalElapsed = snapshotElapsed ?? elapsedSeconds;
    final finalMode = snapshotMode ?? mode;

    if (finalStartedAt == null || finalElapsed < 10) return;

    final durationMinutes = (finalElapsed / 60).round().clamp(1, 24 * 60);
    final session = StudySession(
      startAt: finalStartedAt,
      endAt: DateTime.now(),
      durationMinutes: durationMinutes,
      mode: finalMode,
      breakMinutes: 0,
      subjectId: subjectId,
      subjectName: subjectName,
      topic: topic,
      mood: mood,
      notes: notes,
      backgroundImage: backgroundImage,
    );

    try {
      await _sessionRepository.create(session);
      debugPrint('[TimerProvider] Auto-saved focus session: ${session.durationMinutes}m');
    } catch (e) {
      debugPrint('[TimerProvider] Focus auto-save failed: $e');
    }
  }

  Future<void> _handleAutoSaveOnStop({
    DateTime? snapshotStartedAt,
    int? snapshotElapsed,
    int? snapshotBreak,
    StudySessionMode? snapshotMode,
  }) async {
    final finalStartedAt = snapshotStartedAt ?? startedAt;
    final finalElapsed = snapshotElapsed ?? elapsedSeconds;
    final finalBreak = snapshotBreak ?? breakSeconds;
    final finalMode = snapshotMode ?? mode;

    if (finalStartedAt == null || finalElapsed < 1) {
      _clearMetadata();
      return;
    }

    final durationMinutes = (finalElapsed / 60).ceil().clamp(1, 24 * 60);
    final session = StudySession(
      startAt: finalStartedAt,
      endAt: DateTime.now(),
      durationMinutes: durationMinutes,
      mode: finalMode,
      breakMinutes: (finalBreak / 60).ceil(),
      subjectId: subjectId,
      subjectName: subjectName,
      topic: topic,
      mood: mood,
      notes: notes,
      backgroundImage: backgroundImage,
    );

    try {
      final id = await _sessionRepository.create(session);
      debugPrint('[TimerProvider] Auto-saved final session: ${session.durationMinutes}m');
      unawaited(_aiDebriefService.generateForSession(id, session));
    } catch (e) {
      debugPrint('[TimerProvider] Final auto-save failed: $e');
    } finally {
      _clearMetadata();
    }
  }

  void _clearMetadata() {
    subjectId = null;
    subjectName = null;
    topic = null;
    notes = null;
    mood = null;
    backgroundImage = null;
    startedAt = null;
    elapsedSeconds = 0;
    breakSeconds = 0;
  }

  TimerState _mapTimerState(String? raw) {
    switch (raw) {
      case 'running':
        return TimerState.running;
      case 'paused':
        return TimerState.paused;
      case 'breakPhase':
        return TimerState.breakPhase;
      default:
        return TimerState.idle;
    }
  }

  void pause() {
    if (state == TimerState.running || state == TimerState.breakPhase) {
      unawaited(_bridge.pause().catchError((e) => debugPrint('Pause failed: $e')));
    }
  }

  void resume() {
    if (state == TimerState.paused || state == TimerState.breakPhase) {
      unawaited(_bridge.resume().catchError((e) => debugPrint('Resume failed: $e')));
    }
  }

  void skipBreak() {
    if (isBreakPhase) {
      unawaited(_bridge.resume().catchError((e) => debugPrint('Skip break failed: $e')));
    }
  }

  void stop() {
    stopAndSnapshot();
  }

  TimerSnapshot? stopAndSnapshot() {
    if (startedAt == null || elapsedSeconds <= 0) {
      reset();
      return null;
    }

    final snapshotStart = startedAt!;
    final snapshotMode = mode;
    final snapshotElapsed = elapsedSeconds;
    final snapshotBreak = breakSeconds;

    unawaited(_bridge.stop().catchError((e) => debugPrint('Stop failed: $e')));

    final snapshot = TimerSnapshot(
      mode: snapshotMode,
      startedAt: snapshotStart,
      endedAt: DateTime.now(),
      elapsedSeconds: snapshotElapsed,
      breakSeconds: snapshotBreak,
    );

    return snapshot;
  }

  void reset() {
    unawaited(_bridge.stop().catchError((e) => debugPrint('Reset failed: $e')));
  }

  void syncFromService() {
    unawaited(_subscribeToStateStream());
  }
  
  @override
  void dispose() {
    _stateSubscription?.cancel();
    super.dispose();
  }
}

final timerProvider = ChangeNotifierProvider<TimerProvider>((ref) {
  return TimerProvider(
    TimerServiceBridge.instance,
    ref.watch(sessionRepositoryProvider),
    ref.watch(aiDebriefServiceProvider),
  );
});
