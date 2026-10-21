# 物理 Android 手机部署记录

日期：2026-10-21  
设备：Redmi Note 14 Pro（`24090RA29C`，`malachite`）  
系统：Android 16 / API 36 / arm64-v8a  
序列号：`OJHQLRXOIJP7XOXW`

该手机注册在独立的 ADB server 端口 **5038**，因此所有命令使用：

```bash
adb -P 5038 -s OJHQLRXOIJP7XOXW ...
```

## 安装

| 包 | 版本 | 结果 |
|---|---|---|
| `com.huapohen.wechatinput` | 1.0.0 | 安装成功 |
| `com.huapohen.wechat_input_clone` | 1.1.0 | 安装成功 |

APK 来自 `artifacts/android/wechat-input-android.apk` 与
`artifacts/flutter/wechat-input-flutter.apk`。

## 原生输入法

```bash
adb -P 5038 -s OJHQLRXOIJP7XOXW shell ime enable \
  com.huapohen.wechatinput/.ime.WeTypeCloneImeService
adb -P 5038 -s OJHQLRXOIJP7XOXW shell ime set \
  com.huapohen.wechatinput/.ime.WeTypeCloneImeService
```

- 原默认输入法为 `com.sohu.inputmethod.sogou.xiaomi/.SogouIME`。
- 部署后默认输入法已切到微输入法，便于直接体验。
- 切回搜狗：系统设置 → 输入法，或键盘左下角地球键；也可用：
  `adb shell ime set com.sohu.inputmethod.sogou.xiaomi/.SogouIME`
- 原生 App 首次启动截图：`native-home.png`；键盘体验页：`native-keyboard.png`。
- 手机屏幕为 1220×2712；原生键盘 T9 已渲染，候选栏可用。

## Flutter 版

- 已安装并首次同意隐私，进入首页：`flutter-home.png`。
- 服务设置中把 API 地址改为 `http://127.0.0.1:8787` 并保存：
  `flutter-service-saved.png`。
- 通过 USB ADB reverse 把手机 `127.0.0.1:8787` 转发到 Mac 后端：

```bash
adb -P 5038 -s OJHQLRXOIJP7XOXW reverse tcp:8787 tcp:8787
```

- 点击「检查连接」显示模型 `deepseek-chat`、密钥已配置（仅前缀/指纹）。
- 点击「测试 AI 回复」返回 **`AI 回复：OK`**：`flutter-ai-ok.png`。

## 注意

- `adb reverse` 只在当前 USB 连接/ADB server 会话内有效。拔线后请把
  服务地址改为 Mac 的局域网 IP（后端监听 `0.0.0.0:8787`），或重新执行 reverse。
- 手机上的原生 IME 是基础复刻版；Flutter 版的应用内键盘只作用于本应用输入框。
- iOS 未部署到该 Android 手机；iOS 交付为模拟器 App。
