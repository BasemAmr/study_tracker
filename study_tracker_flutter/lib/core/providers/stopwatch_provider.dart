import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum StopwatchState { idle, running, paused }

class LapData {
  final int number;
  final int splitMs;
  final int totalMs;
  LapData({required this.number, required this.splitMs, required this.totalMs});
}

class StopwatchProvider extends ChangeNotifier {
  StopwatchState state = StopwatchState.idle;
  
  int _elapsedMs = 0;
  int _lastLapTotalMs = 0;
  DateTime? _lastTickTime;
  Timer? _timer;
  
  List<LapData> laps = [];

  String get stopwatchDisplay {
    return formatLapTime(_elapsedMs);
  }

  String formatLapTime(int ms) {
    final totalSeconds = ms ~/ 1000;
    final centiseconds = (ms % 1000) ~/ 10;
    
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');
    final csStr = centiseconds.toString().padLeft(2, '0');
    
    return '$mStr:$sStr.$csStr';
  }

  void start() {
    if (state == StopwatchState.idle) {
      reset();
    }
    state = StopwatchState.running;
    _lastTickTime = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 100), _tick);
    notifyListeners();
  }

  void _tick(Timer t) {
    final now = DateTime.now();
    final diff = now.difference(_lastTickTime!).inMilliseconds;
    _lastTickTime = now;
    _elapsedMs += diff;
    notifyListeners();
  }

  void pause() {
    if (state == StopwatchState.running) {
      state = StopwatchState.paused;
      _timer?.cancel();
      _timer = null;
      notifyListeners();
    }
  }

  void lap() {
    if (state == StopwatchState.running) {
      final split = _elapsedMs - _lastLapTotalMs;
      laps.add(LapData(number: laps.length + 1, splitMs: split, totalMs: _elapsedMs));
      _lastLapTotalMs = _elapsedMs;
      notifyListeners();
    }
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    state = StopwatchState.idle;
    _elapsedMs = 0;
    _lastLapTotalMs = 0;
    laps.clear();
    notifyListeners();
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final stopwatchProvider = ChangeNotifierProvider<StopwatchProvider>((ref) {
  return StopwatchProvider();
});
