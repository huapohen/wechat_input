package com.huapohen.wechatinput

import android.Manifest
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.media.AudioManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings
import android.speech.RecognizerIntent
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.huapohen.wechatinput.data.DataEngine
import com.huapohen.wechatinput.net.ApiClient
import com.huapohen.wechatinput.net.Background
import com.huapohen.wechatinput.store.ChatStore
import com.huapohen.wechatinput.store.ClipboardStore
import com.huapohen.wechatinput.store.PhraseStore
import com.huapohen.wechatinput.store.SessionStore
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class SettingsActivity : BasePageActivity() {
    private var pageId: String = "display"
    private var syncStatus: TextView? = null
    private var lastRetry: (() -> Unit)? = null
    private val exportLauncher = registerForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri ->
        uri?.let { writeMigration(it) }
    }
    private val importLauncher = registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        uri?.let { readMigration(it) }
    }
    private val speechLauncher = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        val text = result.data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()
        if (result.resultCode == RESULT_OK && !text.isNullOrBlank()) {
            AlertDialog.Builder(this)
                .setTitle("识别结果")
                .setMessage(text)
                .setPositiveButton("复制") { _, _ -> copy(text) }
                .setNegativeButton("关闭", null)
                .show()
        } else {
            toast("没有拿到识别结果；请检查麦克风权限与系统语音服务")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pageId = intent.getStringExtra("page_id") ?: "display"
        val page = Pages.byId(pageId)
        setPageTitle(page.title, page.subtitle)
        render()
    }

    override fun currentPageId(): String = pageId

    private fun render() {
        content.removeAllViews()
        when (pageId) {
            "display" -> pageDisplay()
            "keystroke" -> pageKeystroke()
            "toolbar" -> pageToolbar()
            "auxiliary" -> pageAuxiliary()
            "fuzzy" -> pageFuzzy()
            "voice" -> pageVoice()
            "voice_language" -> pageVoiceLanguage()
            "voice_punctuation" -> pageVoicePunctuation()
            "plus" -> pagePlus()
            "clipboard" -> pageClipboard()
            "sync" -> pageSync()
            "migration" -> pageMigration()
            "standalone" -> pageStandalone()
            "privacy" -> pagePrivacy()
            "desktop" -> pageDesktop()
            "keyboard_manage" -> pageKeyboardManage()
            else -> {
                addInfo("页面未实现", "这是一个未注册的页面：$pageId")
            }
        }
    }

    // --- shared builders ---------------------------------------------------
    private fun addGroup(vararg rows: View): LinearLayout {
        val group = Ui.group(this)
        rows.forEachIndexed { i, v ->
            group.addView(v)
            if (i < rows.size - 1) group.addView(Ui.divider(this))
        }
        content.addView(group)
        return group
    }

    private fun toggle(title: String, subtitle: String?, get: () -> Boolean, set: (Boolean) -> Unit) {
        val row = Ui.toggleRow(this, title, subtitle, get()) { v -> set(v) }
        pendingRows.add(row)
    }

    private val pendingRows = ArrayList<View>()
    private fun flushGroup() {
        if (pendingRows.isEmpty()) return
        val group = Ui.group(this)
        pendingRows.forEachIndexed { i, v ->
            group.addView(v)
            if (i < pendingRows.size - 1) group.addView(Ui.divider(this))
        }
        content.addView(group)
        pendingRows.clear()
    }

    private fun navRow(title: String, subtitle: String?, target: String) {
        pendingRows.add(Ui.row(this, title, subtitle, null, true) {
            startActivity(Pages.intent(this, target))
        })
    }

    private fun addInfo(title: String, body: String, accent: Boolean = false) {
        val card = Ui.card(this, 16)
        if (accent) {
            card.setCardBackgroundColor(Ui.color(this, R.color.accent_soft))
            card.strokeColor = 0xFFC7EBDD.toInt()
        }
        card.addView(Ui.text(this, title, 15f, Ui.color(this, R.color.text_primary), true))
        card.addView(Ui.text(this, body, 12.5f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(0, Ui.dp(this@SettingsActivity, 6f), 0, 0)
            setLineSpacing(Ui.dp(this@SettingsActivity, 4f).toFloat(), 1f)
        })
        content.addView(card)
    }

    override fun buttonRow(vararg buttons: View) {
        val row = Ui.horizontal(this)
        buttons.forEachIndexed { i, b ->
            row.addView(b, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                if (i < buttons.size - 1) marginEnd = Ui.dp(this@SettingsActivity, 8f)
            })
        }
        content.addView(row, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            bottomMargin = Ui.dp(this@SettingsActivity, 10f)
        })
    }

    private fun showApiDialog() {
        val input = Ui.editText(this, "http://10.0.2.2:8787").apply {
            setText(Prefs.baseUrl)
            setSingleLine(true)
            inputType = android.text.InputType.TYPE_TEXT_VARIATION_URI
        }
        val wrap = LinearLayout(this).apply {
            setPadding(Ui.dp(this@SettingsActivity, 20f), Ui.dp(this@SettingsActivity, 4f), Ui.dp(this@SettingsActivity, 20f), 0)
        }
        wrap.addView(input, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Ui.dp(this, 52f)))
        AlertDialog.Builder(this)
            .setTitle("API 地址")
            .setMessage("客户端只保存地址，不包含模型密钥。保存后可返回页面测试。")
            .setView(wrap)
            .setPositiveButton("保存") { _, _ ->
                var url = input.text.toString().trim().trimEnd('/')
                if (url.isBlank()) {
                    toast("地址不能为空")
                    return@setPositiveButton
                }
                if (!url.startsWith("http://") && !url.startsWith("https://")) url = "http://$url"
                Prefs.baseUrl = url
                toast("已保存：$url")
                render()
            }
            .setNegativeButton("取消", null)
            .show()
    }

    private fun toast(msg: String) = Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()

    private fun copy(text: String) {
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.setPrimaryClip(ClipData.newPlainText("微输入法", text))
        ClipboardStore.add(text)
        toast("已复制")
    }

    // --- pages -------------------------------------------------------------
    private fun pageDisplay() {
        addInfo(
            "键盘外观",
            "当前键盘高度 ${Prefs.keyboardHeightFactor}% · 候选字号 ${Prefs.candidateSize}sp。分屏键盘在平板/横屏下左右展开，输入区居中。"
        )
        toggle("分屏键盘", "平板上左右分开，双手输入", { Prefs.splitKeyboard }, { Prefs.splitKeyboard = it })
        toggle("显示按键边框", "白色按键与浅绿键盘底", { Prefs.showKeyBorders }, { Prefs.showKeyBorders = it })
        toggle("拼音直接预输入", "输入字母先上屏，再选候选", { Prefs.directPreInput }, { Prefs.directPreInput = it })
        toggle("回车键发送", "聊天输入框中回车发送消息", { Prefs.enterToSend }, { Prefs.enterToSend = it })
        flushGroup()

        val sizeCard = Ui.card(this, 8)
        sizeCard.addView(Ui.sliderRow(this, "键盘高度", { "$it%" }, Prefs.keyboardHeightFactor, 80, 150, 5) {
            Prefs.keyboardHeightFactor = it
        })
        sizeCard.addView(Ui.divider(this))
        sizeCard.addView(Ui.sliderRow(this, "候选字号", { "${it}sp" }, Prefs.candidateSize, 16, 30) {
            Prefs.candidateSize = it
        })
        sizeCard.addView(Ui.divider(this))
        sizeCard.addView(Ui.choiceRow(
            this, "配色", arrayOf("薄荷浅色", "纯白", "跟随系统"), Prefs.displayTheme
        ) { Prefs.displayTheme = it })
        content.addView(sizeCard)

        content.addView(Ui.sectionTitle(this, "服务"))
        val apiRow = Ui.row(this, "API 地址", "AI / 语音后端 / 传送 / 同步", Prefs.baseUrl, true) {
            showApiDialog()
        }
        pendingRows.add(apiRow)
        pendingRows.add(Ui.row(this, "恢复默认地址", "http://10.0.2.2:8787（Android 模拟器）", null, false) {
            Prefs.baseUrl = "http://10.0.2.2:8787"
            toast("已恢复默认地址")
            render()
        })
        flushGroup()

        buttonRow(
            Ui.button(this, "预览键盘", true) { startActivity(Pages.intent(this, "keyboard")) },
            Ui.button(this, "键盘管理", false) { startActivity(Pages.intent(this, "keyboard_manage")) }
        )
    }

    private fun pageKeystroke() {
        addInfo("按键反馈", "声音与振动只作用于微输入法键盘，不会影响其他输入法。")
        toggle("按键声音", "按下时播放短促提示音", { Prefs.keySound }, { Prefs.keySound = it })
        toggle("按键振动", "轻触反馈，强度可调", { Prefs.keyVibrate }, { Prefs.keyVibrate = it })
        toggle("按键气泡", "长按字母时显示放大的气泡", { Prefs.keyBubble }, { Prefs.keyBubble = it })
        flushGroup()
        pendingRows.add(Ui.choiceRow(this, "振动强度", arrayOf("轻", "中", "强"), Prefs.vibrateLevel) {
            Prefs.vibrateLevel = it
        })
        flushGroup()
        buttonRow(Ui.button(this, "测试声音与振动", true) { testFeedback() })
    }

    private fun testFeedback() {
        if (Prefs.keySound) {
            try {
                val tone = ToneGenerator(AudioManager.STREAM_SYSTEM, 40)
                tone.startTone(ToneGenerator.TONE_PROP_BEEP, 120)
                android.os.Handler(mainLooper).postDelayed({ tone.release() }, 220)
            } catch (_: Exception) {
            }
        }
        if (Prefs.keyVibrate) {
            val v = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            val amp = intArrayOf(40, 80, 140)[Prefs.vibrateLevel.coerceIn(0, 2)]
            if (Build.VERSION.SDK_INT >= 26) {
                v.vibrate(VibrationEffect.createOneShot(28, amp))
            }
        }
        toast("已测试：声音 ${if (Prefs.keySound) "开" else "关"} · 振动 ${if (Prefs.keyVibrate) "开" else "关"}")
    }

    private val toolbarItems = listOf(
        Triple("switch", "键盘切换", "⌨"), Triple("voice", "语音", "麦"),
        Triple("clipboard", "剪贴板", "▣"), Triple("phrases", "常用语", "语"),
        Triple("emoji", "表情", "☺"), Triple("handwrite", "手写找字", "笔"),
        Triple("ai", "问 AI", "AI"), Triple("translate", "翻译", "译"),
        Triple("polish", "文字整理", "Aa"), Triple("settings", "设置", "⚙")
    )

    private fun pageToolbar() {
        addInfo("定制工具栏", "键盘顶部工具按此顺序展示。关闭的项目会从工具栏隐藏，可随时重新开启。")
        val order = Prefs.toolbarOrder.split(",").filter { it.isNotBlank() }.toMutableList()
        toolbarItems.forEach { (id, _, _) -> if (id !in order) order.add(id) }
        val disabled = Prefs.raw().getStringSet("toolbar_disabled", emptySet())?.toMutableSet() ?: mutableSetOf()
        order.forEachIndexed { index, id ->
            val meta = toolbarItems.firstOrNull { it.first == id } ?: return@forEachIndexed
            val row = Ui.horizontal(this).apply {
                minimumHeight = Ui.dp(this@SettingsActivity, 56f)
                setPadding(Ui.dp(this@SettingsActivity, 14f), Ui.dp(this@SettingsActivity, 8f), Ui.dp(this@SettingsActivity, 8f), Ui.dp(this@SettingsActivity, 8f))
            }
            row.addView(Ui.text(this, meta.third, 15f, Ui.color(this, R.color.accent_dark), true).apply {
                gravity = Gravity.CENTER
                background = Ui.rounded(Ui.color(this@SettingsActivity, R.color.accent_soft), 99f)
            }, LinearLayout.LayoutParams(Ui.dp(this, 32f), Ui.dp(this, 32f)))
            row.addView(Ui.text(this, meta.second, 15f).apply {
                setPadding(Ui.dp(this@SettingsActivity, 10f), 0, 0, 0)
            }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            val sw = com.google.android.material.materialswitch.MaterialSwitch(this).apply {
                isChecked = id !in disabled
                setOnCheckedChangeListener { _, v ->
                    if (v) disabled.remove(id) else disabled.add(id)
                    Prefs.raw().edit().putStringSet("toolbar_disabled", disabled).apply()
                }
            }
            row.addView(sw, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
            row.addView(smallButton("↑") {
                if (index > 0) {
                    java.util.Collections.swap(order, index, index - 1)
                    Prefs.toolbarOrder = order.joinToString(",")
                    render()
                }
            })
            row.addView(smallButton("↓") {
                if (index < order.size - 1) {
                    java.util.Collections.swap(order, index, index + 1)
                    Prefs.toolbarOrder = order.joinToString(",")
                    render()
                }
            })
            pendingRows.add(row)
        }
        flushGroup()
        buttonRow(
            Ui.button(this, "恢复默认顺序", false) {
                Prefs.toolbarOrder = "switch,voice,clipboard,phrases,emoji,handwrite,ai,translate,polish,settings"
                Prefs.raw().edit().remove("toolbar_disabled").apply()
                render()
            },
            Ui.button(this, "预览工具栏", true) { startActivity(Pages.intent(this, "keyboard")) }
        )
    }

    private fun smallButton(label: String, action: () -> Unit): TextView =
        Ui.text(this, label, 15f, Ui.color(this, R.color.text_secondary), true).apply {
            gravity = Gravity.CENTER
            background = Ui.rounded(Ui.color(this, R.color.surface_alt), 10f)
            isClickable = true
            setOnClickListener { action() }
            layoutParams = LinearLayout.LayoutParams(Ui.dp(this@SettingsActivity, 32f), Ui.dp(this@SettingsActivity, 32f)).apply {
                marginStart = Ui.dp(this@SettingsActivity, 4f)
            }
        }

    private fun pageAuxiliary() {
        addInfo("辅助输入", "这些选项影响中文候选、标点与空格行为。输入法会立即读取最新设置。")
        toggle("中文/数字自动空格", "中英文混输时自动补空格", { Prefs.autoSpace }, { Prefs.autoSpace = it })
        toggle("双击空格输入句号", "快速结束一句话", { Prefs.doubleSpacePeriod }, { Prefs.doubleSpacePeriod = it })
        toggle("英文首字母大写", "句首自动大写", { Prefs.smartCapitalize }, { Prefs.smartCapitalize = it })
        toggle("自动标点", "候选上屏时为中文补全标点", { Prefs.autoPunctuation }, { Prefs.autoPunctuation = it })
        toggle("剪贴板建议", "在候选栏提示最近复制的内容", { Prefs.clipboardSuggestions }, { Prefs.clipboardSuggestions = it })
        toggle("回车发送", "聊天场景回车直接发送", { Prefs.enterToSend }, { Prefs.enterToSend = it })
        flushGroup()
        val slider = Ui.card(this, 8)
        slider.addView(Ui.sliderRow(this, "候选数量", { "$it 个" }, Prefs.candidateCount, 5, 15) {
            Prefs.candidateCount = it
        })
        content.addView(slider)
        navRow("模糊拼音", "平翘舌、前后鼻音", "fuzzy")
        flushGroup()
    }

    private fun pageFuzzy() {
        addInfo("模糊拼音", "开启后，不确定的声母/韵母也能匹配候选。精确匹配仍排在模糊匹配之前。")
        toggle("启用模糊拼音", "总开关", { Prefs.fuzzyEnabled }, {
            Prefs.fuzzyEnabled = it
            render()
        })
        flushGroup()
        val group = Ui.group(this)
        DataEngine.fuzzyOptions.forEachIndexed { i, opt ->
            val checked = opt.id in Prefs.fuzzyPairs
            group.addView(Ui.toggleRow(this, opt.label, null, checked) { v ->
                val set = Prefs.fuzzyPairs.toMutableSet()
                if (v) set.add(opt.id) else set.remove(opt.id)
                Prefs.fuzzyPairs = set
            })
            if (i < DataEngine.fuzzyOptions.size - 1) group.addView(Ui.divider(this))
        }
        content.addView(group)
        buttonRow(
            Ui.button(this, "全部开启", true) { Prefs.fuzzyPairs = DataEngine.fuzzyOptions.map { it.id }.toSet(); render() },
            Ui.button(this, "全部关闭", false) { Prefs.fuzzyPairs = emptySet(); render() }
        )
    }

    private fun pageVoice() {
        addInfo("语音转文字", "使用 Android 系统语音识别。语音不会上传到本项目后端；录音笔的摘要才会调用 AI 接口。")
        toggle("长按空格说话", "松开后按设置提交", { Prefs.voiceLongPress }, { Prefs.voiceLongPress = it })
        toggle("松手即发送", "关闭时识别结果留在输入框", { Prefs.voiceReleaseSend }, { Prefs.voiceReleaseSend = it })
        toggle("智能整理语音", "使用文字整理接口润色识别文本", { Prefs.voiceSmartPolish }, { Prefs.voiceSmartPolish = it })
        toggle("离线语音", "仅使用设备端能力", { Prefs.voiceOffline }, { Prefs.voiceOffline = it })
        toggle("自动标点", "为识别结果补充标点", { Prefs.voicePunctuation }, { Prefs.voicePunctuation = it })
        flushGroup()
        navRow("识别语言", Prefs.voiceLanguageLabel, "voice_language")
        navRow("标点设置", "自动标点与断句样式", "voice_punctuation")
        flushGroup()
        buttonRow(
            Ui.button(this, "测试语音识别", true) { testSpeech() },
            Ui.button(this, "打开录音笔", false) { startActivity(Pages.intent(this, "recorder")) }
        )
    }

    private fun testSpeech() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), 51)
            return
        }
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Prefs.voiceLanguage)
            putExtra(RecognizerIntent.EXTRA_PROMPT, "请说话，微输入法将使用系统识别")
        }
        try {
            speechLauncher.launch(intent)
        } catch (e: Exception) {
            toast("此设备没有可用的语音识别服务")
        }
    }

    private fun pageVoiceLanguage() {
        addInfo("识别语言", "当前：${Prefs.voiceLanguageLabel} (${Prefs.voiceLanguage})。系统识别服务是否支持取决于设备。")
        val languages = listOf(
            "普通话" to "zh-CN", "粤语" to "zh-HK", "English" to "en-US",
            "日本語" to "ja-JP", "한국어" to "ko-KR"
        )
        val group = Ui.group(this)
        languages.forEachIndexed { i, pair ->
            val active = Prefs.voiceLanguage == pair.second
            group.addView(Ui.row(this, pair.first, pair.second, if (active) "✓ 当前" else null, false) {
                Prefs.voiceLanguage = pair.second
                Prefs.voiceLanguageLabel = pair.first
                render()
            })
            if (i < languages.size - 1) group.addView(Ui.divider(this))
        }
        content.addView(group)
        buttonRow(Ui.button(this, "测试 ${Prefs.voiceLanguageLabel}", true) { testSpeech() })
    }

    private fun pageVoicePunctuation() {
        addInfo("标点设置", "识别结果会在列表末尾补上标点。样式仅影响本机展示与上屏。")
        toggle("自动添加标点", "句号、逗号与问号", { Prefs.voicePunctuation }, { Prefs.voicePunctuation = it })
        flushGroup()
        pendingRows.add(Ui.choiceRow(
            this, "断句样式", arrayOf("智能标点", "空格分隔", "不添加"), Prefs.voicePunctuationStyle
        ) { Prefs.voicePunctuationStyle = it })
        flushGroup()
        addInfo("示例", "开启智能标点是：今天天气不错，我们出去走走。\n空格分隔是：今天天气不错 我们出去走走", true)
    }

    private fun pagePlus() {
        addInfo("拼写 Plus", "智能能力总开关。关闭后，键盘与首页入口会提示到本页开启；不会伪造任何 AI 输出。")
        toggle("启用拼写 Plus", "总开关", { Prefs.plusEnabled }, {
            Prefs.plusEnabled = it
            render()
        })
        flushGroup()
        val enabled = Prefs.plusEnabled
        val group = Ui.group(this)
        val items = listOf(
            Triple("问 AI", { Prefs.plusAskAi }, { v: Boolean -> Prefs.plusAskAi = v }),
            Triple("智能拼写", { Prefs.plusSmartSpelling }, { v: Boolean -> Prefs.plusSmartSpelling = v }),
            Triple("拼写纠错", { Prefs.plusSpellingCorrect }, { v: Boolean -> Prefs.plusSpellingCorrect = v }),
            Triple("表情推荐", { Prefs.plusSticker }, { v: Boolean -> Prefs.plusSticker = v }),
            Triple("小表情", { Prefs.plusSmallEmoji }, { v: Boolean -> Prefs.plusSmallEmoji = v }),
            Triple("颜文字", { Prefs.plusKaomoji }, { v: Boolean -> Prefs.plusKaomoji = v }),
            Triple("改写推荐", { Prefs.plusRewrite }, { v: Boolean -> Prefs.plusRewrite = v }),
            Triple("文字整理", { Prefs.plusPolish }, { v: Boolean -> Prefs.plusPolish = v }),
            Triple("排版成图", { Prefs.plusPoster }, { v: Boolean -> Prefs.plusPoster = v }),
            Triple("快速发送", { Prefs.plusQuickSend }, { v: Boolean -> Prefs.plusQuickSend = v })
        )
        items.forEachIndexed { i, item ->
            group.addView(Ui.toggleRow(this, item.first, if (enabled) null else "总开关关闭时不可用", enabled && item.second()) { v -> item.third(v) })
            if (i < items.size - 1) group.addView(Ui.divider(this))
        }
        content.addView(group)
        buttonRow(
            Ui.button(this, "问 AI", true) { startActivity(Pages.intent(this, "ai_chat")) },
            Ui.button(this, "文字工具", false) { startActivity(Pages.intent(this, "text_tools")) }
        )
    }

    private fun pageClipboard() {
        addInfo("剪贴板", "只保存在本机；不上传，除非你在“跨设备粘贴同步”里主动推送。Android 10+ 限制后台读取剪贴板，本应用只在前台读取。")
        toggle("保存剪贴板历史", "用于键盘工具栏与常用语", { Prefs.clipboardEnabled }, { Prefs.clipboardEnabled = it; render() })
        toggle("通知栏剪贴板入口", "在支持的设备上显示", { Prefs.statusBarClipboard }, { Prefs.statusBarClipboard = it })
        flushGroup()
        buttonRow(
            Ui.button(this, "读取当前剪贴板", true) {
                val text = ClipboardStore.current(this)
                if (text.isBlank()) toast("当前剪贴板为空")
                else {
                    ClipboardStore.add(text)
                    render()
                    toast("已加入历史")
                }
            },
            Ui.button(this, "清空历史", false) {
                AlertDialog.Builder(this).setTitle("清空剪贴板历史？").setMessage("此操作不可撤销。")
                    .setPositiveButton("清空") { _, _ -> ClipboardStore.clear(); render() }
                    .setNegativeButton("取消", null).show()
            }
        )
        val items = ClipboardStore.items()
        if (items.isEmpty()) {
            addInfo("暂无记录", "在任意应用复制文字后，回到这里点“读取当前剪贴板”。", true)
        } else {
            content.addView(Ui.sectionTitle(this, "历史记录", "${items.size} 条"))
            val group = Ui.group(this)
            items.take(15).forEachIndexed { i, item ->
                val row = Ui.horizontal(this).apply {
                    setPadding(Ui.dp(this@SettingsActivity, 14f), Ui.dp(this@SettingsActivity, 10f), Ui.dp(this@SettingsActivity, 8f), Ui.dp(this@SettingsActivity, 10f))
                    minimumHeight = Ui.dp(this@SettingsActivity, 54f)
                }
                val col = Ui.vertical(this)
                col.addView(Ui.text(this, item.text.replace("\n", " "), 14f).apply {
                    maxLines = 2
                    ellipsize = android.text.TextUtils.TruncateAt.END
                })
                col.addView(Ui.text(
                    this@SettingsActivity,
                    SimpleDateFormat("MM-dd HH:mm", Locale.CHINA).format(Date(item.time)) + if (item.pinned) " · 已置顶" else "",
                    11f, Ui.color(this@SettingsActivity, R.color.text_secondary)
                ).apply { setPadding(0, Ui.dp(this@SettingsActivity, 2f), 0, 0) })
                row.addView(col, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
                row.addView(smallButton(if (item.pinned) "取消" else "钉") {
                    ClipboardStore.togglePin(item); render()
                })
                row.addView(smallButton("删") { ClipboardStore.remove(item); render() })
                row.isClickable = true
                row.setOnClickListener {
                    copy(item.text)
                    toast("已复制到剪贴板")
                }
                group.addView(row)
                if (i < minOf(items.size, 15) - 1) group.addView(Ui.divider(this))
            }
            content.addView(group)
        }
    }

    private fun pageSync() {
        val token = Prefs.syncToken
        addInfo(
            if (token.isBlank()) "尚未配对" else "已配对",
            if (token.isBlank())
                "输入同一个 6 位数字配对码即可连接另一台设备。配对码在设备间只用于找到彼此，不会上传剪贴板内容。"
            else
                "配对码 ${Prefs.syncCode} · token ${token.take(6)}… · 后端 ${Prefs.baseUrl}",
            token.isNotBlank()
        )
        syncStatus = Ui.text(this, "离线状态下会显示明确错误，操作可重试。", 12f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(Ui.dp(this@SettingsActivity, 4f), 0, Ui.dp(this@SettingsActivity, 4f), Ui.dp(this@SettingsActivity, 8f))
        }
        content.addView(syncStatus)

        val pairCard = Ui.card(this, 16)
        val codeInput = Ui.editText(this, "6 位配对码").apply {
            inputType = android.text.InputType.TYPE_CLASS_NUMBER
            filters = arrayOf(android.text.InputFilter.LengthFilter(6))
            setText(Prefs.syncCode)
        }
        pairCard.addView(codeInput, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Ui.dp(this, 48f)))
        val nameInput = Ui.editText(this, "设备名称").apply {
            setText(Prefs.displayName)
        }
        pairCard.addView(nameInput, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Ui.dp(this, 48f)).apply {
            topMargin = Ui.dp(this@SettingsActivity, 8f)
        })
        val pairRow = Ui.horizontal(this).apply { setPadding(0, Ui.dp(this@SettingsActivity, 8f), 0, 0) }
        pairRow.addView(Ui.button(this, "配对 / 加入", true) {
            val code = codeInput.text.toString().filter { it.isDigit() }
            if (code.length != 6) {
                showSyncError("请输入 6 位数字配对码")
                return@button
            }
            Prefs.displayName = nameInput.text.toString().ifBlank { "我的设备" }
            pair(code)
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { marginEnd = Ui.dp(this@SettingsActivity, 8f) })
        pairRow.addView(Ui.button(this, "生成新码", false) {
            val code = (100000 + (Math.random() * 900000).toInt()).toString()
            codeInput.setText(code)
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        pairCard.addView(pairRow)
        content.addView(pairCard)

        toggle("同步剪贴板", "推送/拉取最近文本", { Prefs.syncClipboard }, { Prefs.syncClipboard = it })
        toggle("同步常用语", "自定义短语", { Prefs.syncPhrases }, { Prefs.syncPhrases = it })
        toggle("同步设置", "键盘与显示设置", { Prefs.syncSettings }, { Prefs.syncSettings = it })
        flushGroup()

        val actions = Ui.card(this, 14)
        actions.addView(Ui.button(this, "推送剪贴板", true) {
            withToken("推送剪贴板") { t ->
                val items = ClipboardStore.items().take(20).map { JSONObject().put("text", it.text) }
                val o = ApiClient.syncClipboard(t, items)
                "已推送 ${items.size} 条；服务端共 ${o.optJSONArray("items")?.length() ?: 0} 条"
            }
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        actions.addView(Ui.button(this, "拉取剪贴板", false) {
            withToken("拉取剪贴板") { t ->
                val arr = ApiClient.listClipboard(t).optJSONArray("items") ?: JSONArray()
                var n = 0
                for (i in 0 until arr.length()) {
                    val text = arr.optJSONObject(i)?.optString("text") ?: continue
                    if (ClipboardStore.add(text)) n++
                }
                "已拉取 $n 条剪贴板"
            }
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = Ui.dp(this@SettingsActivity, 8f)
        })
        actions.addView(Ui.button(this, "推送常用语", false) {
            withToken("推送常用语") { t ->
                val items = PhraseStore.all().map { JSONObject().put("text", it.text).put("code", it.code) }
                val o = ApiClient.syncPhrases(t, items)
                "已推送 ${items.size} 条常用语；服务端共 ${o.optJSONArray("items")?.length() ?: 0} 条"
            }
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = Ui.dp(this@SettingsActivity, 8f)
        })
        actions.addView(Ui.button(this, "拉取常用语", false) {
            withToken("拉取常用语") { t ->
                val arr = ApiClient.syncPhrases(t, emptyList()).optJSONArray("items") ?: JSONArray()
                var n = 0
                for (i in 0 until arr.length()) {
                    val text = arr.optJSONObject(i)?.optString("text") ?: continue
                    if (PhraseStore.add(text, arr.optJSONObject(i)?.optString("code") ?: "")) n++
                }
                "已拉取 $n 条新常用语"
            }
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = Ui.dp(this@SettingsActivity, 8f)
        })
        actions.addView(Ui.button(this, "推送设置", false) {
            withToken("推送设置") { t ->
                ApiClient.putSettings(t, settingsPayload())
                "设置已推送"
            }
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = Ui.dp(this@SettingsActivity, 8f)
        })
        actions.addView(Ui.button(this, "拉取设置", false) {
            withToken("拉取设置") { t ->
                val payload = ApiClient.getSettings(t).optJSONObject("payload")
                if (payload == null || payload.length() == 0) "服务端还没有设置快照"
                else {
                    applySettingsPayload(payload)
                    "设置已更新"
                }
            }
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = Ui.dp(this@SettingsActivity, 8f)
        })
        actions.addView(Ui.button(this, "解除配对", false) {
            Prefs.syncToken = ""
            Prefs.syncCode = ""
            render()
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = Ui.dp(this@SettingsActivity, 8f)
        })
        content.addView(actions)
        val retryRow = Ui.horizontal(this)
        retryRow.addView(Ui.button(this, "重试上次操作", false) {
            lastRetry?.invoke() ?: toast("没有可重试的操作")
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        retryRow.addView(Ui.button(this, "隔空传送", true) {
            startActivity(Pages.intent(this, "transfer"))
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { marginStart = Ui.dp(this@SettingsActivity, 8f) })
        content.addView(retryRow)
    }

    private fun pair(code: String) {
        setSyncBusy("正在配对…")
        lastRetry = { pair(code) }
        Background.runCatching({
            val o = ApiClient.pair(code, Prefs.displayName)
            Background.ui { onPaired(o) }
        }, { e -> showSyncError(ApiClient.friendly(e)) })
    }

    private fun onPaired(o: JSONObject) {
        Prefs.syncToken = o.optString("token")
        Prefs.syncCode = o.optString("code")
        val peer = o.optJSONObject("peer")
        syncStatus?.setTextColor(Ui.color(this, R.color.accent_dark))
        syncStatus?.text = if (peer != null) "配对成功，已发现另一台设备：${peer.optString("name")}" else "配对成功；等待另一台设备加入"
        toast("配对成功")
        render()
    }

    private fun withToken(action: String, block: (String) -> String) {
        val token = Prefs.syncToken
        if (token.isBlank()) {
            showSyncError("请先配对，再$action")
            return
        }
        setSyncBusy("$action…")
        val retry = { withToken(action, block) }
        lastRetry = retry
        Background.runCatching({
            val msg = block(token)
            Background.ui {
                syncStatus?.setTextColor(Ui.color(this, R.color.accent_dark))
                syncStatus?.text = msg
            }
        }, { e -> showSyncError(ApiClient.friendly(e)) })
    }

    private fun setSyncBusy(msg: String) {
        syncStatus?.setTextColor(Ui.color(this, R.color.text_secondary))
        syncStatus?.text = msg
    }

    private fun showSyncError(msg: String) {
        syncStatus?.setTextColor(Ui.color(this, R.color.danger))
        syncStatus?.text = "失败：$msg"
        toast(msg)
    }

    private fun settingsPayload(): JSONObject {
        val keys = listOf(
            "keyboard_mode", "keyboard_height", "candidate_size", "key_sound", "key_vibrate",
            "key_bubble", "split_keyboard", "auto_space", "enter_send", "fuzzy_enabled", "fuzzy_pairs",
            "toolbar_order", "voice_language", "voice_language_label", "plus_enabled"
        )
        val o = JSONObject()
        keys.forEach { k ->
            val v = Prefs.raw().all[k] ?: return@forEach
            when (v) {
                is Set<*> -> o.put(k, JSONArray(v.toList()))
                else -> o.put(k, v)
            }
        }
        return o
    }

    private fun applySettingsPayload(o: JSONObject) {
        val editor = Prefs.raw().edit()
        o.keys().forEach { k ->
            val v = o.opt(k)
            when (v) {
                is Boolean -> editor.putBoolean(k, v)
                is Int -> editor.putInt(k, v)
                is Long -> editor.putLong(k, v)
                is String -> editor.putString(k, v)
                is JSONArray -> {
                    val set = HashSet<String>()
                    for (i in 0 until v.length()) set.add(v.optString(i))
                    editor.putStringSet(k, set)
                }
            }
        }
        editor.apply()
        DataEngine.reloadLearning()
    }

    private fun pageMigration() {
        addInfo(
            "换机助手",
            "导出内容包括：键盘/显示设置、个人频率、固定词、删除词、自定义常用语。文件由你选择保存位置，不经过网络。"
        )
        buttonRow(
            Ui.button(this, "导出迁移文件", true) {
                exportLauncher.launch("wetype-migration-${System.currentTimeMillis()}.json")
            },
            Ui.button(this, "导入迁移文件", false) {
                importLauncher.launch(arrayOf("application/json", "text/plain"))
            }
        )
        val code = Prefs.desktopCode
        addInfo("本机迁移码", code, true)
        buttonRow(
            Ui.button(this, "复制迁移码", false) { copy(code) },
            Ui.button(this, "打开电脑版说明", false) { startActivity(Pages.intent(this, "desktop")) }
        )
    }

    private fun writeMigration(uri: Uri) {
        try {
            val payload = settingsPayload()
            payload.put("version", 1)
            payload.put("exported", System.currentTimeMillis())
            payload.put("user_freq", JSONObject(Prefs.str("user_freq", "{}")))
            payload.put("fixed_words", JSONArray(Prefs.fixedWords().toList()))
            payload.put("deleted_words", JSONArray(Prefs.deletedWords().toList()))
            payload.put("custom_phrases", JSONArray(PhraseStore.custom().map { JSONObject().put("text", it.text).put("code", it.code) }))
            contentResolver.openOutputStream(uri)?.use { it.write(payload.toString(2).toByteArray()) }
            addInfo("导出成功", "已写入所选文件。", true)
        } catch (e: Exception) {
            addInfo("导出失败", e.message ?: "无法写入文件")
        }
    }

    private fun readMigration(uri: Uri) {
        try {
            val text = contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() } ?: ""
            val o = JSONObject(text)
            applySettingsPayload(o)
            o.optJSONObject("user_freq")?.let { Prefs.put("user_freq", it.toString()) }
            o.optJSONArray("fixed_words")?.let { arr ->
                val set = HashSet<String>()
                for (i in 0 until arr.length()) set.add(arr.optString(i))
                Prefs.saveFixedWords(set)
            }
            o.optJSONArray("deleted_words")?.let { arr ->
                val set = HashSet<String>()
                for (i in 0 until arr.length()) set.add(arr.optString(i))
                Prefs.saveDeletedWords(set)
            }
            o.optJSONArray("custom_phrases")?.let { arr ->
                val list = ArrayList<PhraseStore.Phrase>()
                for (i in 0 until arr.length()) {
                    val p = arr.optJSONObject(i) ?: continue
                    list.add(PhraseStore.Phrase(p.optString("text"), p.optString("code"), true))
                }
                PhraseStore.saveCustom(list)
            }
            DataEngine.reloadLearning()
            addInfo("导入成功", "已应用迁移数据。", true)
        } catch (e: Exception) {
            addInfo("导入失败", e.message ?: "文件格式不正确")
        }
    }

    private fun pageStandalone() {
        addInfo(
            "单机模式",
            if (Prefs.standalone) "已开启：所有网络请求会立即被客户端拒绝，键盘与词库仍可完全离线使用。"
            else "开启后，AI、语音识别、传送与同步将不可用；本地键盘与词库不受影响。"
        )
        toggle("启用单机模式", "不连接任何服务器", { Prefs.standalone }, {
            Prefs.standalone = it
            render()
        })
        flushGroup()
        buttonRow(
            Ui.button(this, "检查网络", true) {
                if (Prefs.standalone) toast("单机模式已开启，网络被禁用")
                else Background.runCatching({
                    val h = ApiClient.health()
                    Background.ui { addInfo("后端可用", "模型 ${h.optString("model")} · ${Prefs.baseUrl}", true) }
                }, { e -> addInfo("后端不可用", ApiClient.friendly(e)) })
            },
            Ui.button(this, "清除临时缓存", false) {
                var n = 0
                cacheDir.listFiles()?.forEach { if (it.deleteRecursively()) n++ }
                toast("已清理 $n 个缓存项")
            }
        )
        addInfo("数据说明", "单机模式不等于清除数据。剪贴板历史与录音会话仍保存在本机，可在“隐私与权限”中删除。", true)
    }

    private fun pagePrivacy() {
        val enabled = ImeHelper.enabled(this)
        val selected = ImeHelper.selected(this)
        addInfo(
            "输入法状态",
            when {
                selected -> "微输入法已启用并选中。你可以在任意输入框使用它。"
                enabled -> "微输入法已启用，但当前输入法不是它。点“选择输入法”切换。"
                else -> "尚未启用。点“系统输入法设置”找到微输入法并打开开关。"
            }, enabled
        )
        buttonRow(
            Ui.button(this, "系统输入法设置", true) { ImeHelper.openEnableSettings(this) },
            Ui.button(this, "选择输入法", false) { ImeHelper.showPicker(this) }
        )
        content.addView(Ui.sectionTitle(this, "权限"))
        val mic = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        val group = Ui.group(this)
        group.addView(Ui.row(this, "麦克风", if (mic) "已授予，可用于语音与录音笔" else "未授予；键盘仍可正常使用", if (mic) "已授予" else "未授予", false) {
            if (!mic) ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), 61)
            else toast("麦克风权限已授予")
        })
        group.addView(Ui.divider(this))
        group.addView(Ui.row(this, "网络", if (Prefs.standalone) "单机模式已关闭网络" else "用于 AI、语音后端与跨设备功能", null, true) {
            startActivity(Pages.intent(this, "standalone"))
        })
        group.addView(Ui.divider(this))
        group.addView(Ui.row(this, "剪贴板", "仅在应用前台读取；历史保存在本机", null, true) {
            startActivity(Pages.intent(this, "clipboard"))
        })
        content.addView(group)

        content.addView(Ui.sectionTitle(this, "数据控制"))
        val data = Ui.group(this)
        data.addView(Ui.row(this, "清除个人词库", "频率、固定词与删除词", null, true) {
            AlertDialog.Builder(this).setTitle("清除个人词库？").setMessage("固定词与学习频率会被重置。")
                .setPositiveButton("清除") { _, _ -> DataEngine.reloadLearning(); Prefs.clearLearning(); toast("已清除") }
                .setNegativeButton("取消", null).show()
        })
        data.addView(Ui.divider(this))
        data.addView(Ui.row(this, "清空剪贴板历史", "${ClipboardStore.items().size} 条本机记录", null, true) {
            ClipboardStore.clear(); render()
        })
        data.addView(Ui.divider(this))
        data.addView(Ui.row(this, "删除全部本机数据", "设置、会话、聊天、词库与剪贴板", null, true) {
            AlertDialog.Builder(this)
                .setTitle("删除全部本机数据？")
                .setMessage("此操作不可撤销。后端上的同步数据不会被自动删除。")
                .setPositiveButton("全部删除") { _, _ ->
                    ClipboardStore.clear()
                    ChatStore.clear()
                    SessionStore.save(this, emptyList())
                    Prefs.resetAll()
                    toast("已删除，应用将重新开始")
                    startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP))
                    finish()
                }
                .setNegativeButton("取消", null).show()
        })
        content.addView(data)
        addInfo("独立声明", "微输入法是与腾讯无关的独立研究复刻。无腾讯二进制资源、字体、图标，也没有模型密钥；AI 只在服务端调用。")
    }

    private fun pageDesktop() {
        addInfo("电脑版", "在电脑上输入时，使用同一配对码连接。当前版本提供同步与文件传送的后端通道，桌面客户端不在本次交付范围。")
        content.addView(Ui.sectionTitle(this, "配对码"))
        val codeCard = Ui.card(this, 16)
        codeCard.addView(Ui.text(this, Prefs.desktopCode, 32f, Ui.color(this, R.color.accent_dark), true).apply {
            letterSpacing = 0.18f
            gravity = Gravity.CENTER
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        codeCard.addView(Ui.text(this, "在电脑版输入此 6 位码，或与另一台设备共用配对码。", 12f, Ui.color(this, R.color.text_secondary)).apply {
            gravity = Gravity.CENTER
            setPadding(0, Ui.dp(this@SettingsActivity, 6f), 0, 0)
        })
        content.addView(codeCard)
        buttonRow(
            Ui.button(this, "复制配对码", true) { copy(Prefs.desktopCode) },
            Ui.button(this, "打开同步", false) { startActivity(Pages.intent(this, "sync")) }
        )
        val steps = Ui.group(this)
        listOf(
            "1. 手机与电脑连接同一网络（或使用可访问的后端）。",
            "2. 在“跨设备粘贴同步”配对，六位码相同即找到彼此。",
            "3. 剪贴板与常用语可推送/拉取；文件在“隔空传送”上传下载。"
        ).forEachIndexed { i, s ->
            steps.addView(Ui.row(this, s, null, null, false))
            if (i < 2) steps.addView(Ui.divider(this))
        }
        content.addView(steps)
    }

    private fun pageKeyboardManage() {
        val enabled = ImeHelper.enabled(this)
        val selected = ImeHelper.selected(this)
        addInfo(
            "键盘管理",
            when {
                selected -> "微输入法已启用并选中。"
                enabled -> "微输入法已启用；当前由其他输入法接管。"
                else -> "微输入法尚未在系统中启用。"
            }, enabled
        )
        buttonRow(
            Ui.button(this, "启用输入法", true) { ImeHelper.openEnableSettings(this) },
            Ui.button(this, "选择输入法", false) { ImeHelper.showPicker(this) }
        )
        content.addView(Ui.sectionTitle(this, "已启用的输入法"))
        val imes = ImeHelper.list(this)
        if (imes.isEmpty()) {
            addInfo("系统未返回输入法列表", "请先在系统设置中启用至少一个输入法。", true)
        } else {
            val group = Ui.group(this)
            imes.forEachIndexed { i, info ->
                val isThis = info.packageName == packageName
                group.addView(Ui.row(this, info.loadLabel(packageManager).toString(), info.id, if (isThis) "微输入法" else null, false) {
                    ImeHelper.showPicker(this)
                })
                if (i < imes.size - 1) group.addView(Ui.divider(this))
            }
            content.addView(group)
        }

        content.addView(Ui.sectionTitle(this, "默认中文键盘"))
        val modes = listOf(
            "t9" to "九宫格拼音", "qwerty" to "全键盘拼音", "handwrite" to "手写",
            "stroke" to "笔画", "wubi" to "五笔", "doublepin" to "双拼",
            "english" to "英文", "number" to "数字", "symbols" to "符号", "emoji" to "表情"
        )
        val modeGroup = Ui.group(this)
        modes.forEachIndexed { i, pair ->
            val active = Prefs.keyboardMode == pair.first
            modeGroup.addView(Ui.row(this, pair.second, null, if (active) "✓ 当前" else null, false) {
                Prefs.keyboardMode = pair.first
                toast("默认键盘已设为${pair.second}")
                render()
            })
            if (i < modes.size - 1) modeGroup.addView(Ui.divider(this))
        }
        content.addView(modeGroup)
        buttonRow(
            Ui.button(this, "键盘体验", true) { startActivity(Pages.intent(this, "keyboard")) },
            Ui.button(this, "重置键盘设置", false) {
                Prefs.keyboardMode = "t9"
                Prefs.keyboardHeightFactor = 100
                Prefs.splitKeyboard = false
                toast("已重置")
                render()
            }
        )
    }
}
