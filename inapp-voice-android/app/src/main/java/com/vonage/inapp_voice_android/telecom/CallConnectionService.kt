package com.vonage.inapp_voice_android.telecom

import android.net.Uri
import android.telecom.*
import android.util.Log
import com.vonage.inapp_voice_android.App
import com.vonage.inapp_voice_android.models.CallData
import com.vonage.inapp_voice_android.utils.Constants
import com.vonage.inapp_voice_android.utils.showToast

/**
 * A custom ConnectionService to handle incoming & outgoing calls.
 */
class CallConnectionService : ConnectionService() {
    override fun onCreateIncomingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        /*
        This gets the push info from the ClientManager
        and pulls out the 'from' number specified in your NCCO.
        A CallConnection Object is also created.
        This is how the system tells you
        the user has initiated an action with the System UI.
         */
        val bundle = request!!.extras
        val callId = bundle.getString(Constants.EXTRA_KEY_CALL_ID)!!
        val from = bundle.getString(Constants.EXTRA_KEY_FROM)
        CallData.callId = callId
        CallData.memberName = from
        CallData.memberLegId = null
        CallData.username = App.coreContext.user!!.username
        CallData.region = App.coreContext.user!!.region

        val connection = CallConnection(callId).apply {
            setAddress(Uri.parse(from), TelecomManager.PRESENTATION_ALLOWED)
            setCallerDisplayName(from, TelecomManager.PRESENTATION_ALLOWED)
            setRinging()
        }
        return connection
    }

    override fun onCreateOutgoingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        val bundle = request!!.extras
        val callId = bundle.getString(Constants.EXTRA_KEY_CALL_ID)!!
        val to = bundle.getString(Constants.EXTRA_KEY_TO)
        CallData.callId = callId
        CallData.memberName = to
        CallData.memberLegId = null
        CallData.username = App.coreContext.user!!.username
        CallData.region = App.coreContext.user!!.region

        val connection = CallConnection(callId).apply {
            setAddress(Uri.parse(to), TelecomManager.PRESENTATION_ALLOWED)
            setCallerDisplayName(to, TelecomManager.PRESENTATION_ALLOWED)
            setDialing()
        }
        return connection
    }

    override fun onCreateIncomingConnectionFailed(connectionManagerPhoneAccount: PhoneAccountHandle?, request: ConnectionRequest?
    ) {
        Log.e("onCreateIncomingFailed:",request.toString())
        showToast(applicationContext, "onCreateIncomingConnectionFailed")
    }

    override fun onCreateOutgoingConnectionFailed(connectionManagerPhoneAccount: PhoneAccountHandle?, request: ConnectionRequest?) {
        Log.e("onCreateOutgoingFailed:",request.toString())
        showToast(applicationContext, "onCreateOutgoingConnectionFailed")
    }
}