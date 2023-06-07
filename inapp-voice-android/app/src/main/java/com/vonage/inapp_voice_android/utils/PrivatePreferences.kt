package com.vonage.inapp_voice_android.utils

import android.content.Context

object PrivatePreferences {
    private const val NAME = "MY_PREF"
    const val PUSH_TOKEN = "PUSH_TOKEN"
    const val DEVICE_ID = "DEVICE_ID"
    const val USERNAME = "USERNAME"
    const val USER_ID = "USER_ID"
    const val DC = "DC"
    const val WS = "WS"
    const val REGION = "REGION"
    const val TOKEN = "TOKEN"


    fun set(key: String, value: String?, context: Context){
        context.getSharedPreferences(NAME, Context.MODE_PRIVATE)?.edit()?.apply {
            putString(key, value)
            apply()
        }
    }
    fun get(key: String, context: Context) : String? {
        return context.getSharedPreferences(NAME, Context.MODE_PRIVATE)?.getString(key, null)
    }
}