package com.huapohen.wechatinput

import android.content.Context
import android.content.Intent

data class PageInfo(val id: String, val title: String, val group: String, val subtitle: String, val glyph: String)

object Pages {
    val all = listOf(
        PageInfo("home", "首页", "入口", "简洁、好用、打字快", "微"),
        PageInfo("onboarding", "启用与隐私", "入口", "启用输入法并了解数据边界", "盾"),
        PageInfo("keyboard", "键盘体验", "键盘", "在宿主输入框里测试真实上屏", "⌨"),
        PageInfo("keyboard_manage", "键盘管理", "键盘", "启用、切换与选择默认键盘", "⌨"),
        PageInfo("display", "布局和显示", "设置", "键盘高度、候选大小、分屏", "▤"),
        PageInfo("keystroke", "按键效果", "设置", "声音、振动与按键气泡", "◉"),
        PageInfo("toolbar", "定制工具栏", "设置", "排序键盘顶部的快捷工具", "☰"),
        PageInfo("auxiliary", "辅助输入", "设置", "联想、空格、自动标点", "＋"),
        PageInfo("fuzzy", "模糊拼音", "设置", "平翘舌、前后鼻音等模糊音", "模"),
        PageInfo("voice", "语音转文字", "设置", "长按空格说话、识别语言", "麦"),
        PageInfo("voice_language", "识别语言", "设置", "普通话、粤语、英语等", "语"),
        PageInfo("voice_punctuation", "标点设置", "设置", "自动标点与断句样式", "。"),
        PageInfo("plus", "拼写 Plus", "智能", "拼写、表情与 AI 能力开关", "✨"),
        PageInfo("clipboard", "剪贴板", "设置", "本机剪贴板历史与同步", "▣"),
        PageInfo("sync", "跨设备粘贴同步", "跨设备", "六位配对码连接多台设备", "⇄"),
        PageInfo("migration", "换机助手", "跨设备", "导出/导入设置与个人词库", "⇱"),
        PageInfo("standalone", "单机模式", "设置", "完全离线，不上传任何内容", "◌"),
        PageInfo("privacy", "隐私与权限", "设置", "权限状态、词库清除与数据说明", "盾"),
        PageInfo("desktop", "电脑版", "更多", "在电脑上使用同一套词库", "▢"),
        PageInfo("about", "关于", "更多", "版本、数据来源与独立声明", "i"),
        PageInfo("help", "帮助与反馈", "更多", "常见问题与本地反馈", "?"),
        PageInfo("recorder", "AI 录音笔", "功能", "实时转写，可选 AI 摘要", "●"),
        PageInfo("recorder_session", "录音会话", "功能", "查看转写与摘要", "▤"),
        PageInfo("transfer", "隔空传送", "功能", "上传、列出并下载文件", "⇪"),
        PageInfo("ai_chat", "问 AI", "功能", "多轮对话，可停止与重试", "AI"),
        PageInfo("text_tools", "文字工具", "功能", "整理、改写、翻译、摘要", "Aa"),
        PageInfo("translate", "边写边译", "功能", "输入即翻译，可复制使用", "译"),
        PageInfo("poster", "排版成图", "功能", "把文字排成可分享的图片", "图"),
        PageInfo("phrases", "常用语", "功能", "管理与快速输入常用短语", "语"),
        PageInfo("emoji", "表情", "功能", "Emoji、颜文字与推荐", "☺")
    )

    val settings = all.filter {
        it.id !in setOf(
            "home", "onboarding", "keyboard", "recorder", "recorder_session",
            "transfer", "ai_chat", "text_tools", "translate", "poster", "phrases", "emoji"
        )
    }

    fun byId(id: String): PageInfo = all.firstOrNull { it.id == id } ?: all.first()

    fun intent(context: Context, id: String, extra: Map<String, String> = emptyMap()): Intent {
        val cls = when (id) {
            "home" -> MainActivity::class.java
            "onboarding" -> OnboardingActivity::class.java
            "keyboard" -> KeyboardTestActivity::class.java
            "recorder" -> RecorderActivity::class.java
            "recorder_session" -> RecorderSessionActivity::class.java
            "transfer" -> TransferActivity::class.java
            "ai_chat" -> AiChatActivity::class.java
            "text_tools" -> TextToolsActivity::class.java
            "translate" -> TranslateActivity::class.java
            "poster" -> PosterActivity::class.java
            "phrases" -> PhrasesActivity::class.java
            "emoji" -> EmojiActivity::class.java
            "about" -> AboutActivity::class.java
            "help" -> HelpActivity::class.java
            else -> SettingsActivity::class.java
        }
        val intent = Intent(context, cls)
        if (cls == SettingsActivity::class.java) intent.putExtra("page_id", id)
        extra.forEach { (k, v) -> intent.putExtra(k, v) }
        return intent
    }
}
