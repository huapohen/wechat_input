package com.huapohen.wechatinput

import android.app.Application
import com.huapohen.wechatinput.data.DataEngine

class App : Application() {
    override fun onCreate() {
        super.onCreate()
        instance = this
        Prefs.init(this)
        // The full dictionary is indexed when the IME is first attached; the
        // home/settings UI must not wait for it.
    }

    companion object {
        lateinit var instance: App
            private set
    }
}
