package com.vonage.inapp_voice_android.views.fragments

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
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

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentActivecallBinding.inflate(inflater, container, false)
        // If no argument is provided, state will default to CALL_RINGING
        currentCallState = arguments?.getString(CALL_STATE) ?: CALL_RINGING
        binding.tvCallStatus.text = when(currentCallState){
            CALL_ANSWERED -> ANSWERED_LABEL
            // Use RINGING_LABEL both for CALL_STARTED and CALL_RINGING
            else -> RINGING_LABEL
        }

        binding.tvTargetUser.text = CallData.memberName ?: ""
        return binding.root
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        binding.btHangUp.setOnClickListener {
            onHangup()
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

    companion object {
        const val RINGING_LABEL = "Ringing"
        const val ANSWERED_LABEL = "Answered"
    }
}