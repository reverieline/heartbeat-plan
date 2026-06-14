package org.heritageua.rhr_android

import android.content.Context
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MediaSessionHandler(
    private val context: Context,
    private val channel: MethodChannel
) : MethodChannel.MethodCallHandler {

    private var mediaSession: MediaSession? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val stageName = call.argument<String>("stageName") ?: ""
                val bpm = call.argument<Int>("bpm") ?: 0
                start(stageName, bpm)
                result.success(null)
            }
            "update" -> {
                val stageName = call.argument<String>("stageName") ?: ""
                val bpm = call.argument<Int>("bpm") ?: 0
                val isPaused = call.argument<Boolean>("isPaused") ?: false
                update(stageName, bpm, isPaused)
                result.success(null)
            }
            "stop" -> {
                stop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun getOrCreate(): MediaSession {
        if (mediaSession == null) {
            mediaSession = MediaSession(context, "RHRTraining").apply {
                setCallback(object : MediaSession.Callback() {
                    override fun onPlay() {
                        mainHandler.post { channel.invokeMethod("onPlay", null) }
                    }
                    override fun onPause() {
                        mainHandler.post { channel.invokeMethod("onPause", null) }
                    }
                    override fun onStop() {
                        mainHandler.post { channel.invokeMethod("onStop", null) }
                    }
                })
            }
        }
        return mediaSession!!
    }

    private fun start(stageName: String, bpm: Int) {
        val session = getOrCreate()
        applyState(session, isPaused = false)
        applyMetadata(session, stageName, bpm)
        session.isActive = true
    }

    private fun update(stageName: String, bpm: Int, isPaused: Boolean) {
        val session = mediaSession ?: return
        applyState(session, isPaused)
        applyMetadata(session, stageName, bpm)
    }

    private fun stop() {
        mediaSession?.let { session ->
            session.setPlaybackState(
                PlaybackState.Builder()
                    .setState(PlaybackState.STATE_STOPPED, PlaybackState.PLAYBACK_POSITION_UNKNOWN, 1f)
                    .setActions(0)
                    .build()
            )
            session.isActive = false
            session.release()
        }
        mediaSession = null
    }

    private fun applyState(session: MediaSession, isPaused: Boolean) {
        val state = if (isPaused) PlaybackState.STATE_PAUSED else PlaybackState.STATE_PLAYING
        val actions = if (isPaused) {
            PlaybackState.ACTION_PLAY or PlaybackState.ACTION_STOP
        } else {
            PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_STOP
        }
        session.setPlaybackState(
            PlaybackState.Builder()
                .setState(state, PlaybackState.PLAYBACK_POSITION_UNKNOWN, 1f)
                .setActions(actions)
                .build()
        )
    }

    private fun applyMetadata(session: MediaSession, stageName: String, bpm: Int) {
        val bpmStr = if (bpm > 0) "$bpm bpm" else "-- bpm"
        session.setMetadata(
            MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, stageName)
                .putString(MediaMetadata.METADATA_KEY_ARTIST, bpmStr)
                .putString(MediaMetadata.METADATA_KEY_ALBUM, "RHR Training")
                .build()
        )
    }
}
