package com.huapohen.wechatinput

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.view.Gravity
import android.view.ViewGroup
import android.widget.EditText
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import com.huapohen.wechatinput.data.DataEngine
import com.huapohen.wechatinput.store.ClipboardStore

class EmojiActivity : BasePageActivity() {
    private var tab = 0
    private var recommended = false
    private var recommendText = ""
    private lateinit var gridHost: LinearLayout

    override fun onCreatePage() {
        DataEngine.ensureBasic(this)
        setPageTitle("表情", "Emoji · 颜文字 · 本地规则推荐")
        if (intent.getStringExtra("tab") == "kaomoji") {
            tab = DataEngine.emojiCategories.size
        }
        render()
    }

    private fun render() {
        content.removeAllViews()
        val info = Ui.card(this, 16)
        info.addView(Ui.text(this, "按语境找表情", 15f, Ui.color(this, R.color.text_primary), true))
        info.addView(Ui.text(
            this,
            "输入一句想回复的话，使用本地关键词规则挑选候选；这不会调用 AI，也不会伪造推荐。",
            11.5f, Ui.color(this, R.color.text_secondary)
        ).apply { setPadding(0, Ui.dp(this@EmojiActivity, 4f), 0, Ui.dp(this@EmojiActivity, 8f)) })
        val input = Ui.editText(this, "例如：今天很开心 / 谢谢 / 加油").apply {
            setText(recommendText)
            setSingleLine(true)
        }
        info.addView(input, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Ui.dp(this, 46f)))
        val actions = Ui.horizontal(this).apply { setPadding(0, Ui.dp(this@EmojiActivity, 8f), 0, 0) }
        actions.addView(Ui.button(this, "推荐表情", true) {
            recommendText = input.text.toString()
            recommended = true
            renderTabs()
            renderGrid()
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
            marginEnd = Ui.dp(this@EmojiActivity, 8f)
        })
        actions.addView(Ui.button(this, "浏览全部", false) {
            recommended = false
            renderTabs()
            renderGrid()
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        info.addView(actions)
        content.addView(info)

        content.addView(Ui.sectionTitle(this, "表情库", "点击复制"))
        val tabsHost = Ui.horizontal(this)
        tabsHost.tag = "tabs"
        content.addView(tabsHost)
        gridHost = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        content.addView(gridHost)
        renderTabs()
        renderGrid()
    }

    private fun renderTabs() {
        val tabsHost = content.findViewWithTag<LinearLayout>("tabs") ?: return
        tabsHost.removeAllViews()
        val cats = DataEngine.emojiCategories.map { it.first } + listOf("颜文字")
        cats.forEachIndexed { index, name ->
            val active = index == tab && !recommended
            val chip = Ui.text(this, name, 12f, if (active) Ui.color(this, R.color.accent_dark) else Ui.color(this, R.color.text_secondary), active).apply {
                background = Ui.rounded(if (active) Ui.color(this@EmojiActivity, R.color.accent_soft) else Ui.color(this@EmojiActivity, R.color.surface), 99f, Ui.color(this@EmojiActivity, R.color.border))
                setPadding(Ui.dp(this@EmojiActivity, 10f), Ui.dp(this@EmojiActivity, 7f), Ui.dp(this@EmojiActivity, 10f), Ui.dp(this@EmojiActivity, 7f))
                isClickable = true
                setOnClickListener {
                    tab = index
                    recommended = false
                    renderTabs()
                    renderGrid()
                }
            }
            tabsHost.addView(chip, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginEnd = Ui.dp(this@EmojiActivity, 4f)
            })
        }
    }

    private fun emojiForTab(): List<String> {
        return if (tab >= DataEngine.emojiCategories.size) kaomoji
        else DataEngine.emojiCategories[tab].second
    }

    private fun recommendations(): List<String> {
        val text = recommendText
        val cat = when {
            listOf("开心", "高兴", "笑", "哈哈", "快乐").any { text.contains(it) } -> "笑脸"
            listOf("谢谢", "感谢", "辛苦").any { text.contains(it) } -> "手势"
            listOf("爱", "喜欢", "想你").any { text.contains(it) } -> "爱心"
            listOf("加油", "努力", "冲").any { text.contains(it) } -> "手势"
            listOf("吃", "饭", "饿", "好喝").any { text.contains(it) } -> "食物"
            listOf("天气", "太阳", "雨", "月亮").any { text.contains(it) } -> "自然"
            listOf("难过", "哭", "委屈").any { text.contains(it) } -> "笑脸"
            else -> "笑脸"
        }
        val source = DataEngine.emojiCategories.firstOrNull { it.first == cat }?.second ?: emptyList()
        return source.take(16)
    }

    private fun renderGrid() {
        gridHost.removeAllViews()
        val items = if (recommended) recommendations() else emojiForTab()
        val title = if (recommended) "推荐结果 · 本地规则" else if (tab >= DataEngine.emojiCategories.size) "颜文字" else DataEngine.emojiCategories[tab].first
        gridHost.addView(Ui.text(this, title, 13f, Ui.color(this, R.color.text_secondary), true).apply {
            setPadding(Ui.dp(this@EmojiActivity, 4f), Ui.dp(this@EmojiActivity, 10f), 0, Ui.dp(this@EmojiActivity, 6f))
        })
        val card = Ui.card(this, 8)
        val grid = GridLayout(this).apply { columnCount = if (isTablet) 10 else 7 }
        items.forEach { emoji ->
            val tv = Ui.text(this, emoji, if (emoji.length > 3) 12f else 25f, Ui.color(this, R.color.text_primary)).apply {
                gravity = Gravity.CENTER
                isClickable = true
                background = Ui.rounded(Ui.color(this@EmojiActivity, R.color.surface_alt), 12f)
                setOnClickListener { copy(emoji) }
            }
            grid.addView(tv, GridLayout.LayoutParams().apply {
                width = 0
                height = Ui.dp(this@EmojiActivity, if (emoji.length > 3) 44f else 50f)
                columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f)
                setMargins(Ui.dp(this@EmojiActivity, 3f), Ui.dp(this@EmojiActivity, 3f), Ui.dp(this@EmojiActivity, 3f), Ui.dp(this@EmojiActivity, 3f))
            })
        }
        card.addView(grid)
        gridHost.addView(card)
        if (recommended) {
            val note = Ui.text(this, "推荐仅基于关键词规则；输入其他内容会得到笑脸分类的常用表情。", 11f, Ui.color(this, R.color.text_secondary)).apply {
                setPadding(Ui.dp(this@EmojiActivity, 4f), Ui.dp(this@EmojiActivity, 6f), 0, 0)
            }
            gridHost.addView(note)
        }
    }

    private fun copy(text: String) {
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.setPrimaryClip(ClipData.newPlainText("微输入法", text))
        ClipboardStore.add(text)
        toast("已复制 $text")
    }

    private fun toast(msg: String) = Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()

    private val kaomoji = listOf(
        "(・ω・)", "(￣▽￣)", "ヾ(≧▽≦*)o", "( ´･ω･)", "(๑•̀ㅂ•́)و✧",
        "(＝^･ω･^＝)", "(*/ω＼*)", "ヽ(￣▽￣)ﾉ", "_(:з」∠)_", "orz",
        "◉‿◉", "(◍•ᴗ•◍)", "(๑˃ᴗ˂)ﻭ", "(ง •̀_•́)ง", "٩(◕‿◕)۶",
        "ʕ•ᴥ•ʔ", "(╯°□°）╯︵ ┻━┻", "(｡•́︿•̀｡)", "(๑•́ ₃ •̀๑)", "(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧"
    )
}
