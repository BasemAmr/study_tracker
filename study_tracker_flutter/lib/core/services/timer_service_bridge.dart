import 'dart:async';
import 'package:flutter/services.dart';

class TimerServiceBridge {
  TimerServiceBridge._();

  static final TimerServiceBridge instance = TimerServiceBridge._();

  static const MethodChannel _methodChannel = MethodChannel(
    'com.smart.studytracker/timer_service',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.smart.studytracker/timer_updates',
  );

  Stream<Map<String, dynamic>> get stateStream {
    return _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return <String, dynamic>{};
    });
  }

  Future<void> start(String mode, int focusMinutes, int breakMinutes) async {
    await _methodChannel.invokeMethod<void>('start', <String, dynamic>{
      'mode': mode,
      'focusMinutes': focusMinutes,
      'breakMinutes': breakMinutes,
    });
  }

  Future<void> pause() async {
    await _methodChannel.invokeMethod<void>('pause');
  }

  Future<void> resume() async {
    await _methodChannel.invokeMethod<void>('resume');
  }

  Future<Map<String, dynamic>> stop() async {
    final data = await _methodChannel.invokeMethod<dynamic>('stop');
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }
}
