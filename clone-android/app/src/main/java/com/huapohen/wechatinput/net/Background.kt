package com.huapohen.wechatinput.net

import android.os.Handler
import android.os.Looper
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

object Background {
    private val io: ExecutorService = Executors.newFixedThreadPool(4)
    private val main = Handler(Looper.getMainLooper())

    fun run(task: () -> Unit) {
        io.execute {
            try {
                task()
            } catch (_: Throwable) {
            }
        }
    }

    fun runCatching(task: () -> Unit, onError: (Throwable) -> Unit) {
        io.execute {
            try {
                task()
            } catch (t: Throwable) {
                main.post { onError(t) }
            }
        }
    }

    fun ui(task: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) task() else main.post { task() }
    }
}
