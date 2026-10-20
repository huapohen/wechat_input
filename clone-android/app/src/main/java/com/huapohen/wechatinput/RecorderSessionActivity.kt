package com.huapohen.wechatinput

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.view.Gravity
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.Toast
import com.huapohen.wechatinput.net.ApiClient
import com.huapohen.wechatinput.net.Background
import com.huapohen.wechatinput.store.ClipboardStore
import com.huapohen.wechatinput.store.SessionStore
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class RecorderSessionActivity : BasePageActivity() {
    private var sessionId = ""
    private lateinit var summaryHost: LinearLayout

    override fun onCreatePage() {
        sessionId = intent.getStringExtra("id").orEmpty()
        setHeaderAction("返回录音笔") { startActivity(Pages.intent(this, "recorder")); finish() }
        if (sessionId.isBlank()) {
            listSessions()
        } else {
            showDetail(sessionId)
        }
    }

    private fun listSessions() {
        setPageTitle("录音会话", "本机保存的转写与摘要")
        val sessions = SessionStore.all(this)
        if (sessions.isEmpty()) {
            val card = Ui.card(this, 16)
            card.addView(Ui.text(this, "还没有会话", 15f, Ui.color(this, R.color.text_primary), true))
            card.addView(Ui.text(this, "回到“AI 录音笔”开始一段录音，结束后会自动保存在这里。", 12f, Ui.color(this, R.color.text_secondary)).apply {
                setPadding(0, Ui.dp(this@RecorderSessionActivity, 5f), 0, Ui.dp(this@RecorderSessionActivity, 8f))
            })
            card.addView(Ui.button(this, "打开录音笔", true) { startActivity(Pages.intent(this, "recorder")) })
            content.addView(card)
            return
        }
        content.addView(Ui.sectionTitle(this, "全部会话", "${sessions.size} 段"))
        val group = Ui.group(this)
        sessions.forEachIndexed { i, s ->
            val row = Ui.horizontal(this).apply {
                minimumHeight = Ui.dp(this@RecorderSessionActivity, 64f)
                setPadding(Ui.dp(this@RecorderSessionActivity, 14f), Ui.dp(this@RecorderSessionActivity, 10f), Ui.dp(this@RecorderSessionActivity, 10f), Ui.dp(this@RecorderSessionActivity, 10f))
                isClickable = true
                setOnClickListener {
                    sessionId = s.id
                    onCreatePageAgain()
                }
            }
            val col = Ui.vertical(this)
            col.addView(Ui.text(this, s.title.ifBlank { "录音会话" }, 14f, Ui.color(this, R.color.text_primary), true))
            col.addView(Ui.text(
                this,
                SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.CHINA).format(Date(s.created)) +
                        " · ${s.durationMs / 1000}s" + if (s.summary.isNotBlank()) " · 有摘要" else "",
                11f, Ui.color(this, R.color.text_secondary)
            ).apply { setPadding(0, Ui.dp(this@RecorderSessionActivity, 3f), 0, 0) })
            row.addView(col, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            row.addView(Ui.text(this, "›", 20f, Ui.color(this, R.color.muted)))
            group.addView(row)
            if (i < sessions.size - 1) group.addView(Ui.divider(this))
        }
        content.addView(group)
    }

    private fun onCreatePageAgain() {
        content.removeAllViews()
        if (sessionId.isBlank()) listSessions() else showDetail(sessionId)
    }

    private fun showDetail(id: String) {
        val s = SessionStore.get(this, id)
        if (s == null) {
            setPageTitle("录音会话", "未找到")
            val card = Ui.card(this, 16)
            card.addView(Ui.text(this, "会话不存在或已被删除", 15f, Ui.color(this, R.color.danger), true))
            card.addView(Ui.button(this, "查看全部会话", true) {
                sessionId = ""
                onCreatePageAgain()
            })
            content.addView(card)
            return
        }
        setPageTitle(s.title.ifBlank { "录音会话" }, "转写与 AI 纪要")
        val meta = Ui.card(this, 14)
        meta.addView(Ui.text(this, SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.CHINA).format(Date(s.created)), 13f, Ui.color(this, R.color.text_primary), true))
        meta.addView(Ui.text(
            this,
            "时长 ${s.durationMs / 1000}s · 字符 ${s.transcript.length} · 音频未保存",
            11f, Ui.color(this, R.color.text_secondary)
        ).apply { setPadding(0, Ui.dp(this@RecorderSessionActivity, 3f), 0, 0) })
        content.addView(meta)

        content.addView(Ui.sectionTitle(this, "转写"))
        val transcriptCard = Ui.card(this, 16)
        val body = Ui.text(this, s.transcript.ifBlank { "（无转写）" }, 14f, Ui.color(this, R.color.text_primary)).apply {
            setTextIsSelectable(true)
            setLineSpacing(Ui.dp(this@RecorderSessionActivity, 5f).toFloat(), 1f)
        }
        transcriptCard.addView(body)
        content.addView(transcriptCard)

        content.addView(Ui.sectionTitle(this, "AI 纪要"))
        val summaryCard = Ui.card(this, 16)
        summaryHost = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        renderSummary(s)
        summaryCard.addView(summaryHost)
        val row = Ui.horizontal(this).apply { setPadding(0, Ui.dp(this@RecorderSessionActivity, 8f), 0, 0) }
        row.addView(Ui.button(this, "生成/重试摘要", true) { summarize(s) }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
            marginEnd = Ui.dp(this@RecorderSessionActivity, 8f)
        })
        row.addView(Ui.button(this, "删除会话", false) { delete(s) }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        summaryCard.addView(row)
        content.addView(summaryCard)

        buttonRow(
            Ui.button(this, "复制转写", false) { copy(s.transcript) },
            Ui.button(this, "分享文本", false) { share(s) }
        )
        buttonRow(
            Ui.button(this, "返回列表", false) { sessionId = ""; onCreatePageAgain() },
            Ui.button(this, "打开录音笔", true) { startActivity(Pages.intent(this, "recorder")) }
        )
        addInfo("提示", "摘要由你配置的后端生成；如果失败，错误会显示在上方，可重复请求。")
    }

    private fun renderSummary(s: SessionStore.Session) {
        summaryHost.removeAllViews()
        if (s.summary.isBlank()) {
            summaryHost.addView(Ui.text(this, "尚未生成摘要。转写文本会发送到 ${Prefs.baseUrl}。", 12f, Ui.color(this, R.color.text_secondary)))
            return
        }
        summaryHost.addView(Ui.text(this, s.summary, 14f, Ui.color(this, R.color.text_primary)).apply {
            setLineSpacing(Ui.dp(this@RecorderSessionActivity, 4f).toFloat(), 1f)
            setTextIsSelectable(true)
        })
        if (s.bullets.isNotEmpty()) {
            val list = Ui.vertical(this).apply { setPadding(0, Ui.dp(this@RecorderSessionActivity, 6f), 0, 0) }
            s.bullets.forEach { b -> list.addView(Ui.text(this, "· $b", 12.5f, Ui.color(this, R.color.text_secondary))) }
            summaryHost.addView(list)
        }
    }

    private fun summarize(s: SessionStore.Session) {
        summaryHost.removeAllViews()
        summaryHost.addView(Ui.text(this, "正在请求后端…", 13f, Ui.color(this, R.color.text_secondary)))
        Background.runCatching({
            val o = ApiClient.summary(s.transcript)
            Background.ui {
                val summary = o.optString("text").ifBlank { o.optString("summary") }
                if (summary.isBlank()) {
                    summaryHost.removeAllViews()
                    summaryHost.addView(Ui.text(this, "后端返回空摘要", 13f, Ui.color(this, R.color.danger)))
                    return@ui
                }
                val bulletsArr = o.optJSONArray("bullets")
                val bullets = (0 until (bulletsArr?.length() ?: 0)).map { bulletsArr!!.optString(it) }
                val updated = s.copy(summary = summary, bullets = bullets)
                SessionStore.upsert(this, updated)
                renderSummary(updated)
                toast("摘要已保存")
            }
        }, { e ->
            summaryHost.removeAllViews()
            summaryHost.addView(Ui.text(this, "生成失败：${ApiClient.friendly(e)}", 13f, Ui.color(this, R.color.danger)))
            summaryHost.addView(Ui.button(this, "重试", true) { summarize(s) })
        })
    }

    private fun delete(s: SessionStore.Session) {
        androidx.appcompat.app.AlertDialog.Builder(this)
            .setTitle("删除这段会话？")
            .setMessage("转写与摘要会从本机删除，不可恢复。")
            .setPositiveButton("删除") { _, _ ->
                SessionStore.delete(this, s.id)
                sessionId = ""
                toast("已删除")
                onCreatePageAgain()
            }
            .setNegativeButton("取消", null)
            .show()
    }

    private fun copy(text: String) {
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.setPrimaryClip(ClipData.newPlainText("微输入法", text))
        ClipboardStore.add(text)
        toast("已复制")
    }

    private fun share(s: SessionStore.Session) {
        val text = buildString {
            appendLine(s.title)
            appendLine("${SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.CHINA).format(Date(s.created))} · ${s.durationMs / 1000}s")
            appendLine()
            appendLine(s.transcript)
            if (s.summary.isNotBlank()) {
                appendLine()
                appendLine("摘要：")
                append(s.summary)
            }
        }
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
        }
        startActivity(Intent.createChooser(intent, "分享转写"))
    }

    private fun addInfo(title: String, body: String) {
        val card = Ui.card(this, 16)
        card.addView(Ui.text(this, title, 14f, Ui.color(this, R.color.text_primary), true))
        card.addView(Ui.text(this, body, 11.5f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(0, Ui.dp(this@RecorderSessionActivity, 4f), 0, 0)
        })
        content.addView(card)
    }

    private fun toast(msg: String) = Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
}
