package org.heritageua.rhr_android

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.drawable.Icon
import android.media.AudioAttributes
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MediaSessionHandler(
    context: Context,
    private val channel: MethodChannel
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val CHANNEL_ID      = "rhr_media_controls"
        private const val NOTIFICATION_ID  = 1002
        private const val ACTION_PLAY      = "org.heritageua.rhr_android.MEDIA_PLAY"
        private const val ACTION_PAUSE     = "org.heritageua.rhr_android.MEDIA_PAUSE"
        private const val ACTION_STOP      = "org.heritageua.rhr_android.MEDIA_STOP"
    }

    // Use applicationContext so Activity lifecycle doesn't affect the session.
    private val ctx: Context = context.applicationContext
    private val nm: NotificationManager = ctx.getSystemService(NotificationManager::class.java)
    private val mainHandler = Handler(Looper.getMainLooper())

    private var mediaSession: MediaSession? = null
    private var currentStage    = ""
    private var currentBpm      = 0
    private var totalDurationMs = 0L
    private var elapsedMs       = 0L
    private var receiverRegistered = false

    // Receives ACTION_PLAY / ACTION_PAUSE / ACTION_STOP from notification buttons
    // and routes them through MediaSession.Callback so Flutter gets the callbacks.
    private val transportReceiver = object : BroadcastReceiver() {
        override fun onReceive(c: Context?, intent: Intent?) {
            val controls = mediaSession?.controller?.transportControls ?: return
            when (intent?.action) {
                ACTION_PLAY  -> controls.play()
                ACTION_PAUSE -> controls.pause()
                ACTION_STOP  -> controls.stop()
            }
        }
    }

    // ── MethodChannel ────────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                currentStage    = call.argument<String>("stageName") ?: ""
                currentBpm      = call.argument<Int>("bpm") ?: 0
                totalDurationMs = (call.argument<Int>("totalDurationSeconds") ?: 0) * 1000L
                elapsedMs       = 0L
                start()
                result.success(null)
            }
            "update" -> {
                currentStage = call.argument<String>("stageName") ?: ""
                currentBpm   = call.argument<Int>("bpm") ?: 0
                elapsedMs    = (call.argument<Int>("elapsedSeconds") ?: 0) * 1000L
                val isPaused = call.argument<Boolean>("isPaused") ?: false
                update(isPaused)
                result.success(null)
            }
            "stop" -> {
                stop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ── Session lifecycle ────────────────────────────────────────────────────

    private fun start() {
        ensureChannel()
        ensureReceiver()
        val session = getOrCreate()
        applyMetadata(session)
        applyState(session, false)
        session.isActive = true
        postNotification(session, false)
    }

    private fun update(isPaused: Boolean) {
        val session = mediaSession ?: return
        applyMetadata(session)
        applyState(session, isPaused)
        postNotification(session, isPaused)
    }

    private fun stop() {
        nm.cancel(NOTIFICATION_ID)
        mediaSession?.let { s ->
            s.setPlaybackState(
                PlaybackState.Builder()
                    .setState(PlaybackState.STATE_STOPPED, totalDurationMs, 0f)
                    .build()
            )
            s.isActive = false
            s.release()
        }
        mediaSession = null
        if (receiverRegistered) {
            try { ctx.unregisterReceiver(transportReceiver) } catch (_: Exception) {}
            receiverRegistered = false
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private fun getOrCreate(): MediaSession {
        if (mediaSession == null) {
            mediaSession = MediaSession(ctx, "RHRTraining").apply {
                // Prevent our session from routing hardware media buttons (headphones, BT)
                // away from music apps — we only need the lock screen widget, not button control.
                setMediaButtonReceiver(null)
                // USAGE_UNKNOWN signals this session has no audio of its own, so Android/Samsung
                // does not route audio focus through it or displace the music player's session.
                setPlaybackToLocal(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_UNKNOWN)
                        .setContentType(AudioAttributes.CONTENT_TYPE_UNKNOWN)
                        .build()
                )
                setCallback(object : MediaSession.Callback() {
                    override fun onPlay()  { mainHandler.post { channel.invokeMethod("onPlay",  null) } }
                    override fun onPause() { mainHandler.post { channel.invokeMethod("onPause", null) } }
                    override fun onStop()  { mainHandler.post { channel.invokeMethod("onStop",  null) } }
                    // Samsung One UI only shows slots for PREV/PLAY/NEXT in the media widget.
                    // We occupy the PREV (left) slot as a Stop button.
                    override fun onSkipToPrevious() { mainHandler.post { channel.invokeMethod("onStop", null) } }
                })
            }
        }
        return mediaSession!!
    }

    private fun applyState(session: MediaSession, isPaused: Boolean) {
        val state   = if (isPaused) PlaybackState.STATE_PAUSED else PlaybackState.STATE_PLAYING
        // speed=1f while playing lets Android interpolate the progress bar between our 1s updates.
        val speed   = if (isPaused) 0f else 1f
        // ACTION_SKIP_TO_PREVIOUS occupies Samsung's left (⏮) slot and is routed to onStop —
        // the only way to get a second visible button in One UI's 3-slot media widget.
        val actions = PlaybackState.ACTION_STOP or
                      PlaybackState.ACTION_SKIP_TO_PREVIOUS or
                      if (isPaused) PlaybackState.ACTION_PLAY else PlaybackState.ACTION_PAUSE
        session.setPlaybackState(
            PlaybackState.Builder()
                .setState(state, elapsedMs, speed)
                .setActions(actions)
                .build()
        )
    }

    private fun applyMetadata(session: MediaSession) {
        session.setMetadata(
            MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE,  currentStage)
                .putString(MediaMetadata.METADATA_KEY_ARTIST, if (currentBpm > 0) "$currentBpm bpm" else "-- bpm")
                .putString(MediaMetadata.METADATA_KEY_ALBUM,  "RHR Training")
                // -1 hides the progress bar; positive value enables it.
                .putLong(MediaMetadata.METADATA_KEY_DURATION, if (totalDurationMs > 0) totalDurationMs else -1L)
                .build()
        )
    }

    /** Posts a MediaStyle notification linked to the session.
     *  Android 13+ uses this link to display the lock screen media area widget. */
    private fun postNotification(session: MediaSession, isPaused: Boolean) {
        val stopAction = buildAction("Stop",   ACTION_STOP,  android.R.drawable.ic_menu_close_clear_cancel, 10)
        val ppAction   = if (isPaused)
            buildAction("Resume", ACTION_PLAY,  android.R.drawable.ic_media_play,  11)
        else
            buildAction("Pause",  ACTION_PAUSE, android.R.drawable.ic_media_pause, 12)

        val piFlags = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        val contentIntent = PendingIntent.getActivity(
            ctx, 0,
            ctx.packageManager.getLaunchIntentForPackage(ctx.packageName),
            piFlags
        )

        // MediaStyle links the notification to the session — required for lock screen widget.
        val style = Notification.MediaStyle()
            .setMediaSession(session.sessionToken)
            .setShowActionsInCompactView(0, 1)  // Stop (0) and Pause/Resume (1)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            Notification.Builder(ctx, CHANNEL_ID)
        else
            @Suppress("DEPRECATION") Notification.Builder(ctx)

        builder.setStyle(style)
            .setContentTitle(currentStage)
            .setContentText(if (currentBpm > 0) "$currentBpm bpm" else "-- bpm")
            .setSmallIcon(ctx.applicationInfo.icon)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(contentIntent)
            .addAction(stopAction)   // index 0
            .addAction(ppAction)     // index 1

        nm.notify(NOTIFICATION_ID, builder.build())
    }

    private fun buildAction(label: String, action: String, iconRes: Int, reqCode: Int): Notification.Action {
        val pi = PendingIntent.getBroadcast(
            ctx, reqCode,
            Intent(action).setPackage(ctx.packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Notification.Action.Builder(Icon.createWithResource(ctx, iconRes), label, pi).build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Action.Builder(iconRes, label, pi).build()
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            nm.getNotificationChannel(CHANNEL_ID) == null) {
            NotificationChannel(CHANNEL_ID, "RHR Media Controls", NotificationManager.IMPORTANCE_LOW)
                .apply {
                    setShowBadge(false)
                    setSound(null, null)
                    enableVibration(false)
                }
                .also { nm.createNotificationChannel(it) }
        }
    }

    private fun ensureReceiver() {
        if (!receiverRegistered) {
            val filter = IntentFilter().apply {
                addAction(ACTION_PLAY)
                addAction(ACTION_PAUSE)
                addAction(ACTION_STOP)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                ctx.registerReceiver(transportReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                ctx.registerReceiver(transportReceiver, filter)
            }
            receiverRegistered = true
        }
    }
}
