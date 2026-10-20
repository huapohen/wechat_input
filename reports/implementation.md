# 微输入法 · 三端复刻与验收


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

**Flutter 手机首页：轮播、功能、设置、更多**

[![Flutter 手机首页：轮播、功能、设置、更多](assets/clone/clone-flutter/android-01-home-final.png)](assets/clone/clone-flutter/android-01-home-final.png)

**Flutter 平板首页：侧栏 + 4 列网格**

[![Flutter 平板首页：侧栏 + 4 列网格](assets/clone/clone-flutter/android-01-home-tablet.png)](assets/clone/clone-flutter/android-01-home-tablet.png)

**Flutter 首启隐私与启用**

[![Flutter 首启隐私与启用](assets/clone/clone-flutter/android-00-onboarding2.png)](assets/clone/clone-flutter/android-00-onboarding2.png)

**Flutter 九宫格键盘**

[![Flutter 九宫格键盘](assets/clone/clone-flutter/android-02-keyboard-t9-fixed.png)](assets/clone/clone-flutter/android-02-keyboard-t9-fixed.png)

**Flutter T9 输入 64426，候选包含「你好」**

[![Flutter T9 输入 64426，候选包含「你好」](assets/clone/clone-flutter/android-03-t9-candidates.png)](assets/clone/clone-flutter/android-03-t9-candidates.png)

**Flutter 候选上屏到宿主 TextField**

[![Flutter 候选上屏到宿主 TextField](assets/clone/clone-flutter/android-04-committed.png)](assets/clone/clone-flutter/android-04-committed.png)

**Flutter 键盘管理**

[![Flutter 键盘管理](assets/clone/clone-flutter/android-05-ai2.png)](assets/clone/clone-flutter/android-05-ai2.png)

**Flutter 传送页：真实后端错误与重试**

[![Flutter 传送页：真实后端错误与重试](assets/clone/clone-flutter/android-05-ai3.png)](assets/clone/clone-flutter/android-05-ai3.png)

**Flutter 服务设置：真实 AI 回复 OK**

[![Flutter 服务设置：真实 AI 回复 OK](assets/clone/clone-flutter/android-07-ai-test.png)](assets/clone/clone-flutter/android-07-ai-test.png)

**Flutter AI 录音笔**

[![Flutter AI 录音笔](assets/clone/clone-flutter/android-08-recorder.png)](assets/clone/clone-flutter/android-08-recorder.png)

**Flutter 轮播卡片**

[![Flutter 轮播卡片](assets/clone/clone-flutter/android-carousel.png)](assets/clone/clone-flutter/android-carousel.png)

**Flutter iOS 平板启动**

[![Flutter iOS 平板启动](assets/clone/clone-flutter/ios-tablet-01-final-launch.png)](assets/clone/clone-flutter/ios-tablet-01-final-launch.png)


## 3. Android 原生 + 真实 IME

- 工程：`clone-android/`，Kotlin + XML Views，包名 `com.huapohen.wechatinput`。
- APK：`de21d194…`，7.0 MB。
- IME：`com.huapohen.wechatinput/.ime.WeTypeCloneImeService`，已在系统中启用/选中；系统设置搜索框中通过该 IME 输入 `gekko`，`uiautomator` 读取到宿主 EditText 的实际值。
- 键盘：T9/全键盘/手写/笔画/五笔/双拼/英文/数字/符号/Emoji；候选真实写入宿主；长按空格接系统 `SpeechRecognizer`。
- 页面：30 个页面 ID 全部路由；布局/按键/工具栏/辅助/模糊/语音/Plus/剪贴板/同步/迁移/单机/隐私/电脑版/关于/帮助/录音/传送/AI/文字工具/翻译/排版/常用语/表情。
- 平板：1600×2560 @320dpi，4 列首页 + 292dp 导航栏双栏设置。
- 已知限制：录音/语音无可用模拟麦克风，未做可听验收；SAF 上传从 UI、同步配对、下载按钮未全部点击；部分页面未逐页截图；手写为有限模板。

**Android 原生首页**

[![Android 原生首页](assets/clone/clone-android/01-home-phone.png)](assets/clone/clone-android/01-home-phone.png)

**Android 隐私与启用**

[![Android 隐私与启用](assets/clone/clone-android/02-onboarding-privacy.png)](assets/clone/clone-android/02-onboarding-privacy.png)

**Android 布局和显示**

[![Android 布局和显示](assets/clone/clone-android/03-display-settings.png)](assets/clone/clone-android/03-display-settings.png)

**Android 键盘体验 / T9**

[![Android 键盘体验 / T9](assets/clone/clone-android/04-keyboard-test-t9.png)](assets/clone/clone-android/04-keyboard-test-t9.png)

**Android T9 候选**

[![Android T9 候选](assets/clone/clone-android/05-t9-candidates.png)](assets/clone/clone-android/05-t9-candidates.png)

**Android 候选写入宿主 EditText**

[![Android 候选写入宿主 EditText](assets/clone/clone-android/06-candidate-committed.png)](assets/clone/clone-android/06-candidate-committed.png)

**Android 全键盘**

[![Android 全键盘](assets/clone/clone-android/07-qwerty.png)](assets/clone/clone-android/07-qwerty.png)

**Android nihao → 你好**

[![Android nihao → 你好](assets/clone/clone-android/08-qwerty-nihao.png)](assets/clone/clone-android/08-qwerty-nihao.png)

**Android 键盘模式选择**

[![Android 键盘模式选择](assets/clone/clone-android/09-mode-picker.png)](assets/clone/clone-android/09-mode-picker.png)

**Android 问 AI：真实后端回答**

[![Android 问 AI：真实后端回答](assets/clone/clone-android/10-ai-chat-real-backend.png)](assets/clone/clone-android/10-ai-chat-real-backend.png)

**Android 隔空传送：后端文件列表**

[![Android 隔空传送：后端文件列表](assets/clone/clone-android/11-transfer.png)](assets/clone/clone-android/11-transfer.png)

**Android 系统输入法设置中的微输入法**

[![Android 系统输入法设置中的微输入法](assets/clone/clone-android/12-ime-enabled-system-settings.png)](assets/clone/clone-android/12-ime-enabled-system-settings.png)

**Android 键盘覆盖系统设置搜索**

[![Android 键盘覆盖系统设置搜索](assets/clone/clone-android/12a-settings-ime-visible.png)](assets/clone/clone-android/12a-settings-ime-visible.png)

**Android 通过 IME 在系统设置输入 gekko**

[![Android 通过 IME 在系统设置输入 gekko](assets/clone/clone-android/12b-settings-search-typing.png)](assets/clone/clone-android/12b-settings-search-typing.png)

**Android 平板 4 列首页**

[![Android 平板 4 列首页](assets/clone/clone-android/13-tablet-home.png)](assets/clone/clone-android/13-tablet-home.png)

**Android 平板双栏设置**

[![Android 平板双栏设置](assets/clone/clone-android/14-tablet-settings-two-pane.png)](assets/clone/clone-android/14-tablet-settings-two-pane.png)

**Android 常用语**

[![Android 常用语](assets/clone/clone-android/15-phrases.png)](assets/clone/clone-android/15-phrases.png)

**Android API 地址设置**

[![Android API 地址设置](assets/clone/clone-android/16-api-dialog.png)](assets/clone/clone-android/16-api-dialog.png)

**Android 首页设置网格**

[![Android 首页设置网格](assets/clone/clone-android/17-home-settings-grid.png)](assets/clone/clone-android/17-home-settings-grid.png)

**Android 隐私与权限（独立复核）**

[![Android 隐私与权限（独立复核）](assets/clone/clone-android/pages-privacy-manual.png)](assets/clone/clone-android/pages-privacy-manual.png)

**Android 定制工具栏（独立复核）**

[![Android 定制工具栏（独立复核）](assets/clone/clone-android/pages-toolbar-manual.png)](assets/clone/clone-android/pages-toolbar-manual.png)

**Android 键盘管理（独立复核）**

[![Android 键盘管理（独立复核）](assets/clone/clone-android/pages-keyboard_manage.png)](assets/clone/clone-android/pages-keyboard_manage.png)

**Android 拼写 Plus（独立复核）**

[![Android 拼写 Plus（独立复核）](assets/clone/clone-android/pages-plus.png)](assets/clone/clone-android/pages-plus.png)

**Android 单机模式（独立复核）**

[![Android 单机模式（独立复核）](assets/clone/clone-android/pages-standalone.png)](assets/clone/clone-android/pages-standalone.png)

**Android 语音转文字（独立复核）**

[![Android 语音转文字（独立复核）](assets/clone/clone-android/pages-voice.png)](assets/clone/clone-android/pages-voice.png)


## 4. iOS 原生 + Keyboard Extension

- 工程：`clone-ios/`，SwiftUI 主应用 + `WeTypeKeyboard.appex`，Bundle ID `com.huapohen.wechatinput.ios` / `.keyboard`。
- 已验证：在模拟器 Safari 本地宿主页中，扩展提交 **`你好abc`**；候选 `nihao → 你好`；Full Access 开关流程；iPhone/iPad 启动。
- 页面：首页、布局、按键、工具栏、语音、Plus、剪贴板、同步、单机、隐私、关于、帮助、录音、传送、AI、文字工具、翻译、排版、常用语、Emoji、键盘管理。
- iPad：`NavigationSplitView` 侧栏 + 4 列首页 + 加宽键盘。
- 已知限制：无 IPA/真机签名；手写为 20 字方向模板；语音依赖系统识别；扩展在未开启 Full Access 时降级；UI 测试中的键盘启用流程有环境相关失败，但 `你好abc` 已通过实际宿主页验证。

**iOS 首页**

[![iOS 首页](assets/clone/clone-ios/02-home.png)](assets/clone/clone-ios/02-home.png)

**iOS 布局和显示**

[![iOS 布局和显示](assets/clone/clone-ios/03-display.png)](assets/clone/clone-ios/03-display.png)

**iOS 应用内键盘与候选**

[![iOS 应用内键盘与候选](assets/clone/clone-ios/04-keyboard-inapp.png)](assets/clone/clone-ios/04-keyboard-inapp.png)

**iOS 键盘扩展在 Safari 提交「你好abc」**

[![iOS 键盘扩展在 Safari 提交「你好abc」](assets/clone/clone-ios/05-safari-keyboard.png)](assets/clone/clone-ios/05-safari-keyboard.png)

**iOS 键盘扩展候选：nihao → 你好**

[![iOS 键盘扩展候选：nihao → 你好](assets/clone/clone-ios/05-safari-candidates.png)](assets/clone/clone-ios/05-safari-candidates.png)

**iOS 添加键盘**

[![iOS 添加键盘](assets/clone/clone-ios/06-settings-add-list.png)](assets/clone/clone-ios/06-settings-add-list.png)

**iOS 键盘设置**

[![iOS 键盘设置](assets/clone/clone-ios/06-settings-keyboard.png)](assets/clone/clone-ios/06-settings-keyboard.png)

**iOS Full Access**

[![iOS Full Access](assets/clone/clone-ios/06-settings-fullaccess.png)](assets/clone/clone-ios/06-settings-fullaccess.png)

**iOS 问 AI：真实后端**

[![iOS 问 AI：真实后端](assets/clone/clone-ios/07-ai-chat.png)](assets/clone/clone-ios/07-ai-chat.png)

**iOS 文字工具**

[![iOS 文字工具](assets/clone/clone-ios/08-text-tools.png)](assets/clone/clone-ios/08-text-tools.png)

**iOS 隔空传送**

[![iOS 隔空传送](assets/clone/clone-ios/09-transfer.png)](assets/clone/clone-ios/09-transfer.png)

**iPad 首页**

[![iPad 首页](assets/clone/clone-ios/10-ipad-home.png)](assets/clone/clone-ios/10-ipad-home.png)

**iPad 键盘**

[![iPad 键盘](assets/clone/clone-ios/11-ipad-keyboard.png)](assets/clone/clone-ios/11-ipad-keyboard.png)

**iPad 问 AI**

[![iPad 问 AI](assets/clone/clone-ios/12-ipad-ai.png)](assets/clone/clone-ios/12-ipad-ai.png)

**iOS 语音**

[![iOS 语音](assets/clone/clone-ios/13-voice.png)](assets/clone/clone-ios/13-voice.png)

**iOS 排版成图**

[![iOS 排版成图](assets/clone/clone-ios/14-poster.png)](assets/clone/clone-ios/14-poster.png)


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

```bash
# backend
cd backend && venv/bin/python app.py

# Flutter
cd clone-flutter
/Users/lwblx/flutter/bin/flutter build apk --release
/Users/lwblx/flutter/bin/flutter build ios --simulator --no-codesign

# Android native
cd clone-android && ./gradlew assembleDebug

# iOS native
cd clone-ios
xcodebuild -project WeTypeClone.xcodeproj -scheme WeTypeClone -sdk iphonesimulator -configuration Debug build
```

## 8. 边界与后续

1. 腾讯官方 AI/语音/同步/迁移后端不可获得；本项目不调用、不复刻其私有协议。
2. iOS 原版无 IPA；iOS 复刻依据可见界面 + Android 证据，不是二进制同构。
3. 手写、五笔、双拼、候选排序为公开数据/自建引擎；不是腾讯私有模型。
4. 语音在模拟器上缺少可用麦克风，录音/转写需真机或可注入音频再验收。
5. 工具栏触摸、SAF 上传、同步配对、下载按钮仍有未逐项点击的路径；代码已实现，报告中不把它们标为已验收。
6. 所有原版截图仅用于互操作研究；复刻 App 不包含腾讯图片/字体/词库。
