package com.huapohen.wechatinput

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.ViewGroup
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Toast
import com.huapohen.wechatinput.net.ApiClient
import com.huapohen.wechatinput.net.Background
import com.huapohen.wechatinput.store.ClipboardStore

class TranslateActivity : BasePageActivity() {
    private var sourceLang = 0
    private var targetLang = 1
    private var generation = 0
    private lateinit var source: EditText
    private lateinit var output: android.widget.TextView
    private lateinit var status: android.widget.TextView
    private val handler = Handler(Looper.getMainLooper())
    private var debounce: Runnable? = null
    private var lastTargetText = ""
    private var requestInFlight = false

    private val langs = listOf("自动检测", "中文", "英文", "日文", "韩文")
    private val codes = listOf("auto", "zh", "en", "ja", "ko")

    override fun onCreatePage() {
        setPageTitle("边写边译", "停顿 600ms 自动翻译 · 真实后端")
        setHeaderAction("文字工具") { startActivity(Pages.intent(this, "text_tools")) }

        val langCard = Ui.card(this, 14)
        val langRow = Ui.horizontal(this)
        langRow.addView(Ui.text(this, "从 ${langs[sourceLang]}", 13f, Ui.color(this, R.color.text_primary), true), LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        val swap = Ui.text(this, "⇄", 20f, Ui.color(this, R.color.accent_dark), true).apply {
            gravity = Gravity.CENTER
            setPadding(Ui.dp(this@TranslateActivity, 10f), 0, Ui.dp(this@TranslateActivity, 10f), 0)
            setOnClickListener {
                val t = sourceLang
                sourceLang = targetLang
                targetLang = t
                onCreatePageAgain()
            }
        }
        langRow.addView(swap)
        langRow.addView(Ui.text(this, "到 ${langs[targetLang]}", 13f, Ui.color(this, R.color.text_primary), true), LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
            gravity = Gravity.END
        })
        langCard.addView(langRow)
        val picks = Ui.horizontal(this).apply { setPadding(0, Ui.dp(this@TranslateActivity, 6f), 0, 0) }
        langs.forEachIndexed { i, label ->
            picks.addView(Ui.text(this, label, 11f, if (i == sourceLang) Ui.color(this, R.color.accent_dark) else Ui.color(this, R.color.text_secondary), i == sourceLang).apply {
                gravity = Gravity.CENTER
                background = Ui.rounded(if (i == sourceLang) Ui.color(this, R.color.accent_soft) else Ui.color(this, R.color.surface_alt), 99f)
                setPadding(0, Ui.dp(this@TranslateActivity, 6f), 0, Ui.dp(this@TranslateActivity, 6f))
                isClickable = true
                setOnClickListener { sourceLang = i; onCreatePageAgain() }
            }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginEnd = Ui.dp(this@TranslateActivity, 3f)
            })
        }
        langCard.addView(picks)
        content.addView(langCard)

        source = Ui.editText(this, "输入要翻译的内容…", true).apply {
            setText(intent.getStringExtra("seed_text").orEmpty())
            addTextChangedListener(object : android.text.TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                override fun afterTextChanged(s: android.text.Editable?) {
                    schedule(s?.toString().orEmpty())
                }
            })
        }
        content.addView(source, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Ui.dp(this, 120f)))
        buttonRow(
            Ui.button(this, "翻译一次", true) {
                debounce?.let { handler.removeCallbacks(it) }
                translateNow(source.text.toString())
            },
            Ui.button(this, "清空", false) {
                source.setText("")
                output.text = "译文会显示在这里"
                lastTargetText = ""
            }
        )
        status = Ui.text(this, "停顿后自动翻译 · ${Prefs.baseUrl}", 11f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(Ui.dp(this.context, 4f), 0, 0, Ui.dp(this.context, 6f))
        }
        content.addView(status)

        val outCard = Ui.card(this, 16)
        outCard.addView(Ui.text(this, "译文 / 目标语言", 12f, Ui.color(this, R.color.text_secondary), true))
        output = Ui.text(this, "译文会显示在这里", 16f, Ui.color(this, R.color.text_primary)).apply {
            setPadding(0, Ui.dp(this@TranslateActivity, 8f), 0, Ui.dp(this@TranslateActivity, 10f))
            setTextIsSelectable(true)
            setLineSpacing(Ui.dp(this@TranslateActivity, 4f).toFloat(), 1f)
        }
        outCard.addView(output)
        val outRow = Ui.horizontal(this)
        outRow.addView(Ui.button(this, "复制译文", true) {
            if (lastTargetText.isBlank()) toast("暂无译文")
            else copy(lastTargetText)
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
            marginEnd = Ui.dp(this@TranslateActivity, 8f)
        })
        outRow.addView(Ui.button(this, "复制并清空", false) {
            if (lastTargetText.isBlank()) toast("暂无译文")
            else {
                copy(lastTargetText)
                source.setText("")
            }
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        outCard.addView(outRow)
        content.addView(outCard)
        addInfo("发送", "“复制并清空”会把译文放入剪贴板并结束这一轮输入；回到宿主输入框粘贴即可，不会自动覆盖未确认文本。")

        val seed = intent.getStringExtra("seed_text").orEmpty()
        if (seed.isNotBlank()) schedule(seed)
    }

    private fun onCreatePageAgain() {
        val text = if (::source.isInitialized) source.text.toString() else ""
        content.removeAllViews()
        onCreatePage()
        if (text.isNotBlank()) source.setText(text)
    }

    private fun schedule(text: String) {
        debounce?.let { handler.removeCallbacks(it) }
        if (text.isBlank()) {
            status.text = "等待输入 · ${Prefs.baseUrl}"
            return
        }
        val job = Runnable { translateNow(text) }
        debounce = job
        status.text = "停顿后自动翻译…"
        handler.postDelayed(job, 600)
    }

    private fun translateNow(text: String) {
        val content = text.trim()
        if (content.isEmpty()) return
        generation++
        val token = generation
        requestInFlight = true
        status.text = "正在翻译…"
        status.setTextColor(Ui.color(this, R.color.text_secondary))
        val retry = { translateNow(text) }
        Background.runCatching({
            val result = ApiClient.translate(content, codes[sourceLang], codes[targetLang])
            Background.ui {
                if (token == generation) {
                    requestInFlight = false
                    if (result.isBlank()) {
                        status.text = "后端返回空译文"
                        status.setTextColor(Ui.color(this, R.color.danger))
                    } else {
                        output.text = result
                        lastTargetText = result
                        status.text = "翻译完成 · ${langs[sourceLang]} → ${langs[targetLang]}"
                        status.setTextColor(Ui.color(this, R.color.accent_dark))
                    }
                }
            }
        }, { e ->
            if (token == generation) {
                requestInFlight = false
                status.text = "失败：${ApiClient.friendly(e)} · 点“翻译一次”重试"
                status.setTextColor(Ui.color(this, R.color.danger))
                output.text = "暂时无法翻译。后端：${Prefs.baseUrl}\n${ApiClient.friendly(e)}"
            }
        })
    }

    private fun copy(text: String) {
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.setPrimaryClip(ClipData.newPlainText("微输入法", text))
        ClipboardStore.add(text)
        toast("译文已复制")
    }

    private fun addInfo(title: String, body: String) {
        val card = Ui.card(this, 16)
        card.addView(Ui.text(this, title, 14f, Ui.color(this, R.color.text_primary), true))
        card.addView(Ui.text(this, body, 11.5f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(0, Ui.dp(this@TranslateActivity, 4f), 0, 0)
        })
        content.addView(card)
    }

    private fun toast(msg: String) = Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()

    override fun onDestroy() {
        debounce?.let { handler.removeCallbacks(it) }
        super.onDestroy()
    }
}
