package com.huapohen.wechatinput.ime

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.widget.TextView
import androidx.core.content.ContextCompat
import com.huapohen.wechatinput.Prefs
import com.huapohen.wechatinput.R
import com.huapohen.wechatinput.Ui

/**
 * A key that supports press-and-hold separately from click. Used by the space
 * key so hold-to-talk does not also insert a space.
 */
class KeyView(context: Context) : TextView(context) {
    var onPressStart: (() -> Unit)? = null
    var onPressEnd: (() -> Unit)? = null
    private var firedLong = false
    private val handler = Handler(Looper.getMainLooper())
    private val longRunnable = Runnable {
        firedLong = true
        onPressStart?.invoke()
    }

    init {
        gravity = android.view.Gravity.CENTER
        isClickable = true
        isFocusable = false
        setTextColor(Ui.color(context, R.color.text_primary))
        includeFontPadding = false
        setPadding(Ui.dp(context, 1f), 0, Ui.dp(context, 1f), 0)
        background = ContextCompat.getDrawable(context, R.drawable.bg_key)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                isPressed = true
                firedLong = false
                if (onPressStart != null) handler.postDelayed(longRunnable, 420)
                return true
            }
            MotionEvent.ACTION_UP -> {
                isPressed = false
                handler.removeCallbacks(longRunnable)
                if (firedLong) {
                    onPressEnd?.invoke()
                } else {
                    playSoundEffect(android.view.SoundEffectConstants.CLICK)
                    performClick()
                }
                return true
            }
            MotionEvent.ACTION_CANCEL -> {
                isPressed = false
                handler.removeCallbacks(longRunnable)
                if (firedLong) onPressEnd?.invoke()
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    override fun performClick(): Boolean {
        return super.performClick()
    }
}
