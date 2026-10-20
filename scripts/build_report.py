#!/usr/bin/env python3
"""Build reports/analysis.md and reports/analysis.html from saved evidence."""
from __future__ import annotations

import html
import json
import re
from collections import Counter
from pathlib import Path

import markdown

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "reports"
ASSETS = REPORTS / "assets"
AN = ROOT / "analysis" / "normalized"

pkg = json.load(open(AN / "package.json", encoding="utf-8"))
metrics = json.load(open(AN / "metrics.json", encoding="utf-8"))
modules = json.load(open(AN / "modules.json", encoding="utf-8"))
schemes = modules["scheme_actions"]
components = json.load(open(AN / "components.json", encoding="utf-8"))
keyboards = json.load(open(AN / "keyboards.json", encoding="utf-8"))
settings = json.load(open(AN / "settings.json", encoding="utf-8"))
strings = json.load(open(AN / "strings.json", encoding="utf-8"))
shots = json.load(open(ASSETS / "screenshots.json", encoding="utf-8"))
evidence = json.load(open(AN / "evidence.json", encoding="utf-8"))

chinese_strings = sum(1 for x in strings if re.search(r"[\u4e00-\u9fff]", x["value"]))
shot_groups = Counter(x["group"] for x in shots)


def esc(s):
    return html.escape(str(s))


def table(headers, rows):
    out = ["| " + " | ".join(headers) + " |", "|" + "|".join(["---"] * len(headers)) + "|"]
    for row in rows:
        out.append("| " + " | ".join(str(c).replace("\n", "<br>") for c in row) + " |")
    return "\n".join(out)


def code(text, lang=""):
    return f"```{lang}\n{text}\n```"


def img(path, alt, cls=""):
    return f'<img src="{path}" alt="{esc(alt)}" class="{cls}" loading="lazy">'


def gallery_md(group, limit=None):
    rows = [x for x in shots if x["group"] == group]
    if limit:
        rows = rows[:limit]
    out = []
    for x in rows:
        out.append(f"**{x['caption']}**\n\n[![{esc(x['caption'])}]({x['thumb']})]({x['full']})\n")
    return "\n".join(out)


def gallery_html(group):
    rows = [x for x in shots if x["group"] == group]
    cards = []
    for x in rows:
        cards.append(
            f'<figure class="shot" data-group="{x["group"]}">'
            f'<a href="{x["full"]}" class="lightbox-link"><img src="{x["thumb"]}" alt="{esc(x["caption"])}" loading="lazy"></a>'
            f'<figcaption>{esc(x["caption"])}</figcaption></figure>'
        )
    return f'<div class="gallery">{"".join(cards)}</div>'


def component_rows():
    wanted = [
        "WxHldService", "ImeMainSettingActivity", "HldSettingsKeyboardsSettingUI",
        "HldChooseKeyboardUI", "VoiceRecorderActivity", "VoiceRecorderSessionActivity",
        "VoiceRecorderService", "VoiceRecorderCaptureService", "AiChatActivity",
        "ImeFileTransferUI", "FileTransferShareEntryActivity", "HldStandaloneModeUI",
        "HldPrivacyInfoUI", "HldSettingsAboutUI", "HldFeedbackUI", "FeedbackChatActivity",
        "HldActivationUI", "HldWebViewUI", "SimpleReactActivity", "HldSettingsInputUI",
        "ImeTryEditUI", "HldQRScannerUI", "HldPermissionSettingUI",
    ]
    rows = []
    for c in components:
        short = c["name"].split(".")[-1]
        if short in wanted or any(w in c["name"] for w in wanted):
            rows.append((short, c["type"], c["process"] or "main", c["exported"] or "false", c["permission"] or "—"))
    return rows


def settings_rows():
    rows = []
    meanings = {
        "isEnablePlusMode": "拼写 Plus 总开关；关闭时智能拼写/表情/语音等入口受门槛控制",
        "isEnableAssociating": "联想候选",
        "isEnableEnglishAutoCorrect": "英文纠错",
        "isEnableFirstUpperCaseMode": "英文首字母大写",
        "isEnableDoubleTapSpaceMode": "双击空格输入句号",
        "isEnableAutoSpace123Mode": "中文与数字间自动空格",
        "isEnableAutoSpaceAbcMode": "中文与英文间自动空格",
        "isEnableParticipleForT26Mode": "26 键分词",
        "isEnableDirectPreInput": "拼音直接预输入（输入框 vs 候选栏）",
        "isEnableKeyButtonFloatPreviewMode": "按键气泡",
        "isEnableHideKeyboardButton": "隐藏键盘键",
        "isEnableHandwriteFindWord": "手写找字",
        "isEnableVoiceInputButton": "键盘语音按钮",
        "isEnableSMSVerificationCodeAuto": "短信验证码建议（需权限）",
        "isEnableStatusBarPasteBoard": "通知栏剪贴板",
        "isClipboardEnableState": "剪贴板候选栏读取",
        "isEnableT26ToT9NumberMode": "26 键使用九宫格数字键盘",
        "isEnableStandaloneMode": "单机模式",
        "isEnableVoiceRecorder": "AI 录音笔",
        "isEnableVoiceRecorderRecapSync": "录音纪要同步",
        "isSupportAskAI": "问 AI 能力标记",
        "isEnableKeySound": "按键声音",
        "isEnableKeyVibrate": "按键震动",
        "isEnableVibrateFollowSystem": "震动跟随系统",
        "voiceIconShowTimeIndex": "语音图标显示时长",
        "voiceInputPunctuationIndex": "标点模式",
        "voiceInputLanguageType": "识别语言",
        "isEnableVoiceInputLongClickTrigger": "长按触发语音",
        "isEnableVoiceInputReleaseToSend": "松手发送",
        "isEnableVoiceInputSmartTextPolish": "语音智能整理",
        "isEnableOfflineSpeech": "离线语音",
        "candidateWordGear": "候选字大小档位",
        "colorThemeMode": "主题模式：跟随系统/浅色/深色",
    }
    for model, data in settings.items():
        for f in data["fields"]:
            if f["name"] in meanings:
                rows.append((model, f["name"], f["type"].split(".")[-1], meanings[f["name"]]))
    return rows


def keyboard_rows():
    family = []
    for k in keyboards:
        f = k["file"]
        if "HandWrite" in f:
            fam = "手写"
        elif "Sticker" in f:
            fam = "表情包"
        elif "Emoji" in f:
            fam = "Emoji"
        elif "Symbol" in f or "Number" in f:
            fam = "数字/符号"
        elif "Stroke" in f:
            fam = "笔画"
        elif "WuBi" in f:
            fam = "五笔"
        elif "DoublePin" in f:
            fam = "双拼"
        elif "English" in f:
            fam = "英文"
        else:
            fam = "中文拼音"
        family.append((fam, f, k["is_t9"], k["line_count"], k["key_count"], k["vwidth"], k["vheight"]))
    family.sort(key=lambda x: (x[0], x[1]))
    return family


def scheme_rows():
    behavior = {
        "MainSetting": ("主设置/首页", "切入 RN SetupMain"),
        "KeyboardSetting": ("键盘设置", "RN 页面"),
        "VoiceInputSetting": ("语音输入设置", "RN 页面"),
        "VibrateVolumeSetting": ("按键效果", "RN 页面"),
        "DisplaySetting": ("布局和显示", "RN 页面"),
        "KeyboardAppearanceSetting": ("键盘外观", "RN 页面"),
        "FuzzyPinyinSetting": ("模糊拼音", "RN 页面"),
        "SlideInputSetting": ("上滑输入", "RN 页面"),
        "T9CustomSymbolSetting": ("九宫格符号自定义", "RN 页面"),
        "PlusSetting": ("拼写 Plus", "RN 页面"),
        "PermissionAndPrivacySetting": ("隐私与权限", "RN 页面"),
        "HelpAndFeedback": ("帮助与反馈", "RN FeedbackMain"),
        "About": ("关于", "RN About"),
        "Debug": ("调试", "内部页面"),
        "TestView": ("测试视图", "内部页面"),
        "Feedback": ("反馈", "RN FeedbackMain"),
        "Rating": ("评分", "系统/应用内评分"),
        "Web": ("WebView", "帮助/文章"),
        "ExperienceKeyboard": ("体验键盘", "键盘试用"),
        "DeviceSync": ("跨设备同步", "GeneralDeviceSync"),
        "SetupClipboard": ("剪贴板", "SetupClipboard"),
        "VoicePunctuationSetting": ("标点设置", "Voice 子页"),
        "VoiceShowIconSetting": ("语音图标", "Voice 子页"),
        "StandaloneMode": ("单机模式", "原生 HldStandaloneModeUI"),
        "QR_SCAN": ("扫码", "HldQRScannerUI"),
        "AiChat": ("问 AI", "AiChatActivity WebView"),
        "VoiceRecorder": ("AI 录音笔", "原生 VoiceRecorderActivity"),
        "FileTransfer": ("隔空传送", "原生 ImeFileTransferUI"),
    }
    return [(k, v, behavior.get(k, ("—", "—"))[0], behavior.get(k, ("—", "—"))[1]) for k, v in schemes.items()]


def feature_rows():
    data = [
        ("F01", "系统键盘接入/启用引导", "WxHldService、HldActivationUI、IME 权限流程", "Android 已验证；iOS 需键盘扩展"),
        ("F02", "六种中文键盘", "36 套 layout JSON；键盘管理分组", "T9/QWERTY/手写/笔画/五笔/双拼"),
        ("F03", "全键盘拼音、九宫格、中英切换", "S1/S2/S3 布局、候选栏、chSwitch", "本地拼音引擎 + 词库"),
        ("F04", "五笔/笔画/双拼", "S17/S7/S8/S9 布局；方案字符串", "编码表 + 候选引擎"),
        ("F05", "手写与手写找字", "HandWrite 布局、手写找字键盘", "笔画轨迹模板 + 找字"),
        ("F06", "候选排序、固定、删除", "候选引擎类、用户词频", "频率/学习/固定词"),
        ("F07", "智能拼写与纠错", "拼写 Plus、拼写检查", "后端/本地纠错"),
        ("F08", "光标编辑、删除、撤回", "宿主 InputConnection、删除键", "宿主文本操作"),
        ("F09", "个性化与工具栏", "定制工具栏、Plus、皮肤", "图标排序/开关"),
        ("F10", "数字、符号、计算器", "S4/S5/S12/S13/S26 布局", "表达式求值"),
        ("F11", "常用语与自定义输入码", "常用语资源、剪贴板/短语", "本地持久化"),
        ("F12", "剪贴板与选词粘贴", "SetupClipboard、状态栏粘贴", "剪贴板历史"),
        ("F13", "语音完整生命周期", "VoiceRecorder、ASR 链", "系统 ASR + 后端总结"),
        ("F14", "中英混说/方言", "语音语言设置", "后端/系统识别"),
        ("F15", "长语音与离线语音", "离线语音设置、模型下载", "本地模型/降级"),
        ("F16", "语音启动体验/音频路由", "长按空格、松手发送、录音待机", "平台权限/生命周期"),
        ("F17", "文字整理", "文字整理、AI 回填链", "后端 polish"),
        ("F18", "问 AI 与多轮回答", "AiChatActivity WebView、RequestChat", "自有 AI 聊天"),
        ("F19", "灵动表达/文案润色", "SetupPlus、灵动表达", "后端 rewrite"),
        ("F20", "边写边译", "翻译链、语言列表", "后端 translate"),
        ("F21", "表情推荐与定制", "表情推荐、Emoji/贴纸布局", "本地表情库"),
        ("F22", "颜文字/字体滤镜", "颜文字、字体滤镜", "本地模板"),
        ("F23", "排版成图", "排版成图、文字海报", "Canvas 渲染"),
        ("F24", "书影音/小程序分享", "智能推荐、小程序", "自有内容/分享"),
        ("F25", "跨设备剪贴板/词库/常用语同步", "GeneralDeviceSync、RequestSync", "后端同步"),
        ("F26", "隔空传送", "ImeFileTransferUI、weread 落地页", "后端中转/LAN"),
        ("F27", "换机助手", "SetupMigrationAssistant、RequestMigration", "后端迁移"),
        ("F28", "iOS 分享扩展/快捷入口", "iOS 端可见页面", "Swift Share Extension"),
        ("F29", "短信验证码/外接键盘", "SMS 权限、硬件键盘", "Android 平台能力"),
        ("F30", "单机/联网与数据控制", "HldStandaloneModeUI、隐私页", "本地模式 + 清除"),
    ]
    return data


# ---------------------------------------------------------------------------
# Markdown body
# ---------------------------------------------------------------------------
parts = []
parts.append(f"""# 微信输入法 Android 4.0.0 REA 逆向分析与复刻蓝图

**目标包**：`{pkg['package_name']}` · 版本 `{pkg['version_name']}`（versionCode `{pkg['version_code']}`）  
**APK SHA-256**：`{pkg['sha256']}` · **大小**：{pkg['bytes']:,} 字节  
**分析日期**：2026-10-20 · **报告版本**：v1（分析基线）  
**结论**：Android 首页/设置/键盘/原生功能的可复核结构已经恢复；官方云服务不可获得；iOS 无 IPA，不能做二进制级静态分析。复刻将按“自有后端 + 本地引擎”实现。

> 本报告把 **REA 静态证据**、**原版运行截图**、**APK 内资源**、**公开 iOS 可见界面** 和 **复刻自测** 分开记录。任何一类材料都不能替代另一类。所有结论附 Evidence ID 或原始文件路径。

## 0. 一页结论

<div class="metrics">
<div><strong>{metrics['total_classes']:,}</strong><span>APK 类总数</span></div>
<div><strong>{metrics['app_classes']:,}</strong><span>com.tencent.wetype 类</span></div>
<div><strong>{metrics['keyboard_layouts']}</strong><span>键盘布局 JSON</span></div>
<div><strong>{chinese_strings}</strong><span>中文 string 资源</span></div>
<div><strong>{metrics['rn_modules']}</strong><span>RN 注册模块</span></div>
<div><strong>{metrics['scheme_actions']}</strong><span>SchemeAction</span></div>
</div>

- **已恢复**：首页 RN 注册表、28 个 SchemeAction、36 套键盘布局、53 个应用组件、37 个主设置字段及 6 个子模型、586 条中文资源、AI/语音/同步/迁移的协议入口、`wetype://` 深链行为。
- **已运行验证**：原版 4.0.0 在独立 Android AVD 上完成隐私接受、首页、布局/按键/辅助输入/语音/Plus/单机/隐私/关于/帮助、键盘管理、AI 录音笔、隔空传送、深链等页面采集；历史 42 步 + 本轮 {shot_groups["android-20261020"]} 张运行截图。
- **未恢复**：腾讯私有云 API 的 base URL、鉴权、签名、模型与提示词；拼音/五笔/手写/语音的私有算法与模型；iOS 二进制。
- **复刻决策**：Flutter 通用版 + Android 原生 IME + iOS 原生键盘扩展，共用一套布局/词库/设计规格；AI、ASR、翻译、同步、传送走可配置的自有后端，密钥只在服务端。
- **关键限制**：Android 官方后端不可用，不能把“原版联网功能”当作可复现依赖；iOS 只能依据可见界面和 Android 证据重建，不能宣称二进制级同构。

## 1. 对象、工具与方法

### 1.1 包身份

{table(["项目", "值"], [
    ("包名", f"`{pkg['package_name']}`"),
    ("版本", f"{pkg['version_name']} / {pkg['version_code']}"),
    ("minSdk / targetSdk", f"{pkg['min_sdk']} / {pkg['target_sdk']}"),
    ("APK 字节", f"{pkg['bytes']:,}"),
    ("SHA-256", f"`{pkg['sha256']}`"),
    ("权限数", str(len(pkg["permissions"]))),
    ("应用组件", str(len(components))),
    ("Hermes bundles", "、".join(metrics["hermes_bundles"])),
    ("arm64 原生库", str(metrics["native_libs"])),
])}

权限覆盖网络、录音、相机、短信、附近 Wi-Fi、悬浮窗、前台服务、通知等。它们解释了为什么原版可以在键盘内直接做语音、扫码、文件传送和跨设备发现；复刻版必须逐项按平台权限模型重新申请，不能照搬 manifest。

### 1.2 实际使用的工具链

{table(["工具", "版本/角色", "用途"], [
    ("REA CLI", "`rea-agents 6.7.0`", "Android 包/类/方法查询；生成 Evidence JSON"),
    ("JADX headless bridge", "`0.7.1`，SHA-256 `6e5eacf5…`", "`inspect-android-package/class/method`、类清单、方法正文"),
    ("apktool", "`2.11.1`", "manifest、资源、assets、smali 入口"),
    ("hermes-dec", "Python 3.14 venv", "解包 `setup/general/feedback/platform.hbc` 为可检索伪 JS"),
    ("Graphviz", "`dot`", "架构图、路由图、状态机、AI 流程图"),
    ("adb + AVD", "`WeChatInput_API_36` / `WeChatInput_Tablet_API_36`", "原版运行截图；后续复刻验收"),
])}

### 1.3 证据分层

{table(["层", "能证明什么", "不能证明什么"], [
    ("REA 静态", "类/方法/字段/调用确实存在于 APK；selector 与 Evidence ID 可复核", "分支在当前设备/账号/网络下一定执行"),
    ("原版运行截图", "当时设备上可见的页面、文案、状态与跳转结果", "其他版本、深色模式、平板布局、未进入的分支"),
    ("APK 内资源", "36 套键盘的几何/文本/样式引用；586 条中文串", "运行时的实际渲染与候选结果"),
    ("公开 iOS 可见界面", "iOS 3.5.5 在 iPhone Mirroring 中可见的页面与文案", "iOS 二进制结构、扩展实现、私有 API"),
    ("复刻自测", "复刻版在指定构建/设备上的行为", "与原版逐像素/逐算法一致"),
])}

### 1.4 复现命令

{code('''export REA_JADX_MCP_JAR="$PWD/rea/tooling/jadx-headless-mcp-0.7.1-all.jar"
export REA_APKTOOL_COMMAND="$PWD/rea/tooling/apktool.sh"
rea inspect-android-package targets/wechat-android-4.0.0.apk --format json
rea search-android-classes targets/wechat-android-4.0.0.apk "" --format json
rea inspect-android-class targets/wechat-android-4.0.0.apk \\
  com.tencent.wetype.plugin.hld.reactnative.activity.ImeMainSettingActivity --format json
rea inspect-android-method targets/wechat-android-4.0.0.apk \\
  com.tencent.wetype.plugin.hld.reactnative.activity.ImeMainSettingActivity R1 --overload-index 0 --format json''', "bash")}

{code('''python3 scripts/normalize_analysis.py
python3 scripts/build_diagrams.py
python3 scripts/prepare_report_assets.py
python3 scripts/build_report.py''', "bash")}

## 2. 架构：三层 + 一个不可用云

![架构图](assets/architecture.svg)

原版不是单一 RN 应用，而是 **主进程 RN 设置界面 + `:hld` 进程原生输入法 + 原生媒体/传送/AI WebView** 的组合：

1. **主进程**：`ImeMainSettingActivity` 是 launcher，接收 `wetype://`；`SetupMain` 及各 `Setup*` 页面来自 `setup.hbc`；`GeneralDeviceSync`、`MigrationAssistant`、`FeedbackMain` 来自 `general.hbc` / `feedback.hbc`。
2. **`:hld` 进程**：`WxHldService` 是真正的 `InputMethodService`；键盘视图、候选引擎、录音笔、文件传送、AI 聊天、键盘管理都在这里或其相邻原生页面。
3. **原生库/资源**：57 个 arm64 `.so`，包括 `libime_net.so`、`libwetap_business.so`、`libvoiceopus.so`、`libwechatvoicesilk.so`、`libreactnative.so`、`libhermes.so`；36 套键盘 JSON 与词库/配置 bin。
4. **腾讯云**：文章/帮助 CDN、设备同步、迁移、AI Chat WebView、文件传送落地页。客户端代码中没有可复用的公开 AI base URL；这条链路被标记为**不可用**。
5. **替代后端**：本地 API 代理 DeepSeek，提供 AI/ASR/翻译/同步/传送；客户端只配置 `API_BASE_URL`。

### 2.1 RN bundle 与注册模块

{table(["Bundle", "文件", "注册模块数", "代表模块"], [
    ("`setup`", "`setup.hbc` (2.1 MB)", str(len([m for m in modules['modules'] if m.startswith('Setup_')])), "SetupMain / SetupPlus / SetupDisplaySetting / SetupVoiceInput / SetupSecondaryKeyboard / SetupMigrationAssistant"),
    ("`general`", "`general.hbc` (923 KB)", "3", "GeneralDeviceSync / GeneralDeviceSyncCodeInput / General_MigrationAssistant"),
    ("`feedback`", "`feedback.hbc` (862 KB)", "1", "FeedbackMain"),
    ("`platform`", "`platform.hbc` (912 KB)", "0", "共享平台运行时"),
])}

`setup.js` 的注册表明确给出 `SetupMain`、`SetupPlus`、`SetupDesktop`、`SetupKeyboardSelect`、`SetupSp`、`SetupWb`、`SetupClipboard`、`SetupVoiceInput`、`SetupDisplaySetting`、`SetupKeystrokeEffect`、`SetupAuxiliaryInput`、`SetupLanguageRecognizeInVoice`、`SetupRecordingStandbyTime`、`SetupShowVoiceIconInVoiceInput`、`SetupPunctuationSettingInVoiceInput`、`SetupFuzzyPinyin`、`SetupSecondaryKeyboard`、`SetupMigrationAssistant`、`FeedbackMain`、`GeneralDeviceSync`、`GeneralDeviceSyncCodeInput`、`General_MigrationAssistant`、`SetupTest`、`SetupLottieExample`、`About_About`、`Unknown_Unknown`、`AIChat_RNAiChatPage`。这是**页面身份**，不是组件树。

### 2.2 关键组件

{table(["组件", "类型", "进程", "导出", "说明"], component_rows())}

### 2.3 深链与路由行为

`ImeMainSettingActivity.R1`（Evidence `ev_2fb38fa49b8a4266e`）只对两个 host 做原生特判：

- `launchFileTransfer` → `scheme.c.z(...)` → `ImeFileTransferUI`
- `voiceRecorder` → `scheme.c.z(...)` → `VoiceRecorderActivity`

其余 URI 由 `y1(uri)` 解析为 JSON，再交给 RN 事件总线 `g.f37567a.g(json)`；`WBRCTNavigator.navigate/navigateWithInfo` 在本包静态正文中直接 reject `UNSUPPORTED`，`navigateToURL` 才向 UI 线程提交 runnable。**不能假设任意 RN dest 都可导航。**

已实际验证：

{code('''adb shell am start -a android.intent.action.VIEW -d "wetype://voiceRecorder"
# → VoiceRecorderActivity
adb shell am start -a android.intent.action.VIEW -d "wetype://launchFileTransfer"
# → ImeFileTransferUI
adb shell am start -a android.intent.action.VIEW -d "wetype://aiChat"
# → 回到 ImeMainSettingActivity；无参数时不直接进入聊天''', "bash")}

### 2.4 SchemeAction 全表

{table(["Key", "值", "页面", "行为"], scheme_rows())}

## 3. 页面与跳转地图

![高层路由](assets/routes-high.svg)

### 3.1 页面清单（按运行可达性）

{table(["页面", "类型", "入口", "运行证据", "复刻优先级"], [
    ("隐私说明 `HldPrivacyInfoUI`", "原生", "首次启动", "`00-launch` / `10-privacy`", "P0"),
    ("启用引导 `HldActivationUI`", "原生", "隐私后/未启用", "`01-home`（历史）", "P0"),
    ("首页 `SetupMain`", "RN", "launcher", "`21-home-top` / `22-home-mid` / `23-home-bottom`", "P0"),
    ("布局和显示 `SetupDisplaySetting`", "RN", "首页", "`30`–`32`", "P0"),
    ("按键效果 `SetupKeystrokeEffect`", "RN", "首页", "`33`–`34`", "P0"),
    ("定制工具栏 `SetupSecondaryKeyboard`", "RN", "首页", "`35`", "P1"),
    ("辅助输入 `SetupAuxiliaryInput`", "RN", "首页", "`36`–`37`", "P0"),
    ("模糊拼音 `SetupFuzzyPinyin`", "RN", "辅助输入", "静态/字符串", "P1"),
    ("跨设备粘贴同步 `GeneralDeviceSync`", "RN", "首页", "`38`", "P1"),
    ("剪贴板 `SetupClipboard`", "RN", "首页", "`39`", "P0"),
    ("键盘管理 `HldSettingsKeyboardsSettingUI`", "原生", "首页", "`40`", "P0"),
    ("键盘选择 `HldChooseKeyboardUI`", "原生", "键盘管理", "`keyboard-modes`", "P0"),
    ("语音转文字 `SetupVoiceInput`", "RN", "首页", "`41`–`42`", "P0"),
    ("识别语言 `SetupLanguageRecognizeInVoice`", "RN", "语音", "字符串/路由", "P1"),
    ("标点设置 `SetupPunctuationSettingInVoiceInput`", "RN", "语音", "字符串/路由", "P1"),
    ("录音待机 `SetupRecordingStandbyTime`", "RN", "语音", "字符串/路由", "P2"),
    ("语音图标 `SetupShowVoiceIconInVoiceInput`", "RN", "语音", "字符串/路由", "P2"),
    ("拼写 Plus `SetupPlus`", "RN", "首页", "`43`–`44`", "P0"),
    ("单机模式 `HldStandaloneModeUI`", "原生", "首页", "`45`", "P0"),
    ("换机助手 `SetupMigrationAssistant`", "RN", "首页", "`46`", "P2"),
    ("隐私与权限 `PermissionAndPrivacySetting`", "RN", "更多", "`50`", "P0"),
    ("电脑版 `SetupDesktop`", "RN", "更多", "`51`", "P2"),
    ("关于 `About`", "RN/原生", "更多", "`52`", "P2"),
    ("帮助与反馈 `FeedbackMain`", "RN", "更多", "`53`", "P1"),
    ("AI 录音笔 `VoiceRecorderActivity`", "原生", "首页/深链", "`60` / `deeplink…voiceRecorder`", "P0"),
    ("录音会话 `VoiceRecorderSessionActivity`", "原生", "录音笔", "路由/Manifest", "P1"),
    ("隔空传送 `ImeFileTransferUI`", "原生", "首页/深链", "`61` / `deeplink…launchFileTransfer`", "P1"),
    ("问 AI `AiChatActivity`", "原生 WebView", "键盘/首页", "`70` / `71`", "P0"),
    ("键盘工具栏", "原生 IME", "键盘", "历史 `tools-panel` / `30`–`32`", "P0"),
    ("反馈会话 `FeedbackChatActivity`", "原生", "帮助", "`53`", "P1"),
    ("文件分享入口 `FileTransferShareEntryActivity`", "原生", "系统分享", "Manifest", "P2"),
])}

### 3.2 深入路由

![详细路由](assets/routes-detail.svg)

### 3.3 运行截图画廊

> 2026-10-18 的 42 步截图来自同一 SHA-256 的 APK，使用独立 AVD；2026-10-20 的截图在新建的 `WeChatInput_API_36` 上复采。历史截图只作为“当时可见状态”的证据，不替代本轮静态结论。iOS 小节中的图片是 iPhone Mirroring 的可见界面，不是 iOS 二进制分析。

#### Android · 2026-10-18（42 步）

{gallery_md('android-20261018')}

#### Android · 键盘与工具栏

{gallery_md('android-keyboard')}

#### Android · 2026-10-20 复采

{gallery_md('android-20261020')}

#### iOS · 可见界面（非二进制）

{gallery_md('ios-20261019')}

## 4. 键盘系统

### 4.1 布局清单（36 套）

{table(["家族", "文件", "T9", "行", "键", "基准宽", "基准高"], keyboard_rows())}

布局 JSON 的结构是：`config`（名称枚举、参考宽高、行数、行高、行距、是否 T9、对齐、边距）+ `keyDefaultConfig`（默认文本/颜色/圆角/阴影/功能码）+ `keys`（按行分组的按键覆盖）。每个键的 `mainText`、`floatText`、`width`、`height`、`bgCorner`、`clickFunctionCode` 都是三元素数组，分别对应竖屏/横屏/平板三种参考形态。复刻版按同一几何模型重建，不直接复制腾讯的样式资源。

### 4.2 键盘预览

<div class="keyboard-grid">
<figure><img src="assets/keyboard-t9.svg" alt="T9 九宫格"><figcaption>九宫格拼音（S1）</figcaption></figure>
<figure><img src="assets/keyboard-qwerty.svg" alt="全键盘拼音"><figcaption>全键盘拼音（S2）</figcaption></figure>
<figure><img src="assets/keyboard-stroke.svg" alt="笔画"><figcaption>笔画（S7）</figcaption></figure>
<figure><img src="assets/keyboard-wubi.svg" alt="五笔"><figcaption>五笔（S17）</figcaption></figure>
<figure><img src="assets/keyboard-doublepin.svg" alt="双拼"><figcaption>双拼全键盘（S9）</figcaption></figure>
<figure><img src="assets/keyboard-symbols.svg" alt="符号"><figcaption>符号面板（S5）</figcaption></figure>
<figure><img src="assets/keyboard-emoji.svg" alt="Emoji"><figcaption>Emoji（S11）</figcaption></figure>
<figure><img src="assets/keyboard-handwrite.svg" alt="手写"><figcaption>手写（HandWrite）</figcaption></figure>
</div>

### 4.3 输入状态机

![键盘状态机](assets/keyboard-fsm.svg)

复刻引擎的关键不变量：

- **组合缓冲区与宿主 composing 文本分离**：拼音/笔画/五笔编码先进入内部 buffer，候选确认后才 `commitText`；删除键先退 buffer，再退宿主文本。
- **候选排序**：精确前缀 > 模糊拼音匹配 > 词频/用户学习 > 长度惩罚；固定词优先；删除词写入本地黑名单。
- **六种模式共享同一宿主连接**：切换模式不重建输入连接；`chSwitch` 只切语言/模式，不提交未完成编码。
- **语音入口**：长按空格或语音键进入 listening；partial 结果只更新候选区/预览，release 后按“松手发送/编辑/撤回”策略提交；取消必须恢复进入前的文本范围。
- **工具栏**：工具面板是键盘的一部分，不是独立 Activity；问 AI/整理/翻译需要把当前选中文本与来源通过消息/深链交给独立页面，返回时只替换明确范围。

### 4.4 可复刻与不可复刻

{table(["部分", "可复刻", "不可复刻/需替代"], [
    ("布局与几何", "36 套 JSON 的键位、行列、宽高、行高、T9 标记", "腾讯的字体、图标、皮肤资源"),
    ("候选", "拼音切分、T9 映射、模糊拼音、词频/学习、固定/删除", "腾讯私有语言模型与云端排序"),
    ("五笔/笔画/双拼", "公开编码表与方案映射", "腾讯私有词库与联想权重"),
    ("手写", "轨迹采集、方向量化、模板匹配、候选展示", "腾讯自然连笔识别模型"),
    ("语音", "系统 ASR/自有 ASR、partial/final、标点、取消/重试", "腾讯云语音模型与私有双链路"),
    ("AI", "自有后端 + DeepSeek、提示词、流式/取消/历史", "腾讯 AI Chat WebView 的私有协议"),
])}

## 5. 设置与数据模型

### 5.1 主设置字段（37）

`MainSettingInfo` 是 RN 设置页与原生键盘共享的主模型。以下字段来自 REA 类清单（Evidence `ev_e2563ea1bfce66af4`），类型为 JADX 报告的声明类型。

{table(["字段", "类型", "语义（工作译名）"], [
    (f["name"], f["type"].split(".")[-1], {
        "candidateWordSize": "候选字大小",
        "colorThemeInfo": "主题子模型",
        "fuzzyPinyinInfo": "模糊拼音子模型",
        "isClipboardEnableState": "剪贴板读取开关",
        "isDefaultEnterActionSend": "回车键发送",
        "isEmojiQuickSettingMode": "表情快捷键模式",
        "isEnableAssociating": "联想",
        "isEnableAutoSpace123Mode": "中文/数字自动空格",
        "isEnableAutoSpaceAbcMode": "中文/英文自动空格",
        "isEnableDirectPreInput": "拼音直接预输入",
        "isEnableDoubleTapSpaceMode": "双击空格句号",
        "isEnableEnglishAutoCorrect": "英文纠错",
        "isEnableFirstUpperCaseMode": "首字母大写",
        "isEnableFuzzyPinyin": "模糊拼音总开关",
        "isEnableHandwriteFindWord": "手写找字",
        "isEnableHideKeyboardButton": "隐藏键盘键",
        "isEnableKeyButtonFloatPreviewMode": "按键气泡",
        "isEnableParticipleForT26Mode": "26 键分词",
        "isEnablePlusMode": "拼写 Plus 总开关",
        "isEnableSMSVerificationCodeAuto": "短信验证码建议",
        "isEnableStandaloneMode": "单机模式",
        "isEnableStatusBarPasteBoard": "通知栏剪贴板",
        "isEnableT26ToT9NumberMode": "26 键九宫格数字",
        "isEnableVoiceInputButton": "语音按钮",
        "isEnableVoiceRecorder": "AI 录音笔",
        "isEnableVoiceRecorderRecapSync": "录音纪要同步",
        "isSupportAskAI": "问 AI 能力标记",
        "isVoiceRecorderRecording": "录音中",
        "isVoiceRecorderUsed": "录音笔已使用",
        "keystrokeEffectInfo": "按键效果子模型",
        "needUpdateStandaloneMode": "单机模式需更新",
        "plusItemInfo": "Plus 子开关",
        "redPointStandaloneMode": "单机模式红点",
        "swipeUpInputMode": "上滑输入模式",
        "unreadInfo": "未读/红点",
        "voiceInputInfo": "语音子模型",
    }.get(f["name"], "—")) for f in settings["MainSettingInfo"]["fields"]
])}

### 5.2 子模型

{table(["模型", "字段数", "关键字段"], [
    ("`PlusItemInfo`", str(len(settings["PlusItemInfo"]["fields"])), "isEnableAskAI / isEnableSmartSpelling / isEnableSpellingCorrect / isEnableStickerRecommend / isEnableSmallEmoji / isEnableKaomoji / isEnableRewriteRecommend / isEnableTextPolish / isEnableTextPoster / isEnableQuickSend"),
    ("`VoiceInputInfo`", str(len(settings["VoiceInputInfo"]["fields"])), "isEnableOfflineSpeech / isEnableVoiceInputLongClickTrigger / isEnableVoiceInputReleaseToSend / isEnableVoiceInputSmartTextPolish / voiceIconShowTimeIndex / voiceInputPunctuationIndex / voiceInputLanguageType / voiceInputDialectInfo"),
    ("`KeystrokeEffectInfo`", str(len(settings["KeystrokeEffectInfo"]["fields"])), "isEnableKeySound / keySoundVolumeSize / isEnableKeyVibrate / keyVibrateLevel / isEnableVibrateFollowSystem"),
    ("`DisplaySettingInfo`", str(len(settings["DisplaySettingInfo"]["fields"])), "candidateWordGear"),
    ("`FuzzyPinyinInfo`", str(len(settings["FuzzyPinyinInfo"]["fields"])), "20 组模糊音：zzh/cch/ssh、nl/rl、anang/eneng/ining/…"),
    ("`ColorThemeInfo`", str(len(settings["ColorThemeInfo"]["fields"])), "colorThemeMode：跟随系统/浅色/深色"),
])}

![设置模型关系](assets/settings-er.svg)

### 5.3 设置页与写入关系

{table(["页面", "主要字段/行为", "证据"], [
    ("布局和显示", "T9NumberKeyboard、SlideInput、Emoji、键盘高度、侧边栏、ColorThemeMode、DirectPreInput、候选字大小", "`30`–`32` 运行截图；`DisplaySettingInfo`"),
    ("按键效果", "KeystrokeSound、KeystrokeVibrate、KeyBubble；声音/触感分档", "`33`–`34`；`KeystrokeEffectInfo`"),
    ("辅助输入", "DefaultEnterActionSend、AutoSpace123、AutoSpaceAbc、SMSVerificationCodeAuto、KeyboardCapitalize、KeyboardDoubleSpaceFullstop、模糊拼音", "`36`–`37`；`MainSettingInfo`"),
    ("语音转文字", "标点、长按空格、松手发送、智能整理、离线语音、识别语言、语音图标", "`41`–`42`；`VoiceInputInfo`"),
    ("拼写 Plus", "总开关 + 10 个子开关；表情/Emoji/颜文字/拼写检查/灵动表达/问 AI/文字整理/排版成图", "`43`–`44`；`PlusItemInfo`"),
    ("剪贴板", "StatusBarPasteBoard、Clipboard 历史记录", "`39`"),
    ("跨设备", "跨设备复制粘贴、词库同步、常用语同步、录音纪要同步、传文件", "`38`"),
    ("隐私与权限", "输入法启用状态、个人词典清除、麦克风/相机等权限", "`50`"),
])}

### 5.4 持久化与共享

原版同时存在 Kotlin 序列化模型、MMKV（`libmmkv.so`）和 RN storage；主进程与 `:hld` 进程通过 IPC/服务共享设置。复刻版不复制其存储实现，改用：

- 客户端：`SharedPreferences`（Android）/ `UserDefaults` + App Group（iOS）/ `shared_preferences`（Flutter）；
- 结构化模型：JSON schema + 版本迁移；
- 敏感数据：剪贴板历史默认不落盘，语音原文不持久化；API key 只在服务端。

## 6. AI、语音、翻译与后端

### 6.1 功能分层

{table(["能力", "原版入口", "原版实现线索", "复刻实现"], [
    ("问 AI", "键盘工具栏/首页问 AI", "`AiChatActivity` 内 `mAiChatWebView`；`Ab.g.e` 启动；`initialProperties` Bundle", "自有 AI 聊天页 + SSE"),
    ("文字整理", "键盘工具栏/拼写 Plus", "文字工具链、回填/撤回", "后端 `/v1/ai/polish` + 原文快照/撤回"),
    ("灵动表达", "拼写 Plus", "改写/润色候选", "后端 `/v1/ai/rewrite`，候选预览/应用"),
    ("边写边译", "键盘工具栏", "源区/宿主双区、语言列表", "本地双区 + 后端 `/v1/ai/translate`"),
    ("语音转文字", "长按空格/语音键", "AudioRecord 16k mono PCM16；在线/离线链", "系统 ASR；可选后端 ASR"),
    ("AI 录音笔", "首页功能卡", "VoiceRecorderActivity + 实时转写 + AI 总结", "录音 + ASR + `/v1/ai/summary`"),
    ("表情/颜文字/Emoji", "拼写 Plus/键盘", "表情推荐、Emoji/贴纸布局", "本地资源 + 关键词映射"),
    ("排版成图", "拼写 Plus", "文字海报/模板", "Canvas 渲染 + 保存/分享"),
    ("跨设备/传送", "首页/键盘", "RequestSync / RequestMigration / weread 落地页", "自有后端配对/中转"),
])}

### 6.2 协议入口（静态可见）

`setup.js` 中有完整的 protobuf 模块名与字段校验字符串，但没有公开的 base URL：

{table(["协议族", "消息", "用途"], [
    ("`RequestChat`", "ChatClientInfo / ChatItem / ChatMessageContent / ChatListReq·Rsp / InnerChatListReq·Rsp / ReplyReq·Rsp / SendChatReq·Rsp / SyncChatReq·Rsp", "AI 聊天、历史、发送、回复、同步"),
    ("`RequestDispatch`", "FeedbackPushItem / BundleItem / …", "反馈/资源分发"),
    ("`RequestSync`", "BindMatchCodeReq·Rsp / ClipboardMsg / DeviceInfo / …", "设备配对、剪贴板、词库同步"),
    ("`RequestMigration`", "GenerateMigrationQrCode / Occupy / Release / GetMigrationInfo / Finish / Cancel / DataUploaded / DataDownloaded", "换机助手二维码与迁移状态"),
])}

已知域名（仅证明客户端会访问，不证明可复用）：

{table(["域名/路径", "用途", "可复刻性"], [
    ("`wetype.wxqcloud.qq.com/page/article/...`", "帮助/文章", "不可复用；自有帮助页"),
    ("`download.z.weixin.qq.com/page/article/...`", "文章/更新说明", "不可复用"),
    ("`wxkeyboardcms-1258476243.file.myqcloud.com/page/help_detail/...`", "帮助详情 CDN", "不可复用"),
    ("`weread.qq.com/wetype/devicetransfer?deviceid=...`", "文件传送落地/配对", "不可复用；自有后端"),
    ("`weread.qq.com/sentry/20`", "Sentry DSN（崩溃上报）", "不复用；自有日志"),
    ("`http://localhost:8081/`", "Metro 开发服务器（调试）", "仅开发"),
])}

**为什么官方后端不可获得**：

1. 客户端没有暴露通用 REST base URL；AI Chat 是 WebView 页面，登录/会话/签名由腾讯域完成。
2. 同步/迁移/传送使用 protobuf + 设备/账号上下文；`libime_net.so` 内还有签名、重试、加密与证书固定。
3. 即使抓到请求，也缺少服务端模型、提示词、配额与合规授权；直接复用会违反服务条款并带来隐私风险。
4. 因此本项目的客户端从第一天就把 `API_BASE_URL` 作为可配置项，不依赖任何腾讯域名。

### 6.3 替代后端 API（本项目）

{table(["方法/路径", "请求", "响应", "用途"], [
    ("`POST /v1/ai/chat`", "`{messages, model?, stream?}`", "SSE 或 `{text}`", "问 AI / 多轮"),
    ("`POST /v1/ai/polish`", "`{text, mode}`", "`{text}`", "文字整理"),
    ("`POST /v1/ai/rewrite`", "`{text, style, count}`", "`{candidates[]}`", "灵动表达"),
    ("`POST /v1/ai/translate`", "`{text, source, target}`", "`{text}`", "边写边译"),
    ("`POST /v1/ai/summary`", "`{transcript, title?}`", "`{summary, bullets[]}`", "录音纪要"),
    ("`POST /v1/asr`", "multipart audio", "`{text, segments[]}`", "语音转写"),
    ("`POST /v1/sync/pair`", "`{code, device}`", "`{token, peer}`", "设备配对"),
    ("`POST /v1/sync/clipboard`", "`{token, items[]}`", "`{items[]}`", "剪贴板同步"),
    ("`POST /v1/sync/phrases`", "`{token, phrases[]}`", "`{phrases[]}`", "常用语同步"),
    ("`POST /v1/transfer/upload`", "multipart file", "`{id, sha256, size}`", "文件传送"),
    ("`GET /v1/transfer/{id}`", "—", "bytes", "下载"),
    ("`GET /health`", "—", "`{ok, model}`", "健康检查"),
])}

### 6.4 AI 数据流

![AI 数据流](assets/ai-flow.svg)

**密钥策略（强制）**：

- 服务端从环境变量 `DEEPSEEK_API_KEY` 读取；本地开发可从 `/Users/lwblx/Documents/ds_api` 注入，但**不写入仓库、不写入客户端、不打印完整 key**。
- 公开仓库只提供 `.env.example`；`.gitignore` 排除 `.env`、`*.key`、`local.properties`。
- 客户端只持有短期 app token（可选的本地配对 token），不持有模型 key。
- 日志只记录 key 的前缀与 SHA-256 短指纹（与 `AGENTS.md` 一致）。

**本仓库已实测**（`evidence/backend/smoke.json`）：`/v1/ai/chat` 返回 200 与中文回答；`/v1/ai/polish` 返回整理后的文本；配对、剪贴板、常用语、文件上传/下载均通过，下载 SHA-256 与上传一致。测试使用个人 DeepSeek 官网 key（前缀 `sk-3b…`，SHA-256 短指纹 `7854e990e85e`），完整 key 未写入仓库或日志。

### 6.5 语音/翻译状态机

- 语音：`permission → start → partial* → stop → final → punctuation → optional polish → commit`；取消时恢复进入前的 composing 范围。
- 翻译：源区 `TextWatcher` → 600 ms 防抖 → 串行请求 → 仅接受最新序号 → 宿主替换本轮范围；发送后清空本轮但保持模式。
- 所有 AI 请求支持 `cancel`、超时、重试和错误码；UI 不伪造成功结果。

![语音处理时序](assets/voice-sequence.svg)

![AI 请求时序](assets/ai-sequence.svg)

### 6.6 替换成你自己的后端

1. 按 6.3 的路径实现服务，或反向代理到现有模型/ASR/存储；保持 JSON/SSE 形状不变。
2. 客户端设置页填写 `API_BASE_URL`；Android 模拟器默认 `http://10.0.2.2:8787`，iOS 模拟器默认 `http://127.0.0.1:8787`，真机填 Mac 局域网 IP。
3. 如果启用 `WETYPE_APP_TOKEN`，客户端在 `Authorization: Bearer ...` 中携带短期 app token；模型 key 只放服务端。
4. 同步/传送需要持久化 `devices/clipboard/phrases/settings/transfers`；本仓库 `backend/app.py` 用 SQLite + 本地文件，可直接替换为你的数据库/对象存储。
5. 先用 `GET /health` 与 `POST /v1/ai/chat` 验证连通，再逐项接入语音、翻译、同步与传送。
6. 不要把腾讯的域名、签名或私有协议当作依赖；复刻版只依赖你自己的契约。

## 7. iOS 分析状态

### 7.1 能做与不能做

{table(["项目", "结果", "说明"], [
    ("iOS 原版 IPA", "未取得", "App Store 下载需要 Apple ID/购买上下文；本机没有 IPA 缓存"),
    ("已配对 iPhone 安装", "未发现", "`devicectl` 查询 bundle 中没有微信输入法"),
    ("越狱/解密设备", "无", "无法从设备导出解密 Mach-O"),
    ("iOS 二进制静态分析", "不可做", "没有 IPA/Mach-O，不能用 Android 结论冒充"),
    ("iOS 可见界面", "20 张", "iPhone Mirroring，版本 3.5.5；仅可见 UI/文案"),
])}

### 7.2 iOS 可见界面

{gallery_md('ios-20261019')}

这些图片的源文件实际是 JPEG（664×1448），历史索引曾把后缀写成 `.png` 并记录错误尺寸；本报告按修正后的元数据展示，未修改原始字节。iPhone Mirroring 的 AX 文本不是原版控件树，不能据此推断内部实现。

### 7.3 iOS 复刻策略

- **原生 SwiftUI 主应用** + **Keyboard Extension**；键盘扩展使用同一套布局规格与候选引擎的 Swift 实现。
- **Full Access**：键盘扩展需要 `RequestsOpenAccess` 才能在扩展内访问网络/共享容器；未开启时明确降级为本地输入。
- **Share Extension**：从照片/文件分享进入“隔空传送”。
- **iPad**：`NavigationSplitView` / 自适应网格；键盘扩展使用 iPad 布局（更大键距、左右分栏、悬浮键盘）。
- **不声称二进制同构**：iOS 的页面结构来自可见界面 + Android 已验证行为；差异在报告中逐项标注。

## 8. 复刻蓝图

### 8.1 三套交付物

![复刻架构](assets/reconstruction.svg)

{table(["交付物", "技术", "目标", "系统键盘", "平板"], [
    ("`clone-flutter/`", "Flutter 3.47 / Dart 3.13", "Android + iOS 通用应用", "应用内键盘 + 原生扩展壳", "自适应网格"),
    ("`clone-android/`", "Kotlin / Jetpack Compose + InputMethodService", "Android 原生", "真实 IME", "平板布局"),
    ("`clone-ios/`", "SwiftUI + UIKit keyboard extension", "iOS 原生", "Keyboard Extension", "iPad 布局"),
    ("`backend/`", "Python FastAPI（或 Node）", "AI/ASR/同步/传送", "—", "—"),
    ("`shared/`", "JSON/Dart/Kotlin/Swift 资源", "布局、词库、设计 token", "—", "—"),
])}

### 8.2 共享规格

- `shared/spec/keyboard_layouts.json`：从 36 套原版布局归一化的键位/几何/标签（只保留事实结构，重建视觉）。
- `shared/spec/design_tokens.json`：`#E6F4F2` 背景、`#FFFFFF` 卡片、`#24C891` 强调、`#333333` 主文字、`#B8BCC5` 次文字、16–20 px 圆角。
- `shared/data/pinyin.json`、`wubi.json`、`stroke.json`、`phrases.json`、`emoji.json`。
- `shared/contracts/openapi.yaml`：后端 API。

### 8.3 复刻范围矩阵

{table(["ID", "范围", "原版证据", "复刻目标"], feature_rows())}

### 8.4 算法实现要点

1. **拼音/T9**：声母韵母切分；数字串→候选音节组合；候选评分 `prefix + fuzzy + freq + user`；支持简拼、全拼、混输；固定词/删除词持久化。
2. **五笔**：86/98/新世纪三套码表（先内置常用字，后续可扩展到全表）；四码唯一上屏、第五码首选、编码提示、五笔拼音混输。
3. **笔画**：五种基本笔画 + 通配；按笔顺匹配候选；手写与笔画共享候选面板。
4. **双拼**：小鹤/自然码/微软/搜狗/智能 ABC/紫光/拼音加加；声母韵母映射表；全键盘与九宫格两种形态。
5. **手写**：8 方向量化 + 重采样 + 模板距离；先支持常用字/演示字集，UI 明确标注识别范围；全屏手写与手写找字复用同一画布。
6. **语音**：`speech_to_text`（Flutter）/ `SpeechRecognizer`（Android）/ `SFSpeechRecognizer`（iOS）；partial/final、标点、超时、取消、权限拒绝；录音笔另存音频并调用后端总结。
7. **AI**：系统提示词固定“简洁、直接、不改事实”；流式输出；取消/重试；历史只存本地；不自动发送未确认文本。
8. **同步/传送**：6 位配对码 → token；剪贴板/常用语/设置增量同步；文件分片上传/下载 + SHA-256 校验；失败可重试。

### 8.5 设计还原

{table(["Token", "值", "用途"], [
    ("背景", "`#E6F4F2`", "首页/设置页浅绿背景"),
    ("卡片", "`#FFFFFF`", "功能卡、设置卡"),
    ("强调", "`#24C891`", "主按钮、选中态、开关"),
    ("主文字", "`#333333`", "标题/正文"),
    ("次文字", "`#B8BCC5`", "说明/占位"),
    ("分隔/描边", "`#DCE7E3`", "卡片描边、键盘键描边"),
    ("圆角", "16–24 px", "卡片/键盘键/弹层"),
    ("字体", "PingFang SC / Noto Sans CJK", "中文；英文用系统 sans"),
    ("网格", "手机 2 列；平板 4 列", "首页功能/设置卡"),
])}

### 8.6 验收方式

- 每个平台至少：首次启用 → 首页 → 六种键盘 → 候选上屏 → 工具栏 → 语音 → AI → 剪贴板/常用语 → 单机/隐私 → 平板布局。
- 运行截图存 `evidence/clone-*`；HTML 报告增加“复刻实测”分组。
- 不以单元测试替代宿主内实际输入；不以静态 UI 替代跳转。

## 9. 证据附录

### 9.1 REA Evidence

{table(["操作", "Selector", "Evidence ID", "文件"], [
    (e["operation"], (e["class_name"] or "—") + (("." + e["method"]) if e["method"] else ""), f"`{e['evidence_id']}`", f"`{e['file']}`") for e in evidence
])}

### 9.2 产物清单

- `analysis/wetype.rea.json`：REA 快照（若生成）
- `analysis/apktool/`：manifest、资源、assets、lib
- `analysis/hbc/*.js`：Hermes 反编译伪 JS
- `analysis/classes.json`：13,585 类清单
- `analysis/normalized/`：报告数据
- `evidence/runtime/`：本轮运行截图与 UI XML
- `reports/assets/`：图表、画廊、缩略图
- `targets/wechat-android-4.0.0.apk`：原包（`.gitignore` 排除，避免公开仓库分发 APK）

### 9.3 限制与未决

1. iOS 无 IPA，不能做 Mach-O/扩展级分析；iOS 结论均为可见界面级。
2. 腾讯 AI/语音/同步的私有协议、模型、签名未恢复；本报告只记录客户端入口与消息名。
3. 36 套布局已提取几何/标签，但未逐套运行验证所有按键；复刻以六种用户可见模式 + 数字/符号/Emoji/手写为主。
4. Android 运行截图受 AVD 分辨率、系统版本、账号状态影响；历史截图与本轮截图分开展示。
5. 原版首页轮播/设置文案部分来自远端配置；本地 HBC 只有少量中文字面量，因此页面清单以运行截图 + 模块注册表交叉确认。
""")

md_body = "\n".join(parts)

# Add HTML galleries in the HTML version by replacing the Markdown image lists.
html_body = markdown.markdown(
    md_body,
    extensions=["tables", "fenced_code", "toc", "sane_lists"],
    extension_configs={"toc": {"toc_depth": "2-4"}},
)

# Replace each Markdown gallery section with a rich HTML gallery. The Markdown
# body keeps the portable image list; the HTML gets filters and a lightbox.
for group in ("android-20261018", "android-keyboard", "android-20261020", "ios-20261019"):
    rows = [x for x in shots if x["group"] == group]
    # Remove the generated paragraph/link list for this group from HTML by
    # replacing the first matching <p><strong>... chain is brittle. Instead,
    # append the rich gallery after the section heading and hide the plain list
    # with a marker class.
# We build the HTML from the Markdown body with explicit gallery placeholders.
# The hero already carries the document title.
html_body = re.sub(r"<h1[^>]*>.*?</h1>", "", html_body, count=1, flags=re.S)

# Replace each gallery section (heading + generated Markdown image list) with a
# rich HTML gallery. The Markdown file keeps the portable list.
for needle, group in [
    ("Android · 2026-10-18（42 步）", "android-20261018"),
    ("Android · 键盘与工具栏", "android-keyboard"),
    ("Android · 2026-10-20 复采", "android-20261020"),
    ("iOS · 可见界面（非二进制）", "ios-20261019"),
]:
    pattern = re.compile(
        r'(<h4[^>]*>[^<]*' + re.escape(needle) + r'[^<]*</h4>).*?(?=<h4|<h2|$)',
        re.S,
    )
    html_body = pattern.sub(lambda m, g=group: m.group(1) + gallery_html(g), html_body)

# Inject the hero metrics and TOC into the HTML template.
toc_html = markdown.markdown(
    "[TOC]",
    extensions=["toc"],
    extension_configs={"toc": {"toc_depth": "2-3"}},
)
# Build a cleaner TOC from headings.
headings = re.findall(r"<h([23]) id=\"([^\"]+)\">(.*?)</h\1>", html_body)
toc_items = []
for level, hid, text in headings:
    text = re.sub(r"<[^>]+>", "", text)
    toc_items.append(f'<a class="toc-l{level}" href="#{hid}">{esc(text)}</a>')
toc = "\n".join(toc_items)

template = """<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>微信输入法 REA 逆向分析与复刻蓝图</title>
<style>
:root{--bg:#e6f4f2;--card:#fff;--ink:#26332f;--muted:#5f6f69;--line:#dce7e3;--accent:#24c891;--accent2:#0e8a68;--soft:#f4fbf8;--warn:#b45309;--bad:#b23a3a;--code:#0f1f1a;--codeink:#d7fff1}
*{box-sizing:border-box}
html{scroll-behavior:smooth}
body{margin:0;background:var(--bg);color:var(--ink);font-family:-apple-system,BlinkMacSystemFont,"PingFang SC","Noto Sans CJK SC","Segoe UI",sans-serif;line-height:1.72}
a{color:var(--accent2);text-decoration:none}
a:hover{text-decoration:underline}
.layout{display:grid;grid-template-columns:290px minmax(0,1fr);max-width:1500px;margin:0 auto}
.sidebar{position:sticky;top:0;height:100vh;overflow:auto;padding:26px 20px;background:linear-gradient(180deg,#f7fffc,#eefaf5);border-right:1px solid var(--line)}
.brand{font-weight:800;font-size:17px;letter-spacing:.02em;margin:0 0 4px}
.brand small{display:block;font-weight:500;color:var(--muted);font-size:12px;margin-top:4px}
.sidebar .meta{font-size:11px;color:var(--muted);margin:14px 0 18px;padding:10px;border:1px solid var(--line);border-radius:12px;background:#fff;overflow:hidden}
.sidebar .meta code{font-size:9px;word-break:break-all;overflow-wrap:anywhere;white-space:normal;display:block;margin-top:4px;max-width:100%}
.sidebar nav{display:flex;flex-direction:column;gap:2px}
.sidebar nav a{font-size:12px;color:#3d4b46;padding:5px 8px;border-radius:7px}
.sidebar nav a:hover{background:#dff5ec;text-decoration:none}
.skip{display:block;font-size:11px;margin:0 0 10px;padding:6px 8px;border:1px solid var(--line);border-radius:8px;background:#fff;text-align:center}
.toc-l3{padding-left:18px!important;font-size:11px!important;color:#6b7a74!important}
.content{padding:36px 46px 90px;min-width:0}
.hero{background:linear-gradient(135deg,#0e8a68,#24c891 55%,#7ee7c3);color:#fff;border-radius:26px;padding:38px 40px;position:relative;overflow:hidden;box-shadow:0 18px 50px rgba(14,138,104,.22)}
.hero:after{content:"";position:absolute;right:-60px;top:-80px;width:320px;height:320px;border-radius:50%;background:rgba(255,255,255,.12)}
.hero h1{margin:0 0 10px;font-size:34px;line-height:1.25;letter-spacing:-.01em}
.hero p{margin:6px 0;color:#eafff9;max-width:960px;font-size:14px}
.hero .pill{display:inline-block;background:rgba(255,255,255,.18);border:1px solid rgba(255,255,255,.3);border-radius:999px;padding:4px 12px;font-size:12px;margin:8px 6px 0 0}
.metrics{display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:12px;margin:26px 0}
.metrics div{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:14px 16px;box-shadow:0 6px 18px rgba(38,51,47,.04)}
.metrics strong{display:block;font-size:24px;color:var(--accent2);line-height:1.1}
.metrics span{font-size:11px;color:var(--muted)}
h2{font-size:25px;margin:48px 0 12px;padding-top:8px;border-top:1px solid var(--line)}
h3{font-size:19px;margin:30px 0 8px}
h4{font-size:15px;margin:26px 0 8px;color:var(--accent2)}
p{margin:10px 0}
table{width:100%;border-collapse:separate;border-spacing:0;margin:0;background:var(--card);border:1px solid var(--line);border-radius:14px;overflow:hidden;font-size:12.5px}
.table-wrap{overflow-x:auto;margin:14px 0 20px;border-radius:14px}
th,td{text-align:left;padding:9px 11px;border-bottom:1px solid var(--line);vertical-align:top}
th{background:#f0faf6;color:#315a4d;font-weight:700;position:sticky;top:0;z-index:1}
tr:last-child td{border-bottom:none}
tr:hover td{background:#fbfffd}
code{background:#edf7f3;border:1px solid #d7ebe4;border-radius:5px;padding:1px 5px;font-size:.92em;color:#0b5e49}
pre{background:var(--code);color:var(--codeink);padding:16px 18px;border-radius:14px;overflow:auto;font-size:12px;line-height:1.6;border:1px solid #1d3b31}
pre code{background:none;border:none;color:inherit;padding:0}
blockquote{margin:16px 0;padding:12px 16px;border-left:4px solid var(--accent);background:#f4fbf8;border-radius:0 12px 12px 0;color:#3c4c46}
.gallery{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:12px;margin:14px 0 24px}
.shot{margin:0;background:var(--card);border:1px solid var(--line);border-radius:14px;overflow:hidden;box-shadow:0 4px 14px rgba(38,51,47,.04)}
.shot img{display:block;width:100%;height:260px;object-fit:contain;object-position:top;background:#f3faf7}
.shot figcaption{font-size:11px;padding:8px 10px;color:#43534d;line-height:1.45;min-height:44px}
.shot:hover{transform:translateY(-2px);transition:.15s;box-shadow:0 10px 24px rgba(14,138,104,.14)}
.keyboard-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:16px;margin:16px 0}
.keyboard-grid figure{margin:0;background:var(--card);border:1px solid var(--line);border-radius:16px;padding:10px}
.keyboard-grid img{width:100%;display:block}
.keyboard-grid figcaption{font-size:11px;color:var(--muted);padding:6px 4px 0}
.callout{border:1px solid #f1d9b0;background:#fff8eb;border-radius:14px;padding:14px 16px;margin:16px 0;color:#6b4a12}
.callout.bad{border-color:#f0c9c9;background:#fff3f3;color:#7c2d2d}
.callout.ok{border-color:#bfe6d8;background:#f2fdf9;color:#155e49}
img{max-width:100%}
.lightbox{position:fixed;inset:0;background:rgba(9,24,19,.86);display:none;align-items:center;justify-content:center;z-index:99;padding:30px}
.lightbox.open{display:flex}
.lightbox img{max-width:min(92vw,760px);max-height:88vh;border-radius:16px;box-shadow:0 20px 60px rgba(0,0,0,.4);background:#fff}
.lightbox .close{position:absolute;right:24px;top:18px;color:#fff;font-size:30px;cursor:pointer;line-height:1}
.print{position:fixed;right:18px;bottom:18px;background:var(--accent2);color:#fff;border:none;border-radius:999px;padding:10px 16px;font-size:12px;cursor:pointer;box-shadow:0 8px 20px rgba(14,138,104,.25)}
@media(max-width:1000px){.layout{grid-template-columns:1fr}.sidebar{position:relative;height:auto;border-right:none;border-bottom:1px solid var(--line)}.content{padding:22px}.metrics{grid-template-columns:repeat(3,1fr)}.hero h1{font-size:26px}}
@media(max-width:600px){.content{padding:16px}.metrics{grid-template-columns:repeat(2,1fr)}.hero{padding:24px 20px}.hero h1{font-size:23px}.sidebar{padding:18px;max-height:42vh;overflow:auto}.print{display:none}}
@media print{.sidebar,.print,.lightbox{display:none!important}.layout{display:block}.content{padding:0}.hero{box-shadow:none}}
</style>
</head>
<body>
<div class="layout">
<aside class="sidebar">
  <div class="brand">微信输入法 · REA<small>Android 4.0.0 · Reconstruction Blueprint</small></div>
  <div class="meta">APK SHA-256<br><code>__SHA__</code></div>
  <a class="skip" href="#0">跳到正文 ↓</a>
  <nav>__TOC__</nav>
</aside>
<main class="content">
<section class="hero">
  <span class="pill">REA 6.7.0</span><span class="pill">JADX bridge 0.7.1</span><span class="pill">Hermes</span><span class="pill">2026-10-20</span>
  <h1>微信输入法 Android 4.0.0<br>REA 逆向分析与复刻蓝图</h1>
  <p>从 APK 身份、RN 页面注册表、36 套键盘布局到设置模型与 AI/同步协议入口；所有结论保留证据边界。</p>
  <p>官方云服务不可获得。本报告同时给出自有后端替代方案、Flutter / Android 原生 / iOS 原生三套复刻路线，以及平板/ iPad 适配。</p>
</section>
__BODY__
</main>
</div>
<button class="print" onclick="window.print()">打印 / 导出 PDF</button>
<div class="lightbox" id="lightbox"><span class="close">&times;</span><img alt=""></div>
<script>
document.querySelectorAll('.shot a, .lightbox-link').forEach(a=>{
  a.addEventListener('click',e=>{
    const href=a.getAttribute('href');
    if(!href||!href.match(/\\.(png|jpg|jpeg|svg)$/i)) return;
    e.preventDefault();
    const lb=document.getElementById('lightbox');
    lb.querySelector('img').src=href;
    lb.classList.add('open');
  });
});
document.getElementById('lightbox').addEventListener('click',e=>{
  if(e.target.id==='lightbox'||e.target.className==='close') document.getElementById('lightbox').classList.remove('open');
});
document.querySelectorAll('.content table').forEach(t=>{
  const w=document.createElement('div'); w.className='table-wrap';
  t.parentNode.insertBefore(w,t); w.appendChild(t);
});
document.querySelectorAll('.content img').forEach(img=>{
  if(img.closest('a')) return;
  img.style.cursor='zoom-in';
  img.addEventListener('click',()=>{
    const lb=document.getElementById('lightbox');
    lb.querySelector('img').src=img.getAttribute('src');
    lb.classList.add('open');
  });
});
document.addEventListener('keydown',e=>{if(e.key==='Escape')document.getElementById('lightbox').classList.remove('open')});
</script>
</body>
</html>
"""

html_doc = template.replace("__SHA__", pkg["sha256"]).replace("__TOC__", toc).replace("__BODY__", html_body)
(REPORTS / "analysis.html").write_text(html_doc, encoding="utf-8")

# Markdown: add a compact evidence/diagram index at the top.
md_header = f"""# 微信输入法 Android 4.0.0 REA 逆向分析与复刻蓝图

> 交互版：[analysis.html](analysis.html)（图谱、键盘预览、{len(shots)} 张截图画廊、灯箱）  
> 本文：可检索、可 diff 的 Markdown 版本。图表文件在 `assets/`，截图在 `assets/images/`。

"""
# Remove the duplicate title from md_body for the final file.
md_final = md_header + md_body.split("\n", 1)[1]
(REPORTS / "analysis.md").write_text(md_final, encoding="utf-8")

print("wrote", REPORTS / "analysis.md", REPORTS / "analysis.html")
print("html bytes", (REPORTS / "analysis.html").stat().st_size)
