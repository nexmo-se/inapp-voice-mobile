package com.vonage.inapp_voice_android.core

import android.content.Context
import android.util.Log
import com.vonage.inapp_voice_android.models.CallData
import com.vonage.inapp_voice_android.models.User
import com.vonage.inapp_voice_android.telecom.CallConnection
import com.vonage.inapp_voice_android.telecom.TelecomHelper
import com.vonage.inapp_voice_android.utils.PrivatePreferences


/**
 * A singleton class for storing and accessing Core Application Data
 */
class CoreContext private constructor(context: Context) {
    private val applicationContext: Context = context.applicationContext
    val telecomHelper: TelecomHelper by lazy { TelecomHelper(applicationContext) }
    val clientManager: VoiceClientManager by lazy { VoiceClientManager(applicationContext) }
    val notificationManager: InternalNotificationManager by lazy { InternalNotificationManager(applicationContext) }
    var sessionId: String? = null
    var activeCall:CallConnection? = null

    /**
     * The last Username logged.
     */
    var user: User? get() {
        if (PrivatePreferences.get(PrivatePreferences.USERNAME, applicationContext) == null) {
            return null
        }
        return User(
            PrivatePreferences.get(PrivatePreferences.USERNAME, applicationContext)!!,
            PrivatePreferences.get(PrivatePreferences.USER_ID, applicationContext)!!,
            PrivatePreferences.get(PrivatePreferences.REGION, applicationContext)!!,
            PrivatePreferences.get(PrivatePreferences.DC, applicationContext)!!,
            PrivatePreferences.get(PrivatePreferences.WS, applicationContext)!!,
            PrivatePreferences.get(PrivatePreferences.TOKEN, applicationContext)!!

        )
    } set(user) {
        PrivatePreferences.set(PrivatePreferences.USERNAME, user?.username, applicationContext)
        PrivatePreferences.set(PrivatePreferences.USER_ID, user?.userId, applicationContext)
        PrivatePreferences.set(PrivatePreferences.REGION, user?.region, applicationContext)
        PrivatePreferences.set(PrivatePreferences.DC, user?.dc, applicationContext)
        PrivatePreferences.set(PrivatePreferences.WS, user?.ws, applicationContext)
        PrivatePreferences.set(PrivatePreferences.TOKEN, user?.token, applicationContext)
    }

    /**
     * The Firebase Push Token obtained via PushNotificationService.
     */
    var pushToken: String? get() {
        return PrivatePreferences.get(PrivatePreferences.PUSH_TOKEN, applicationContext)
    } set(value) {
        PrivatePreferences.set(PrivatePreferences.PUSH_TOKEN, value, applicationContext)
    }
    /**
     * The Device ID bound to the Push Token once it will be registered.
     * It will be used to unregister the Push Token later on.
     */
    var deviceId: String? get() {
        return PrivatePreferences.get(PrivatePreferences.DEVICE_ID, applicationContext)
    } set(value) {
        PrivatePreferences.set(PrivatePreferences.DEVICE_ID, value, applicationContext)
    }

    companion object {
        // Volatile will guarantee a thread-safe & up-to-date version of the instance
        @Volatile
        private var instance: CoreContext? = null

        fun getInstance(context: Context): CoreContext {
            return instance ?: synchronized(this) {
                instance ?: CoreContext(context).also { instance = it }
            }
        }
    }
}