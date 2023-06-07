package com.vonage.inapp_voice_android

import android.app.Application
import android.util.Log
import com.vonage.inapp_voice_android.core.CoreContext

class App: Application() {

    companion object {
        lateinit var coreContext: CoreContext
    }
    init {
    }

    override fun onCreate() {
        super.onCreate()
        coreContext = CoreContext.getInstance(applicationContext)
    }

}
