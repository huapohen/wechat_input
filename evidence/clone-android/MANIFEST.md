# Evidence manifest — native Android clone

Device: **emulator-5580** (console 5580, adb serial `127.0.0.1:5581`),
AVD `WeChatInput_API_36`, 1344 × 2992 @ 480 dpi, Android 36.
Tablet captures: same emulator resized to 1600 × 2560 @ 320 dpi, then restored.
Backend: `http://10.0.2.2:8787`. Captured 2026-10-20.

| # | File | What it shows |
|---|---|---|
| 01 | `01-home-phone.png` | Phone home: mint header, wordmark, status “已启用”, 9-card carousel, 功能/设置/更多 |
| 02 | `02-onboarding-privacy.png` | Onboarding/privacy page with enable step, data disclosures and consent |
| 03 | `03-display-settings.png` | 布局和显示: sliders, switches, theme, API 地址 row, preview link |
| 04 | `04-keyboard-test-t9.png` | 键盘体验 page with T9 keyboard over a real host EditText |
| 05 | `05-t9-candidates.png` | T9 buffer `64`; candidate bar shows 你/尼/妮… |
| 06 | `06-candidate-committed.png` | Host EditText after commit: 尼你好; candidate bar reset |
| 07 | `07-qwerty.png` | 全键盘拼音 layout (toast confirms mode switch) |
| 08 | `08-qwerty-nihao.png` | QWERTY buffer `nihao` with candidate 你好 |
| 09 | `09-mode-picker.png` | In-keyboard mode picker (九宫格/全键盘/手写/笔画/五笔…) |
| 10 | `10-ai-chat-real-backend.png` | 问 AI multi-turn UI with a real backend translation of 今天天气很好 |
| 11 | `11-transfer.png` | 隔空传送 with backend file list (`wetype-transfer.txt`, `smoke.txt`) |
| 12 | `12-ime-enabled-system-settings.png` | Android system IME settings showing 微输入法 enabled |
| 12a | `12a-settings-ime-visible.png` | 微输入法 keyboard shown over Android Settings search |
| 12b | `12b-settings-search-typing.png` | Text `gekko` committed by the IME into Settings search (real system app) |
| 13 | `13-tablet-home.png` | Tablet home at sw≈800dp: 4-column grid, wide header |
| 14 | `14-tablet-settings-two-pane.png` | Tablet settings: left navigation rail + content pane |
| 15 | `15-phrases.png` | 常用语 page (opened from home 功能 grid) |
| 16 | `16-api-dialog.png` | Editable API base URL dialog |
| 17 | `17-home-settings-grid.png` | Home scrolled to settings grid and more rows |
| 18 | `18-text-tools-real-backend.png` | 文字工具 整理 result returned by the real backend, with apply/undo controls |

Raw captures remain in `/tmp` during the run; these copies are the delivered
evidence. `04`, `05`, `06`, `07`, `08` were taken while the emulator’s system IME
was our service (`settings get secure default_input_method` verified).
