package com.huapohen.wechatinput

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Toast
import com.huapohen.wechatinput.data.DataEngine

class KeyboardTestActivity : BasePageActivity() {
    private lateinit var host: EditText
    private lateinit var statusText: android.widget.TextView
    private lateinit var currentIme: android.widget.TextView

    override fun onCreatePage() {
        setPageTitle("键盘体验", "真实宿主输入框 · 候选上屏 · 模式切换")
        setHeaderAction("选择输入法") { ImeHelper.showPicker(this) }

        addInfo(
            "在这里直接打字",
            "下方是普通 EditText。焦点进入后会弹出系统输入法；选择微输入法后，九宫格/全键盘候选会真实写入这个输入框，而不是演示文本。"
        )
        statusText = Ui.text(this, "输入法状态检查中…", 13f, Ui.color(this, R.color.text_primary), true).apply {
            setPadding(Ui.dp(this@KeyboardTestActivity, 4f), 0, 0, Ui.dp(this@KeyboardTestActivity, 4f))
        }
        content.addView(statusText)
        currentIme = Ui.text(this, "", 11f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(Ui.dp(this@KeyboardTestActivity, 4f), 0, 0, Ui.dp(this@KeyboardTestActivity, 10f))
        }
        content.addView(currentIme)

        val card = Ui.card(this, 14)
        host = EditText(this).apply {
            hint = "点这里，开始输入…"
            setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, 18f)
            setTextColor(Ui.color(this@KeyboardTestActivity, R.color.text_primary))
            setHintTextColor(Ui.color(this@KeyboardTestActivity, R.color.muted))
            background = Ui.rounded(Ui.color(this@KeyboardTestActivity, R.color.surface_alt), 14f, Ui.color(this@KeyboardTestActivity, R.color.border))
            setPadding(Ui.dp(this@KeyboardTestActivity, 14f), Ui.dp(this@KeyboardTestActivity, 14f), Ui.dp(this@KeyboardTestActivity, 14f), Ui.dp(this@KeyboardTestActivity, 14f))
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            minLines = 4
            gravity = Gravity.TOP or Gravity.START
        }
        card.addView(host, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Ui.dp(this, 150f)))
        content.addView(card)

        buttonRow(
            Ui.button(this, "聚焦并弹出键盘", true) { focusHost() },
            Ui.button(this, "清空", false) { host.setText("") }
        )
        buttonRow(
            Ui.button(this, "启用微输入法", false) { ImeHelper.openEnableSettings(this) },
            Ui.button(this, "在系统设置测试", false) {
                startActivity(Intent(Settings.ACTION_SETTINGS))
                toast("在设置顶部搜索框里使用微输入法输入")
            }
        )

        content.addView(Ui.sectionTitle(this, "键盘模式", "点击切换默认模式"))
        val modes = listOf(
            "t9" to "九宫格拼音 2-9", "qwerty" to "全键盘拼音",
            "handwrite" to "手写（模板识别）", "stroke" to "笔画 h/s/p/n/z",
            "wubi" to "五笔 86", "doublepin" to "双拼（小鹤）",
            "english" to "英文", "number" to "数字", "symbols" to "符号", "emoji" to "Emoji"
        )
        val chips = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }
        modes.chunked(2).forEach { rowItems ->
            val row = Ui.horizontal(this)
            rowItems.forEach { (id, label) ->
                val active = Prefs.keyboardMode == id
                val chip = Ui.text(this, label, 13f, if (active) Ui.color(this, R.color.accent_dark) else Ui.color(this, R.color.text_primary), active).apply {
                    background = Ui.rounded(
                        if (active) Ui.color(this@KeyboardTestActivity, R.color.accent_soft) else Ui.color(this@KeyboardTestActivity, R.color.surface),
                        14f, Ui.color(this@KeyboardTestActivity, R.color.border)
                    )
                    gravity = Gravity.CENTER
                    setPadding(Ui.dp(this@KeyboardTestActivity, 8f), Ui.dp(this@KeyboardTestActivity, 12f), Ui.dp(this@KeyboardTestActivity, 8f), Ui.dp(this@KeyboardTestActivity, 12f))
                    isClickable = true
                    setOnClickListener {
                        Prefs.keyboardMode = id
                        toast("默认模式：$label（重新聚焦后生效）")
                        host.clearFocus()
                        focusHost()
                    }
                }
                row.addView(chip, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                    marginEnd = Ui.dp(this@KeyboardTestActivity, 8f)
                    bottomMargin = Ui.dp(this@KeyboardTestActivity, 8f)
                })
            }
            if (rowItems.size == 1) {
                row.addView(View(this), LinearLayout.LayoutParams(0, 1, 1f))
            }
            chips.addView(row)
        }
        content.addView(chips)

        content.addView(Ui.sectionTitle(this, "本地引擎"))
        val engine = Ui.card(this, 16)
        val engineLoaded = DataEngine.isLoaded()
        engine.addView(Ui.text(
            this,
            if (engineLoaded) "● 词库已加载" else "● 词库正在加载",
            14f,
            if (engineLoaded) Ui.color(this, R.color.accent_dark) else Ui.color(this, R.color.warning),
            true
        ))
        engine.addView(Ui.text(
            this,
            "拼音字 26,703 · 拼音词 46,111 · 五笔 26,271 · 笔画 4,299 · 双拼（小鹤）。\n候选排序：固定词 > 用户词频 > 精确匹配 > 词组 > 模糊拼音。",
            12f, Ui.color(this, R.color.text_secondary)
        ).apply { setPadding(0, Ui.dp(this@KeyboardTestActivity, 6f), 0, 0) })
        engine.addView(Ui.text(
            this,
            "手写为有限模板 + 笔画表前缀匹配，不是云端手写模型；About/Help 中已如实标注。",
            11f, Ui.color(this, R.color.text_secondary)
        ).apply { setPadding(0, Ui.dp(this@KeyboardTestActivity, 6f), 0, 0) })
        content.addView(engine)

        Handler(Looper.getMainLooper()).postDelayed({ focusHost() }, 450)
    }

    private fun focusHost() {
        host.requestFocus()
        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        imm.showSoftInput(host, InputMethodManager.SHOW_IMPLICIT)
    }

    override fun onResume() {
        super.onResume()
        refreshStatus()
    }

    private fun refreshStatus() {
        if (!::statusText.isInitialized) return
        val enabled = ImeHelper.enabled(this)
        val selected = ImeHelper.selected(this)
        statusText.text = when {
            selected -> "● 微输入法已选中，可直接输入"
            enabled -> "● 已启用，但当前由其他输入法接管"
            else -> "● 微输入法尚未启用"
        }
        statusText.setTextColor(
            if (selected) Ui.color(this, R.color.accent_dark)
            else if (enabled) Ui.color(this, R.color.warning)
            else Ui.color(this, R.color.danger)
        )
        val id = Settings.Secure.getString(contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD) ?: "未知"
        currentIme.text = "当前 IME：$id"
    }

    private fun addInfo(title: String, body: String) {
        val card = Ui.card(this, 16)
        card.addView(Ui.text(this, title, 15f, Ui.color(this, R.color.text_primary), true))
        card.addView(Ui.text(this, body, 12f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(0, Ui.dp(this@KeyboardTestActivity, 5f), 0, 0)
            setLineSpacing(Ui.dp(this@KeyboardTestActivity, 3f).toFloat(), 1f)
        })
        content.addView(card)
    }

    private fun toast(msg: String) = Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
}
