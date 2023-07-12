package com.vonage.inapp_voice_android.telecom

import android.net.Uri
import android.os.Bundle
import android.telecom.CallAudioState
import android.telecom.Connection
import android.telecom.DisconnectCause
import android.util.Log
import com.vonage.inapp_voice_android.App
import com.vonage.voice.api.CallId

/**
 * A Connection class used to initiate a connection
 * when a User receives an incoming or outgoing call
 */
class CallConnection(val callId: CallId) : Connection() {
    private val coreContext = App.coreContext
    private val clientManager = coreContext.clientManager
    var isMuted = false
    init {
        // Update active call only if current is null
        coreContext.activeCall = coreContext.activeCall ?: this

        if  (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val properties = connectionProperties or PROPERTY_SELF_MANAGED
            connectionProperties = properties
        }

//        val capabilities = connectionCapabilities or CAPABILITY_MUTE or CAPABILITY_SUPPORT_HOLD or CAPABILITY_HOLD
//        connectionCapabilities = capabilities

        audioModeIsVoip = true
    }
    override fun onAnswer() {
        clientManager.answerCall(this)
    }

    override fun onReject() {
        clientManager.rejectCall(this)
    }

    override fun onDisconnect() {
        clientManager.hangupCall(this)
    }

    override fun onAbort() {
        clientManager.hangupCall(this)
    }

    override fun onCallAudioStateChanged(state: CallAudioState?) {
        state ?: return
        // Trigger mute/unmute only if states are not consistent
        val shouldMute = state.isMuted
        if (shouldMute != this.isMuted) {
            val muteAction = if (shouldMute) clientManager::muteCall else clientManager::unmuteCall
            muteAction(this)
        }
        val route = state.route
        println("isMuted: $isMuted, route: $route")
    }

    override fun onPlayDtmfTone(c: Char) {
        println("Dtmf Char received: $c")
        clientManager.sendDtmf(this, c.toString())
    }

    fun selfDestroy(){
        println("[$callId] Connection  is no more useful, destroying it")
        setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
        destroy()
    }

    fun clearActiveCall(){
        // Reset active call only if it was the current one
        coreContext.activeCall?.takeIf { it == this }?.let { coreContext.activeCall = null }
    }
}