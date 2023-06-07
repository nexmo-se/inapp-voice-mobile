package com.vonage.inapp_voice_android.core

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.vonage.clientcore.core.api.CallId
import com.vonage.clientcore.core.api.models.Username
import com.vonage.clientcore.core.conversation.VoiceChannelType
import com.vonage.inapp_voice_android.R
import com.vonage.inapp_voice_android.utils.Constants
import com.vonage.inapp_voice_android.views.CallActivity

/**
 * An internal class to handle Notifications
 */
class InternalNotificationManager(private val context: Context) {
    companion object {
        private const val CHANNEL_ID = "VonageSampleAppIncomingCalls"
        private const val CHANNEL_NAME = "Incoming Calls"
        private const val INCOMING_CALL_NOTIFICATION_ID = 123
        private const val NOTIFICATION_REQUEST_CODE = 1234
    }

    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private var callId: CallId? = null

    /**
     * From Android 8.0 (API 26) it is mandatory to create a Notification Channel
     */
    private fun createNotificationChannel(){
        // Create the notification channel with a unique ID
        val importance = NotificationManager.IMPORTANCE_HIGH
        val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, importance)
        // We'll use the default system ringtone for our incoming call notification channel.  You can
        // use your own audio resource here.
        // We'll use the default system ringtone for our incoming call notification channel.  You can
        // use your own audio resource here.
        val ringtoneUri: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        channel.setSound(
            ringtoneUri,
            AudioAttributes.Builder() // Setting the AudioAttributes is important as it identifies the purpose of your
                // notification sound.
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        )
        // Get the NotificationManager and create the channel
        notificationManager.createNotificationChannel(channel)
    }


    /**
     * This method will show an Incoming call Notification if the device is locked
     */
    fun showIncomingCallNotification(callId: CallId, from: Username, type: VoiceChannelType){

        // Update state var
        this.callId = callId
        // Create the Intent to launch the main activity with extra data
        val intent = Intent(context, CallActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK //or Intent.FLAG_ACTIVITY_NO_USER_ACTION
            putExtra(Constants.EXTRA_KEY_CALL_ID, callId)
            putExtra(Constants.EXTRA_KEY_FROM, from)
            putExtra(Constants.EXTRA_KEY_CHANNEL_TYPE, type.name)
        }
        val pendingIntent = PendingIntent.getActivity(context, NOTIFICATION_REQUEST_CODE, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

        // Create Notification Channel if it doesn't exist
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notificationManager.getNotificationChannel(CHANNEL_ID) ?: createNotificationChannel()
        }
        // Create the notification builder
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.vonage_logo_svg)
            .setContentTitle("Incoming Call from $from")
            .setContentText("Tap to answer")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            //.setContentIntent(pendingIntent)
            .setFullScreenIntent(pendingIntent, true)
        //.setAutoCancel(true)

        val notification = builder.build()
        notification.flags = notification.flags or Notification.FLAG_INSISTENT
        // Show the notification
        notificationManager.notify(INCOMING_CALL_NOTIFICATION_ID, notification)
    }

    /**
     * This method will dismiss the incoming call notification
     */
    fun dismissIncomingCallNotification(callId: CallId){
        if(this.callId == callId) {
            notificationManager.cancel(INCOMING_CALL_NOTIFICATION_ID)
            this.callId = null
        }
    }

    fun isIncomingCallNotificationActive() : Boolean {
        return notificationManager.activeNotifications.any { it.id == INCOMING_CALL_NOTIFICATION_ID }
    }
}