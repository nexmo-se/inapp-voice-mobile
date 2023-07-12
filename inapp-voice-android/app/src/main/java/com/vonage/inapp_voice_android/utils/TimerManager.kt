package com.vonage.inapp_voice_android.utils

import android.os.Handler
import android.os.Looper

object TimerManager {
    private val handler: Handler = Handler(Looper.getMainLooper())
    private val timerMap: MutableMap<String, Runnable> = mutableMapOf()

    const val CONNECTION_SERVICE_TIMER = "ConnectionServiceTimer"

    fun startTimer(timerId: String, delayMillis: Long, callback: () -> Unit) {
        val runnable = Runnable {
            callback.invoke()
            timerMap.remove(timerId)
        }
        timerMap[timerId] = runnable
        handler.postDelayed(runnable, delayMillis)
    }

    fun cancelTimer(timerId: String) {
        val runnable = timerMap[timerId]
        if (runnable != null) {
            handler.removeCallbacks(runnable)
            timerMap.remove(timerId)
        }
    }
}
