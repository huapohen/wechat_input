package com.huapohen.wechatinput

import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.view.inputmethod.InputMethodInfo
import android.view.inputmethod.InputMethodManager
import com.huapohen.wechatinput.ime.WeTypeCloneImeService

object ImeHelper {
    private const val ID = "com.huapohen.wechatinput/.ime.WeTypeCloneImeService"

    fun enabled(context: Context): Boolean = try {
        val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        imm.enabledInputMethodList.any { it.id == ID || it.packageName == context.packageName }
    } catch (_: Exception) {
        false
    }

    fun selected(context: Context): Boolean = try {
        val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        val current = Settings.Secure.getString(context.contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
        current != null && (current == ID || current.startsWith(context.packageName + "/"))
    } catch (_: Exception) {
        false
    }

    fun list(context: Context): List<InputMethodInfo> = try {
        val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        imm.enabledInputMethodList
    } catch (_: Exception) {
        emptyList()
    }

    fun openEnableSettings(context: Context) {
        context.startActivity(
            Intent(Settings.ACTION_INPUT_METHOD_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }

    fun showPicker(context: Context) {
        val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        imm.showInputMethodPicker()
    }

    fun settingsIntent(): Intent = Intent(Settings.ACTION_INPUT_METHOD_SETTINGS)

    fun imeId(): String = ID
}
