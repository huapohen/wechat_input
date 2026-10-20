# 项目进度 / Progress

更新时间：2026-10-20 21:22

| 阶段 | 状态 | 交付 |
|---|---|---|
| REA Android 静态分析 | 完成 | 包身份、13,585 类、1,890 应用类、36 套键盘、设置模型、RN 模块、SchemeAction、组件清单 |
| 原版运行采集 | 完成 | 42 步历史截图 + 本轮 36 张 + 7 张键盘图 + 20 张 iOS 可见界面 |
| 分析报告 | 完成 v1 | `reports/analysis.md`、`reports/analysis.html`（图谱/键盘预览/截图画廊） |
| 共享规格与词库 | 完成 | `shared/spec/*`、`shared/data/*`（2.7 MB） |
| 替代后端 | 完成并真实调用 | `backend/`；AI/整理/配对/剪贴板/常用语/上传下载均通过 |
| Flutter 通用版 | 完成 | APK `0fd0ca2c…`；T9「你好」上屏、AI 真实回复、平板 4 列；iOS 模拟器 App |
| Android 原生 IME | 完成 | APK `de21d194…`；真实 IME、系统设置宿主输入 `gekko`、AI、平板双栏 |
| iOS 原生 + 键盘扩展 | 完成 | 模拟器 App + Keyboard Extension；Safari 宿主值 **`你好abc`**；iPad 侧栏 |
| 平板/iPad 适配 | 完成 | Flutter/Android/iPad 均有运行截图 |
| 复刻验收截图 | 完成 | Flutter 14、Android 20+、iOS 18；见 `evidence/clone-*` |
| 实现验收报告 | 完成 | `reports/implementation.md`、`reports/implementation.html` |
| GitHub 推送 | 完成 | `https://github.com/huapohen/wechat_input`（main，公开） |

## 关键决策

- 原版腾讯云不可用；客户端不包含模型 key，统一走可配置 `API_BASE_URL`。
- 键盘布局取自 APK 的几何/标签事实，视觉与代码为独立重建。
- iOS 无 IPA，不能做二进制分析；iOS 版按可见界面 + Android 证据重建，不是二进制同构。
- 三端共享 `shared/`，但不共享 UI 框架；Flutter 与两端原生独立实现。

## 未完成/限制

- iOS 只有模拟器 App，无开发签名，不能产出可安装 IPA。
- 模拟器无可用麦克风，语音转写/录音未做可听验收。
- 手写是 20 字方向模板；五笔/双拼使用公开表/简化映射，不是腾讯私有模型。
- Android 部分页面的工具栏触摸、SAF 上传 UI、同步配对按钮未逐项点击；实现存在，报告不标为已验收。
