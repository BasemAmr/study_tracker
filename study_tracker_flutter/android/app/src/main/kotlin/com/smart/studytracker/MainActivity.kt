package com.smart.studytracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
	private var eventSink: EventChannel.EventSink? = null
	private var stateReceiver: BroadcastReceiver? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"com.smart.studytracker/timer_service",
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"start" -> {
					val mode = call.argument<String>("mode") ?: "long_session"
					val focusMinutes = call.argument<Int>("focusMinutes") ?: 25
					val breakMinutes = call.argument<Int>("breakMinutes") ?: 5

					val intent = Intent(this, TimerService::class.java).apply {
						action = TimerService.ACTION_START
						putExtra("mode", mode)
						putExtra("focusMinutes", focusMinutes)
						putExtra("breakMinutes", breakMinutes)
					}

					if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
						startForegroundService(intent)
					} else {
						startService(intent)
					}
					result.success(null)
				}

				"pause" -> {
					startService(Intent(this, TimerService::class.java).apply {
						action = TimerService.ACTION_PAUSE
					})
					result.success(null)
				}

				"resume" -> {
					startService(Intent(this, TimerService::class.java).apply {
						action = TimerService.ACTION_RESUME
					})
					result.success(null)
				}

				"stop" -> {
					val snapshot = TimerService.currentStateMap()
					startService(Intent(this, TimerService::class.java).apply {
						action = TimerService.ACTION_STOP
					})
					result.success(snapshot)
				}

				else -> result.notImplemented()
			}
		}

		EventChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"com.smart.studytracker/timer_updates",
		).setStreamHandler(object : EventChannel.StreamHandler {
			override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
				eventSink = events
				eventSink?.success(TimerService.currentStateMap())

				stateReceiver = object : BroadcastReceiver() {
					override fun onReceive(context: Context?, intent: Intent?) {
						if (intent?.action != TimerService.BROADCAST_STATE) {
							return
						}

						val payload = hashMapOf<String, Any?>(
							"state" to intent.getStringExtra("state"),
							"mode" to intent.getStringExtra("mode"),
							"startedAtEpochMs" to if (intent.hasExtra("startedAtEpochMs")) intent.getLongExtra("startedAtEpochMs", 0L) else null,
							"elapsedSeconds" to intent.getIntExtra("elapsedSeconds", 0),
							"breakSeconds" to intent.getIntExtra("breakSeconds", 0),
							"phaseElapsedSeconds" to intent.getIntExtra("phaseElapsedSeconds", 0),
							"pomodoroCount" to intent.getIntExtra("pomodoroCount", 0),
							"focusMinutes" to intent.getIntExtra("focusMinutes", 25),
							"breakMinutes" to intent.getIntExtra("breakMinutes", 5),
							"isBreakPhase" to intent.getBooleanExtra("isBreakPhase", false),
						)
						eventSink?.success(payload)
					}
				}

				val filter = IntentFilter(TimerService.BROADCAST_STATE)
				registerReceiver(stateReceiver, filter)
			}

			override fun onCancel(arguments: Any?) {
				stateReceiver?.let {
					unregisterReceiver(it)
				}
				stateReceiver = null
				eventSink = null
			}
		})
	}
}
