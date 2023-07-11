package com.vonage.inapp_voice_android.views

import android.R.attr.label
import android.content.*
import android.content.pm.PackageManager
import android.graphics.Color
import android.opengl.Visibility
import android.os.Bundle
import android.telecom.Connection
import android.util.Log
import android.view.View
import android.widget.Button
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import com.vonage.clientcore.core.api.models.Username
import com.vonage.clientcore.core.conversation.VoiceChannelType
import com.vonage.inapp_voice_android.App
import com.vonage.inapp_voice_android.R
import com.vonage.inapp_voice_android.api.APIRetrofit
import com.vonage.inapp_voice_android.api.DeleteInformation
import com.vonage.inapp_voice_android.databinding.ActivityCallBinding
import com.vonage.inapp_voice_android.models.CallData
import com.vonage.inapp_voice_android.utils.*
import com.vonage.inapp_voice_android.utils.navigateToLoginActivity
import com.vonage.inapp_voice_android.utils.showAlert
import com.vonage.inapp_voice_android.utils.showToast
import com.vonage.inapp_voice_android.views.fragments.FragmentActiveCall
import com.vonage.inapp_voice_android.views.fragments.FragmentIdleCall
import retrofit2.Call
import retrofit2.Callback
import retrofit2.Response


class CallActivity : AppCompatActivity() {
    private val coreContext = App.coreContext
    private val clientManager = coreContext.clientManager
    private val notificationManager = coreContext.notificationManager
    private val telecomHelper = coreContext.telecomHelper
    private lateinit var binding: ActivityCallBinding

    /**
     * When an Active Call gets disconnected
     * (either remotely or locally) it will be null.
     * Hence, we use these variables to manually update the UI in that case
     */
    private var fallbackState: Int? = null

    private var fallbackUsername: Username? = null
    private var currentState = CALL_DISCONNECTED
    private var isMuteToggled = false
    private lateinit var logoutButton: Button

    /**
     * This Local BroadcastReceiver will be used
     * to receive messages from other activities
     */
    private val messageReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            // Handle the messages here

            // Call Is Muted Update
            intent?.getBooleanExtra(IS_MUTED, false)?.let {
                if (isMuteToggled != it) {
                    // TODO: mute
//                    toggleMute()
                }
            }
            // Call Remotely Disconnected
            intent?.getBooleanExtra(IS_REMOTE_DISCONNECT, false)?.let {
                fallbackState = if (it) Connection.STATE_DISCONNECTED else null
            }

            // Call Remotely Hangup
            intent?.getBooleanExtra(IS_REMOTE_REJECT, false)?.let {
                if (it && currentState == CALL_STARTED) {
                    showAlert(this@CallActivity, "Call Rejected", false)
                }
            }

            // Call Remotely Timeout
            intent?.getBooleanExtra(IS_REMOTE_TIMEOUT, false)?.let {
                if (it && currentState == CALL_STARTED) {
                    showAlert(this@CallActivity, "No Answer", false)
                }
            }

            // Call State Updated
            intent?.getStringExtra(CALL_STATE)?.let {
                currentState = it

                if (it == CALL_DISCONNECTED) {
                    replaceFragment(FragmentIdleCall())
                } else if (it == CALL_STARTED) {
                    replaceFragment(FragmentActiveCall())
                } else if (it == CALL_ANSWERED) {
                    replaceFragment(FragmentActiveCall())
                    updateCallData()
                }
            }

            // Handle Call Error
            intent?.getStringExtra(CALL_ERROR)?.let {
                handleCallError(it)
            }

            // Handle Session Error
            intent?.getStringExtra(SESSION_ERROR)?.let {
                handleSessionError(it)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        binding = ActivityCallBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val user = coreContext.user
        if (user == null ) {
            navigateToLoginActivity()
            return
        }

        handleIntent(intent)

        //
        // Set toolbar View
        val toolbar = binding.tbCall
        logoutButton = toolbar.btLogout
        logoutButton.visibility = View.VISIBLE

        replaceFragment(FragmentIdleCall())

        logoutButton.setOnClickListener {
            logout()
        }

        binding.btCopyData.setOnClickListener {
            val clipboard: ClipboardManager =
                getSystemService(CLIPBOARD_SERVICE) as ClipboardManager

            val copyText = "myLegId - ${CallData.username} : ${CallData.callId}, memberLegId - ${CallData.memberName.toString()} : ${CallData.memberLegId.toString()}, region : ${CallData.region}"
            val clip = ClipData.newPlainText("copyData", copyText)
            clipboard.setPrimaryClip(clip)
            showToast(this@CallActivity, "Copied")
        }

        registerReceiver(messageReceiver, IntentFilter(MESSAGE_ACTION))
    }

    override fun onResume() {
        super.onResume()
        val user = coreContext.user
        if (user == null ) {
            navigateToLoginActivity()
            return
        }
        coreContext.activeCall?.let {
            replaceFragment(FragmentActiveCall())
        }
        if (CallData.callId.isNotEmpty()) {
            updateCallData()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(messageReceiver)
    }

    /**
     * An Intent with extras will be received if
     * the App received an incoming call while device was locked.
     */
    private fun handleIntent(intent: Intent?){
        intent ?: return
        val callId = intent.getStringExtra(Constants.EXTRA_KEY_CALL_ID) ?: return
        val from = intent.getStringExtra(Constants.EXTRA_KEY_FROM) ?: return
        val typeString = intent.getStringExtra(Constants.EXTRA_KEY_CHANNEL_TYPE) ?: return
        val type = VoiceChannelType.valueOf(typeString)
        fallbackUsername = from
        fallbackState = Connection.STATE_RINGING

        CallData.callId = callId
        CallData.memberName = from
        CallData.region = coreContext.user!!.region
        CallData.username = coreContext.user!!.username
        updateCallData()

        turnKeyguardOff {
            if(notificationManager.isIncomingCallNotificationActive()){
                notificationManager.dismissIncomingCallNotification(callId)
                telecomHelper.startIncomingCall(callId, from, type)
            } else {
                // If the Notification has been canceled in the meantime
                this.finish()
            }
        }
    }

    private fun replaceFragment(fragment: Fragment) {

        if (currentState == CALL_ANSWERED || currentState == CALL_STARTED) {
            logoutButton.visibility = View.GONE
        }
        else {
            logoutButton.visibility = View.VISIBLE
        }

        val bundle = Bundle()
        if (currentState == CALL_ANSWERED || currentState == CALL_STARTED) {
            bundle.putString(CALL_STATE, currentState)
        }
        fragment.arguments = bundle
        val fragmentManager = supportFragmentManager
        val fragmentTransaction = fragmentManager.beginTransaction()
        fragmentTransaction.replace(R.id.fcCallStatus, fragment)
        fragmentTransaction.commitAllowingStateLoss()
    }

    private fun updateCallData() {
        binding.clCallData.visibility = View.VISIBLE
        binding.tvMyLegIdTitle.text = "myLegId - ${CallData.username}"
        binding.tvMyLegIdData.text = CallData.callId

        if (CallData.memberName !== null && CallData.memberLegId !== null ) {
            binding.tvMemberLegIdTitle.text = "memberLegId - ${CallData.memberName}"
            binding.tvMemberLegIdData.text = CallData.memberLegId
            binding.tvMemberLegIdTitle.visibility = View.VISIBLE
            binding.tvMemberLegIdData.visibility = View.VISIBLE
        }
        else {
            binding.tvMemberLegIdTitle.visibility = View.GONE
            binding.tvMemberLegIdData.visibility = View.GONE
        }

        binding.tvCallDataRegionData.text = CallData.region

    }

    private fun logout() {
        logoutButton.isEnabled = false
        logoutButton.setTextColor(Color.DKGRAY)
        val user = coreContext.user

        clientManager.logout {
            CallData.callId = ""
            navigateToLoginActivity()
        }

        APIRetrofit.instance.deleteUser(DeleteInformation(user!!.dc, user.userId, user.token)).enqueue(object:
            Callback<Void> {
            override fun onResponse(call: Call<Void>, response: Response<Void>) {
                logoutButton.isEnabled = true
                logoutButton.setTextColor(0x0100F5)
            }

            override fun onFailure(call: Call<Void>, t: Throwable) {
                logoutButton.isEnabled = true
                logoutButton.setTextColor(0x0100F5)
//                showAlert(this@CallActivity, "Failed to Delete User", false)
            }

        })
    }

    private fun handleCallError(message: String) {
        showAlert(this@CallActivity, message, false)
        // Hangup call
        coreContext.activeCall?.let { call ->
            clientManager.hangupCall(call)
        }
        replaceFragment(FragmentIdleCall())
    }

    private fun handleSessionError(message: String) {
        showAlert(this@CallActivity, message, true)
        coreContext.sessionId = null
        logout()
    }
//    private fun toggleMute() : Boolean{
//        isMuteToggled = binding.btnMute.toggleButton(isMuteToggled)
//        return isMuteToggled
//    }

    companion object {
        const val MESSAGE_ACTION = "com.vonage.inapp_voice_android.MESSAGE_TO_CALL_ACTIVITY"
        const val IS_MUTED = "isMuted"
        const val CALL_STATE = "callState"
        const val CALL_ANSWERED = "answered"
        const val CALL_STARTED = "started"
        const val CALL_RINGING = "ringing"
        const val CALL_DISCONNECTED = "disconnected"
        const val CALL_ERROR = "callError"
        const val SESSION_ERROR = "sessionError"
        const val IS_REMOTE_DISCONNECT = "isRemoteDisconnect"
        const val IS_REMOTE_REJECT = "isRemoteReject"
        const val IS_REMOTE_TIMEOUT = "isRemoteTimeout"
    }
}