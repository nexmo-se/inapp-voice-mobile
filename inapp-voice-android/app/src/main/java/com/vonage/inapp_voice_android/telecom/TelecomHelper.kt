package com.vonage.inapp_voice_android.telecom

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.telecom.PhoneAccount
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.telephony.PhoneStateListener
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import com.vonage.clientcore.core.api.models.Username
import com.vonage.clientcore.core.conversation.VoiceChannelType
import com.vonage.inapp_voice_android.utils.Constants
import com.vonage.inapp_voice_android.utils.showToast
import com.vonage.voice.api.CallId

/**
 * This Class will act as an interface
 * between the App and the Telecom Manager/Connection Service.
 */
class TelecomHelper(private val context: Context) {
    companion object {
        private const val CUSTOM_PHONE_ACCOUNT_NAME = "Vonage Voip Calling"
    }
    private val telecomManager = context.getSystemService(AppCompatActivity.TELECOM_SERVICE) as TelecomManager
    private val phoneAccountHandle : PhoneAccountHandle
    init {
        val componentName = ComponentName(context, CallConnectionService::class.java)
        phoneAccountHandle = PhoneAccountHandle(componentName, CUSTOM_PHONE_ACCOUNT_NAME)
        registerPhoneAccount()
    }

    /**
     *  As long as this property is false,
     *  the app will not be able to interact with the Telecom Manager
     */
    private val isPhoneAccountEnabled : Boolean get(){
        // In order to get an up-to-date state of the PhoneAccount
        // we need to fetch it through telecomManager.getPhoneAccount
        val phoneAccount = telecomManager.getPhoneAccount(phoneAccountHandle)
        return (phoneAccount.isEnabled)
            .also { if(!it) showEnableAccountActivity() }
    }

    private fun registerPhoneAccount(){
        // Get Phone account (if exists) or register it
        val phoneAccount = telecomManager.getPhoneAccount(phoneAccountHandle) ?:
        PhoneAccount
            .builder(phoneAccountHandle, CUSTOM_PHONE_ACCOUNT_NAME)
            .setCapabilities(PhoneAccount.CAPABILITY_CALL_PROVIDER)
            .build()
            .also {
                telecomManager.registerPhoneAccount(it)
            }
        // If PhoneAccount is disabled, prompt user to enable it
        if(!phoneAccount.isEnabled) {
            showEnableAccountActivity()
        }
    }

    private fun showEnableAccountActivity(){
        val intent = Intent()
        intent.setClassName(
            "com.android.server.telecom",
            "com.android.server.telecom.settings.EnableAccountPreferenceActivity"
        )
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        context.startActivity(intent)
        showToast(
            context,
            "Please enable $CUSTOM_PHONE_ACCOUNT_NAME Phone Account to use VoIP capabilities",
        )
    }

    /**
     * This method triggers the connection service and shows the System Incoming Call UI to handle incoming calls.
     */
    fun startIncomingCall(callId:CallId, from:Username, type: VoiceChannelType){
        println(("Call from: ${from}, via channel $callId, channelType: $type"))
        val extras = Bundle()
        extras.putString(Constants.EXTRA_KEY_CALL_ID, callId)
        extras.putString(Constants.EXTRA_KEY_FROM, from)
        val isManageOwnCallsPermitted = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O)  ActivityCompat.checkSelfPermission(context, Manifest.permission.MANAGE_OWN_CALLS) == PackageManager.PERMISSION_GRANTED else true
        val isCallPermitted = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) telecomManager.isIncomingCallPermitted(phoneAccountHandle) else true
        if (isManageOwnCallsPermitted && isPhoneAccountEnabled && isCallPermitted){
            telecomManager.addNewIncomingCall(phoneAccountHandle, extras)
        }
    }

    /**
     * This method places VoIP calls on behalf of the app.
     */
    fun startOutgoingCall(callId:CallId, to: String){
        println(("Calling Server with callId: $callId"))
        val rootExtras = Bundle()
        val extras = Bundle()
        extras.putString(Constants.EXTRA_KEY_TO, to)
        extras.putString(Constants.EXTRA_KEY_CALL_ID, callId)
        rootExtras.putParcelable(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, phoneAccountHandle)
        rootExtras.putParcelable(TelecomManager.EXTRA_OUTGOING_CALL_EXTRAS, extras)
        val isManageOwnCallsPermitted = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O)  ActivityCompat.checkSelfPermission(context, Manifest.permission.MANAGE_OWN_CALLS) == PackageManager.PERMISSION_GRANTED else true
        val isCallPhonePermitted = ActivityCompat.checkSelfPermission(context, Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED
        val isCallPermitted = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) telecomManager.isOutgoingCallPermitted(phoneAccountHandle) else  true


        if (isManageOwnCallsPermitted && isCallPhonePermitted && isPhoneAccountEnabled && isCallPermitted){
            telecomManager.placeCall(Uri.parse("tel:$to"), rootExtras)
        }
    }
}