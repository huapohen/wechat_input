package com.huapohen.wechatinput

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.button.MaterialButton
import com.huapohen.wechatinput.net.ApiClient
import com.huapohen.wechatinput.net.Background
import com.huapohen.wechatinput.store.ChatStore
import com.huapohen.wechatinput.store.ClipboardStore
import java.util.concurrent.atomic.AtomicBoolean

class AiChatActivity : AppCompatActivity() {
    private lateinit var messageList: LinearLayout
    private lateinit var scroll: ScrollView
    private lateinit var input: EditText
    private lateinit var sendButton: MaterialButton
    private lateinit var stopButton: MaterialButton
    private lateinit var statusText: TextView
    private val history = ArrayList<ChatStore.Message>()
    private var lastRequest: ArrayList<ChatStore.Message>? = null
    private var streaming = false
    private var cancelFlag: AtomicBoolean? = null
    private var lastAssistantView: TextView? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_chat)
        messageList = findViewById(R.id.messageList)
        scroll = findViewById(R.id.chatScroll)
        input = findViewById(R.id.input)
        sendButton = findViewById(R.id.sendButton)
        stopButton = findViewById(R.id.stopButton)
        statusText = findViewById(R.id.statusText)
        findViewById<ImageButton>(R.id.backButton).setOnClickListener { finish() }
        findViewById<TextView>(R.id.newChat).setOnClickListener { newChat() }
        findViewById<TextView>(R.id.clearChat).setOnClickListener { confirmClear() }

        applyWidth()
        history.addAll(ChatStore.load())
        renderHistory()
        input.setText(intent.getStringExtra("seed_text").orEmpty())
        input.requestFocus()

        sendButton.setOnClickListener { send() }
        stopButton.setOnClickListener {
            cancelFlag?.set(true)
            ApiClient.cancelChat()
            stopButton.text = "停止中…"
            statusText.text = "正在停止…"
        }
        input.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == android.view.inputmethod.EditorInfo.IME_ACTION_SEND) {
                send()
                true
            } else false
        }
    }

    private fun applyWidth() {
        val screen = resources.displayMetrics.widthPixels
        val pad = (resources.displayMetrics.density * 20).toInt()
        val max = (resources.displayMetrics.density * 1180).toInt()
        val width = minOf(screen, max)
        val col = findViewById<LinearLayout>(R.id.chatColumn)
        col.layoutParams = FrameLayout.LayoutParams(width, ViewGroup.LayoutParams.MATCH_PARENT).apply {
            gravity = Gravity.CENTER_HORIZONTAL
        }
        if (width < screen) {
            col.setPadding(0, 0, 0, 0)
        }
    }

    private fun renderHistory() {
        messageList.removeAllViews()
        if (history.isEmpty()) {
            addWelcome()
            return
        }
        history.forEach { addBubble(it.role, it.content) }
        scrollToBottom()
    }

    private fun addWelcome() {
        val card = Ui.card(this, 18).apply {
            setCardBackgroundColor(Ui.color(this@AiChatActivity, R.color.accent_soft))
            strokeColor = 0xFFC7EBDD.toInt()
        }
        card.addView(Ui.text(this, "问点什么？", 20f, Ui.color(this, R.color.text_primary), true))
        card.addView(Ui.text(this, "多轮对话直接调用你配置的后端；失败会显示真实错误并可重试。历史只保存在本机。", 12f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(0, Ui.dp(this@AiChatActivity, 6f), 0, Ui.dp(this@AiChatActivity, 10f))
        })
        val prompts = listOf(
            "帮我把这句话写得更简洁：我们下午三点开会，请大家准时参加。",
            "把“今天天气很好”翻译成英文和日文。",
            "给我三个周末放松的建议，不要泛泛而谈。"
        )
        prompts.forEach { p ->
            val chip = Ui.text(this, p, 12f, Ui.color(this, R.color.text_primary)).apply {
                background = Ui.rounded(Color.WHITE, 14f, Ui.color(this@AiChatActivity, R.color.border))
                setPadding(Ui.dp(this@AiChatActivity, 12f), Ui.dp(this@AiChatActivity, 9f), Ui.dp(this@AiChatActivity, 12f), Ui.dp(this@AiChatActivity, 9f))
                isClickable = true
                setOnClickListener { input.setText(p); input.setSelection(p.length) }
            }
            card.addView(chip, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                bottomMargin = Ui.dp(this@AiChatActivity, 6f)
            })
        }
        messageList.addView(card)
    }

    private fun addBubble(role: String, text: String, isError: Boolean = false): TextView {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = if (role == "user") Gravity.END else Gravity.START
        }
        val bubble = TextView(this).apply {
            this.text = text
            setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, 15f)
            setTextColor(if (role == "user") Color.WHITE else Ui.color(this@AiChatActivity, R.color.text_primary))
            setLineSpacing(Ui.dp(this@AiChatActivity, 4f).toFloat(), 1f)
            val r = if (role == "user") {
                GradientDrawable().apply {
                    setColor(Ui.color(this@AiChatActivity, R.color.accent))
                    cornerRadii = floatArrayOf(18f, 18f, 18f, 18f, 6f, 6f, 18f, 18f)
                }
            } else if (isError) {
                GradientDrawable().apply {
                    setColor(0xFFFFF3F2.toInt())
                    setStroke(Ui.dp(this@AiChatActivity, 1f), Ui.color(this@AiChatActivity, R.color.danger))
                    cornerRadius = Ui.dp(this@AiChatActivity, 16f).toFloat()
                }
            } else {
                GradientDrawable().apply {
                    setColor(Color.WHITE)
                    setStroke(Ui.dp(this@AiChatActivity, 1f), Ui.color(this@AiChatActivity, R.color.border))
                    cornerRadius = Ui.dp(this@AiChatActivity, 16f).toFloat()
                }
            }
            background = r
            setPadding(Ui.dp(this@AiChatActivity, 14f), Ui.dp(this@AiChatActivity, 10f), Ui.dp(this@AiChatActivity, 14f), Ui.dp(this@AiChatActivity, 10f))
            maxWidth = (resources.displayMetrics.widthPixels * 0.84).toInt()
            setTextIsSelectable(true)
            setOnLongClickListener {
                if (this.text.isNotBlank()) {
                    copy(this.text.toString())
                    true
                } else false
            }
        }
        row.addView(bubble, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        val wrapper = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        wrapper.addView(row)
        bubble.tag = wrapper
        messageList.addView(wrapper, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = Ui.dp(this@AiChatActivity, 6f)
            bottomMargin = Ui.dp(this@AiChatActivity, 6f)
        })
        if (role != "user") {
            val tools = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.START
                setPadding(Ui.dp(this@AiChatActivity, 4f), 0, 0, 0)
            }
            if (!isError) {
                tools.addView(Ui.text(this, "复制", 10.5f, Ui.color(this, R.color.text_secondary)).apply {
                    setPadding(0, Ui.dp(this@AiChatActivity, 2f), Ui.dp(this@AiChatActivity, 12f), Ui.dp(this@AiChatActivity, 4f))
                    setOnClickListener { copy(bubble.text.toString()) }
                })
            }
            wrapper.addView(tools)
        }
        scrollToBottom()
        return bubble
    }

    private fun addErrorCard(message: String) {
        val card = Ui.card(this, 14).apply {
            setCardBackgroundColor(0xFFFFF7F6.toInt())
            strokeColor = Ui.color(this@AiChatActivity, R.color.danger)
        }
        card.addView(Ui.text(this, "请求失败", 14f, Ui.color(this, R.color.danger), true))
        card.addView(Ui.text(this, message, 12.5f, Ui.color(this, R.color.text_primary)).apply {
            setPadding(0, Ui.dp(this@AiChatActivity, 4f), 0, Ui.dp(this@AiChatActivity, 8f))
            setLineSpacing(Ui.dp(this@AiChatActivity, 3f).toFloat(), 1f)
        })
        val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        row.addView(Ui.button(this, "重试", true) { retry() }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
            marginEnd = Ui.dp(this@AiChatActivity, 8f)
        })
        row.addView(Ui.button(this, "检查设置", false) {
            startActivity(Pages.intent(this, "display"))
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        card.addView(row)
        messageList.addView(card)
        scrollToBottom()
    }

    private fun send() {
        if (streaming) return
        val text = input.text.toString().trim()
        if (text.isEmpty()) {
            toast("请输入内容")
            return
        }
        input.setText("")
        history.add(ChatStore.Message("user", text))
        addBubble("user", text)
        startRequest()
    }

    private fun retry() {
        if (streaming) return
        if (history.isEmpty()) {
            toast("没有可重试的消息")
            return
        }
        startRequest()
    }

    private fun startRequest() {
        if (history.isEmpty()) return
        val request = ArrayList<ChatStore.Message>()
        request.add(ChatStore.Message("system", "你是微输入法内置的 AI 助手。回答简洁、准确、直接；不要编造事实。"))
        request.addAll(history.takeLast(20))
        lastRequest = request
        streaming = true
        cancelFlag = AtomicBoolean(false)
        val flag = cancelFlag!!
        sendButton.isEnabled = false
        sendButton.alpha = 0.5f
        stopButton.visibility = View.VISIBLE
        stopButton.text = "停止"
        statusText.text = "正在生成… · ${Prefs.baseUrl}"
        val bubble = addBubble("assistant", "…")
        lastAssistantView = bubble
        val sb = StringBuilder()
        val startTime = System.currentTimeMillis()
        Background.run {
            ApiClient.chat(
                request.map { it.role to it.content },
                onDelta = { delta ->
                    sb.append(delta)
                    Background.ui {
                        bubble.text = sb.toString()
                        scrollToBottom()
                    }
                },
                onDone = {
                    Background.ui {
                        if (flag.get()) {
                            val partial = sb.toString()
                            if (partial.isNotBlank()) {
                                bubble.text = partial + "\n\n（已停止）"
                                history.add(ChatStore.Message("assistant", partial))
                                ChatStore.save(history)
                            } else {
                                messageList.removeView(bubble.tag as View)
                            }
                        } else {
                            val answer = sb.toString()
                            if (answer.isBlank()) {
                                bubble.text = "（后端返回了空内容）"
                                addErrorCard("后端返回空内容。请检查模型配置后重试。")
                            } else {
                                bubble.text = answer
                                history.add(ChatStore.Message("assistant", answer))
                                ChatStore.save(history)
                            }
                        }
                        finishStreaming()
                    }
                },
                onError = { err ->
                    Background.ui {
                        if (flag.get()) {
                            val partial = sb.toString()
                            if (partial.isNotBlank()) {
                                bubble.text = partial + "\n\n（已停止）"
                                history.add(ChatStore.Message("assistant", partial))
                                ChatStore.save(history)
                            } else {
                                messageList.removeView(bubble.tag as View)
                            }
                        } else {
                            messageList.removeView(bubble.tag as View)
                            addErrorCard("$err\n\n后端：${Prefs.baseUrl}\n耗时 ${(System.currentTimeMillis() - startTime) / 1000}s")
                        }
                        finishStreaming()
                    }
                },
                cancelled = flag
            )
        }
    }

    private fun finishStreaming() {
        streaming = false
        sendButton.isEnabled = true
        sendButton.alpha = 1f
        stopButton.visibility = View.GONE
        statusText.text = "多轮对话 · 历史只存本机"
        scrollToBottom()
    }

    private fun newChat() {
        if (streaming) {
            cancelFlag?.set(true)
        }
        history.clear()
        renderHistory()
        statusText.text = "多轮对话 · 历史只存本机"
    }

    private fun confirmClear() {
        AlertDialog.Builder(this)
            .setTitle("清空对话历史？")
            .setMessage("本机保存的多轮对话会被删除，不影响后端。")
            .setPositiveButton("清空") { _, _ ->
                ChatStore.clear()
                newChat()
            }
            .setNegativeButton("取消", null)
            .show()
    }

    private fun scrollToBottom() {
        scroll.post { scroll.fullScroll(View.FOCUS_DOWN) }
    }

    private fun copy(text: String) {
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.setPrimaryClip(ClipData.newPlainText("微输入法", text))
        ClipboardStore.add(text)
        toast("已复制")
    }

    private fun toast(msg: String) = Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()

    override fun onBackPressed() {
        if (streaming) {
            cancelFlag?.set(true)
        }
        super.onBackPressed()
    }
}
