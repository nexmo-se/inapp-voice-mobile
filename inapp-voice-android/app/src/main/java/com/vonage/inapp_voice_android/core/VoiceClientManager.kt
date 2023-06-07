package com.vonage.inapp_voice_android.core

import android.content.Context
import android.telecom.DisconnectCause
import android.util.Log
import com.google.firebase.messaging.RemoteMessage
import com.vonage.android_core.PushType
import com.vonage.android_core.VGClientConfig
import com.vonage.clientcore.core.api.*
import com.vonage.inapp_voice_android.models.User
import com.vonage.inapp_voice_android.telecom.CallConnection
import com.vonage.inapp_voice_android.App
import com.vonage.inapp_voice_android.api.APIRetrofit
import com.vonage.inapp_voice_android.api.RegisterFcmInformation
import com.vonage.inapp_voice_android.api.UnregisterFcmInformation
import com.vonage.inapp_voice_android.models.CallData
import com.vonage.inapp_voice_android.push.PushNotificationService
import com.vonage.inapp_voice_android.utils.*
import com.vonage.inapp_voice_android.utils.notifyCallDisconnectedToCallActivity
import com.vonage.inapp_voice_android.utils.notifyIsMutedToCallActivity
import com.vonage.inapp_voice_android.utils.showToast
import com.vonage.voice.api.VoiceClient
import retrofit2.Call
import retrofit2.Callback
import retrofit2.Response

/**
 * This Class will act as an interface
 * between the App and the Voice Client SDK
 */
class VoiceClientManager(private val context: Context) {
    private lateinit var client : VoiceClient
    private val coreContext = App.coreContext

    private fun initClient(user: User){
        setDefaultLoggingLevel(LoggingLevel.Info)

        var config = VGClientConfig()
        if (user.dc.contains("-us-")) {
            config = VGClientConfig(ClientConfigRegion.US)
        }
        else if (user.dc.contains("-eu-")) {
            config = VGClientConfig(ClientConfigRegion.EU)

        }
        else if (user.dc.contains("-ap-")) {
            config = VGClientConfig(ClientConfigRegion.AP)
        }

        client = VoiceClient(context)
        client.setConfig(config)
        setClientListeners()
    }

    private fun setClientListeners(){

        client.setSessionErrorListener { err ->
            coreContext.activeCall?.run {
                selfDestroy()
                clearActiveCall()
            }
            when(err){
                SessionErrorReason.TransportClosed -> notifySessionErrorToCallActivity(context, "Session Error: TransportClosed")
                SessionErrorReason.TokenExpired -> notifySessionErrorToCallActivity(context, "Session Error: TokenExpired")
                SessionErrorReason.PingTimeout -> notifySessionErrorToCallActivity(context, "Session Error: PingTimeout")
            }
        }

        client.setCallInviteListener { callId, from, type ->
            // Temp Push notification bug:
            // reject incoming calls when there is an active one
            coreContext.activeCall?.let { return@setCallInviteListener }

            if(isDeviceLocked(context)){
                coreContext.notificationManager.showIncomingCallNotification(callId, from, type)
            } else {
                coreContext.telecomHelper.startIncomingCall(callId, from, type)
            }
        }

        client.setOnLegStatusUpdate { callId, legId, status ->
            println("Call $callId has received status update $status for leg $legId")
            takeIfActive(callId)?.apply {
                if(status == LegStatus.answered){
                    setActive()
                    CallData.memberLegId = legId

                    notifyCallAnsweredToCallActivity(context)
                }
            }
        }

        client.setOnCallHangupListener { callId, callQuality, reason ->
            takeIfActive(callId)?.apply {
                val (cause, isRemote) = when(reason) {
                    HangupReason.remoteReject -> DisconnectCause.REJECTED to true
                    HangupReason.remoteHangup -> DisconnectCause.REMOTE to true
                    HangupReason.localHangup -> DisconnectCause.LOCAL to false
                    HangupReason.mediaTimeout -> DisconnectCause.BUSY to true
                }
                setDisconnected(DisconnectCause(cause))
                clearActiveCall()
                notifyCallDisconnectedToCallActivity(context, isRemote, reason == HangupReason.remoteHangup)
            }
        }

        client.setCallInviteCancelListener { callId, reason ->
            println("Invite to Call $callId has been canceled with reason: ${reason.name}")
            takeIfActive(callId)?.apply {
                val cause = when(reason){
                    VoiceInviteCancelReason.AnsweredElsewhere -> DisconnectCause(DisconnectCause.ANSWERED_ELSEWHERE)
                    VoiceInviteCancelReason.RejectedElsewhere -> DisconnectCause(DisconnectCause.REJECTED)
                    VoiceInviteCancelReason.RemoteCancel -> DisconnectCause(DisconnectCause.CANCELED)
                    VoiceInviteCancelReason.RemoteTimeout -> DisconnectCause(DisconnectCause.MISSED)
                    else -> { return@apply }
                }
                setDisconnected(cause)
                clearActiveCall()
                notifyCallDisconnectedToCallActivity(context, true)
            } ?: coreContext.notificationManager.dismissIncomingCallNotification(callId)
        }

        client.setCallTransferListener { callId, conversationId ->
            println("Call $callId has been transferred to conversation $conversationId")
        }

        client.setOnMutedListener { callId, legId, isMuted ->
            println("LegId $legId for Call $callId has been ${if(isMuted) "muted" else "unmuted"}")
            takeIf { callId == legId } ?: return@setOnMutedListener
            // Update Active Call Mute State
            takeIfActive(callId)?.isMuted = isMuted
            // Notify Call Activity
            notifyIsMutedToCallActivity(context, isMuted)
        }

        client.setOnDTMFListener { callId, legId, digits ->
            println("LegId $legId has sent DTMF digits '$digits' to Call $callId")
        }
    }

    fun login(user: User, onSuccessCallback: ((String) -> Unit)? = null, onErrorCallback: (() -> Unit)? = null){
        initClient(user)
        client.createSession(user.token){ error, sessionId ->
            sessionId?.let {
                showToast(context, "Connected")
                registerDevicePushToken(user)
                coreContext.sessionId = it
                coreContext.user = user
                onSuccessCallback?.invoke(it)
            } ?: error?.let {
                onErrorCallback?.invoke()
                showToast(context, "Login Failed: ${error.message}")
            }
        }
    }

    fun logout(onSuccessCallback: (() -> Unit)? = null){
        unregisterDevicePushToken(coreContext.user)
        coreContext.sessionId = null
        coreContext.user = null
        client.deleteSession { error ->
            error?.let {
                showToast(context, "Error Logging Out: ${error.message}")
            } ?: run {
                onSuccessCallback?.invoke()
            }
        }
    }

    fun startOutboundCall(callContext: Map<String, String>? = null){
        client.serverCall(callContext) { err, callId ->
            err?.let {
                notifyCallErrorToCallActivity(context, "Error starting outbound call: $it")
                println("Error starting outbound call: $it")
            } ?: callId?.let {
                notifyCallStartedToCallActivity(context)

                println("Outbound Call successfully started with Call ID: $it")
                val to = callContext?.get(Constants.CONTEXT_KEY_RECIPIENT) ?: Constants.DEFAULT_DIALED_NUMBER
                coreContext.telecomHelper.startOutgoingCall(it, to)
            }
        }
    }

    private fun registerDevicePushToken(user: User){
        val registerTokenCallback : (String) -> Unit = { token ->
            client.registerDevicePushToken(token) { err, deviceId ->
                err?.let {
                    println("Error in registering Device Push Token: $err")
                } ?: deviceId?.let {
                    coreContext.deviceId = deviceId
                    println("Device Push Token successfully registered with Device ID: $deviceId")
                }
            }

            // Register for backend FCM
            APIRetrofit.instance.registerFcm(RegisterFcmInformation(user.dc, user.token, token))
                .enqueue(object :
                    Callback<Void> {
                    override fun onResponse(call: Call<Void>, response: Response<Void>) {
                    }

                    override fun onFailure(call: Call<Void>, t: Throwable) {
                    }
                })
        }
        coreContext.pushToken?.let {
            registerTokenCallback(it)
        } ?: PushNotificationService.requestToken {
            registerTokenCallback(it)
        }
    }

    private fun unregisterDevicePushToken(user: User?){
        coreContext.deviceId?.let {
            client.unregisterDevicePushToken(it) { err ->
                err?.let {
                    notifyCallErrorToCallActivity(context, "Error in unregistering Device Push Token: $err")
                    println("Error in unregistering Device Push Token: $err")
                }
            }
        }
        if (user != null) {
            APIRetrofit.instance.unregisterFcm(UnregisterFcmInformation(user.dc, user.token))
                .enqueue(object :
                    Callback<Void> {
                    override fun onResponse(call: Call<Void>, response: Response<Void>) {
                    }
                    override fun onFailure(call: Call<Void>, t: Throwable) {
                    }
                 })
        }
    }

    fun processIncomingPush(remoteMessage: RemoteMessage) {
        val dataString = remoteMessage.data.toString()
        val type: PushType = VoiceClient.getPushNotificationType(dataString)
        if (type == PushType.INCOMING_CALL) {
            // This method will trigger the Client's Call Invite Listener
            client.processPushCallInvite(dataString)
        }
    }

    fun answerCall(call: CallConnection, attempt: Int = 3){
        call.takeIfActive()?.apply {
            client.answer(callId) { err ->
                if (err != null) {
                    if (attempt > 0) {
                        answerCall(call, attempt -1)
                    }else {
                        println("Error Answering Call, Attempt ${attempt}: $err")
                        setDisconnected(DisconnectCause(DisconnectCause.ERROR))
                        clearActiveCall()
                        notifyCallErrorToCallActivity(context, "Unable to Answer the Call: $err")
                    }

                } else {
                    println("Answered call with id: $callId")
                    setActive()
                    notifyCallAnsweredToCallActivity(context)
                }
            }
        } ?: call.selfDestroy()
    }

    fun rejectCall(call: CallConnection, attempt: Int = 3){
        call.takeIfActive()?.apply {
            client.reject(callId){ err ->
                if (err != null) {
                    if (attempt > 0) {
                        rejectCall(call, attempt -1)
                    }else {
                        notifyCallErrorToCallActivity(context, "Unable to Reject the Call: $err")
                        println("Error Rejecting Call: $err")
                        setDisconnected(DisconnectCause(DisconnectCause.ERROR))
                        clearActiveCall()
                    }
                } else {
                    println("Rejected call with id: $callId")
                    setDisconnected(DisconnectCause(DisconnectCause.REJECTED))
                    clearActiveCall()
                    notifyCallDisconnectedToCallActivity(context, false)
                }
            }
        } ?: call.selfDestroy()
    }

    fun hangupCall(call: CallConnection, attempt: Int = 3){
        call.takeIfActive()?.apply {
            client.hangup(callId) { err ->
                if (err != null) {
                    if (attempt > 0) {
                        hangupCall(call, attempt -1)
                    }else {
                        setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
                        clearActiveCall()
//                        notifyCallErrorToCallActivity(context, "Unable to Hanging Up Call: $err")
                        notifyCallDisconnectedToCallActivity(context, false)
                        println("Error Hanging Up Call: $err")
                    }
                } else {
                    println("Hung up call with id: $callId")
                    setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
                    clearActiveCall()
                    notifyCallDisconnectedToCallActivity(context, false)
                }

            }
        } ?: call.selfDestroy()
    }

    fun muteCall(call: CallConnection){
        call.takeIfActive()?.apply {
            client.mute(callId) { err ->
                if (err != null) {
                    notifyCallErrorToCallActivity(context, "Error Muting Call: $err")
                    println("Error Muting Call: $err")
                } else {
                    println("Muted call with id: $callId")
                }
            }
        }
    }

    fun unmuteCall(call: CallConnection){
        call.takeIfActive()?.apply {
            client.unmute(callId) { err ->
                if (err != null) {
                    notifyCallErrorToCallActivity(context, "Error Un-muting Call: $err")
                    println("Error Un-muting Call: $err")
                } else {
                    println("Un-muted call with id: $callId")
                }
            }
        }
    }

    fun sendDtmf(call: CallConnection, digit: String){
        call.takeIfActive()?.apply {
            client.sendDTMF(callId, digit){ err ->
                if (err != null) {
                    notifyCallErrorToCallActivity(context, "Error in Sending DTMF '$digit': $err")
                    println("Error in Sending DTMF '$digit': $err")
                } else {
                    println("Sent DTMF '$digit' on call with id: $callId")
                }
            }
        }
    }

    // Utilities to filter active calls
    private fun takeIfActive(callId: CallId) : CallConnection? {
      return coreContext.activeCall?.takeIf { it.callId == callId }
    }
    private fun CallConnection.takeIfActive() : CallConnection? {
        return takeIfActive(callId)
    }
}