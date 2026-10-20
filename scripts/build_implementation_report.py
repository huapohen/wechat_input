#!/usr/bin/env python3
"""Build reports/implementation.md and .html from clone evidence."""
from __future__ import annotations

import json
import re
import shutil
from pathlib import Path

import markdown

ROOT = Path(__file__).resolve().parents[1]


def code(text, lang=""):
    return f"```{lang}\n{text}\n```"
REPORTS = ROOT / "reports"
EVID = ROOT / "evidence"

FLUTTER = [
    ("android-01-home-final.png", "Flutter 手机首页：轮播、功能、设置、更多"),
    ("android-01-home-tablet.png", "Flutter 平板首页：侧栏 + 4 列网格"),
    ("android-00-onboarding2.png", "Flutter 首启隐私与启用"),
    ("android-02-keyboard-t9-fixed.png", "Flutter 九宫格键盘"),
    ("android-03-t9-candidates.png", "Flutter T9 输入 64426，候选包含「你好」"),
    ("android-04-committed.png", "Flutter 候选上屏到宿主 TextField"),
    ("android-05-ai2.png", "Flutter 键盘管理"),
    ("android-05-ai3.png", "Flutter 传送页：真实后端错误与重试"),
    ("android-07-ai-test.png", "Flutter 服务设置：真实 AI 回复 OK"),
    ("android-08-recorder.png", "Flutter AI 录音笔"),
    ("android-carousel.png", "Flutter 轮播卡片"),
    ("ios-tablet-01-final-launch.png", "Flutter iOS 平板启动"),
]
ANDROID = [
    ("01-home-phone.png", "Android 原生首页"),
    ("02-onboarding-privacy.png", "Android 隐私与启用"),
    ("03-display-settings.png", "Android 布局和显示"),
    ("04-keyboard-test-t9.png", "Android 键盘体验 / T9"),
    ("05-t9-candidates.png", "Android T9 候选"),
    ("06-candidate-committed.png", "Android 候选写入宿主 EditText"),
    ("07-qwerty.png", "Android 全键盘"),
    ("08-qwerty-nihao.png", "Android nihao → 你好"),
    ("09-mode-picker.png", "Android 键盘模式选择"),
    ("10-ai-chat-real-backend.png", "Android 问 AI：真实后端回答"),
    ("11-transfer.png", "Android 隔空传送：后端文件列表"),
    ("12-ime-enabled-system-settings.png", "Android 系统输入法设置中的微输入法"),
    ("12a-settings-ime-visible.png", "Android 键盘覆盖系统设置搜索"),
    ("12b-settings-search-typing.png", "Android 通过 IME 在系统设置输入 gekko"),
    ("13-tablet-home.png", "Android 平板 4 列首页"),
    ("14-tablet-settings-two-pane.png", "Android 平板双栏设置"),
    ("15-phrases.png", "Android 常用语"),
    ("16-api-dialog.png", "Android API 地址设置"),
    ("17-home-settings-grid.png", "Android 首页设置网格"),
    ("pages/privacy-manual.png", "Android 隐私与权限（独立复核）"),
    ("pages/toolbar-manual.png", "Android 定制工具栏（独立复核）"),
    ("pages/keyboard_manage.png", "Android 键盘管理（独立复核）"),
    ("pages/plus.png", "Android 拼写 Plus（独立复核）"),
    ("pages/standalone.png", "Android 单机模式（独立复核）"),
    ("pages/voice.png", "Android 语音转文字（独立复核）"),
]
IOS = [
    ("02-home.png", "iOS 首页"),
    ("03-display.png", "iOS 布局和显示"),
    ("04-keyboard-inapp.png", "iOS 应用内键盘与候选"),
    ("05-safari-keyboard.png", "iOS 键盘扩展在 Safari 提交「你好abc」"),
    ("05-safari-candidates.png", "iOS 键盘扩展候选：nihao → 你好"),
    ("06-settings-add-list.png", "iOS 添加键盘"),
    ("06-settings-keyboard.png", "iOS 键盘设置"),
    ("06-settings-fullaccess.png", "iOS Full Access"),
    ("07-ai-chat.png", "iOS 问 AI：真实后端"),
    ("08-text-tools.png", "iOS 文字工具"),
    ("09-transfer.png", "iOS 隔空传送"),
    ("10-ipad-home.png", "iPad 首页"),
    ("11-ipad-keyboard.png", "iPad 键盘"),
    ("12-ipad-ai.png", "iPad 问 AI"),
    ("13-voice.png", "iOS 语音"),
    ("14-poster.png", "iOS 排版成图"),
]


def local_shot(platform, f):
    src = EVID / platform / f
    if not src.exists():
        return None
    name = f.replace("/", "-")
    dst = REPORTS / "assets" / "clone" / platform / name
    dst.parent.mkdir(parents=True, exist_ok=True)
    if not dst.exists():
        shutil.copy2(src, dst)
    return f"assets/clone/{platform}/{name}"


def gallery_md(items, platform):
    out = []
    for f, cap in items:
        p = local_shot(platform, f)
        if p:
            out.append(f"**{cap}**\n\n[![{cap}]({p})]({p})\n")
    return "\n".join(out)


def gallery_html(items, platform):
    cards = []
    for f, cap in items:
        p = local_shot(platform, f)
        if p:
            cards.append(
                f'<figure class="shot"><a class="lb" href="{p}"><img src="{p}" alt="{cap}" loading="lazy"></a>'
                f"<figcaption>{cap}</figcaption></figure>"
            )
    return f'<div class="gallery">{ "".join(cards) }</div>'


body = f"""# 微输入法 · 三端复刻与验收

**日期**：2026-10-20 · **状态**：可运行交付  
**范围**：Flutter 通用版（Android/iOS、手机/平板）、Android 原生 + 真实 IME、iOS 原生 + Keyboard Extension、替代后端。  
**原则**：独立研究/互操作复刻；不包含腾讯二进制资源、字体、词库或模型密钥；官方云服务不可用。

## 0. 交付矩阵

| 交付物 | 产物 | 大小 | SHA-256 | 状态 |
|---|---|---|---|---|
| Flutter APK | [`artifacts/flutter/wechat-input-flutter.apk`](../artifacts/flutter/wechat-input-flutter.apk) | 57 MB | `0fd0ca2c…42434` | 启动/首页/T9/AI/平板已验证 |
| Android 原生 APK | [`artifacts/android/wechat-input-android.apk`](../artifacts/android/wechat-input-android.apk) | 7.0 MB | `de21d194…26d3c` | IME/系统宿主输入/AI/平板已验证 |
| iOS 模拟器 App | [`artifacts/ios/WeTypeClone-simulator.app.zip`](../artifacts/ios/WeTypeClone-simulator.app.zip) | 8.8 MB | `56198a4b…5d6148` | 主应用 + Keyboard Extension；`你好abc` 已验证 |
| Flutter iOS App | [`artifacts/flutter/WeTypeRunner-simulator.app.zip`](../artifacts/flutter/WeTypeRunner-simulator.app.zip) | 57 MB | `46b204db…c324` | 模拟器启动；交互覆盖较少 |
| 后端 | [`backend/app.py`](../backend/app.py) | — | — | AI/同步/传送真实冒烟通过 |

> iOS 未生成可安装 IPA：本机没有可用的开发签名团队。交付的是模拟器 `.app`/`.app.zip`；真机 IPA 需在 Xcode 中选择你的开发者账号后 Archive。iOS 原版也没有 IPA，不能做二进制级逆向。

## 1. 替代后端

`backend/app.py` 提供 `/v1/ai/*`、`/v1/asr`、`/v1/sync/*`、`/v1/transfer/*`。模型 key 仅在服务端；客户端只保存 base URL 和可选 app token。

{code('''GET  /health
POST /v1/ai/chat        # SSE 或 JSON
POST /v1/ai/polish
POST /v1/ai/rewrite
POST /v1/ai/translate
POST /v1/ai/summary
POST /v1/sync/pair
POST /v1/sync/clipboard
POST /v1/sync/phrases
POST /v1/transfer/upload
GET  /v1/transfer/{id}''', "text") if False else ""}

真实冒烟（`evidence/backend/smoke.json`）：

- `/v1/ai/chat` 200，返回中文回答；
- `/v1/ai/polish` 200，返回「我们明天下午三点开会吧。」；
- `/v1/sync/pair`、剪贴板、常用语 200；
- 文件上传/下载 200，下载 SHA-256 与上传一致；
- 使用个人 DeepSeek 官网 key（前缀 `sk-3b…`，短指纹 `7854e990e85e`），完整 key 未进入仓库或日志。

## 2. Flutter 通用版

- 工程：`clone-flutter/`，包名 `com.huapohen.wechat_input_clone`。
- APK：`0fd0ca2c…`，release，已安装到 `emulator-5592` 并启动。
- 页面：首页 9 卡轮播、功能/设置/更多、布局/按键/工具栏/辅助/模糊/语音/Plus/剪贴板/同步/迁移/单机/隐私/电脑版/关于/帮助、录音笔、传送、AI、文字工具、翻译、排版、常用语、表情、键盘管理。
- 键盘：应用内 T9/QWERTY/手写/笔画/五笔/双拼/英文/数字/符号/Emoji；候选来自 `shared/data`；T9 `64426` 选出「你好」并真实写入宿主 `TextField`。
- AI：服务设置中的「测试 AI 回复」返回真实 `OK`；AI 聊天/文字工具/翻译/录音摘要均走后端。
- 平板：`wm size 2048x2732` + density 320，侧栏 + 4 列首页。
- 已知限制：工具栏触摸导航未在此轮验证；iOS 交互覆盖只有启动/隐私；`shared_preferences_android` 需 pin 到 2.4.28；构建使用隔离 Gradle home + Aliyun 镜像。

{gallery_md(FLUTTER, "clone-flutter")}

## 3. Android 原生 + 真实 IME

- 工程：`clone-android/`，Kotlin + XML Views，包名 `com.huapohen.wechatinput`。
- APK：`de21d194…`，7.0 MB。
- IME：`com.huapohen.wechatinput/.ime.WeTypeCloneImeService`，已在系统中启用/选中；系统设置搜索框中通过该 IME 输入 `gekko`，`uiautomator` 读取到宿主 EditText 的实际值。
- 键盘：T9/全键盘/手写/笔画/五笔/双拼/英文/数字/符号/Emoji；候选真实写入宿主；长按空格接系统 `SpeechRecognizer`。
- 页面：30 个页面 ID 全部路由；布局/按键/工具栏/辅助/模糊/语音/Plus/剪贴板/同步/迁移/单机/隐私/电脑版/关于/帮助/录音/传送/AI/文字工具/翻译/排版/常用语/表情。
- 平板：1600×2560 @320dpi，4 列首页 + 292dp 导航栏双栏设置。
- 已知限制：录音/语音无可用模拟麦克风，未做可听验收；SAF 上传从 UI、同步配对、下载按钮未全部点击；部分页面未逐页截图；手写为有限模板。

{gallery_md(ANDROID, "clone-android")}

## 4. iOS 原生 + Keyboard Extension

- 工程：`clone-ios/`，SwiftUI 主应用 + `WeTypeKeyboard.appex`，Bundle ID `com.huapohen.wechatinput.ios` / `.keyboard`。
- 已验证：在模拟器 Safari 本地宿主页中，扩展提交 **`你好abc`**；候选 `nihao → 你好`；Full Access 开关流程；iPhone/iPad 启动。
- 页面：首页、布局、按键、工具栏、语音、Plus、剪贴板、同步、单机、隐私、关于、帮助、录音、传送、AI、文字工具、翻译、排版、常用语、Emoji、键盘管理。
- iPad：`NavigationSplitView` 侧栏 + 4 列首页 + 加宽键盘。
- 已知限制：无 IPA/真机签名；手写为 20 字方向模板；语音依赖系统识别；扩展在未开启 Full Access 时降级；UI 测试中的键盘启用流程有环境相关失败，但 `你好abc` 已通过实际宿主页验证。

{gallery_md(IOS, "clone-ios")}

## 5. 平板 / iPad

| 平台 | 证据 | 结果 |
|---|---|---|
| Flutter 平板 | `android-01-home-tablet.png` | 侧栏 + 4 列 + 1180 最大宽度 |
| Android 平板 | `13-tablet-home.png`、`14-tablet-settings-two-pane.png` | 4 列 + 双栏设置 |
| iPad | `10-ipad-home.png`、`11-ipad-keyboard.png`、`12-ipad-ai.png` | 侧栏 + 4 列 + 加宽键盘 |

## 6. 功能核对（真实执行）

| 项 | Flutter | Android 原生 | iOS 原生 |
|---|---|---|---|
| 首页/页面跳转 | 通过（截图） | 通过（截图 + 页面清单） | 通过（截图 + UI 测试代码） |
| 系统键盘 | 应用内键盘 | **真实 IME + 系统宿主** | **Keyboard Extension + Safari** |
| T9 → 候选 → 上屏 | 通过 | 通过 | 通过 |
| AI 真实回复 | 通过（8797 后端副本） | 通过（8787） | 通过（8788 后端副本） |
| 平板/iPad | 通过 | 通过 | 通过 |
| 语音 | 页面/系统识别入口 | 代码/权限，未可听验收 | 页面/系统识别入口 |
| 传送 | 页面/错误状态 | 后端列表/上传代码 | 页面 |
| 同步/迁移 | 页面/后端契约 | 页面/后端契约 | 页面/后端契约 |

## 7. 构建与运行

{code('''# backend
cd backend && venv/bin/python app.py

# Flutter
cd clone-flutter
/Users/lwblx/flutter/bin/flutter build apk --release
/Users/lwblx/flutter/bin/flutter build ios --simulator --no-codesign

# Android native
cd clone-android && ./gradlew assembleDebug

# iOS native
cd clone-ios
xcodebuild -project WeTypeClone.xcodeproj -scheme WeTypeClone -sdk iphonesimulator -configuration Debug build''', "bash")}

## 8. 边界与后续

1. 腾讯官方 AI/语音/同步/迁移后端不可获得；本项目不调用、不复刻其私有协议。
2. iOS 原版无 IPA；iOS 复刻依据可见界面 + Android 证据，不是二进制同构。
3. 手写、五笔、双拼、候选排序为公开数据/自建引擎；不是腾讯私有模型。
4. 语音在模拟器上缺少可用麦克风，录音/转写需真机或可注入音频再验收。
5. 工具栏触摸、SAF 上传、同步配对、下载按钮仍有未逐项点击的路径；代码已实现，报告中不把它们标为已验收。
6. 所有原版截图仅用于互操作研究；复刻 App 不包含腾讯图片/字体/词库。
"""

md = "# 微输入法 · 三端复刻与验收\n\n" + body.split("\n", 1)[1]
(REPORTS / "implementation.md").write_text(md, encoding="utf-8")

html_body = markdown.markdown(body, extensions=["tables", "fenced_code", "toc", "sane_lists"])
html_body = re.sub(r"<h1[^>]*>.*?</h1>", "", html_body, count=1, flags=re.S)
html_body = html_body.replace(
    "<h2 id=\"2-flutter\">2. Flutter 通用版</h2>",
    "<h2 id=\"2-flutter\">2. Flutter 通用版</h2>" + gallery_html(FLUTTER, "clone-flutter"),
)
html_body = html_body.replace(
    "<h2 id=\"3-android-ime\">3. Android 原生 + 真实 IME</h2>",
    "<h2 id=\"3-android-ime\">3. Android 原生 + 真实 IME</h2>" + gallery_html(ANDROID, "clone-android"),
)
html_body = html_body.replace(
    "<h2 id=\"4-ios-keyboard-extension\">4. iOS 原生 + Keyboard Extension</h2>",
    "<h2 id=\"4-ios-keyboard-extension\">4. iOS 原生 + Keyboard Extension</h2>" + gallery_html(IOS, "clone-ios"),
)
# Remove the plain Markdown image lists from the HTML (rich gallery replaces them).
html_body = re.sub(r'<p><strong>[^<]+</strong></p>\s*<p><a href="assets/clone/[^"]+"><img[^>]+></a></p>', "", html_body, flags=re.S)

# Remove the plain Markdown image list from the HTML (the rich gallery replaces it).
html_body = re.sub(r'<p><strong>[^<]+</strong></p>\s*<p><a href="(?:../)?evidence/[^"]+"><img[^>]+></a></p>', "", html_body, flags=re.S)

toc = []
for m in re.finditer(r'<h([23]) id="([^"]+)">(.*?)</h\1>', html_body):
    level, hid, text = m.groups()
    text = re.sub(r"<[^>]+>", "", text)
    toc.append(f'<a class="toc-l{level}" href="#{hid}">{text}</a>')

template = """<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>微输入法 · 三端复刻与验收</title>
<style>
:root{--bg:#e6f4f2;--card:#fff;--ink:#26332f;--muted:#5f6f69;--line:#dce7e3;--accent:#24c891;--accent2:#0e8a68}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font-family:-apple-system,"PingFang SC","Noto Sans CJK SC",sans-serif;line-height:1.7}
.layout{display:grid;grid-template-columns:280px minmax(0,1fr);max-width:1440px;margin:0 auto}
.sidebar{position:sticky;top:0;height:100vh;overflow:auto;padding:24px 18px;background:#f5fdf9;border-right:1px solid var(--line)}
.brand{font-weight:800;font-size:16px;margin-bottom:10px}.brand small{display:block;color:var(--muted);font-size:11px;font-weight:500;margin-top:4px}
.sidebar nav{display:flex;flex-direction:column;gap:2px}.sidebar nav a{font-size:12px;color:#3d4b46;padding:5px 8px;border-radius:7px;text-decoration:none}.sidebar nav a:hover{background:#dff5ec}.toc-l3{padding-left:18px!important;font-size:11px!important;color:#6b7a74!important}
.content{padding:32px 44px 80px;min-width:0}
.hero{background:linear-gradient(135deg,#0e8a68,#24c891 60%,#8ce9c9);color:#fff;border-radius:24px;padding:32px 34px;box-shadow:0 18px 50px rgba(14,138,104,.2)}
.hero h1{margin:0 0 8px;font-size:30px}.hero p{margin:6px 0;color:#eafff9;font-size:14px}
.pill{display:inline-block;background:rgba(255,255,255,.18);border:1px solid rgba(255,255,255,.3);border-radius:999px;padding:4px 11px;font-size:12px;margin:8px 6px 0 0}
h2{font-size:23px;margin:42px 0 10px;border-top:1px solid var(--line);padding-top:8px}h3{font-size:18px;margin:26px 0 8px}
table{width:100%;border-collapse:separate;border-spacing:0;margin:14px 0 20px;background:var(--card);border:1px solid var(--line);border-radius:14px;overflow:hidden;font-size:12.5px}
th,td{text-align:left;padding:9px 11px;border-bottom:1px solid var(--line);vertical-align:top}th{background:#f0faf6;color:#315a4d}
code{background:#edf7f3;border:1px solid #d7ebe4;border-radius:5px;padding:1px 5px;color:#0b5e49}
pre{background:#0f1f1a;color:#d7fff1;padding:15px 17px;border-radius:14px;overflow:auto;font-size:12px}
.gallery{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:12px;margin:14px 0 22px}
.shot{margin:0;background:#fff;border:1px solid var(--line);border-radius:14px;overflow:hidden}.shot img{width:100%;height:250px;object-fit:contain;background:#f3faf7}.shot figcaption{font-size:11px;padding:8px 10px;color:#43534d;line-height:1.45;min-height:42px}.shot:hover{box-shadow:0 10px 24px rgba(14,138,104,.14)}
.lightbox{position:fixed;inset:0;background:rgba(9,24,19,.86);display:none;align-items:center;justify-content:center;z-index:99;padding:30px}.lightbox.open{display:flex}.lightbox img{max-width:92vw;max-height:88vh;border-radius:14px}.lightbox .close{position:absolute;right:24px;top:16px;color:#fff;font-size:30px;cursor:pointer}
@media(max-width:900px){.layout{grid-template-columns:1fr}.sidebar{position:relative;height:auto}.content{padding:18px}.gallery{grid-template-columns:repeat(2,1fr)}}
</style></head><body><div class="layout"><aside class="sidebar"><div class="brand">微输入法 · 验收<small>Flutter · Android · iOS</small></div><nav>__TOC__</nav></aside><main class="content"><section class="hero"><span class="pill">Analysis → Build → Run</span><span class="pill">2026-10-20</span><h1>微输入法 · 三端复刻与验收</h1><p>Flutter 通用版、Android 真实 IME、iOS Keyboard Extension；后端、平板/iPad 与真实 AI 调用。</p><p>结论先行：三端都可运行；边界与未验收项在文中明确列出。</p></section>__BODY__</main></div><div class="lightbox" id="lightbox"><span class="close">&times;</span><img alt=""></div>
<script>
document.querySelectorAll('.lb,.gallery a').forEach(a=>a.addEventListener('click',e=>{const h=a.getAttribute('href');if(!h)return;e.preventDefault();const lb=document.getElementById('lightbox');lb.querySelector('img').src=h;lb.classList.add('open');}));
document.getElementById('lightbox').addEventListener('click',e=>{if(e.target.id==='lightbox'||e.target.className==='close')document.getElementById('lightbox').classList.remove('open');});
document.addEventListener('keydown',e=>{if(e.key==='Escape')document.getElementById('lightbox').classList.remove('open');});
</script></body></html>"""

html = template.replace("__TOC__", "\n".join(toc)).replace("__BODY__", html_body)
(REPORTS / "implementation.html").write_text(html, encoding="utf-8")
print("wrote implementation.md/html", len(html))
