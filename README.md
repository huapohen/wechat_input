# 微信输入法 REA 分析与三端复刻

本仓库是一份独立研究/互操作复刻，不是腾讯官方项目，也不包含腾讯的 APK、Hermes 包、字体、词库或图片资源。目标是记录微信输入法 Android 4.0.0 的可复核逆向结果，并以 Flutter、Android 原生、iOS 原生三套实现重建其信息架构、键盘交互与设置体系。

## 先看什么

- **[REA 分析报告（HTML）](reports/analysis.html)**：交互目录、架构/路由/键盘状态机图谱、36 套键盘预览、108 张运行证据、iOS 可见界面、AI/后端与复刻蓝图。
- **[REA 分析报告（Markdown）](reports/analysis.md)**：可检索、可 diff 的文本版本。
- **[项目进度](PROGRESS.md) / [进度页](PROGRESS.html)**：阶段与交付状态。
- **[共享规格](shared/CLONE_BRIEF.md)**：三端共用的页面、键盘、数据和验收约束。
- **[构建说明](BUILD.md)**：后端、Flutter、Android、iOS 的构建命令。

## 交付物

| 目录 | 内容 | 状态 |
|---|---|---|
| `reports/` | 分析报告、图表、截图画廊 | v1 完成 |
| `analysis/` | REA/JADX 证据、Hermes 反编译、规范化数据 | 完成 |
| `evidence/` | 原版与本轮运行截图、UI XML | 持续更新 |
| `backend/` | 可配置 AI/ASR/同步/传送后端 | 真实 DeepSeek 调用通过 |
| `clone-flutter/` | Flutter 通用版（Android/iOS、手机/平板） | 构建中 |
| `clone-android/` | Android 原生 + 真实 IME（手机/平板） | 构建中 |
| `clone-ios/` | iOS 原生 + Keyboard Extension（iPhone/iPad） | 构建中 |
| `shared/` | 设计 token、布局、拼音/五笔/笔画/词库 | 完成 |

## 快速开始

```bash
cd backend
python3 -m venv venv && venv/bin/pip install -r requirements.txt
export DEEPSEEK_API_KEY='sk-...'
venv/bin/python app.py
```

客户端默认连接 `http://10.0.2.2:8787`（Android 模拟器）或 `http://127.0.0.1:8787`（iOS 模拟器）。真实设备请填写 Mac 的局域网 IP。

## 边界

- 腾讯官方云服务不可获得；本项目不调用、不复刻其私有协议。AI/同步/传送全部走自有后端。
- iOS 未取得 IPA；iOS 版依据 iPhone Mirroring 可见界面 + Android 已验证行为重建，不是二进制级同构。
- 原版拼音/五笔/手写/语音的私有算法与模型未恢复；复刻使用公开词典、自建引擎、设备 ASR 与可配置模型后端。
- 三端 UI 为独立重建，不包含原版图片/字体/词库。

## 许可与来源

- 复刻代码：本仓库。
- 拼音数据：pypinyin（MIT）。
- 五笔/笔画表：Rime 字典，来源与授权见 `shared/sources/`。
- 原版截图仅用于研究与互操作分析，版权归腾讯所有。
