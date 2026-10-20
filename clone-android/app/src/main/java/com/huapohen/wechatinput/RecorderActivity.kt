package com.huapohen.wechatinput

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.view.Gravity
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.huapohen.wechatinput.net.ApiClient
import com.huapohen.wechatinput.net.Background
import com.huapohen.wechatinput.store.SessionStore
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class RecorderActivity : BasePageActivity() {
    private var recording = false
    private var paused = false
    private var startedAt = 0L
    private var accumulated = 0L
    private var sessionId = ""
    private val transcript = StringBuilder()
    private val handler = Handler(Looper.getMainLooper())
    private var speech: SpeechRecognizer? = null
    private lateinit var statusText: android.widget.TextView
    private lateinit var timerText: android.widget.TextView
    private lateinit var transcriptView: android.widget.TextView
    private lateinit var partialView: android.widget.TextView
    private lateinit var summaryView: android.widget.TextView
    private lateinit var sessionHost: LinearLayout
    private lateinit var startButton: com.google.android.material.button.MaterialButton
    private lateinit var pauseButton: com.google.android.material.button.MaterialButton
    private lateinit var stopButton: com.google.android.material.button.MaterialButton
    private var lastError: String? = null

    private val ticker = object : Runnable {
        override fun run() {
            if (recording && !paused) {
                timerText.text = formatDuration(elapsed())
                handler.postDelayed(this, 1000)
            }
        }
    }

    override fun onCreatePage() {
        setPageTitle("AI 录音笔", "设备实时转写 · 可选 AI 纪要")
        setHeaderAction("历史") { startActivity(Pages.intent(this, "recorder_session")) }

        addInfo(
            "录音笔",
            "使用 Android 系统语音识别实时转写；音频不上传、不保存。点“生成 AI 摘要”时，转写文本会发送到你配置的后端。"
        )
        val panel = Ui.card(this, 16)
        val head = Ui.horizontal(this)
        statusText = Ui.text(this, "● 待机", 14f, Ui.color(this, R.color.text_secondary), true)
        timerText = Ui.text(this, "00:00", 28f, Ui.color(this, R.color.text_primary), true).apply {
            letterSpacing = 0.06f
        }
        head.addView(statusText, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        head.addView(timerText)
        panel.addView(head)
        val wave = Ui.text(this, "▁▂▃▅▆▇▆▅▃▂▁", 18f, Ui.color(this, R.color.accent)).apply {
            gravity = Gravity.CENTER
            setPadding(0, Ui.dp(this@RecorderActivity, 8f), 0, Ui.dp(this@RecorderActivity, 8f))
        }
        panel.addView(wave)
        val actions = Ui.horizontal(this)
        startButton = Ui.button(this, "开始录音", true) { toggleStart() }
        pauseButton = Ui.button(this, "暂停", false) { togglePause() }.apply { isEnabled = false; alpha = 0.5f }
        stopButton = Ui.button(this, "结束", false) { stop() }.apply { isEnabled = false; alpha = 0.5f }
        actions.addView(startButton, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { marginEnd = Ui.dp(this@RecorderActivity, 6f) })
        actions.addView(pauseButton, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { marginEnd = Ui.dp(this@RecorderActivity, 6f) })
        actions.addView(stopButton, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        panel.addView(actions, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = Ui.dp(this@RecorderActivity, 8f)
        })
        content.addView(panel)

        content.addView(Ui.sectionTitle(this, "实时转写"))
        val transcriptCard = Ui.card(this, 16)
        transcriptView = Ui.text(this, "点击“开始录音”后，识别结果会逐句出现在这里。", 14f, Ui.color(this, R.color.text_secondary)).apply {
            setLineSpacing(Ui.dp(this@RecorderActivity, 5f).toFloat(), 1f)
            minHeight = Ui.dp(this@RecorderActivity, 80f)
        }
        transcriptCard.addView(transcriptView)
        partialView = Ui.text(this, "", 13f, Ui.color(this, R.color.accent_dark)).apply {
            setPadding(0, Ui.dp(this@RecorderActivity, 6f), 0, 0)
        }
        transcriptCard.addView(partialView)
        content.addView(transcriptCard)

        content.addView(Ui.sectionTitle(this, "AI 纪要"))
        val summaryCard = Ui.card(this, 16)
        summaryView = Ui.text(this, "结束一段录音后，可让后端生成摘要与要点。", 12.5f, Ui.color(this, R.color.text_secondary)).apply {
            setLineSpacing(Ui.dp(this@RecorderActivity, 4f).toFloat(), 1f)
        }
        summaryCard.addView(summaryView)
        val sumRow = Ui.horizontal(this).apply { setPadding(0, Ui.dp(this@RecorderActivity, 8f), 0, 0) }
        sumRow.addView(Ui.button(this, "生成 AI 摘要", true) { summarize() }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
            marginEnd = Ui.dp(this@RecorderActivity, 8f)
        })
        sumRow.addView(Ui.button(this, "重新试一次", false) { summarize() }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        summaryCard.addView(sumRow)
        content.addView(summaryCard)

        content.addView(Ui.sectionTitle(this, "历史会话"))
        sessionHost = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        content.addView(sessionHost)
        renderSessions()

        addInfo("能力边界", "转写依赖设备系统语音服务，模拟器可能没有可用识别服务。录音笔不会保存音频文件；“AI 摘要”失败时会显示真实错误。")
    }

    private fun toggleStart() {
        if (recording) stop() else start()
    }

    private fun start() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), 71)
            return
        }
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            showError("此设备没有可用的系统语音识别服务")
            return
        }
        transcript.setLength(0)
        transcriptView.text = "正在聆听…"
        transcriptView.setTextColor(Ui.color(this, R.color.text_primary))
        summaryView.text = "结束录音后可生成摘要。"
        sessionId = SessionStore.newId()
        startedAt = System.currentTimeMillis()
        accumulated = 0L
        recording = true
        paused = false
        lastError = null
        statusText.text = "● 录音中"
        statusText.setTextColor(Ui.color(this, R.color.accent_dark))
        startButton.text = "重新开始"
        pauseButton.isEnabled = true
        pauseButton.alpha = 1f
        pauseButton.text = "暂停"
        stopButton.isEnabled = true
        stopButton.alpha = 1f
        handler.removeCallbacks(ticker)
        handler.post(ticker)
        ensureRecognizer()
        listen()
    }

    private fun ensureRecognizer() {
        if (speech == null) {
            if (!SpeechRecognizer.isRecognitionAvailable(this)) return
            speech = SpeechRecognizer.createSpeechRecognizer(this).also { it.setRecognitionListener(listener) }
        }
    }

    private fun listen() {
        if (!recording || paused) return
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Prefs.voiceLanguage)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
            if (Prefs.voiceOffline) putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        }
        try {
            speech?.startListening(intent)
            partialView.text = "正在聆听…"
        } catch (e: Exception) {
            showError("无法启动语音识别：${e.message}")
        }
    }

    private fun togglePause() {
        if (!recording) return
        if (paused) {
            paused = false
            accumulated += System.currentTimeMillis() - startedAt
            startedAt = System.currentTimeMillis()
            pauseButton.text = "暂停"
            statusText.text = "● 录音中"
            partialView.text = "继续聆听…"
            listen()
            handler.removeCallbacks(ticker)
            handler.post(ticker)
        } else {
            paused = true
            accumulated += System.currentTimeMillis() - startedAt
            pauseButton.text = "继续"
            statusText.text = "● 已暂停"
            statusText.setTextColor(Ui.color(this, R.color.warning))
            speech?.stopListening()
            partialView.text = ""
        }
    }

    private fun stop() {
        if (!recording) return
        if (!paused) accumulated += System.currentTimeMillis() - startedAt
        recording = false
        paused = false
        speech?.stopListening()
        handler.removeCallbacks(ticker)
        statusText.text = "● 已结束"
        statusText.setTextColor(Ui.color(this, R.color.text_secondary))
        startButton.text = "开始录音"
        pauseButton.isEnabled = false
        pauseButton.alpha = 0.5f
        stopButton.isEnabled = false
        stopButton.alpha = 0.5f
        partialView.text = ""
        timerText.text = formatDuration(accumulated)
        val text = transcript.toString().trim()
        if (text.isBlank()) {
            transcriptView.text = "没有识别到内容。请检查麦克风权限与系统语音服务，或重试。"
            transcriptView.setTextColor(Ui.color(this, R.color.text_secondary))
            return
        }
        val session = SessionStore.Session(
            id = sessionId,
            title = text.lineSequence().firstOrNull()?.take(24) ?: "录音会话",
            created = System.currentTimeMillis(),
            durationMs = accumulated,
            transcript = text
        )
        SessionStore.upsert(this, session)
        transcriptView.text = text
        transcriptView.setTextColor(Ui.color(this, R.color.text_primary))
        renderSessions()
        toast("已保存会话，可生成 AI 摘要")
    }

    private fun summarize() {
        val text = transcript.toString().trim()
        if (text.isBlank()) {
            toast("先录一段并拿到转写文本")
            return
        }
        summaryView.setTextColor(Ui.color(this, R.color.text_secondary))
        summaryView.text = "正在请求 ${Prefs.baseUrl}…"
        Background.runCatching({
            val o = ApiClient.summary(text)
            Background.ui {
                val summary = o.optString("text").ifBlank { o.optString("summary") }
                if (summary.isBlank()) {
                    summaryView.text = "后端返回空摘要"
                    summaryView.setTextColor(Ui.color(this, R.color.danger))
                } else {
                    val bullets = o.optJSONArray("bullets")
                    val sb = StringBuilder(summary)
                    if (bullets != null && bullets.length() > 0) {
                        sb.append("\n\n")
                        for (i in 0 until bullets.length()) sb.append("· ").append(bullets.optString(i)).append('\n')
                    }
                    summaryView.text = sb.toString().trim()
                    summaryView.setTextColor(Ui.color(this, R.color.text_primary))
                    val existing = SessionStore.get(this, sessionId)
                    val session = SessionStore.Session(
                        id = sessionId,
                        title = existing?.title ?: (text.lineSequence().firstOrNull()?.take(24) ?: "录音会话"),
                        created = existing?.created ?: System.currentTimeMillis(),
                        durationMs = accumulated,
                        transcript = text,
                        summary = summary,
                        bullets = (0 until (bullets?.length() ?: 0)).map { bullets!!.optString(it) }
                    )
                    SessionStore.upsert(this, session)
                    renderSessions()
                }
            }
        }, { e ->
            summaryView.text = "摘要失败：${ApiClient.friendly(e)}\n后端：${Prefs.baseUrl}\n可点“重新试一次”。"
            summaryView.setTextColor(Ui.color(this, R.color.danger))
        })
    }

    private fun showError(msg: String) {
        lastError = msg
        toast(msg)
        if (::summaryView.isInitialized) {
            summaryView.text = "转写不可用：$msg"
            summaryView.setTextColor(Ui.color(this, R.color.danger))
        }
        if (!recording && ::statusText.isInitialized) {
            statusText.text = "● 错误"
            statusText.setTextColor(Ui.color(this, R.color.danger))
        }
    }

    private fun renderSessions() {
        if (!::sessionHost.isInitialized) return
        sessionHost.removeAllViews()
        val sessions = SessionStore.all(this)
        if (sessions.isEmpty()) {
            val card = Ui.card(this, 16)
            card.addView(Ui.text(this, "还没有保存的会话", 13f, Ui.color(this, R.color.text_secondary)))
            sessionHost.addView(card)
            return
        }
        val group = Ui.group(this)
        sessions.take(8).forEachIndexed { i, s ->
            val row = Ui.horizontal(this).apply {
                minimumHeight = Ui.dp(this@RecorderActivity, 58f)
                setPadding(Ui.dp(this@RecorderActivity, 14f), Ui.dp(this@RecorderActivity, 8f), Ui.dp(this@RecorderActivity, 10f), Ui.dp(this@RecorderActivity, 8f))
                isClickable = true
                setOnClickListener {
                    startActivity(Pages.intent(this@RecorderActivity, "recorder_session", mapOf("id" to s.id)))
                }
            }
            val col = Ui.vertical(this)
            col.addView(Ui.text(this, s.title.ifBlank { "录音会话" }, 14f, Ui.color(this, R.color.text_primary), true))
            col.addView(Ui.text(
                this,
                SimpleDateFormat("MM-dd HH:mm", Locale.CHINA).format(Date(s.created)) + " · " + formatDuration(s.durationMs) +
                        if (s.summary.isNotBlank()) " · 有摘要" else "",
                11f, Ui.color(this, R.color.text_secondary)
            ).apply { setPadding(0, Ui.dp(this@RecorderActivity, 2f), 0, 0) })
            row.addView(col, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            row.addView(Ui.text(this, "›", 20f, Ui.color(this, R.color.muted)))
            group.addView(row)
            if (i < minOf(sessions.size, 8) - 1) group.addView(Ui.divider(this))
        }
        sessionHost.addView(group)
    }

    private fun elapsed(): Long = accumulated + if (recording && !paused) System.currentTimeMillis() - startedAt else 0L

    private fun formatDuration(ms: Long): String {
        val s = ms / 1000
        return String.format(Locale.US, "%02d:%02d", s / 60, s % 60)
    }

    private fun addInfo(title: String, body: String) {
        val card = Ui.card(this, 16)
        card.addView(Ui.text(this, title, 14f, Ui.color(this, R.color.text_primary), true))
        card.addView(Ui.text(this, body, 11.5f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(0, Ui.dp(this@RecorderActivity, 4f), 0, 0)
            setLineSpacing(Ui.dp(this@RecorderActivity, 3f).toFloat(), 1f)
        })
        content.addView(card)
    }

    private fun toast(msg: String) = Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()

    private val listener = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {
            partialView.text = "请说话…"
        }

        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {}

        override fun onError(error: Int) {
            if (!recording || paused) return
            val retryable = error == SpeechRecognizer.ERROR_NO_MATCH ||
                    error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT ||
                    error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY
            if (retryable) {
                handler.postDelayed({ if (recording && !paused) listen() }, 500)
            } else {
                val reason = when (error) {
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "缺少麦克风权限"
                    SpeechRecognizer.ERROR_NETWORK -> "语音服务网络错误"
                    SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "语音服务超时"
                    SpeechRecognizer.ERROR_SERVER -> "语音服务错误"
                    SpeechRecognizer.ERROR_AUDIO -> "录音失败"
                    else -> "错误 $error"
                }
                showError(reason)
            }
        }

        override fun onResults(results: Bundle?) {
            val text = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()
            if (text.isNotBlank()) {
                transcript.append(text)
                if (Prefs.voicePunctuation && (text.isEmpty() || text.last() !in "。！？.!?")) transcript.append("。")
                transcriptView.text = transcript.toString()
                transcriptView.setTextColor(Ui.color(this@RecorderActivity, R.color.text_primary))
            }
            partialView.text = ""
            if (recording && !paused) handler.postDelayed({ if (recording && !paused) listen() }, 300)
        }

        override fun onPartialResults(partialResults: Bundle?) {
            val text = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()
            partialView.text = text
        }

        override fun onEvent(eventType: Int, params: Bundle?) {}
    }

    override fun onDestroy() {
        recording = false
        handler.removeCallbacksAndMessages(null)
        speech?.destroy()
        speech = null
        super.onDestroy()
    }

    override fun onPause() {
        super.onPause()
        if (recording && !paused) {
            paused = true
            accumulated += System.currentTimeMillis() - startedAt
            speech?.stopListening()
            pauseButton.text = "继续"
            statusText.text = "● 已暂停"
        }
    }
}
