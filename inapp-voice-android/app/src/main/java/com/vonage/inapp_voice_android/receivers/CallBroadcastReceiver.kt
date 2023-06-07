package com.vonage.inapp_voice_android.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.telephony.TelephonyManager
import androidx.core.os.postDelayed
import com.vonage.inapp_voice_android.utils.navigateToCallActivity

class CallBroadcastReceiver: BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        context ?: return
        if(intent?.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED){ return }
        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        when(state){
            TelephonyManager.EXTRA_STATE_RINGING -> {
                // The Call Activity needs to be in foreground
                // for the audio to be recorded
                navigateToCallActivity(context)
            }
            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                //Add 500ms delay to make transition smoother
                Handler(Looper.getMainLooper()).postDelayed(500){
                    navigateToCallActivity(context)
                }
            }
        }
    }
}