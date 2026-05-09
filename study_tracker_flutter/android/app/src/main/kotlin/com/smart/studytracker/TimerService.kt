package com.smart.studytracker

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

class TimerService : Service() {
    companion object {
        const val CHANNEL_ID = "study_tracker_timer_channel"
        const val NOTIFICATION_ID = 1101

        const val ACTION_START = "com.smart.studytracker.timer.START"
        const val ACTION_PAUSE = "com.smart.studytracker.timer.PAUSE"
        const val ACTION_RESUME = "com.smart.studytracker.timer.RESUME"
        const val ACTION_STOP = "com.smart.studytracker.timer.STOP"

        const val BROADCAST_STATE = "com.smart.studytracker.timer.STATE"

        private var state: String = "idle"
        private var mode: String = "long_session"
        private var startedAtEpochMs: Long? = null
        private var elapsedSeconds: Int = 0
        private var breakSeconds: Int = 0
        private var phaseElapsedSeconds: Int = 0
        private var pomodoroCount: Int = 0
        private var focusMinutes: Int = 25
        private var breakMinutes: Int = 5
        private var isBreakPhase: Boolean = false

        fun currentStateMap(): HashMap<String, Any?> {
            return hashMapOf(
                "state" to state,
                "mode" to mode,
                "startedAtEpochMs" to startedAtEpochMs,
                "elapsedSeconds" to elapsedSeconds,
                "breakSeconds" to breakSeconds,
                "phaseElapsedSeconds" to phaseElapsedSeconds,
                "pomodoroCount" to pomodoroCount,
                "focusMinutes" to focusMinutes,
                "breakMinutes" to breakMinutes,
                "isBreakPhase" to isBreakPhase,
            )
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private val ticker = object : Runnable {
        override fun run() {
            tick()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                mode = intent.getStringExtra("mode") ?: "long_session"
                focusMinutes = intent.getIntExtra("focusMinutes", 25)
                breakMinutes = intent.getIntExtra("breakMinutes", 5)

                state = "running"
                isBreakPhase = false
                startedAtEpochMs = System.currentTimeMillis()
                elapsedSeconds = 0
                breakSeconds = 0
                phaseElapsedSeconds = 0
                pomodoroCount = 0

                startForeground(NOTIFICATION_ID, buildNotification())
                startTicker()
                broadcastState()
            }

            ACTION_PAUSE -> {
                if (state == "running" || state == "breakPhase") {
                    state = "paused"
                    stopTicker()
                    updateNotification()
                    broadcastState()
                }
            }

            ACTION_RESUME -> {
                if (state == "paused") {
                    state = if (isBreakPhase) "breakPhase" else "running"
                    startTicker()
                    updateNotification()
                    broadcastState()
                } else if (state == "breakPhase") {
                    // Resume action doubles as "skip break" when already in break.
                    isBreakPhase = false
                    phaseElapsedSeconds = 0
                    state = "running"
                    updateNotification()
                    broadcastState()
                }
            }

            ACTION_STOP -> {
                stopTicker()
                resetInternalState()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                broadcastState()
            }
        }

        return START_STICKY
    }

    override fun onDestroy() {
        stopTicker()
        super.onDestroy()
    }

    private fun startTicker() {
        handler.removeCallbacks(ticker)
        handler.postDelayed(ticker, 1000)
    }

    private fun stopTicker() {
        handler.removeCallbacks(ticker)
    }

    private fun tick() {
        if (state == "running") {
            elapsedSeconds += 1
            phaseElapsedSeconds += 1

            if (mode == "pomodoro" && !isBreakPhase) {
                val focusLimit = focusMinutes * 60
                if (phaseElapsedSeconds >= focusLimit) {
                    phaseElapsedSeconds = 0
                    isBreakPhase = true
                    state = "breakPhase"
                    pomodoroCount += 1
                }
            }

            if (isBreakPhase) {
                breakSeconds += 1
            }
        } else if (state == "breakPhase") {
            breakSeconds += 1
            phaseElapsedSeconds += 1
            val breakLimit = breakMinutes * 60
            if (phaseElapsedSeconds >= breakLimit) {
                phaseElapsedSeconds = 0
                isBreakPhase = false
                state = "running"
            }
        }

        updateNotification()
        broadcastState()
    }

    private fun resetInternalState() {
        state = "idle"
        mode = "long_session"
        startedAtEpochMs = null
        elapsedSeconds = 0
        breakSeconds = 0
        phaseElapsedSeconds = 0
        pomodoroCount = 0
        focusMinutes = 25
        breakMinutes = 5
        isBreakPhase = false
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Study Timer",
                NotificationManager.IMPORTANCE_LOW,
            )
            channel.description = "Foreground timer updates"
            manager.createNotificationChannel(channel)
        }
    }

    private fun updateNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun buildNotification(): Notification {
        val pauseIntent = Intent(this, TimerService::class.java).apply { action = ACTION_PAUSE }
        val resumeIntent = Intent(this, TimerService::class.java).apply { action = ACTION_RESUME }
        val stopIntent = Intent(this, TimerService::class.java).apply { action = ACTION_STOP }

        val pausePending = PendingIntent.getService(
            this,
            2001,
            pauseIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val resumePending = PendingIntent.getService(
            this,
            2002,
            resumeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stopPending = PendingIntent.getService(
            this,
            2003,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val title = when (state) {
            "breakPhase" -> "Break running"
            "paused" -> "Timer paused"
            "running" -> "Focus running"
            else -> "Timer idle"
        }

        val text = formatDuration(elapsedSeconds)

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(state == "running" || state == "breakPhase" || state == "paused")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOnlyAlertOnce(true)
            .setSound(null)
            .setVibrate(longArrayOf())
            .apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    setSilent(true)
                }
            }

        if (state == "paused") {
            builder.addAction(0, "Resume", resumePending)
        } else {
            builder.addAction(0, "Pause", pausePending)
        }
        builder.addAction(0, "Stop", stopPending)

        return builder.build()
    }

    private fun formatDuration(seconds: Int): String {
        val h = seconds / 3600
        val m = (seconds % 3600) / 60
        val s = seconds % 60
        return if (h > 0) {
            String.format("%02d:%02d:%02d", h, m, s)
        } else {
            String.format("%02d:%02d", m, s)
        }
    }

    private fun broadcastState() {
        val intent = Intent(BROADCAST_STATE)
        val data = currentStateMap()
        for ((k, v) in data) {
            when (v) {
                is String -> intent.putExtra(k, v)
                is Int -> intent.putExtra(k, v)
                is Long -> intent.putExtra(k, v)
                is Boolean -> intent.putExtra(k, v)
            }
        }
        sendBroadcast(intent)
    }
}
