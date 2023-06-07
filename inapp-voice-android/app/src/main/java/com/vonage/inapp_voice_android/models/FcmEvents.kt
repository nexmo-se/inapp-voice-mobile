package com.vonage.inapp_voice_android.models

import androidx.lifecycle.MutableLiveData

object FcmEvents {
    val serviceEvent: MutableLiveData<String> by lazy {
        MutableLiveData<String>()
    }
}