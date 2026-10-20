package com.huapohen.wechatinput

import android.content.ContentValues
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.view.Gravity
import android.view.ViewGroup
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.Toast
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class PosterActivity : BasePageActivity() {
    private var style = 0
    private var fontSize = 44
    private var bitmap: Bitmap? = null
    private lateinit var source: EditText
    private lateinit var preview: ImageView
    private lateinit var status: android.widget.TextView

    private val styles = listOf(
        Triple("薄荷", intArrayOf(0xFFE6F4F2.toInt(), 0xFFBFEBDD.toInt()), 0xFF0E8A68.toInt()),
        Triple("墨绿", intArrayOf(0xFF26332F.toInt(), 0xFF0E8A68.toInt()), 0xFFE6FFF7.toInt()),
        Triple("暖白", intArrayOf(0xFFFFF8EF.toInt(), 0xFFF0DCC8.toInt()), 0xFF5A4128.toInt())
    )

    override fun onCreatePage() {
        setPageTitle("排版成图", "本地 Canvas 渲染 · 可保存与分享")
        val inputCard = Ui.card(this, 14)
        source = Ui.editText(this, "输入要排版的文字…", true).apply {
            setText(intent.getStringExtra("seed_text").orEmpty().ifBlank { "把想说的话，排成一张图。" })
        }
        inputCard.addView(source, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Ui.dp(this, 100f)))
        val styleRow = Ui.horizontal(this).apply { setPadding(0, Ui.dp(this@PosterActivity, 8f), 0, 0) }
        styles.forEachIndexed { i, s ->
            styleRow.addView(Ui.text(this, s.first, 12f, if (i == style) Ui.color(this, R.color.accent_dark) else Ui.color(this, R.color.text_secondary), i == style).apply {
                gravity = Gravity.CENTER
                background = Ui.rounded(if (i == style) Ui.color(this, R.color.accent_soft) else Ui.color(this, R.color.surface_alt), 99f, Ui.color(this, R.color.border))
                setPadding(0, Ui.dp(this@PosterActivity, 8f), 0, Ui.dp(this@PosterActivity, 8f))
                isClickable = true
                setOnClickListener { style = i; onCreatePageAgain() }
            }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginEnd = Ui.dp(this@PosterActivity, 5f)
            })
        }
        inputCard.addView(styleRow)
        content.addView(inputCard)

        val sliderCard = Ui.card(this, 6)
        sliderCard.addView(Ui.sliderRow(this, "字号", { "${it}px" }, fontSize, 30, 64, 2) {
            fontSize = it
        })
        content.addView(sliderCard)

        buttonRow(
            Ui.button(this, "生成海报", true) { generate() },
            Ui.button(this, "保存并分享", false) { share() }
        )
        status = Ui.text(this, "尚未生成", 11f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(Ui.dp(this, 4f), 0, 0, Ui.dp(this, 6f))
        }
        content.addView(status)
        val card = Ui.card(this, 8)
        preview = ImageView(this).apply {
            adjustViewBounds = true
            scaleType = ImageView.ScaleType.FIT_CENTER
            setBackgroundColor(0xFFF2F7F5.toInt())
        }
        card.addView(preview, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Ui.dp(this, 360f)))
        content.addView(card)
        addInfo("渲染说明", "海报完全在设备本地生成，不调用 AI、不上传文字。图片保存到 MediaStore 或应用缓存，分享通过系统分享面板。")
        generate()
    }

    private fun onCreatePageAgain() {
        val text = if (::source.isInitialized) source.text.toString() else ""
        content.removeAllViews()
        onCreatePage()
        if (text.isNotBlank()) {
            source.setText(text)
            generate()
        }
    }

    private fun generate() {
        val text = source.text.toString().trim()
        if (text.isEmpty()) {
            toast("请先输入文字")
            return
        }
        val bmp = render(text)
        bitmap = bmp
        preview.setImageBitmap(bmp)
        status.text = "已生成 ${bmp.width}×${bmp.height} · ${styles[style].first}"
        status.setTextColor(Ui.color(this, R.color.accent_dark))
    }

    private fun render(text: String): Bitmap {
        val w = 1080
        val h = 1440
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val palette = styles[style]
        val bg = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(0f, 0f, w.toFloat(), h.toFloat(), palette.second[0], palette.second[1], Shader.TileMode.CLAMP)
        }
        c.drawRect(0f, 0f, w.toFloat(), h.toFloat(), bg)

        val deco = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0x22FFFFFF }
        c.drawCircle(w - 80f, 130f, 190f, deco)
        c.drawCircle(70f, h - 160f, 150f, deco)

        val fg = palette.third
        val label = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = fg
            alpha = 180
            textSize = 30f
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        }
        c.drawText("微输入法 · 排版成图", 92f, 130f, label)

        val body = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = fg
            textSize = fontSize.toFloat()
            typeface = Typeface.create("sans-serif", Typeface.NORMAL)
        }
        val maxWidth = w - 184f
        val lines = wrap(text, body, maxWidth)
        var y = 260f
        val lineHeight = fontSize * 1.55f
        lines.take(16).forEach { line ->
            c.drawText(line, 92f, y, body)
            y += lineHeight
        }
        val rule = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = fg
            alpha = 70
            strokeWidth = 2f
        }
        c.drawLine(92f, h - 200f, w - 92f, h - 200f, rule)
        val foot = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = fg
            alpha = 170
            textSize = 24f
        }
        c.drawText("简洁、好用、打字快", 92f, h - 140f, foot)
        val date = SimpleDateFormat("yyyy.MM.dd", Locale.CHINA).format(Date())
        c.drawText(date, w - 240f, h - 140f, foot)
        return bmp
    }

    private fun wrap(text: String, paint: Paint, maxWidth: Float): List<String> {
        val result = ArrayList<String>()
        text.split("\n").forEach { paragraph ->
            if (paragraph.isEmpty()) {
                result.add("")
                return@forEach
            }
            var rest = paragraph
            while (rest.isNotEmpty()) {
                val count = paint.breakText(rest, true, maxWidth, null)
                if (count <= 0) break
                result.add(rest.substring(0, count))
                rest = rest.substring(count)
            }
        }
        return result
    }

    private fun share() {
        val bmp = bitmap ?: run { generate(); return }
        try {
            val dir = File(cacheDir, "posters").apply { mkdirs() }
            val file = File(dir, "poster-${System.currentTimeMillis()}.png")
            FileOutputStream(file).use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(intent, "分享海报"))
            if (Build.VERSION.SDK_INT >= 29) saveToGallery(bmp)
        } catch (e: Exception) {
            toast("分享失败：${e.message}")
        }
    }

    private fun saveToGallery(bmp: Bitmap) {
        try {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, "wetype-poster-${System.currentTimeMillis()}.png")
                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/微输入法")
            }
            val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values) ?: return
            contentResolver.openOutputStream(uri)?.use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
            status.text = "已保存到相册 Pictures/微输入法 · 并可分享"
        } catch (_: Exception) {
        }
    }

    private fun addInfo(title: String, body: String) {
        val card = Ui.card(this, 16)
        card.addView(Ui.text(this, title, 14f, Ui.color(this, R.color.text_primary), true))
        card.addView(Ui.text(this, body, 11.5f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(0, Ui.dp(this@PosterActivity, 4f), 0, 0)
        })
        content.addView(card)
    }

    private fun toast(msg: String) = Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
}
