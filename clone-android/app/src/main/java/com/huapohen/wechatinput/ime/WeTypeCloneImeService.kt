package com.huapohen.wechatinput.ime

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.inputmethodservice.InputMethodService
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import android.widget.FrameLayout
import android.widget.Toast
import androidx.core.content.ContextCompat
import com.huapohen.wechatinput.MainActivity
import com.huapohen.wechatinput.Pages
import com.huapohen.wechatinput.Prefs
import com.huapohen.wechatinput.Ui
import com.huapohen.wechatinput.data.DataEngine
import com.huapohen.wechatinput.net.ApiClient
import com.huapohen.wechatinput.net.Background

class WeTypeCloneImeService : InputMethodService(), ImeHost {
    private lateinit var keyboard: KeyboardView
    private var speech: SpeechRecognizer? = null
    private var listening = false
    private var cancelled = false
    private var lastPartial = ""
    private val main = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        Prefs.init(this)
        if (!DataEngine.isLoaded()) {
            Thread {
                DataEngine.ensureLoaded(this)
                main.post { if (::keyboard.isInitialized) keyboard.onEngineReady() }
            }.start()
        }
    }

    override fun onCreateInputView(): View {
        val wrapper = FrameLayout(this).apply {
            setBackgroundColor(Ui.color(this@WeTypeCloneImeService, com.huapohen.wechatinput.R.color.keyboard_bg))
        }
        keyboard = KeyboardView(this)
        keyboard.host = this
        val screen = resources.displayMetrics.widthPixels
        val max = Ui.dp(this, 920f)
        val width = minOf(screen, max)
        wrapper.addView(
            keyboard,
            FrameLayout.LayoutParams(width, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                gravity = Gravity.CENTER_HORIZONTAL or Gravity.BOTTOM
            }
        )
        return wrapper
    }

    override fun onStartInput(attribute: EditorInfo?, restarting: Boolean) {
        super.onStartInput(attribute, restarting)
        if (::keyboard.isInitialized) keyboard.resetBuffer()
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        if (::keyboard.isInitialized) keyboard.refreshFromPrefs()
    }

    override fun onFinishInputView(finishingInput: Boolean) {
        cancelVoice()
        if (::keyboard.isInitialized) keyboard.resetBuffer()
        super.onFinishInputView(finishingInput)
    }

    override fun onEvaluateInputViewShown(): Boolean = true
    override fun onEvaluateFullscreenMode(): Boolean = false

    override fun onDestroy() {
        speech?.destroy()
        speech = null
        super.onDestroy()
    }

    private fun ic(): InputConnection? = currentInputConnection

    override fun commitText(text: String) {
        if (text.isEmpty()) return
        ic()?.commitText(text, 1)
        keyboard.hideVoicePanel()
    }

    override fun setComposing(text: String) {
        if (text.isEmpty()) {
            ic()?.finishComposingText()
        } else {
            ic()?.setComposingText(text, 1)
        }
    }

    override fun backspace() {
        ic()?.deleteSurroundingText(1, 0)
    }

    override fun enter() {
        val info = currentInputEditorInfo
        if (Prefs.enterToSend) {
            val action = info?.imeOptions?.and(EditorInfo.IME_MASK_ACTION)
            if (action != null && action != EditorInfo.IME_ACTION_NONE && action != EditorInfo.IME_ACTION_UNSPECIFIED) {
                if (ic()?.performEditorAction(action) == true) return
            }
            if (ic()?.performEditorAction(EditorInfo.IME_ACTION_SEND) == true) return
            if (ic()?.performEditorAction(EditorInfo.IME_ACTION_DONE) == true) return
        }
        ic()?.sendKeyEvent(android.view.KeyEvent(android.view.KeyEvent.ACTION_DOWN, android.view.KeyEvent.KEYCODE_ENTER))
        ic()?.sendKeyEvent(android.view.KeyEvent(android.view.KeyEvent.ACTION_UP, android.view.KeyEvent.KEYCODE_ENTER))
    }

    override fun space() {
        ic()?.commitText(" ", 1)
    }

    override fun finishComposing() {
        ic()?.finishComposingText()
    }

    override fun launchPage(target: String, text: String) {
        try {
            val intent = if (target == "home") {
                Intent(this, MainActivity::class.java)
            } else {
                Pages.intent(this, target, if (text.isNotBlank()) mapOf("seed_text" to text) else emptyMap())
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            startActivity(intent)
            requestHideSelf(0)
        } catch (e: Exception) {
            toast("无法打开页面：${e.message}")
        }
    }

    override fun toast(message: String) {
        main.post { Toast.makeText(applicationContext, message, Toast.LENGTH_SHORT).show() }
    }

    // --- voice -------------------------------------------------------------
    override fun startVoice() {
        if (listening) {
            stopVoice()
            return
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            toast("请先在“微输入法 → 隐私与权限”中授予麦克风权限")
            launchPage("privacy", "")
            return
        }
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            toast("此设备没有可用的系统语音识别服务")
            return
        }
        cancelled = false
        lastPartial = ""
        if (speech == null) {
            speech = SpeechRecognizer.createSpeechRecognizer(this).also { it.setRecognitionListener(listener) }
        }
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Prefs.voiceLanguage)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
            if (Prefs.voiceOffline) putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        }
        try {
            listening = true
            speech?.startListening(intent)
            keyboard.showVoicePanel("")
            main.postDelayed({
                if (listening) {
                    listening = false
                    speech?.stopListening()
                }
            }, 60_000)
        } catch (e: Exception) {
            listening = false
            keyboard.voiceFailed("无法启动语音识别：${e.message}")
        }
    }

    override fun stopVoice() {
        if (!listening) return
        listening = false
        speech?.stopListening()
    }

    override fun cancelVoice() {
        cancelled = true
        listening = false
        speech?.cancel()
        if (::keyboard.isInitialized) keyboard.hideVoicePanel()
    }

    private val listener = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {
            keyboard.updateVoicePartial("请说话…")
        }

        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {
            listening = false
        }

        override fun onError(error: Int) {
            listening = false
            if (cancelled) {
                keyboard.hideVoicePanel()
                return
            }
            val reason = when (error) {
                SpeechRecognizer.ERROR_AUDIO -> "录音失败"
                SpeechRecognizer.ERROR_CLIENT -> "识别客户端错误"
                SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "缺少麦克风权限"
                SpeechRecognizer.ERROR_NETWORK -> "语音服务网络错误"
                SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "语音服务超时"
                SpeechRecognizer.ERROR_NO_MATCH -> "没有识别到语音"
                SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "识别服务忙"
                SpeechRecognizer.ERROR_SERVER -> "识别服务返回错误"
                SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "没有检测到说话"
                else -> "错误 $error"
            }
            keyboard.voiceFailed("语音识别失败：$reason")
        }

        override fun onResults(results: Bundle?) {
            listening = false
            if (cancelled) {
                keyboard.hideVoicePanel()
                return
            }
            val text = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()
            finishVoice(text)
        }

        override fun onPartialResults(partialResults: Bundle?) {
            val text = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()
            if (text.isNotBlank()) {
                lastPartial = text
                keyboard.updateVoicePartial(text)
            }
        }

        override fun onEvent(eventType: Int, params: Bundle?) {}
    }

    private fun finishVoice(raw: String) {
        val text = raw.ifBlank { lastPartial }
        if (text.isBlank()) {
            keyboard.voiceFailed("没有识别到语音")
            return
        }
        if (Prefs.voiceSmartPolish && !Prefs.standalone) {
            keyboard.updateVoicePartial("正在整理…")
            Background.runCatching({
                val polished = ApiClient.polish(text)
                Background.ui {
                    if (polished.isNotBlank()) keyboard.commitFromVoice(polished) else keyboard.commitFromVoice(text)
                }
            }, {
                main.post {
                    keyboard.commitFromVoice(text)
                    toast("语音整理失败，已使用原始识别结果")
                }
            })
        } else {
            keyboard.commitFromVoice(text)
        }
    }
}
