# 项目进度 / Progress

更新时间：2026-10-20 20:05

| 阶段 | 状态 | 交付 |
|---|---|---|
| REA Android 静态分析 | 完成 | 包身份、13,585 类、1,890 应用类、36 套键盘、设置模型、RN 模块、SchemeAction、组件清单 |
| 原版运行采集 | 完成 | 42 步历史截图 + 本轮 39 张 + 7 张键盘图 + 20 张 iOS 可见界面 |
| 分析报告 | 完成 v1 | `reports/analysis.md`、`reports/analysis.html`（图谱/键盘预览/截图画廊） |
| 共享规格与词库 | 完成 | `shared/spec/*`、`shared/data/*`（2.7 MB） |
| 替代后端 | 完成并真实调用 | `backend/`，DeepSeek `deepseek-chat` 返回 200 |
| Flutter 通用版 | 进行中 | `clone-flutter/` |
| Android 原生 IME | 进行中 | `clone-android/` |
| iOS 原生 + 键盘扩展 | 进行中 | `clone-ios/` |
| 平板/iPad 适配 | 进行中 | 三端自适应 |
| 复刻验收截图 | 待开始 | 安装、模拟使用、截图、parity review |
| GitHub 推送 | 待开始 | `https://github.com/huapohen/wechat_input` |

## 关键决策

- 原版腾讯云不可用；客户端不包含模型 key，统一走可配置 `API_BASE_URL`。
- 键盘布局取自 APK 的几何/标签事实，视觉与代码为独立重建。
- iOS 无 IPA，不能做二进制分析；iOS 版按可见界面 + Android 证据重建。
- 三端共享 `shared/`，但不共享 UI 框架；Flutter 与两端原生独立实现。
