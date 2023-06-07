package com.vonage.inapp_voice_android.push

import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.vonage.inapp_voice_android.App
import com.vonage.inapp_voice_android.models.FcmEvents

class PushNotificationService : FirebaseMessagingService() {
    companion object {
        /**
         * Request FCM Token Explicitly.
         */
        fun requestToken(onSuccessCallback: ((String) -> Unit)? = null){
            FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
                if (task.isSuccessful) {
                    task.result?.let { token ->
                        println("FCM Device Push Token: $token")
                        App.coreContext.pushToken = token
                        onSuccessCallback?.invoke(token)
                    }
                }
            }
        }
    }
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        println("New FCM Device Push Token:  $token")
        // Set new Push Token
        App.coreContext.pushToken = token
    }
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        // Whenever a Push Notification comes in
        // If there is no active session then
        // Create one using the latest valid Auth Token and notify the ClientManager
        // Else notify the ClientManager directly
        App.coreContext.run {
            if (remoteMessage.data.isNotEmpty() && remoteMessage.data["message"] == "updateUsersState") {
                if (sessionId == null) {return}
                FcmEvents.serviceEvent.postValue(remoteMessage.messageId)
            }
            else if (sessionId == null) {
                val user = user ?: return@run
                clientManager.login(user, onSuccessCallback = {
                    clientManager.processIncomingPush(remoteMessage)
                })

            } else {
                clientManager.processIncomingPush(remoteMessage)
            }
        }
    }
}