package com.huapohen.wechatinput

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.view.Gravity
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import com.huapohen.wechatinput.data.DataEngine
import com.huapohen.wechatinput.net.ApiClient
import com.huapohen.wechatinput.net.Background

class AboutActivity : BasePageActivity() {
    private lateinit var backendStatus: android.widget.TextView

    override fun onCreatePage() {
        DataEngine.ensureBasic(this)
        setPageTitle("关于", "版本、数据来源与独立声明")
        val hero = Ui.card(this, 18)
        hero.setCardBackgroundColor(Ui.color(this, R.color.accent_soft))
        hero.strokeColor = 0xFFC7EBDD.toInt()
        val row = Ui.horizontal(this)
        row.addView(Ui.text(this, "微", 30f, android.graphics.Color.WHITE, true).apply {
            gravity = Gravity.CENTER
            background = Ui.rounded(Ui.color(this@AboutActivity, R.color.accent), 16f)
        }, LinearLayout.LayoutParams(Ui.dp(this, 58f), Ui.dp(this, 58f)))
        val col = Ui.vertical(this).apply { setPadding(Ui.dp(this@AboutActivity, 14f), 0, 0, 0) }
        col.addView(Ui.text(this, "微输入法", 24f, Ui.color(this, R.color.text_primary), true))
        col.addView(Ui.text(this, "简洁、好用、打字快", 12f, Ui.color(this, R.color.text_secondary)))
        row.addView(col, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        hero.addView(row)
        hero.addView(Ui.text(this, "版本 1.0.0 (1) · 原生 Android · minSdk 26 / targetSdk 35", 12f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(0, Ui.dp(this@AboutActivity, 12f), 0, 0)
        })
        content.addView(hero)

        addInfo(
            "独立声明",
            "微输入法是独立研究与互操作复刻，与腾讯没有任何隶属、授权或背书关系。应用不包含腾讯的二进制文件、Hermes 包、字体、图标、词库或模型密钥。界面与交互基于公开可见事实重建。"
        )
        addInfo(
            "数据来源",
            "拼音字 26,703 · 拼音词 46,111 · 五笔 86 码 26,271 · 笔画 4,299 · 双拼（小鹤/自然码/微软）· Emoji ${DataEngine.emojiCategories.sumOf { it.second.size }} 个。数据随应用打包在资产目录，候选计算完全在本机。"
        )

        content.addView(Ui.sectionTitle(this, "能力边界"))
        val group = Ui.group(this)
        listOf(
            "手写识别" to "使用有限方向模板 + 公开笔画表前缀匹配，不是云端手写模型；复杂连笔不保证识别。",
            "语音识别" to "调用 Android SpeechRecognizer；识别质量取决于设备上的系统语音服务与网络。",
            "AI 功能" to "AI 对话、整理、改写、翻译、摘要调用你配置的后端；客户端不含模型密钥。",
            "剪贴板同步" to "需要手动配对；只有你点推送时才会把文本发送到后端。"
        ).forEachIndexed { i, pair ->
            group.addView(Ui.row(this, pair.first, pair.second, null, false) {
                AlertDialog.Builder(this).setTitle(pair.first).setMessage(pair.second).setPositiveButton("知道了", null).show()
            })
            if (i < 3) group.addView(Ui.divider(this))
        }
        content.addView(group)

        content.addView(Ui.sectionTitle(this, "开源与许可"))
        val licenses = Ui.group(this)
        listOf(
            "AndroidX / Material Components" to "Apache License 2.0",
            "Kotlin" to "Apache License 2.0",
            "Noto Sans CJK / 系统字体" to "设备系统字体，未打包字体文件",
            "公开编码表" to "本工作区 shared/data 清洗后的拼音、五笔、笔画事实表"
        ).forEachIndexed { i, pair ->
            licenses.addView(Ui.row(this, pair.first, pair.second, null, true) {
                AlertDialog.Builder(this).setTitle(pair.first).setMessage(pair.second + "\n\n本应用为研究用途，不复制第三方专有资源。").setPositiveButton("关闭", null).show()
            })
            if (i < 3) licenses.addView(Ui.divider(this))
        }
        content.addView(licenses)

        content.addView(Ui.sectionTitle(this, "环境"))
        backendStatus = Ui.text(this, "后端：${Prefs.baseUrl} · 未检查", 12f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(Ui.dp(this@AboutActivity, 4f), 0, 0, Ui.dp(this@AboutActivity, 8f))
        }
        content.addView(backendStatus)
        buttonRow(
            Ui.button(this, "检查后端状态", true) { checkBackend() },
            Ui.button(this, "复制版本信息", false) { copyDiagnostics() }
        )
        buttonRow(
            Ui.button(this, "隐私与权限", false) { startActivity(Pages.intent(this, "privacy")) },
            Ui.button(this, "帮助与反馈", false) { startActivity(Pages.intent(this, "help")) }
        )
        val bottom = Ui.text(this, "© 2026 微输入法研究项目 · 非腾讯产品", 11f, Ui.color(this, R.color.text_secondary)).apply {
            gravity = Gravity.CENTER
            setPadding(0, Ui.dp(this@AboutActivity, 12f), 0, 0)
        }
        content.addView(bottom)
    }

    private fun checkBackend() {
        if (Prefs.standalone) {
            backendStatus.text = "后端：单机模式已开启，网络请求被禁用"
            backendStatus.setTextColor(Ui.color(this, R.color.warning))
            return
        }
        backendStatus.text = "后端：正在检查…"
        Background.runCatching({
            val h = ApiClient.health()
            Background.ui {
                backendStatus.text = "后端：可用 · ${h.optString("model")} · ${Prefs.baseUrl}"
                backendStatus.setTextColor(Ui.color(this, R.color.accent_dark))
            }
        }, { e ->
            backendStatus.text = "后端：不可用 · ${ApiClient.friendly(e)}"
            backendStatus.setTextColor(Ui.color(this, R.color.danger))
        })
    }

    private fun copyDiagnostics() {
        val text = buildString {
            appendLine("微输入法 1.0.0 (1)")
            appendLine("Android ${Build.VERSION.RELEASE} / API ${Build.VERSION.SDK_INT}")
            appendLine("${Build.MANUFACTURER} ${Build.MODEL}")
            appendLine("IME enabled=${ImeHelper.enabled(this@AboutActivity)} selected=${ImeHelper.selected(this@AboutActivity)}")
            appendLine("base_url=${Prefs.baseUrl} standalone=${Prefs.standalone}")
            append("mode=${Prefs.keyboardMode}")
        }
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.setPrimaryClip(ClipData.newPlainText("微输入法诊断", text))
        Toast.makeText(this, "诊断信息已复制", Toast.LENGTH_SHORT).show()
    }

    private fun addInfo(title: String, body: String) {
        val card = Ui.card(this, 16)
        card.addView(Ui.text(this, title, 15f, Ui.color(this, R.color.text_primary), true))
        card.addView(Ui.text(this, body, 12f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(0, Ui.dp(this@AboutActivity, 6f), 0, 0)
            setLineSpacing(Ui.dp(this@AboutActivity, 3f).toFloat(), 1f)
        })
        content.addView(card)
    }
}
