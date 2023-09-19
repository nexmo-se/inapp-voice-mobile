package com.vonage.inapp_voice_android.views.fragments

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.annotation.RequiresApi
import androidx.fragment.app.Fragment
import com.vonage.inapp_voice_android.App
import com.vonage.inapp_voice_android.R
import com.vonage.inapp_voice_android.databinding.FragmentActivecallBinding
import com.vonage.inapp_voice_android.models.CallData
import com.vonage.inapp_voice_android.views.CallActivity.Companion.CALL_ANSWERED
import com.vonage.inapp_voice_android.views.CallActivity.Companion.CALL_RINGING
import com.vonage.inapp_voice_android.views.CallActivity.Companion.CALL_STATE


class FragmentActiveCall: Fragment(R.layout.fragment_activecall) {
    private var _binding: FragmentActivecallBinding? = null
    private val binding get() = _binding!!

    private val coreContext = App.coreContext
    private val clientManager = coreContext.clientManager
    private lateinit var currentCallState: String

    private val messageReceiver = object : BroadcastReceiver() {
          override fun onReceive(context: Context?, intent: Intent?) {
           // Call Is Muted Update
        intent?.getBooleanExtra(IS_MUTED, false)?.let {
            if (it) {
                binding.btMute.setBackgroundColor(Color.GREEN)
             }
            else {
                 binding.btMute.setBackgroundColor(Color.GRAY)
              }
          }
        }
    }

    private val headsetReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent) {
            if (intent.action == AudioManager.ACTION_HEADSET_PLUG) {
                Handler().postDelayed({
                    displaySpeakerState()
                }, 1000)
            }
        }
    }
    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentActivecallBinding.inflate(inflater, container, false)
        // If no argument is provided, state will default to CALL_RINGING
        currentCallState = arguments?.getString(CALL_STATE) ?: CALL_RINGING
         when(currentCallState){
            CALL_ANSWERED -> {
                binding.tvCallStatus.text = ANSWERED_LABEL
                binding.btMute.visibility = View.VISIBLE
                binding.btSpeaker.visibility = View.VISIBLE
            }
            // Use RINGING_LABEL both for CALL_STARTED and CALL_RINGING
            else -> {
                binding.tvCallStatus.text = RINGING_LABEL
                binding.btMute.visibility = View.GONE
                binding.btSpeaker.visibility = View.GONE
            }
        }

        // mute call initial state
        coreContext.activeCall?.let { call ->
            if (call.isMuted) {
                binding.btMute.setBackgroundColor(Color.GREEN)
            }
            else {
                binding.btMute.setBackgroundColor(Color.GRAY)
            }
        }

        // speaker initial state
        val audioManager = activity?.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION

        if (audioManager.isSpeakerphoneOn) {
            binding.btSpeaker.setBackgroundColor(Color.GREEN)
        }
        else {
            binding.btSpeaker.setBackgroundColor(Color.GRAY)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Use the generated request
            audioManager.requestAudioFocus(getAudioFocusRequest())

        } else {
            audioManager.requestAudioFocus(
                { },
                AudioAttributes.CONTENT_TYPE_SPEECH,
                AudioManager.AUDIOFOCUS_GAIN
            )
        }

        binding.tvTargetUser.text = CallData.memberName ?: ""

        BluetoothAdapter.getDefaultAdapter().getProfileProxy(context, object : BluetoothProfile.ServiceListener {
            // This method will be used when the new device connects
            override fun onServiceConnected(profile: Int, proxy: BluetoothProfile?) {
                // Checking if it is the headset that's active
                displaySpeakerState()
            }
            // This method will be used when the new device disconnects
            override fun onServiceDisconnected(profile: Int) {
                displaySpeakerState()
            }

        // Enabling ServiceListener for headsets
        }, BluetoothProfile.HEADSET)


        // Register our BroadcastReceiver
        requireActivity().registerReceiver(headsetReceiver, IntentFilter(Intent.ACTION_HEADSET_PLUG))
        requireActivity().registerReceiver(messageReceiver, IntentFilter(MESSAGE_ACTION))

        return binding.root
    }

    override fun onDestroyView() {
        super.onDestroyView()
        requireActivity().unregisterReceiver(messageReceiver)
        requireActivity().unregisterReceiver(headsetReceiver)
        _binding = null
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        binding.btHangUp.setOnClickListener {
            onHangup()
        }
        binding.btMute.setOnClickListener {
            toggleMute()
        }

        binding.btSpeaker.setOnClickListener {
            toggleSpeaker()
        }
    }
    private fun onHangup(){
        coreContext.activeCall?.let { call ->
            if (currentCallState == CALL_RINGING) {
                clientManager.rejectCall(call)
            }
            else {
                clientManager.hangupCall(call)
            }
        }
    }
    private fun toggleMute() {
        coreContext.activeCall?.let { call ->
            if (call.isMuted) {
                clientManager.unmuteCall(call)
            }
            else {
                clientManager.muteCall(call)
            }
        }
    }
    private fun toggleSpeaker() {
        val audioManager =
            activity?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return

        if (audioManager.isSpeakerphoneOn) {
            binding.btSpeaker.setBackgroundColor(Color.GRAY)
            audioManager.isSpeakerphoneOn = false
        }
        else {
            binding.btSpeaker.setBackgroundColor(Color.GREEN)
            audioManager.isSpeakerphoneOn = true
        }
    }

    private fun displaySpeakerState() {
        val audioManager =
            activity?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        if (audioManager.isSpeakerphoneOn) {
            binding.btSpeaker.setBackgroundColor(Color.GREEN)
        }
        else {
            binding.btSpeaker.setBackgroundColor(Color.GRAY)
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun getAudioFocusRequest() = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN).build()

    companion object {
        const val RINGING_LABEL = "Ringing"
        const val ANSWERED_LABEL = "Answered"
        const val IS_MUTED = "isMuted"
        const val MESSAGE_ACTION = "com.vonage.inapp_voice_android.MESSAGE_TO_ACTIVE_CALL_FRAGMENT"
    }
}