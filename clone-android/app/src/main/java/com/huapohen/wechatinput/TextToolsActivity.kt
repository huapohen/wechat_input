package com.huapohen.wechatinput

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.view.Gravity
import android.view.ViewGroup
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Toast
import com.huapohen.wechatinput.net.ApiClient
import com.huapohen.wechatinput.net.Background
import com.huapohen.wechatinput.store.ClipboardStore

class TextToolsActivity : BasePageActivity() {
    private var tool = 0
    private var style = 0
    private var targetLang = 0
    private var input: EditText? = null
    private var resultHost: LinearLayout? = null
    private var status: android.widget.TextView? = null
    private var busy = false
    private var previousResult: String? = null
    private var lastSource = ""

    private val tools = listOf("整理", "改写", "翻译", "摘要")
    private val styles = listOf("自然", "正式", "轻松", "简洁")
    private val targets = listOf("中文", "英文", "日文", "韩文")

    override fun onCreatePage() {
        setPageTitle("文字工具", "整理 · 改写 · 翻译 · 摘要（真实后端）")
        setHeaderAction("问 AI") { startActivity(Pages.intent(this, "ai_chat")) }

        val inputCard = Ui.card(this, 14)
        input = Ui.editText(this, "粘贴或输入要处理的文字…", true).apply {
            setText(intent.getStringExtra("seed_text").orEmpty())
        }
        inputCard.addView(input, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Ui.dp(this, 140f)))
        val toolRow = Ui.horizontal(this).apply { setPadding(0, Ui.dp(this@TextToolsActivity, 8f), 0, 0) }
        tools.forEachIndexed { index, label ->
            val chip = Ui.text(this, label, 13f, if (index == tool) Ui.color(this, R.color.accent_dark) else Ui.color(this, R.color.text_primary), index == tool).apply {
                gravity = Gravity.CENTER
                background = Ui.rounded(
                    if (index == tool) Ui.color(this@TextToolsActivity, R.color.accent_soft) else Ui.color(this@TextToolsActivity, R.color.surface_alt),
                    12f, Ui.color(this@TextToolsActivity, R.color.border)
                )
                setPadding(0, Ui.dp(this@TextToolsActivity, 10f), 0, Ui.dp(this@TextToolsActivity, 10f))
                isClickable = true
                setOnClickListener {
                    tool = index
                    onCreatePageAgain()
                }
            }
            toolRow.addView(chip, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginEnd = Ui.dp(this@TextToolsActivity, 6f)
            })
        }
        inputCard.addView(toolRow)

        if (tool == 1) {
            val row = Ui.horizontal(this).apply { setPadding(0, Ui.dp(this@TextToolsActivity, 8f), 0, 0) }
            styles.forEachIndexed { i, s ->
                row.addView(Ui.text(this, s, 12f, if (i == style) Ui.color(this, R.color.accent_dark) else Ui.color(this, R.color.text_secondary), i == style).apply {
                    gravity = Gravity.CENTER
                    background = Ui.rounded(if (i == style) Ui.color(this, R.color.accent_soft) else Ui.color(this, R.color.surface), 99f, Ui.color(this, R.color.border))
                    setPadding(0, Ui.dp(this@TextToolsActivity, 6f), 0, Ui.dp(this@TextToolsActivity, 6f))
                    isClickable = true
                    setOnClickListener { style = i; onCreatePageAgain() }
                }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                    marginEnd = Ui.dp(this@TextToolsActivity, 4f)
                })
            }
            inputCard.addView(row)
        }
        if (tool == 2) {
            val row = Ui.horizontal(this).apply { setPadding(0, Ui.dp(this@TextToolsActivity, 8f), 0, 0) }
            targets.forEachIndexed { i, s ->
                row.addView(Ui.text(this, s, 12f, if (i == targetLang) Ui.color(this, R.color.accent_dark) else Ui.color(this, R.color.text_secondary), i == targetLang).apply {
                    gravity = Gravity.CENTER
                    background = Ui.rounded(if (i == targetLang) Ui.color(this, R.color.accent_soft) else Ui.color(this, R.color.surface), 99f, Ui.color(this, R.color.border))
                    setPadding(0, Ui.dp(this@TextToolsActivity, 6f), 0, Ui.dp(this@TextToolsActivity, 6f))
                    isClickable = true
                    setOnClickListener { targetLang = i; onCreatePageAgain() }
                }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                    marginEnd = Ui.dp(this@TextToolsActivity, 4f)
                })
            }
            inputCard.addView(row)
        }
        content.addView(inputCard)

        buttonRow(
            Ui.button(this, runLabel(), true) { run() },
            Ui.button(this, "粘贴剪贴板", false) {
                val text = ClipboardStore.current(this)
                if (text.isBlank()) toast("剪贴板为空") else input?.setText(text)
            }
        )
        status = Ui.text(this, "后端：${Prefs.baseUrl}", 11f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(Ui.dp(this@TextToolsActivity, 4f), 0, 0, Ui.dp(this@TextToolsActivity, 6f))
        }
        content.addView(status)
        resultHost = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        content.addView(resultHost)
        addInfo("提示", "结果不会自动替换宿主文本；点“复制/应用”把结果放入剪贴板，或在键盘工具栏中继续使用。")
    }

    private fun runLabel(): String = when (tool) {
        0 -> "开始整理"
        1 -> "生成 3 个改写候选"
        2 -> "翻译为${targets[targetLang]}"
        else -> "生成摘要"
    }

    private fun onCreatePageAgain() {
        content.removeAllViews()
        onCreatePage()
    }

    private fun run() {
        if (busy) return
        val text = input?.text?.toString()?.trim().orEmpty()
        if (text.length < 2) {
            toast("请先输入文字")
            return
        }
        busy = true
        lastSource = text
        status?.text = "正在请求 ${Prefs.baseUrl}…"
        status?.setTextColor(Ui.color(this, R.color.text_secondary))
        resultHost?.removeAllViews()
        resultHost?.addView(Ui.text(this, "处理中…", 13f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(Ui.dp(this@TextToolsActivity, 4f), Ui.dp(this@TextToolsActivity, 8f), 0, 0)
        })
        val retry = { run() }
        Background.runCatching({
            when (tool) {
                0 -> {
                    val out = ApiClient.polish(text)
                    Background.ui { showResult(out, "整理完成") }
                }
                1 -> {
                    val out = ApiClient.rewrite(text, styles[style], 3)
                    Background.ui { showCandidates(out) }
                }
                2 -> {
                    val out = ApiClient.translate(text, "auto", when (targetLang) {
                        1 -> "en"
                        2 -> "ja"
                        3 -> "ko"
                        else -> "zh"
                    })
                    Background.ui { showResult(out, "翻译完成") }
                }
                else -> {
                    val o = ApiClient.summary(text)
                    Background.ui { showSummary(o.optString("text"), o) }
                }
            }
        }, { e ->
            busy = false
            status?.text = "失败 · ${ApiClient.friendly(e)}"
            status?.setTextColor(Ui.color(this, R.color.danger))
            resultHost?.removeAllViews()
            val card = Ui.card(this, 14)
            card.setCardBackgroundColor(0xFFFFF7F6.toInt())
            card.strokeColor = Ui.color(this, R.color.danger)
            card.addView(Ui.text(this, "请求失败", 14f, Ui.color(this, R.color.danger), true))
            card.addView(Ui.text(this, ApiClient.friendly(e), 12.5f).apply { setPadding(0, Ui.dp(this@TextToolsActivity, 4f), 0, Ui.dp(this@TextToolsActivity, 8f)) })
            card.addView(Ui.button(this, "重试", true) { retry() })
            resultHost?.addView(card)
        })
    }

    private fun showResult(text: String, label: String) {
        busy = false
        status?.text = "$label · 模型返回"
        status?.setTextColor(Ui.color(this, R.color.accent_dark))
        resultHost?.removeAllViews()
        if (text.isBlank()) {
            resultHost?.addView(Ui.text(this, "后端返回空内容", 13f, Ui.color(this, R.color.danger)))
            return
        }
        previousResult = text
        val card = Ui.card(this, 16)
        card.addView(Ui.text(this, label, 13f, Ui.color(this, R.color.text_secondary), true))
        val body = Ui.text(this, text, 15f, Ui.color(this, R.color.text_primary)).apply {
            setTextIsSelectable(true)
            setPadding(0, Ui.dp(this@TextToolsActivity, 8f), 0, Ui.dp(this@TextToolsActivity, 10f))
            setLineSpacing(Ui.dp(this@TextToolsActivity, 4f).toFloat(), 1f)
        }
        card.addView(body)
        val row = Ui.horizontal(this)
        row.addView(Ui.button(this, "复制", true) { copy(text) }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
            marginEnd = Ui.dp(this@TextToolsActivity, 8f)
        })
        row.addView(Ui.button(this, "应用并清空", false) {
            copy(text)
            input?.setText("")
            toast("已复制，可回到输入框粘贴")
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        row.addView(Ui.button(this, "撤销", false) {
            input?.setText(lastSource)
            lastSource = ""
            resultHost?.removeAllViews()
            status?.text = "已撤销结果，原文已恢复"
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
            marginStart = Ui.dp(this@TextToolsActivity, 8f)
        })
        card.addView(row)
        resultHost?.addView(card)
    }

    private fun showCandidates(items: List<String>) {
        busy = false
        status?.text = "已生成 ${items.size} 个候选"
        status?.setTextColor(Ui.color(this, R.color.accent_dark))
        resultHost?.removeAllViews()
        if (items.isEmpty()) {
            resultHost?.addView(Ui.text(this, "后端没有返回候选", 13f, Ui.color(this, R.color.danger)))
            return
        }
        previousResult = items.firstOrNull()
        items.forEachIndexed { i, text ->
            val card = Ui.card(this, 14)
            card.addView(Ui.text(this, "候选 ${i + 1}", 12f, Ui.color(this, R.color.text_secondary), true))
            card.addView(Ui.text(this, text, 14f).apply {
                setPadding(0, Ui.dp(this@TextToolsActivity, 5f), 0, Ui.dp(this@TextToolsActivity, 8f))
                setTextIsSelectable(true)
            })
            card.addView(Ui.button(this, "使用这个候选", i == 0) { copy(text) })
            resultHost?.addView(card)
        }
        resultHost?.addView(Ui.button(this, "撤销并恢复原文", false) {
            input?.setText(lastSource)
            resultHost?.removeAllViews()
            status?.text = "已撤销候选，原文已恢复"
        })
    }

    private fun showSummary(text: String, o: org.json.JSONObject) {
        busy = false
        status?.text = "摘要完成"
        status?.setTextColor(Ui.color(this, R.color.accent_dark))
        resultHost?.removeAllViews()
        if (text.isBlank()) {
            resultHost?.addView(Ui.text(this, "后端返回空摘要", 13f, Ui.color(this, R.color.danger)))
            return
        }
        previousResult = text
        val card = Ui.card(this, 16)
        card.addView(Ui.text(this, o.optString("summary").ifBlank { "摘要" }, 15f, Ui.color(this, R.color.text_primary), true))
        val bullets = o.optJSONArray("bullets")
        if (bullets != null && bullets.length() > 0) {
            for (i in 0 until bullets.length()) {
                card.addView(Ui.text(this, "· ${bullets.optString(i)}", 13f, Ui.color(this, R.color.text_secondary)).apply {
                    setPadding(0, Ui.dp(this@TextToolsActivity, 4f), 0, 0)
                })
            }
        }
        val full = Ui.text(this, text, 12f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(0, Ui.dp(this@TextToolsActivity, 8f), 0, Ui.dp(this@TextToolsActivity, 8f))
            setTextIsSelectable(true)
        }
        card.addView(full)
        card.addView(Ui.button(this, "复制完整摘要", true) { copy(text) })
        resultHost?.addView(card)
    }

    private fun copy(text: String) {
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.setPrimaryClip(ClipData.newPlainText("微输入法", text))
        ClipboardStore.add(text)
        toast("已复制")
    }

    private fun addInfo(title: String, body: String) {
        val card = Ui.card(this, 16)
        card.addView(Ui.text(this, title, 14f, Ui.color(this, R.color.text_primary), true))
        card.addView(Ui.text(this, body, 11.5f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(0, Ui.dp(this@TextToolsActivity, 4f), 0, 0)
        })
        content.addView(card)
    }

    private fun toast(msg: String) = Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
}
