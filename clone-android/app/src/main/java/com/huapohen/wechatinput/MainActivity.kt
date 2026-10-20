package com.huapohen.wechatinput

import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat

class MainActivity : AppCompatActivity() {
    private val isTablet: Boolean
        get() = resources.configuration.smallestScreenWidthDp >= 600

    private lateinit var column: LinearLayout
    private lateinit var statusChip: TextView
    private lateinit var enableButton: com.google.android.material.button.MaterialButton
    private var dots: LinearLayout? = null
    private var carousel: HorizontalScrollView? = null

    private data class Carousel(
        val title: String,
        val subtitle: String,
        val glyph: String,
        val target: String,
        val plusGate: String? = null,
        val extra: Map<String, String> = emptyMap(),
        val colors: IntArray
    )

    private val carouselItems = listOf(
        Carousel("文字整理", "一键整理口语，补全标点", "Aa", "text_tools", "plusPolish", emptyMap(), intArrayOf(0xFF0E8A68.toInt(), 0xFF24C891.toInt())),
        Carousel("AI 录音笔", "实时转写，生成纪要", "●", "recorder", null, emptyMap(), intArrayOf(0xFF26332F.toInt(), 0xFF3C6E60.toInt())),
        Carousel("多语言自由说", "普通话、粤语、英语随口说", "语", "voice_language", null, emptyMap(), intArrayOf(0xFF3A7D6B.toInt(), 0xFF6FCBB1.toInt())),
        Carousel("表情推荐", "按语境找合适的表情", "☺", "emoji", "plusSticker", emptyMap(), intArrayOf(0xFFB35C43.toInt(), 0xFFE0956F.toInt())),
        Carousel("趣味颜文字", "给句子加一点表情", "◡", "emoji", "plusKaomoji", mapOf("tab" to "kaomoji"), intArrayOf(0xFF4B5D8A.toInt(), 0xFF8397C8.toInt())),
        Carousel("问 AI", "不懂就问，接着聊", "AI", "ai_chat", "plusAskAi", emptyMap(), intArrayOf(0xFF1E6B7A.toInt(), 0xFF43B3BF.toInt())),
        Carousel("排版成图", "把文字排成可分享的海报", "图", "poster", "plusPoster", emptyMap(), intArrayOf(0xFF8A5A2B.toInt(), 0xFFC99B5F.toInt())),
        Carousel("跨设备粘贴传送", "手机与电脑之间传文件", "⇄", "transfer", null, emptyMap(), intArrayOf(0xFF3F5A52.toInt(), 0xFF7FA79A.toInt())),
        Carousel("灵动表达", "把一句话改写得更得体", "✨", "plus", "plusRewrite", emptyMap(), intArrayOf(0xFF6B4E7D.toInt(), 0xFFAD8FBC.toInt()))
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        column = findViewById(R.id.homeColumn)
        val scroll = findViewById<ScrollView>(R.id.homeScroll)
        applyMaxWidth(scroll)

        buildHeader()
        buildCarousel()
        buildFeatures()
        buildSettings()
        buildMore()
        buildFooter()

        if (!Prefs.onboarded && savedInstanceState == null) {
            startActivity(Intent(this, OnboardingActivity::class.java))
        }
    }

    private fun applyMaxWidth(scroll: ScrollView) {
        val screen = resources.displayMetrics.widthPixels
        val pad = (resources.displayMetrics.density * 18).toInt()
        val max = (resources.displayMetrics.density * 1180).toInt()
        val width = minOf(screen - pad, max)
        column.layoutParams = FrameLayout.LayoutParams(width, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            gravity = Gravity.CENTER_HORIZONTAL
        }
    }

    override fun onResume() {
        super.onResume()
        refreshImeStatus()
    }

    private fun refreshImeStatus() {
        val enabled = ImeHelper.enabled(this)
        val selected = ImeHelper.selected(this)
        val label = when {
            selected -> "● 当前输入法"
            enabled -> "● 已启用，点此切换"
            else -> "● 尚未启用"
        }
        statusChip?.text = label
        statusChip?.setTextColor(
            if (enabled) ContextCompat.getColor(this, R.color.accent_dark)
            else ContextCompat.getColor(this, R.color.warning)
        )
        enableButton?.text = when {
            selected -> "键盘体验"
            enabled -> "选择输入法"
            else -> "启用微输入法"
        }
    }

    private fun buildHeader() {
        val header = FrameLayout(this).apply {
            background = GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                intArrayOf(0xFF24C891.toInt(), 0xFF0E8A68.toInt())
            ).apply { cornerRadius = Ui.dp(this@MainActivity, 24f).toFloat() }
        }
        val inner = Ui.vertical(this).apply { setPadding(Ui.dp(this, 20f), Ui.dp(this, 20f), Ui.dp(this, 20f), Ui.dp(this, 18f)) }
        val top = Ui.horizontal(this)
        val mark = Ui.text(this, "微", 28f, Color.WHITE, true).apply {
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0x33FFFFFF)
            }
        }
        top.addView(mark, LinearLayout.LayoutParams(Ui.dp(this, 54f), Ui.dp(this, 54f)))
        val titles = Ui.vertical(this).apply { setPadding(Ui.dp(this, 14f), 0, 0, 0) }
        titles.addView(Ui.text(this, "微输入法", 26f, Color.WHITE, true))
        titles.addView(Ui.text(this, "简洁、好用、打字快", 13f, 0xFFE6FFF7.toInt()).apply {
            setPadding(0, Ui.dp(this@MainActivity, 3f), 0, 0)
        })
        top.addView(titles, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        val glyph = Ui.text(this, "⌨", 24f, Color.WHITE).apply { gravity = Gravity.CENTER }
        top.addView(glyph, LinearLayout.LayoutParams(Ui.dp(this, 38f), Ui.dp(this, 38f)))
        inner.addView(top)

        inner.addView(Ui.spacer(this, 16f))
        statusChip = Ui.text(this, "● 检查中", 12f, 0xFF0E8A68.toInt(), true).apply {
            background = GradientDrawable().apply {
                cornerRadius = Ui.dp(this@MainActivity, 99f).toFloat()
                setColor(0xEEFFFFFF.toInt())
            }
            setPadding(Ui.dp(this@MainActivity, 12f), Ui.dp(this@MainActivity, 6f), Ui.dp(this@MainActivity, 12f), Ui.dp(this@MainActivity, 6f))
            isClickable = true
            setOnClickListener { startActivity(Intent(this@MainActivity, KeyboardTestActivity::class.java)) }
        }
        val row = Ui.horizontal(this)
        row.addView(statusChip)
        row.addView(View(this), LinearLayout.LayoutParams(0, 1, 1f))
        enableButton = Ui.button(this, "启用微输入法", false) { onEnableClicked() }.apply {
            setBackgroundTintList(android.content.res.ColorStateList.valueOf(Color.WHITE))
            setTextColor(0xFF0E8A68.toInt())
            textSize = 13f
            minWidth = 0
            minimumWidth = 0
            setPadding(Ui.dp(this@MainActivity, 14f), 0, Ui.dp(this@MainActivity, 14f), 0)
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, Ui.dp(this@MainActivity, 40f))
        }
        row.addView(enableButton)
        inner.addView(row)

        val stats = Ui.horizontal(this).apply { setPadding(0, Ui.dp(this@MainActivity, 14f), 0, 0) }
        listOf("本地词库 7 万+", "六种中文键盘", "无模型密钥").forEach { label ->
            val t = Ui.text(this, label, 11f, 0xFFE6FFF7.toInt()).apply {
                background = GradientDrawable().apply {
                    cornerRadius = Ui.dp(this@MainActivity, 99f).toFloat()
                    setColor(0x26FFFFFF)
                }
                setPadding(Ui.dp(this@MainActivity, 9f), Ui.dp(this@MainActivity, 4f), Ui.dp(this@MainActivity, 9f), Ui.dp(this@MainActivity, 4f))
            }
            stats.addView(t, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                marginEnd = Ui.dp(this@MainActivity, 6f)
            })
        }
        inner.addView(stats)
        header.addView(inner)
        column.addView(header, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        refreshImeStatus()
    }

    private fun onEnableClicked() {
        when {
            ImeHelper.selected(this) -> startActivity(Intent(this, KeyboardTestActivity::class.java))
            ImeHelper.enabled(this) -> ImeHelper.showPicker(this)
            else -> ImeHelper.openEnableSettings(this)
        }
    }

    private fun buildCarousel() {
        column.addView(Ui.spacer(this, 18f))
        val heading = Ui.horizontal(this)
        heading.addView(Ui.text(this, "探索", 18f, Ui.color(this, R.color.text_primary), true), LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        heading.addView(Ui.text(this, "左右滑动 · 9 张", 12f, Ui.color(this, R.color.text_secondary)))
        column.addView(heading, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { bottomMargin = Ui.dp(this@MainActivity, 10f) })

        val hsv = HorizontalScrollView(this).apply {
            isHorizontalScrollBarEnabled = false
            clipToPadding = false
        }
        val cards = Ui.horizontal(this).apply { setPadding(0, 0, Ui.dp(this@MainActivity, 16f), 0) }
        carouselItems.forEach { item ->
            val card = FrameLayout(this).apply {
                background = GradientDrawable(
                    GradientDrawable.Orientation.TL_BR,
                    item.colors
                ).apply { cornerRadius = Ui.dp(this@MainActivity, 22f).toFloat() }
                isClickable = true
                setOnClickListener { openCarousel(item) }
            }
            val body = Ui.vertical(this).apply { setPadding(Ui.dp(this@MainActivity, 18f), Ui.dp(this@MainActivity, 16f), Ui.dp(this@MainActivity, 18f), Ui.dp(this@MainActivity, 14f)) }
            body.addView(Ui.text(this, item.glyph, 22f, Color.WHITE, true).apply {
                gravity = Gravity.CENTER
                background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(0x33FFFFFF) }
            }, LinearLayout.LayoutParams(Ui.dp(this@MainActivity, 42f), Ui.dp(this@MainActivity, 42f)))
            body.addView(Ui.text(this, item.title, 20f, Color.WHITE, true).apply {
                setPadding(0, Ui.dp(this@MainActivity, 12f), 0, 0)
            })
            body.addView(Ui.text(this, item.subtitle, 12f, 0xDFFFFFFF.toInt()).apply {
                setPadding(0, Ui.dp(this@MainActivity, 4f), 0, 0)
            })
            body.addView(View(this), LinearLayout.LayoutParams(1, 0, 1f))
            body.addView(Ui.text(this, "打开  →", 12f, Color.WHITE, true))
            card.addView(body)
            val w = if (isTablet) 320 else 262
            cards.addView(card, LinearLayout.LayoutParams(Ui.dp(this@MainActivity, w.toFloat()), Ui.dp(this@MainActivity, 190f)).apply {
                marginEnd = Ui.dp(this@MainActivity, 12f)
            })
        }
        hsv.addView(cards)
        column.addView(hsv, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Ui.dp(this, 190f)))
        carousel = hsv

        dots = Ui.horizontal(this).apply {
            gravity = Gravity.CENTER
            setPadding(0, Ui.dp(this@MainActivity, 10f), 0, 0)
        }
        carouselItems.indices.forEach { index ->
            val dot = View(this).apply {
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(if (index == 0) Ui.color(this@MainActivity, R.color.accent_dark) else Ui.color(this@MainActivity, R.color.border))
                }
            }
            dots!!.addView(dot, LinearLayout.LayoutParams(Ui.dp(this@MainActivity, 6f), Ui.dp(this@MainActivity, 6f)).apply {
                marginEnd = Ui.dp(this@MainActivity, 5f)
            })
        }
        column.addView(dots)
        hsv.setOnScrollChangeListener { _, scrollX, _, _, _ ->
            val cardWidth = Ui.dp(this, (if (isTablet) 332 else 274).toFloat())
            val idx = (scrollX + cardWidth / 2) / cardWidth
            dots?.let { row ->
                for (i in 0 until row.childCount) {
                    (row.getChildAt(i).background as GradientDrawable).setColor(
                        if (i == idx.coerceIn(0, carouselItems.size - 1)) Ui.color(this, R.color.accent_dark)
                        else Ui.color(this, R.color.border)
                    )
                }
            }
        }
    }

    private fun openCarousel(item: Carousel) {
        if (item.plusGate != null && !Prefs.plusEnabled) {
            Toast.makeText(this, "拼写 Plus 已关闭，可在设置中开启", Toast.LENGTH_SHORT).show()
            startActivity(Pages.intent(this, "plus"))
            return
        }
        if (item.plusGate != null) {
            val enabled = when (item.plusGate) {
                "plusAskAi" -> Prefs.plusAskAi
                "plusPolish" -> Prefs.plusPolish
                "plusSticker" -> Prefs.plusSticker
                "plusKaomoji" -> Prefs.plusKaomoji
                "plusPoster" -> Prefs.plusPoster
                "plusRewrite" -> Prefs.plusRewrite
                else -> true
            }
            if (!enabled) {
                Toast.makeText(this, "该能力已在拼写 Plus 中关闭，可重新开启", Toast.LENGTH_SHORT).show()
                startActivity(Pages.intent(this, "plus"))
                return
            }
        }
        startActivity(Pages.intent(this, item.target, item.extra))
    }

    private fun buildFeatures() {
        column.addView(Ui.sectionTitle(this, "功能", "NEW"))
        val grid = Ui.settingsGrid(this, if (isTablet) 4 else 2, listOf(
            featureCard("AI 录音笔", "实时转写 · AI 纪要", "●", "NEW") { startActivity(Pages.intent(this, "recorder")) },
            featureCard("隔空传送", "上传文件到后端中转", "⇪", null) { startActivity(Pages.intent(this, "transfer")) },
            featureCard("键盘体验", "在宿主输入框里试打", "⌨", null) { startActivity(Pages.intent(this, "keyboard")) },
            featureCard("常用语", "收藏并快速上屏", "语", null) { startActivity(Pages.intent(this, "phrases")) }
        ))
        column.addView(grid)
    }

    private fun featureCard(title: String, subtitle: String, glyph: String, badge: String?, onClick: () -> Unit): View {
        val card = Ui.card(this, 14).apply {
            layoutParams = ViewGroup.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT)
            isClickable = true
            setOnClickListener { onClick() }
        }
        val row = Ui.horizontal(this)
        val g = Ui.text(this, glyph, 20f, Ui.color(this, R.color.accent_dark), true).apply {
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Ui.color(this@MainActivity, R.color.accent_soft))
            }
        }
        row.addView(g, LinearLayout.LayoutParams(Ui.dp(this, 42f), Ui.dp(this, 42f)))
        val col = Ui.vertical(this).apply { setPadding(Ui.dp(this, 10f), 0, 0, 0) }
        val titleRow = Ui.horizontal(this)
        titleRow.addView(Ui.text(this, title, 15f, Ui.color(this, R.color.text_primary), true))
        if (badge != null && !isTablet) titleRow.addView(Ui.pill(this, badge).apply {
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                marginStart = Ui.dp(this@MainActivity, 6f)
            }
        })
        col.addView(titleRow)
        col.addView(Ui.text(this, subtitle, 11f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(0, Ui.dp(this@MainActivity, 3f), 0, 0)
        })
        row.addView(col, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        card.addView(row)
        return card
    }

    private fun buildSettings() {
        column.addView(Ui.sectionTitle(this, "设置", "全部可调"))
        val ids = listOf("display", "keystroke", "toolbar", "auxiliary", "sync", "clipboard", "keyboard_manage", "voice", "plus", "standalone", "migration", "fuzzy")
        val views = ids.map { id -> settingCard(Pages.byId(id)) }
        column.addView(Ui.settingsGrid(this, if (isTablet) 4 else 2, views))
    }

    private fun settingCard(page: PageInfo): View {
        val card = Ui.card(this, 14).apply {
            layoutParams = ViewGroup.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT)
            isClickable = true
            setOnClickListener { startActivity(Pages.intent(this@MainActivity, page.id)) }
        }
        val row = Ui.horizontal(this)
        val g = Ui.text(this, page.glyph, 16f, Ui.color(this, R.color.accent_dark), true).apply {
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Ui.color(this@MainActivity, R.color.accent_soft))
            }
        }
        row.addView(g, LinearLayout.LayoutParams(Ui.dp(this, 36f), Ui.dp(this, 36f)))
        val col = Ui.vertical(this).apply { setPadding(Ui.dp(this, 10f), 0, 0, 0) }
        col.addView(Ui.text(this, page.title, 14f, Ui.color(this, R.color.text_primary), true))
        col.addView(Ui.text(this, page.subtitle, 10f, Ui.color(this, R.color.text_secondary)).apply {
            maxLines = 2
            setPadding(0, Ui.dp(this@MainActivity, 2f), 0, 0)
        })
        row.addView(col, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        card.addView(row)
        return card
    }

    private fun buildMore() {
        column.addView(Ui.sectionTitle(this, "更多"))
        val group = Ui.group(this)
        listOf("onboarding", "privacy", "desktop", "about", "help").forEachIndexed { index, id ->
            val page = Pages.byId(id)
            group.addView(Ui.row(this, page.title, page.subtitle, null, true) {
                startActivity(Pages.intent(this, page.id))
            })
            if (index < 4) group.addView(Ui.divider(this))
        }
        column.addView(group)
    }

    private fun buildFooter() {
        column.addView(Ui.spacer(this, 10f))
        val footer = Ui.text(
            this,
            "微输入法 v1.0 · 独立研究与互操作复刻\n不包含腾讯的二进制资源、字体或模型密钥。",
            11f, Ui.color(this, R.color.text_secondary)
        ).apply {
            gravity = Gravity.CENTER
            setLineSpacing(Ui.dp(this@MainActivity, 3f).toFloat(), 1f)
        }
        column.addView(footer)
    }
}
