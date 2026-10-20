package com.huapohen.wechatinput

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Toast
import com.huapohen.wechatinput.net.ApiClient
import com.huapohen.wechatinput.net.Background
import org.json.JSONArray
import org.json.JSONObject

class HelpActivity : BasePageActivity() {
    private lateinit var feedbackInput: EditText
    private lateinit var status: android.widget.TextView

    override fun onCreatePage() {
        setPageTitle("帮助与反馈", "常见问题 · 本地反馈 · 后端诊断")
        addInfo(
            "先检查这三件事",
            "1) 系统设置 → 输入法 → 启用“微输入法”；2) 点“选择输入法”切换；3) 如果 AI/传送失败，确认后端地址可访问。"
        )
        buttonRow(
            Ui.button(this, "系统输入法设置", true) { ImeHelper.openEnableSettings(this) },
            Ui.button(this, "选择输入法", false) { ImeHelper.showPicker(this) }
        )
        buttonRow(
            Ui.button(this, "键盘体验", false) { startActivity(Pages.intent(this, "keyboard")) },
            Ui.button(this, "隐私与权限", false) { startActivity(Pages.intent(this, "privacy")) }
        )

        content.addView(Ui.sectionTitle(this, "常见问题"))
        val faq = listOf(
            "为什么输入法在系统里找不到？" to "打开系统设置 → 系统 → 语言和输入法 → 屏幕键盘 → 管理键盘，启用“微输入法”。部分 ROM 把这个入口放在“其他设置”。",
            "候选栏没有字怎么办？" to "首次启动会在后台建立本地索引（约 2 秒）。如果仍为空，进入“键盘管理 → 键盘体验”检查引擎是否已加载，或清除应用数据后重试。",
            "AI 功能报错怎么办？" to "AI 调用的是你配置的后端。在“布局和显示”里检查 API 地址（模拟器默认 http://10.0.2.2:8787），并确认后端 /health 可用。报错会显示具体原因。",
            "语音没有反应？" to "语音使用 Android 系统识别服务，需要麦克风权限和系统语音服务。模拟器可能没有可用的识别服务；键盘输入不受影响。",
            "手写识别为什么不准确？" to "手写是有限方向模板 + 公开笔画表匹配，不是云端手写模型。复杂连笔会给出空候选或错误候选；可改用拼音/笔画。",
            "剪贴板历史在哪里？" to "“剪贴板”页保存本机历史；“跨设备粘贴同步”只有在你点推送时才会上传。",
            "如何恢复默认？" to "“键盘管理 → 重置键盘设置”恢复键盘；“隐私与权限 → 删除全部本机数据”清空所有本地状态。"
        )
        val group = Ui.group(this)
        faq.forEachIndexed { index, pair ->
            val item = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
            val head = Ui.horizontal(this).apply {
                minimumHeight = Ui.dp(this@HelpActivity, 52f)
                setPadding(Ui.dp(this@HelpActivity, 14f), Ui.dp(this@HelpActivity, 10f), Ui.dp(this@HelpActivity, 12f), Ui.dp(this@HelpActivity, 10f))
                isClickable = true
            }
            head.addView(Ui.text(this, pair.first, 14f, Ui.color(this, R.color.text_primary), true), LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            val arrow = Ui.text(this, "＋", 16f, Ui.color(this, R.color.text_secondary))
            head.addView(arrow)
            val body = Ui.text(this, pair.second, 12.5f, Ui.color(this, R.color.text_secondary)).apply {
                visibility = View.GONE
                setPadding(Ui.dp(this@HelpActivity, 14f), 0, Ui.dp(this@HelpActivity, 14f), Ui.dp(this@HelpActivity, 12f))
                setLineSpacing(Ui.dp(this@HelpActivity, 3f).toFloat(), 1f)
            }
            head.setOnClickListener {
                val show = body.visibility != View.VISIBLE
                body.visibility = if (show) View.VISIBLE else View.GONE
                arrow.text = if (show) "－" else "＋"
            }
            item.addView(head)
            item.addView(body)
            group.addView(item)
            if (index < faq.size - 1) group.addView(Ui.divider(this))
        }
        content.addView(group)

        content.addView(Ui.sectionTitle(this, "反馈"))
        val card = Ui.card(this, 16)
        feedbackInput = Ui.editText(this, "描述遇到的问题、复现步骤或建议…", true)
        card.addView(feedbackInput, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Ui.dp(this, 110f)))
        val row = Ui.horizontal(this).apply { setPadding(0, Ui.dp(this@HelpActivity, 8f), 0, 0) }
        row.addView(Ui.button(this, "保存反馈", true) {
            val text = feedbackInput.text.toString().trim()
            if (text.length < 4) {
                toast("请至少输入 4 个字")
                return@button
            }
            saveFeedback(text)
            feedbackInput.setText("")
            toast("反馈已保存到本机（共 ${feedbackCount()} 条）")
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
            marginEnd = Ui.dp(this@HelpActivity, 8f)
        })
        row.addView(Ui.button(this, "复制诊断信息", false) {
            copyDiagnostics()
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        card.addView(row)
        card.addView(Ui.text(this, "没有联网提交反馈；内容保存在本机，可随时清除。", 11f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(0, Ui.dp(this@HelpActivity, 8f), 0, 0)
        })
        content.addView(card)

        content.addView(Ui.sectionTitle(this, "后端诊断"))
        status = Ui.text(this, "尚未检查 · ${Prefs.baseUrl}", 12f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(Ui.dp(this@HelpActivity, 4f), 0, 0, Ui.dp(this@HelpActivity, 6f))
        }
        content.addView(status)
        buttonRow(
            Ui.button(this, "检查后端", true) { check() },
            Ui.button(this, "重新检查", false) { check() }
        )
        buttonRow(
            Ui.button(this, "清空本地反馈", false) {
                Prefs.put("feedback_list", "[]")
                toast("已清空")
            },
            Ui.button(this, "关于", false) { startActivity(Pages.intent(this, "about")) }
        )
    }

    private fun check() {
        if (Prefs.standalone) {
            status.text = "单机模式已开启：网络请求被禁用"
            status.setTextColor(Ui.color(this, R.color.warning))
            return
        }
        status.text = "正在检查 ${Prefs.baseUrl}…"
        status.setTextColor(Ui.color(this, R.color.text_secondary))
        Background.runCatching({
            val h = ApiClient.health()
            Background.ui {
                status.text = "后端可用 · 模型 ${h.optString("model")} · ${Prefs.baseUrl}"
                status.setTextColor(Ui.color(this, R.color.accent_dark))
            }
        }, { e ->
            status.text = "后端不可用：${ApiClient.friendly(e)}"
            status.setTextColor(Ui.color(this, R.color.danger))
        })
    }

    private fun saveFeedback(text: String) {
        val arr = try {
            JSONArray(Prefs.str("feedback_list", "[]"))
        } catch (_: Exception) {
            JSONArray()
        }
        arr.put(
            JSONObject().put("text", text).put("time", System.currentTimeMillis())
                .put("device", "${Build.MANUFACTURER} ${Build.MODEL}").put("version", Build.VERSION.SDK_INT)
        )
        Prefs.put("feedback_list", arr.toString())
    }

    private fun feedbackCount(): Int = try {
        JSONArray(Prefs.str("feedback_list", "[]")).length()
    } catch (_: Exception) {
        0
    }

    private fun copyDiagnostics() {
        val text = """
            微输入法 1.0.0 (1)
            Android ${Build.VERSION.RELEASE} / API ${Build.VERSION.SDK_INT}
            ${Build.MANUFACTURER} ${Build.MODEL}
            IME enabled=${ImeHelper.enabled(this)} selected=${ImeHelper.selected(this)}
            base_url=${Prefs.baseUrl} standalone=${Prefs.standalone}
            keyboard_mode=${Prefs.keyboardMode} height=${Prefs.keyboardHeightFactor}
        """.trimIndent()
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.setPrimaryClip(ClipData.newPlainText("微输入法诊断", text))
        toast("诊断信息已复制")
    }

    private fun addInfo(title: String, body: String) {
        val card = Ui.card(this, 16)
        card.addView(Ui.text(this, title, 15f, Ui.color(this, R.color.text_primary), true))
        card.addView(Ui.text(this, body, 12f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(0, Ui.dp(this@HelpActivity, 5f), 0, 0)
        })
        content.addView(card)
    }

    private fun toast(msg: String) = Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
}
