package com.huapohen.wechatinput.ime

import android.content.ClipboardManager
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.media.AudioManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.GridLayout
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import com.huapohen.wechatinput.Prefs
import com.huapohen.wechatinput.R
import com.huapohen.wechatinput.Ui
import com.huapohen.wechatinput.data.DataEngine
import com.huapohen.wechatinput.store.ClipboardStore
import com.huapohen.wechatinput.store.PhraseStore

class KeyboardView(context: Context) : LinearLayout(context) {
    var host: ImeHost? = null
    private var mode: String = Prefs.keyboardMode
    private var lastChineseMode: String = "t9"
    private var buffer = ""
    private var shift = false
    private var handwriteCandidates: List<String> = emptyList()
    private var currentCandidates: List<String> = emptyList()
    private var engineReady = DataEngine.isLoaded()
    private var emojiCategory = 0
    private var symbolPage = 0
    private var voicePanel: View? = null
    private var voicePartial: TextView? = null

    private lateinit var candidateRow: LinearLayout
    private lateinit var candidateScroll: HorizontalScrollView
    private lateinit var bufferPill: TextView
    private lateinit var expandButton: TextView
    private lateinit var contentArea: FrameLayout
    private lateinit var toolbarHost: LinearLayout
    private val keyHeight: Int
        get() {
            val base = if (resources.configuration.screenWidthDp > resources.configuration.screenHeightDp) 38 else 47
            return Ui.dp(context, base * Prefs.keyboardHeightFactor / 100f)
        }

    private val modeNames = listOf(
        "t9" to "九宫格拼音", "qwerty" to "全键盘拼音", "handwrite" to "手写",
        "stroke" to "笔画", "wubi" to "五笔", "doublepin" to "双拼",
        "english" to "英文", "number" to "数字", "symbols" to "符号", "emoji" to "表情"
    )

    init {
        orientation = VERTICAL
        setBackgroundColor(
            if (Prefs.displayTheme == 1) Color.WHITE else Ui.color(context, R.color.keyboard_bg)
        )
        setPadding(Ui.dp(context, 4f), 0, Ui.dp(context, 4f), Ui.dp(context, 24f))
        buildCandidateBar()
        buildToolbar()
        contentArea = FrameLayout(context)
        addView(contentArea, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
        rebuildRows()
        updateCandidates()
    }

    // --- public API used by the service -----------------------------------
    fun refreshFromPrefs() {
        val newMode = Prefs.keyboardMode
        if (newMode != mode) {
            mode = newMode
            buffer = ""
            rebuildRows()
        }
        updateCandidates()
    }

    fun resetBuffer() {
        buffer = ""
        handwriteCandidates = emptyList()
        currentCandidates = emptyList()
        host?.finishComposing()
        updateCandidates()
        hidePanel()
        hideVoicePanel()
    }

    fun onEngineReady() {
        engineReady = true
        updateCandidates()
    }

    fun showVoicePanel(partial: String) {
        if (voicePanel == null) {
            val panel = FrameLayout(context).apply {
                setBackgroundColor(0xF7FFFFFF.toInt())
                isClickable = true
            }
            val col = LinearLayout(context).apply {
                orientation = VERTICAL
                gravity = Gravity.CENTER
                setPadding(Ui.dp(context, 24f), Ui.dp(context, 16f), Ui.dp(context, 24f), Ui.dp(context, 16f))
            }
            val mic = TextView(context).apply {
                text = "麦"
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 28f)
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
                background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(Ui.color(context, R.color.accent)) }
            }
            col.addView(mic, LinearLayout.LayoutParams(Ui.dp(context, 62f), Ui.dp(context, 62f)))
            col.addView(Ui.text(context, "正在聆听…", 17f, Ui.color(context, R.color.text_primary), true).apply {
                setPadding(0, Ui.dp(context, 8f), 0, 0)
            })
            voicePartial = Ui.text(context, partial.ifBlank { "松手完成，或点“完成”" }, 14f, Ui.color(context, R.color.text_secondary)).apply {
                gravity = Gravity.CENTER
                maxLines = 3
                ellipsize = TextUtils.TruncateAt.END
                setPadding(0, Ui.dp(context, 4f), 0, Ui.dp(context, 8f))
            }
            col.addView(voicePartial)
            val row = Ui.horizontal(context)
            row.addView(Ui.button(context, "取消", false) { host?.cancelVoice(); hideVoicePanel() }, LinearLayout.LayoutParams(0, Ui.dp(context, 42f), 1f).apply {
                marginEnd = Ui.dp(context, 8f)
            })
            row.addView(Ui.button(context, "完成", true) { host?.stopVoice() }, LinearLayout.LayoutParams(0, Ui.dp(context, 42f), 1f))
            col.addView(row, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
            panel.addView(col, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { gravity = Gravity.CENTER })
            contentArea.addView(panel, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
            voicePanel = panel
        } else {
            voicePartial?.text = partial.ifBlank { "松手完成，或点“完成”" }
        }
    }

    fun updateVoicePartial(partial: String) {
        voicePartial?.text = partial.ifBlank { "…" }
    }

    fun hideVoicePanel() {
        voicePanel?.let { contentArea.removeView(it) }
        voicePanel = null
        voicePartial = null
    }

    fun voiceFailed(message: String) {
        hideVoicePanel()
        host?.toast(message)
    }

    fun commitFromVoice(text: String) {
        hideVoicePanel()
        if (text.isBlank()) return
        var finalText = text.trim()
        if (Prefs.voicePunctuation) {
            finalText = when (Prefs.voicePunctuationStyle) {
                1 -> finalText + " "
                2 -> finalText
                else -> if (finalText.isNotEmpty() && finalText.last() in "。！？.!?") finalText else finalText + "。"
            }
        }
        if (Prefs.voiceReleaseSend) {
            host?.commitText(finalText)
        } else {
            host?.setComposing(finalText)
        }
    }

    // --- candidate bar -----------------------------------------------------
    private fun buildCandidateBar() {
        val bar = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundColor(if (Prefs.displayTheme == 1) Color.WHITE else Color.TRANSPARENT)
            setPadding(Ui.dp(context, 4f), Ui.dp(context, 3f), Ui.dp(context, 4f), Ui.dp(context, 3f))
        }
        bufferPill = Ui.text(context, "", 14f, Ui.color(context, R.color.accent_dark), true).apply {
            background = GradientDrawable().apply {
                cornerRadius = Ui.dp(context, 99f).toFloat()
                setColor(Ui.color(context, R.color.accent_soft))
            }
            setPadding(Ui.dp(context, 9f), Ui.dp(context, 5f), Ui.dp(context, 9f), Ui.dp(context, 5f))
            visibility = GONE
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }
        bar.addView(bufferPill, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            marginEnd = Ui.dp(context, 4f)
        })
        candidateScroll = HorizontalScrollView(context).apply {
            isHorizontalScrollBarEnabled = false
            clipToPadding = false
        }
        candidateRow = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        candidateScroll.addView(candidateRow)
        bar.addView(candidateScroll, LinearLayout.LayoutParams(0, LayoutParams.MATCH_PARENT, 1f))
        expandButton = Ui.text(context, "⌄", 18f, Ui.color(context, R.color.text_secondary), true).apply {
            gravity = Gravity.CENTER
            setPadding(Ui.dp(context, 8f), 0, Ui.dp(context, 8f), 0)
            visibility = GONE
            isClickable = true
            setOnClickListener { showAllCandidates() }
        }
        bar.addView(expandButton, LinearLayout.LayoutParams(Ui.dp(context, 34f), LayoutParams.MATCH_PARENT))
        addView(bar, LayoutParams(LayoutParams.MATCH_PARENT, Ui.dp(context, 44f)))
    }

    private fun updateCandidates() {
        candidateRow.removeAllViews()
        bufferPill.text = buffer
        bufferPill.visibility = if (buffer.isEmpty()) GONE else VISIBLE
        expandButton.visibility = GONE
        currentCandidates = when {
            mode == "handwrite" -> handwriteCandidates
            buffer.isEmpty() -> emptyList()
            !engineReady -> emptyList()
            else -> DataEngine.candidates(mode, buffer, Prefs.candidateCount)
        }
        if (buffer.isEmpty() && (mode != "handwrite" || handwriteCandidates.isEmpty())) {
            addHint(modeLabel(), null)
            addHint("长按空格说话", { host?.startVoice() })
            addHint("剪贴板", { showClipboardPanel() })
            addHint("常用语", { showPhrasesPanel() })
            return
        }
        if (!engineReady && mode != "handwrite") {
            addHint("词库加载中…", null)
            return
        }
        if (currentCandidates.isEmpty()) {
            addHint(if (buffer.isNotEmpty()) "直接上屏 $buffer" else "手写找字", {
                if (buffer.isNotEmpty()) commitRaw() else showModePanel()
            })
            return
        }
        currentCandidates.forEach { text ->
            val chip = Ui.text(context, text, minOf(24f, Prefs.candidateSize.toFloat()), Ui.color(context, R.color.text_primary)).apply {
                setPadding(Ui.dp(context, 11f), Ui.dp(context, 6f), Ui.dp(context, 11f), Ui.dp(context, 6f))
                isClickable = true
                setOnClickListener { commitCandidate(text) }
                setOnLongClickListener {
                    showCandidateActions(text)
                    true
                }
            }
            candidateRow.addView(chip)
        }
        val count = Prefs.candidateCount
        if (currentCandidates.size >= count) expandButton.visibility = VISIBLE
    }

    private fun addHint(label: String, action: (() -> Unit)?) {
        val chip = Ui.text(context, label, 12f, Ui.color(context, R.color.text_secondary)).apply {
            setPadding(Ui.dp(context, 10f), Ui.dp(context, 5f), Ui.dp(context, 10f), Ui.dp(context, 5f))
            if (action != null) {
                isClickable = true
                setOnClickListener { action() }
                background = GradientDrawable().apply {
                    cornerRadius = Ui.dp(context, 99f).toFloat()
                    setColor(0x66FFFFFF)
                }
            }
        }
        candidateRow.addView(chip)
    }

    private fun modeLabel(): String = when (mode) {
        "t9" -> "九宫格"
        "qwerty" -> "全键盘"
        "handwrite" -> "手写"
        "stroke" -> "笔画"
        "wubi" -> "五笔"
        "doublepin" -> "双拼"
        "english" -> "EN"
        "number" -> "数字"
        "symbols" -> "符号"
        "emoji" -> "表情"
        else -> mode
    }

    private fun showAllCandidates() {
        if (buffer.isBlank()) return
        val list = DataEngine.candidates(mode, buffer, 30)
        if (list.isEmpty()) return
        showPanel("全部候选", list.map { it to null }) { index ->
            commitCandidate(list[index])
        }
    }

    private fun showCandidateActions(text: String) {
        val actions: List<Pair<String, () -> Unit>> = listOf(
            "固定为首选" to {
                DataEngine.fix(text)
                host?.toast("已固定：$text")
                updateCandidates()
            },
            "删除该候选" to {
                DataEngine.delete(text)
                host?.toast("已删除：$text")
                updateCandidates()
            },
            "复制" to {
                val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                cm.setPrimaryClip(android.content.ClipData.newPlainText("微输入法", text))
                host?.toast("已复制")
            }
        )
        showActionPanel("对“$text”的操作", actions)
    }

    private fun commitCandidate(text: String) {
        DataEngine.learn(text)
        host?.commitText(text)
        buffer = ""
        if (mode == "handwrite") handwriteCandidates = emptyList()
        updateCandidates()
        if (mode == "handwrite") rebuildRows()
    }

    private fun commitRaw() {
        if (buffer.isBlank()) return
        val text = buffer
        buffer = ""
        host?.commitText(text)
        updateCandidates()
    }

    // --- toolbar -----------------------------------------------------------
    private fun buildToolbar() {
        val scroll = HorizontalScrollView(context).apply {
            isHorizontalScrollBarEnabled = false
            clipToPadding = false
        }
        toolbarHost = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(Ui.dp(context, 3f), 0, Ui.dp(context, 3f), 0)
        }
        scroll.addView(toolbarHost)
        addView(scroll, LayoutParams(LayoutParams.MATCH_PARENT, Ui.dp(context, 38f)))
        rebuildToolbar()
    }

    private fun rebuildToolbar() {
        toolbarHost.removeAllViews()
        val disabled = Prefs.raw().getStringSet("toolbar_disabled", emptySet()) ?: emptySet()
        val order = Prefs.toolbarOrder.split(",").filter { it.isNotBlank() && it !in disabled }
        val meta = mapOf(
            "switch" to ("⌨" to "键盘"), "voice" to ("麦" to "语音"),
            "clipboard" to ("▣" to "剪贴"), "phrases" to ("语" to "常用语"),
            "emoji" to ("☺" to "表情"), "handwrite" to ("笔" to "手写"),
            "ai" to ("AI" to "问AI"), "translate" to ("译" to "翻译"),
            "polish" to ("Aa" to "整理"), "settings" to ("⚙" to "设置")
        )
        order.forEach { id ->
            val pair = meta[id] ?: return@forEach
            val item = LinearLayout(context).apply {
                orientation = VERTICAL
                gravity = Gravity.CENTER
                setPadding(Ui.dp(context, 5f), 0, Ui.dp(context, 5f), 0)
                isClickable = true
                setOnClickListener { onToolbar(id) }
                setOnLongClickListener { host?.toast(pair.second); true }
            }
            item.addView(Ui.text(context, pair.first, 15f, Ui.color(context, R.color.accent_dark), true))
            item.addView(Ui.text(context, pair.second, 8.5f, Ui.color(context, R.color.text_secondary)))
            toolbarHost.addView(item, LayoutParams(Ui.dp(context, 47f), LayoutParams.MATCH_PARENT))
        }
    }

    private fun onToolbar(id: String) {
        when (id) {
            "switch" -> showModePanel()
            "voice" -> host?.startVoice()
            "clipboard" -> showClipboardPanel()
            "phrases" -> showPhrasesPanel()
            "emoji" -> setMode("emoji")
            "handwrite" -> setMode("handwrite")
            "ai" -> host?.launchPage("ai_chat", buffer)
            "translate" -> host?.launchPage("translate", buffer)
            "polish" -> host?.launchPage("text_tools", buffer)
            "settings" -> host?.launchPage("home", "")
        }
    }

    // --- rows --------------------------------------------------------------
    fun setMode(newMode: String) {
        if (newMode !in modeNames.map { it.first }) return
        buffer = ""
        handwriteCandidates = emptyList()
        mode = newMode
        if (newMode !in listOf("english", "number", "symbols", "emoji")) lastChineseMode = newMode
        Prefs.keyboardMode = newMode
        hidePanel()
        hideVoicePanel()
        rebuildRows()
        updateCandidates()
        rememberHighlights()
        host?.toast(modeNames.firstOrNull { it.first == newMode }?.second ?: newMode)
    }

    private var highlightedMode: String? = null
    private fun rememberHighlights() {
        highlightedMode = mode
    }

    private fun rebuildRows() {
        contentArea.removeAllViews()
        val rows = LinearLayout(context).apply {
            orientation = VERTICAL
            setPadding(0, Ui.dp(context, 2f), 0, 0)
        }
        when (mode) {
            "t9" -> buildT9(rows)
            "qwerty", "wubi", "doublepin", "english" -> buildQwerty(rows)
            "handwrite" -> buildHandwrite(rows)
            "stroke" -> buildStroke(rows)
            "number" -> buildNumber(rows)
            "symbols" -> buildSymbols(rows)
            "emoji" -> buildEmoji(rows)
            else -> buildQwerty(rows)
        }
        contentArea.addView(rows, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            gravity = Gravity.BOTTOM
        })
    }

    private fun row(): LinearLayout = LinearLayout(context).apply {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER
    }

    private fun addRow(parent: LinearLayout, vararg keys: Pair<String, Float>, special: Set<String> = emptySet()) {
        val r = row()
        keys.forEach { (label, weight) ->
            val kv = makeKey(label, label in special, if (label.length > 1) 13f else 20f)
            r.addView(kv, LinearLayout.LayoutParams(0, keyHeight, weight).apply {
                setMargins(Ui.dp(context, 2f), Ui.dp(context, 2f), Ui.dp(context, 2f), Ui.dp(context, 2f))
            })
        }
        parent.addView(r)
    }

    private fun makeKey(label: String, special: Boolean, size: Float): KeyView {
        val kv = KeyView(context)
        kv.text = label
        kv.setTextSize(TypedValue.COMPLEX_UNIT_SP, size)
        if (special) kv.background = androidx.core.content.ContextCompat.getDrawable(context, R.drawable.bg_key_special)
        kv.setOnClickListener { pressFeedback() }
        return kv
    }

    private fun pressFeedback() {
        if (Prefs.keyVibrate) {
            val v = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            if (v != null && v.hasVibrator()) {
                if (Build.VERSION.SDK_INT >= 26) {
                    v.vibrate(VibrationEffect.createOneShot(18, intArrayOf(40, 80, 140)[Prefs.vibrateLevel.coerceIn(0, 2)]))
                } else {
                    @Suppress("DEPRECATION")
                    v.vibrate(18)
                }
            }
        }
        if (Prefs.keySound) {
            try {
                val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                am.playSoundEffect(AudioManager.FX_KEYPRESS_STANDARD, 0.55f)
            } catch (_: Exception) {
            }
        }
    }

    private fun textKey(label: String, onClick: (String) -> Unit): KeyView {
        val kv = makeKey(label, false, if (label.length > 1) 13f else 20f)
        kv.setOnClickListener {
            pressFeedback()
            onClick(label)
        }
        return kv
    }

    private fun actionKey(label: String, weight: Float = 1f, special: Boolean = true, action: () -> Unit): KeyView {
        val kv = makeKey(label, special, if (label.length > 1) 13f else 18f)
        kv.setOnClickListener {
            pressFeedback()
            action()
        }
        kv.layoutParams = LinearLayout.LayoutParams(0, keyHeight, weight).apply {
            setMargins(Ui.dp(context, 2f), Ui.dp(context, 2f), Ui.dp(context, 2f), Ui.dp(context, 2f))
        }
        return kv
    }

    private fun addToRow(r: LinearLayout, key: View, weight: Float) {
        key.layoutParams = LinearLayout.LayoutParams(0, keyHeight, weight).apply {
            setMargins(Ui.dp(context, 2f), Ui.dp(context, 2f), Ui.dp(context, 2f), Ui.dp(context, 2f))
        }
        r.addView(key)
    }

    private fun spaceKey(label: String = "空格", weight: Float = 3f): KeyView {
        val kv = makeKey(label, true, 13f)
        kv.layoutParams = LinearLayout.LayoutParams(0, keyHeight, weight).apply {
            setMargins(Ui.dp(context, 2f), Ui.dp(context, 2f), Ui.dp(context, 2f), Ui.dp(context, 2f))
        }
        kv.setOnClickListener {
            pressFeedback()
            pressSpace()
        }
        if (Prefs.voiceLongPress) {
            kv.onPressStart = {
                pressFeedback()
                host?.startVoice()
            }
            kv.onPressEnd = { host?.stopVoice() }
        }
        return kv
    }

    private fun pressSpace() {
        if (buffer.isNotEmpty()) {
            if (mode == "english") {
                val word = buffer
                buffer = ""
                host?.commitText(word + " ")
                updateCandidates()
            } else {
                val cand = currentCandidates.firstOrNull() ?: buffer
                commitCandidate(cand)
            }
            return
        }
        if (mode == "english") {
            if (Prefs.doubleSpacePeriod && System.currentTimeMillis() - lastSpaceAt < 360) {
                host?.backspace()
                host?.commitText(". ")
            } else {
                host?.space()
            }
            lastSpaceAt = System.currentTimeMillis()
        } else {
            if (Prefs.doubleSpacePeriod && System.currentTimeMillis() - lastSpaceAt < 360) {
                host?.backspace()
                host?.commitText("。")
            } else {
                host?.space()
            }
            lastSpaceAt = System.currentTimeMillis()
        }
    }

    private var lastSpaceAt = 0L

    private fun buildT9(rows: LinearLayout) {
        val digits = listOf(
            "1\n，。?" to "1", "2\nabc" to "2", "3\ndef" to "3",
            "4\nghi" to "4", "5\njkl" to "5", "6\nmno" to "6",
            "7\npqrs" to "7", "8\ntuv" to "8", "9\nwxyz" to "9"
        )
        digits.chunked(3).forEach { chunk ->
            val r = row()
            chunk.forEach { (label, digit) ->
                val kv = makeKey(label, false, 15f)
                kv.setOnClickListener {
                    pressFeedback()
                    if (digit == "1") host?.commitText("，") else append(digit)
                }
                addToRow(r, kv, 1f)
            }
            rows.addView(r)
        }
        val bottom = row()
        addToRow(bottom, actionKey("中/英", 1.1f) { toggleLanguage() }, 1.1f)
        addToRow(bottom, actionKey("符号", 1f) { setMode("symbols") }, 1f)
        addToRow(bottom, textKey("0") { append("0") }, 1f)
        addToRow(bottom, spaceKey("空格", 2.3f), 2.3f)
        addToRow(bottom, actionKey("⌫", 1f) { delete() }, 1f)
        addToRow(bottom, actionKey("换行", 1.2f) { enter() }, 1.2f)
        rows.addView(bottom)
    }

    private fun buildQwerty(rows: LinearLayout) {
        val chinese = mode != "english"
        val letters = if (mode == "wubi") "qwertyuiop/asdfghjkl/zxcvbnm"
        else "qwertyuiop/asdfghjkl/zxcvbnm"
        val lines = letters.split("/")
        lines.forEachIndexed { rowIndex, line ->
            val r = row()
            val leftPad = if (rowIndex == 1) 0.5f else 0f
            val rightPad = if (rowIndex == 1) 0.5f else 0f
            if (leftPad > 0) {
                val spacer = View(context)
                r.addView(spacer, LinearLayout.LayoutParams(0, 1, leftPad))
            }
            val split = Prefs.splitKeyboard && resources.configuration.screenWidthDp >= 700
            val mid = if (split) line.length / 2 else -1
            line.forEachIndexed { index, ch ->
                if (split && index == mid) {
                    val gap = View(context)
                    r.addView(gap, LinearLayout.LayoutParams(0, 1, 0.6f))
                }
                val label = if (!chinese || mode == "english") {
                    if (shift) ch.uppercase() else ch.toString()
                } else ch.toString()
                val kv = textKey(label) { c ->
                    append(c)
                    if (shift) {
                        shift = false
                        rebuildRows()
                    }
                }
                addToRow(r, kv, 1f)
            }
            if (rightPad > 0) {
                val spacer = View(context)
                r.addView(spacer, LinearLayout.LayoutParams(0, 1, rightPad))
            }
            if (rowIndex == 2) {
                if (mode == "english") {
                    addToRow(r, actionKey("⇧", 1.4f) {
                        shift = !shift
                        rebuildRows()
                    }, 1.4f)
                } else {
                    addToRow(r, actionKey("中/英", 1.4f) { toggleLanguage() }, 1.4f)
                }
            }
            // shift is placed before the last row letters; reorder by rebuilding row below
            if (rowIndex == 2) {
                val last = r.getChildAt(r.childCount - 1)
                r.removeView(last)
                val rest = ArrayList<View>()
                for (i in 0 until r.childCount) rest.add(r.getChildAt(i))
                r.removeAllViews()
                r.addView(last)
                rest.forEach { r.addView(it) }
            }
            if (rowIndex == 2) {
                addToRow(r, actionKey("⌫", 1.5f) { delete() }, 1.5f)
            }
            rows.addView(r)
        }
        val bottom = row()
        addToRow(bottom, actionKey(if (chinese) "中/英" else "123", 1.4f) {
            if (chinese) toggleLanguage() else setMode("number")
        }, 1.4f)
        addToRow(bottom, actionKey("符号", 1f) { setMode("symbols") }, 1f)
        addToRow(bottom, spaceKey("空格", 3.2f), 3.2f)
        addToRow(bottom, actionKey("换行", 1.4f) { enter() }, 1.4f)
        rows.addView(bottom)
    }

    private fun buildStroke(rows: LinearLayout) {
        val r = row()
        listOf("横" to "h", "竖" to "s", "撇" to "p", "捺" to "n", "折" to "z").forEach { (label, code) ->
            val kv = makeKey(label, false, 22f)
            kv.setOnClickListener {
                pressFeedback()
                append(code)
            }
            addToRow(r, kv, 1f)
        }
        rows.addView(r)
        val r2 = row()
        addToRow(r2, actionKey("拼音", 1.2f) { toggleLanguage() }, 1.2f)
        addToRow(r2, actionKey("符号", 1f) { setMode("symbols") }, 1f)
        addToRow(r2, spaceKey("空格", 2.5f), 2.5f)
        addToRow(r2, actionKey("⌫", 1f) { delete() }, 1f)
        addToRow(r2, actionKey("换行", 1.2f) { enter() }, 1.2f)
        rows.addView(r2)
        val hint = Ui.text(context, "笔画编码：h 横 · s 竖 · p 撇 · n 捺 · z 折", 10f, Ui.color(context, R.color.text_secondary)).apply {
            gravity = Gravity.CENTER
            setPadding(0, Ui.dp(context, 3f), 0, 0)
        }
        rows.addView(hint)
    }

    private fun buildHandwrite(rows: LinearLayout) {
        val frame = FrameLayout(context).apply {
            background = GradientDrawable().apply {
                cornerRadius = Ui.dp(context, 16f).toFloat()
                setColor(Color.WHITE)
                setStroke(1, Ui.color(context, R.color.border))
            }
        }
        val canvas = HandWriteView(context)
        canvas.onDirections = { dirs ->
            handwriteCandidates = DataEngine.handwritingCandidates(dirs, Prefs.candidateCount)
            buffer = ""
            updateCandidates()
        }
        frame.addView(canvas, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Ui.dp(context, 150f)))
        val hint = Ui.text(context, "在此手写（有限模板，候选不保证正确）", 11f, Ui.color(context, R.color.muted)).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            setPadding(0, 0, 0, Ui.dp(context, 6f))
        }
        frame.addView(hint, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Ui.dp(context, 150f)))
        rows.addView(frame, LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, Ui.dp(context, 150f)).apply {
            setMargins(Ui.dp(context, 3f), Ui.dp(context, 3f), Ui.dp(context, 3f), Ui.dp(context, 3f))
        })
        val bottom = row()
        addToRow(bottom, actionKey("清空", 1.3f) {
            canvas.clearInk()
            handwriteCandidates = emptyList()
            updateCandidates()
        }, 1.3f)
        addToRow(bottom, actionKey("⌫", 1f) { delete() }, 1f)
        addToRow(bottom, actionKey("拼音", 1.2f) { setMode("t9") }, 1.2f)
        addToRow(bottom, spaceKey("空格", 2f), 2f)
        addToRow(bottom, actionKey("换行", 1.2f) { enter() }, 1.2f)
        rows.addView(bottom)
    }

    private fun buildNumber(rows: LinearLayout) {
        val lines = listOf(
            listOf("1", "2", "3", "⌫"),
            listOf("4", "5", "6", "."),
            listOf("7", "8", "9", "-"),
            listOf("符号", "0", "空格", "换行")
        )
        lines.forEachIndexed { rowIndex, keys ->
            val r = row()
            keys.forEach { label ->
                val kv = makeKey(label, label.length > 1, if (label.length > 1) 13f else 20f)
                kv.setOnClickListener {
                    pressFeedback()
                    when (label) {
                        "⌫" -> host?.backspace()
                        "空格" -> host?.space()
                        "换行" -> enter()
                        "符号" -> setMode("symbols")
                        else -> host?.commitText(label)
                    }
                }
                addToRow(r, kv, 1f)
            }
            rows.addView(r)
        }
        val bottom = row()
        addToRow(bottom, actionKey("ABC", 1.4f) { setMode(lastChineseMode) }, 1.4f)
        addToRow(bottom, actionKey("表情", 1f) { setMode("emoji") }, 1f)
        addToRow(bottom, actionKey("+", 1f) { host?.commitText("+") }, 1f)
        addToRow(bottom, actionKey("×", 1f) { host?.commitText("×") }, 1f)
        addToRow(bottom, actionKey("÷", 1f) { host?.commitText("÷") }, 1f)
        addToRow(bottom, actionKey("=", 1f) { host?.commitText("=") }, 1f)
        rows.addView(bottom)
    }

    private fun buildSymbols(rows: LinearLayout) {
        val pages = listOf(
            listOf("，", "。", "？", "！", "、", "；", "：", "“", "”", "‘", "’", "（", "）", "【", "】", "《", "》", "…", "—", "～", "·", "￥"),
            listOf("$", "€", "£", "%", "‰", "@", "#", "&", "*", "+", "-", "=", "<", ">", "±", "×", "÷", "©", "®", "™", "§", "°"),
            listOf("(", ")", "[", "]", "{", "}", "/", "\\", "|", "_", "^", "~", "`", "′", "″", "¶", "•", "√", "∞", "≈", "≠", "≤", "≥")
        )
        val tabs = row()
        pages.indices.forEach { i ->
            val label = listOf("常用", "货币/符号", "括号/数学")[i]
            val tab = Ui.text(context, label, 12f, if (i == symbolPage) Ui.color(context, R.color.accent_dark) else Ui.color(context, R.color.text_secondary), i == symbolPage).apply {
                background = GradientDrawable().apply {
                    cornerRadius = Ui.dp(context, 99f).toFloat()
                    setColor(if (i == symbolPage) Ui.color(context, R.color.accent_soft) else Color.TRANSPARENT)
                }
                setPadding(Ui.dp(context, 12f), Ui.dp(context, 6f), Ui.dp(context, 12f), Ui.dp(context, 6f))
                setOnClickListener {
                    symbolPage = i
                    rebuildRows()
                }
            }
            tabs.addView(tab, LinearLayout.LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))
        }
        rows.addView(tabs)
        val grid = GridLayout(context).apply { columnCount = 8 }
        pages[symbolPage.coerceIn(0, 2)].forEach { sym ->
            val tv = Ui.text(context, sym, 20f, Ui.color(context, R.color.text_primary)).apply {
                gravity = Gravity.CENTER
                background = androidx.core.content.ContextCompat.getDrawable(context, R.drawable.bg_key)
                isClickable = true
                setOnClickListener {
                    pressFeedback()
                    host?.commitText(sym)
                }
            }
            grid.addView(tv, GridLayout.LayoutParams().apply {
                width = 0
                height = Ui.dp(context, 42f)
                columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f)
                setMargins(Ui.dp(context, 2f), Ui.dp(context, 2f), Ui.dp(context, 2f), Ui.dp(context, 2f))
            })
        }
        rows.addView(grid)
        val bottom = row()
        addToRow(bottom, actionKey("ABC", 1.4f) { setMode(lastChineseMode) }, 1.4f)
        addToRow(bottom, actionKey("123", 1f) { setMode("number") }, 1f)
        addToRow(bottom, spaceKey("空格", 2.5f), 2.5f)
        addToRow(bottom, actionKey("⌫", 1f) { delete() }, 1f)
        addToRow(bottom, actionKey("换行", 1.2f) { enter() }, 1.2f)
        rows.addView(bottom)
    }

    private val kaomoji = listOf(
        "(・ω・)", "(￣▽￣)", "ヾ(≧▽≦*)o", "( ´･ω･)", "(๑•̀ㅂ•́)و✧",
        "(＝^･ω･^＝)", "(*/ω＼*)", "ヽ(￣▽￣)ﾉ", "_(:з」∠)_", "orz",
        "◉‿◉", "(◍•ᴗ•◍)", "(๑˃ᴗ˂)ﻭ", "(ง •̀_•́)ง", "٩(◕‿◕)۶",
        "ʕ•ᴥ•ʔ", "(╯°□°）╯︵ ┻━┻", "(｡•́︿•̀｡)", "(๑•́ ₃ •̀๑)", "(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧"
    )

    private fun buildEmoji(rows: LinearLayout) {
        val tabs = HorizontalScrollView(context).apply { isHorizontalScrollBarEnabled = false }
        val tabRow = LinearLayout(context).apply { orientation = HORIZONTAL }
        val cats = DataEngine.emojiCategories.map { it.first } + listOf("颜文字")
        cats.forEachIndexed { i, name ->
            val t = Ui.text(context, name, 12f, if (i == emojiCategory) Ui.color(context, R.color.accent_dark) else Ui.color(context, R.color.text_secondary), i == emojiCategory).apply {
                background = GradientDrawable().apply {
                    cornerRadius = Ui.dp(context, 99f).toFloat()
                    setColor(if (i == emojiCategory) Ui.color(context, R.color.accent_soft) else Color.TRANSPARENT)
                }
                setPadding(Ui.dp(context, 10f), Ui.dp(context, 5f), Ui.dp(context, 10f), Ui.dp(context, 5f))
                setOnClickListener {
                    emojiCategory = i
                    rebuildRows()
                }
            }
            tabRow.addView(t)
        }
        tabs.addView(tabRow)
        rows.addView(tabs, LayoutParams(LayoutParams.MATCH_PARENT, Ui.dp(context, 34f)))

        val scroll = ScrollView(context)
        val grid = GridLayout(context).apply { columnCount = if (resources.configuration.screenWidthDp >= 600) 12 else 8 }
        val items = if (emojiCategory >= DataEngine.emojiCategories.size) kaomoji
        else DataEngine.emojiCategories[emojiCategory].second
        items.forEach { emoji ->
            val tv = Ui.text(context, emoji, if (emoji.length > 3) 12f else 23f, Ui.color(context, R.color.text_primary)).apply {
                gravity = Gravity.CENTER
                isClickable = true
                setOnClickListener { host?.commitText(emoji) }
            }
            grid.addView(tv, GridLayout.LayoutParams().apply {
                width = 0
                height = Ui.dp(context, if (emoji.length > 3) 38f else 42f)
                columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f)
            })
        }
        scroll.addView(grid)
        rows.addView(scroll, LayoutParams(LayoutParams.MATCH_PARENT, Ui.dp(context, 176f)))
        val bottom = row()
        addToRow(bottom, actionKey("ABC", 1.4f) { setMode(lastChineseMode) }, 1.4f)
        addToRow(bottom, actionKey("123", 1f) { setMode("number") }, 1f)
        addToRow(bottom, spaceKey("空格", 2.5f), 2.5f)
        addToRow(bottom, actionKey("⌫", 1f) { delete() }, 1f)
        addToRow(bottom, actionKey("换行", 1.2f) { enter() }, 1.2f)
        rows.addView(bottom)
    }

    // --- actions -----------------------------------------------------------
    private fun append(char: String) {
        var c = char
        if (mode == "english") {
            if (shift || (Prefs.smartCapitalize && buffer.isEmpty())) {
                c = c.uppercase()
            }
            shift = false
        }
        buffer += if (mode == "english") c else c.lowercase()
        updateCandidates()
    }

    private fun delete() {
        if (buffer.isNotEmpty()) {
            buffer = buffer.dropLast(1)
            updateCandidates()
        } else {
            host?.backspace()
        }
    }

    private fun enter() {
        if (buffer.isNotEmpty()) {
            val cand = currentCandidates.firstOrNull() ?: buffer
            host?.commitText(cand)
            buffer = ""
            updateCandidates()
        }
        host?.enter()
    }

    private fun toggleLanguage() {
        if (mode == "english") setMode(lastChineseMode)
        else setMode("english")
    }

    private fun showModePanel() {
        showPanel("选择键盘", modeNames.map { it.second to if (it.first == mode) "当前" else null }) { index ->
            setMode(modeNames[index].first)
        }
    }

    private fun showClipboardPanel() {
        val items = ClipboardStore.items()
        val list = if (items.isEmpty()) {
            listOf("（暂无剪贴板历史）" to null)
        } else items.take(20).map { it.text.replace("\n", " ").take(80) to null }
        showPanel("剪贴板", list) { index ->
            if (items.isNotEmpty() && index < items.size) {
                host?.commitText(items[index].text)
                ClipboardStore.add(items[index].text)
                hidePanel()
            }
        }
    }

    private fun showPhrasesPanel() {
        val phrases = PhraseStore.all()
        showPanel("常用语", phrases.map { it.text to it.code }) { index ->
            host?.commitText(phrases[index].text)
            DataEngine.learn(phrases[index].text)
            hidePanel()
        }
    }

    // --- overlays ----------------------------------------------------------
    private var panel: View? = null

    private fun showPanel(title: String, items: List<Pair<String, String?>>, onPick: (Int) -> Unit) {
        hidePanel()
        val overlay = FrameLayout(context).apply {
            setBackgroundColor(0x22000000)
            isClickable = true
            setOnClickListener { hidePanel() }
        }
        val sheet = LinearLayout(context).apply {
            orientation = VERTICAL
            background = GradientDrawable().apply {
                cornerRadius = Ui.dp(context, 20f).toFloat()
                setColor(Color.WHITE)
            }
            setPadding(Ui.dp(context, 12f), Ui.dp(context, 10f), Ui.dp(context, 12f), Ui.dp(context, 8f))
            isClickable = true
        }
        val head = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        head.addView(Ui.text(context, title, 14f, Ui.color(context, R.color.text_primary), true), LinearLayout.LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))
        head.addView(Ui.text(context, "关闭", 12f, Ui.color(context, R.color.accent_dark), true).apply {
            setPadding(Ui.dp(context, 10f), Ui.dp(context, 4f), Ui.dp(context, 10f), Ui.dp(context, 4f))
            setOnClickListener { hidePanel() }
        })
        sheet.addView(head)
        val scroll = ScrollView(context)
        val list = LinearLayout(context).apply { orientation = VERTICAL }
        items.forEachIndexed { index, pair ->
            val row = LinearLayout(context).apply {
                orientation = HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                minimumHeight = Ui.dp(context, 44f)
                setPadding(Ui.dp(context, 6f), 0, Ui.dp(context, 6f), 0)
                isClickable = true
                setOnClickListener {
                    onPick(index)
                }
            }
            row.addView(Ui.text(context, pair.first, 14f).apply {
                maxLines = 1
                ellipsize = TextUtils.TruncateAt.END
            }, LinearLayout.LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))
            val hint = pair.second
            if (hint != null) row.addView(Ui.text(context, hint, 11f, Ui.color(context, R.color.text_secondary)))
            list.addView(row)
            if (index < items.size - 1) list.addView(Ui.divider(context))
        }
        scroll.addView(list)
        sheet.addView(scroll, LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, 0, 1f))
        overlay.addView(sheet, FrameLayout.LayoutParams(LayoutParams.MATCH_PARENT, Ui.dp(context, 250f)).apply {
            gravity = Gravity.BOTTOM
            setMargins(Ui.dp(context, 8f), 0, Ui.dp(context, 8f), Ui.dp(context, 4f))
        })
        contentArea.addView(overlay, FrameLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        panel = overlay
    }

    private fun showActionPanel(title: String, actions: List<Pair<String, () -> Unit>>) {
        showPanel(title, actions.map { it.first to null }) { index ->
            hidePanel()
            actions[index].second.invoke()
        }
    }

    private fun hidePanel() {
        panel?.let { contentArea.removeView(it) }
        panel = null
    }
}
