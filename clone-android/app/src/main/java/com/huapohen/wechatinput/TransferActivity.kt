package com.huapohen.wechatinput

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.view.Gravity
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
import com.huapohen.wechatinput.net.ApiClient
import com.huapohen.wechatinput.net.Background
import org.json.JSONArray
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class TransferActivity : BasePageActivity() {
    private var selected: Uri? = null
    private var selectedName = ""
    private var selectedSize = 0L
    private var selectedMime = ""
    private lateinit var status: android.widget.TextView
    private lateinit var listHost: LinearLayout
    private lateinit var selectedText: android.widget.TextView
    private var lastRetry: (() -> Unit)? = null

    private val picker = registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            selected = uri
            queryMeta(uri)
        }
    }

    override fun onCreatePage() {
        setPageTitle("隔空传送", "SAF 选文件 · 后端中转 · 可下载")
        setHeaderAction("刷新列表") { loadList() }

        addInfo(
            "隔空传送",
            "选择本机文件上传到后端（上限 50 MB），另一台设备可用同一个配对码拉取。文件内容经过你配置的后端，不上传到任何第三方。"
        )
        val pairCard = Ui.card(this, 14)
        val codeRow = Ui.horizontal(this)
        codeRow.addView(Ui.text(this, "配对码", 13f, Ui.color(this, R.color.text_secondary), true), LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        codeRow.addView(Ui.text(this, Prefs.syncCode.ifBlank { Prefs.desktopCode }, 22f, Ui.color(this, R.color.accent_dark), true).apply {
            letterSpacing = 0.14f
        })
        pairCard.addView(codeRow)
        val actions = Ui.horizontal(this).apply { setPadding(0, Ui.dp(this@TransferActivity, 6f), 0, 0) }
        actions.addView(Ui.button(this, "选择文件", true) { picker.launch(arrayOf("*/*")) }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
            marginEnd = Ui.dp(this@TransferActivity, 6f)
        })
        actions.addView(Ui.button(this, "复制配对码", false) {
            copyText(Prefs.syncCode.ifBlank { Prefs.desktopCode })
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        pairCard.addView(actions)
        content.addView(pairCard)

        val uploadCard = Ui.card(this, 14)
        selectedText = Ui.text(this, "尚未选择文件", 12.5f, Ui.color(this, R.color.text_secondary))
        uploadCard.addView(selectedText)
        val upRow = Ui.horizontal(this).apply { setPadding(0, Ui.dp(this@TransferActivity, 8f), 0, 0) }
        upRow.addView(Ui.button(this, "上传所选文件", true) { upload() }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
            marginEnd = Ui.dp(this@TransferActivity, 6f)
        })
        upRow.addView(Ui.button(this, "清除选择", false) {
            selected = null
            selectedName = ""
            selectedText.text = "尚未选择文件"
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        uploadCard.addView(upRow)
        content.addView(uploadCard)

        status = Ui.text(this, "后端：${Prefs.baseUrl}", 11f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(Ui.dp(this, 4f), 0, 0, Ui.dp(this, 6f))
        }
        content.addView(status)
        buttonRow(
            Ui.button(this, "刷新列表", true) { loadList() },
            Ui.button(this, "重试上次操作", false) { lastRetry?.invoke() ?: toast("没有可重试的操作") }
        )
        content.addView(Ui.sectionTitle(this, "后端文件", "点击下载"))
        listHost = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        content.addView(listHost)
        loadList()
    }

    private fun queryMeta(uri: Uri) {
        try {
            var name = uri.lastPathSegment ?: "file"
            var size = 0L
            contentResolver.query(uri, null, null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    val ni = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    val si = c.getColumnIndex(OpenableColumns.SIZE)
                    if (ni >= 0) name = c.getString(ni)
                    if (si >= 0) size = c.getLong(si)
                }
            }
            selectedName = name
            selectedSize = size
            selectedMime = contentResolver.getType(uri) ?: "application/octet-stream"
            selectedText.text = "$name · ${formatSize(size)} · ${selectedMime}\n已选择，尚未上传"
            selectedText.setTextColor(Ui.color(this, R.color.text_primary))
        } catch (e: Exception) {
            selectedText.text = "无法读取文件信息：${e.message}"
            selectedText.setTextColor(Ui.color(this, R.color.danger))
        }
    }

    private fun upload() {
        val uri = selected
        if (uri == null) {
            toast("请先选择文件")
            return
        }
        if (selectedSize > 50L * 1024 * 1024) {
            status.text = "文件超过 50 MB 上限"
            status.setTextColor(Ui.color(this, R.color.danger))
            return
        }
        val retry = { upload() }
        lastRetry = retry
        status.text = "正在上传 ${selectedName}…"
        status.setTextColor(Ui.color(this, R.color.text_secondary))
        Background.runCatching({
            val input = contentResolver.openInputStream(uri)
                ?: throw IllegalStateException("无法打开所选文件")
            val result = ApiClient.upload(
                this, selectedName, selectedMime, input,
                if (Prefs.syncCode.isNotBlank()) Prefs.syncToken else "",
                onProgress = { sent ->
                    Background.ui { status.text = "正在上传 ${formatSize(sent)} / ${formatSize(selectedSize)}" }
                }
            )
            Background.ui {
                status.text = "上传成功：${result.optString("name")} · ${result.optString("sha256").take(12)}…"
                status.setTextColor(Ui.color(this, R.color.accent_dark))
                loadList()
            }
        }, { e ->
            status.text = "上传失败：${ApiClient.friendly(e)}"
            status.setTextColor(Ui.color(this, R.color.danger))
            toast("上传失败，可点“重试上次操作”")
        })
    }

    private fun loadList() {
        status.text = "正在读取 ${Prefs.baseUrl}/v1/transfer/list …"
        status.setTextColor(Ui.color(this, R.color.text_secondary))
        Background.runCatching({
            val arr = ApiClient.transferList(if (Prefs.syncCode.isNotBlank()) Prefs.syncToken else "")
            Background.ui {
                status.text = "后端可用 · ${arr.length()} 个文件 · ${Prefs.baseUrl}"
                status.setTextColor(Ui.color(this, R.color.accent_dark))
                renderList(arr)
            }
        }, { e ->
            status.text = "无法读取文件列表：${ApiClient.friendly(e)}"
            status.setTextColor(Ui.color(this, R.color.danger))
            listHost.removeAllViews()
            val card = Ui.card(this, 14)
            card.setCardBackgroundColor(0xFFFFF7F6.toInt())
            card.strokeColor = Ui.color(this, R.color.danger)
            card.addView(Ui.text(this, "后端不可用", 14f, Ui.color(this, R.color.danger), true))
            card.addView(Ui.text(this, ApiClient.friendly(e), 12f).apply { setPadding(0, Ui.dp(this@TransferActivity, 4f), 0, Ui.dp(this@TransferActivity, 8f)) })
            card.addView(Ui.button(this, "重试", true) { loadList() })
            listHost.addView(card)
        })
    }

    private fun renderList(arr: JSONArray) {
        listHost.removeAllViews()
        if (arr.length() == 0) {
            val card = Ui.card(this, 16)
            card.addView(Ui.text(this, "还没有文件", 14f, Ui.color(this, R.color.text_primary), true))
            card.addView(Ui.text(this, "选择文件上传后，会出现在这里。", 12f, Ui.color(this, R.color.text_secondary)).apply {
                setPadding(0, Ui.dp(this@TransferActivity, 4f), 0, 0)
            })
            listHost.addView(card)
            return
        }
        val group = Ui.group(this)
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i) ?: continue
            val id = o.optString("id")
            val name = o.optString("name")
            val size = o.optLong("size")
            val created = o.optLong("created") * 1000
            val row = Ui.horizontal(this).apply {
                minimumHeight = Ui.dp(this@TransferActivity, 64f)
                setPadding(Ui.dp(this@TransferActivity, 14f), Ui.dp(this@TransferActivity, 8f), Ui.dp(this@TransferActivity, 8f), Ui.dp(this@TransferActivity, 8f))
            }
            val col = Ui.vertical(this)
            col.addView(Ui.text(this, name.ifBlank { "文件" }, 14f, Ui.color(this, R.color.text_primary), true))
            col.addView(Ui.text(
                this,
                "${formatSize(size)} · " + if (created > 0) SimpleDateFormat("MM-dd HH:mm", Locale.CHINA).format(Date(created)) else id.take(8),
                11f, Ui.color(this, R.color.text_secondary)
            ).apply { setPadding(0, Ui.dp(this@TransferActivity, 3f), 0, 0) })
            row.addView(col, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            row.addView(Ui.button(this, "下载", false) { download(id, name) })
            group.addView(row)
            if (i < arr.length() - 1) group.addView(Ui.divider(this))
        }
        listHost.addView(group)
    }

    private fun download(id: String, name: String) {
        if (id.isBlank()) return
        status.text = "正在下载 $name…"
        status.setTextColor(Ui.color(this, R.color.text_secondary))
        val retry = { download(id, name) }
        lastRetry = retry
        Background.runCatching({
            val dir = File(cacheDir, "transfers").apply { mkdirs() }
            val safe = name.replace(Regex("[/\\\\]"), "_").ifBlank { "download" }
            val target = File(dir, "${System.currentTimeMillis()}-$safe")
            ApiClient.download(id, target) { got ->
                Background.ui { status.text = "正在下载 ${formatSize(got)}" }
            }
            Background.ui {
                status.text = "已下载：${target.name}"
                status.setTextColor(Ui.color(this, R.color.accent_dark))
                openFile(target)
            }
        }, { e ->
            status.text = "下载失败：${ApiClient.friendly(e)}"
            status.setTextColor(Ui.color(this, R.color.danger))
            toast("下载失败，可重试")
        })
    }

    private fun openFile(file: File) {
        try {
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            val mime = contentResolver.getType(uri) ?: "application/octet-stream"
            val view = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(view, "打开文件"))
        } catch (e: Exception) {
            val share = Intent(Intent.ACTION_SEND).apply {
                type = "application/octet-stream"
                putExtra(Intent.EXTRA_STREAM, FileProvider.getUriForFile(this@TransferActivity, "$packageName.fileprovider", file))
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(share, "没有可打开此文件的应用，改为分享"))
        }
    }

    private fun formatSize(bytes: Long): String = when {
        bytes >= 1024 * 1024 -> String.format(Locale.US, "%.1f MB", bytes / 1024.0 / 1024.0)
        bytes >= 1024 -> String.format(Locale.US, "%.1f KB", bytes / 1024.0)
        else -> "$bytes B"
    }

    private fun copyText(text: String) {
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.setPrimaryClip(ClipData.newPlainText("微输入法", text))
        toast("已复制")
    }

    private fun addInfo(title: String, body: String) {
        val card = Ui.card(this, 16)
        card.addView(Ui.text(this, title, 14f, Ui.color(this, R.color.text_primary), true))
        card.addView(Ui.text(this, body, 11.5f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(0, Ui.dp(this@TransferActivity, 4f), 0, 0)
        })
        content.addView(card)
    }

    private fun toast(msg: String) = Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
}
