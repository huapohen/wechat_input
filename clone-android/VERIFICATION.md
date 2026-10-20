# 微输入法 — native Android verification

Independent study/interoperability clone. No Tencent binaries, assets, fonts, or
model keys are included. UI is rebuilt with native Android Views (XML roots +
Kotlin builders); no Compose dependency.

## Toolchain and build

| Item | Value |
|---|---|
| JDK | OpenJDK 21.0.12 |
| Gradle | 9.3.1 (wrapper generated; distribution already cached on this machine) |
| AGP | 8.11.1 |
| Kotlin | 2.2.20 |
| compileSdk / targetSdk / minSdk | 36 / 35 / 26 |
| applicationId | `com.huapohen.wechatinput` |
| Display name | 微输入法 |

Build command (run from `clone-android/`):

```bash
./gradlew assembleDebug
```

The wrapper points at Gradle 9.3.1. The exact distribution used for the
verification run is also available at
`~/.gradle/wrapper/dists/gradle-9.3.1-all/5wooodlkfwsm42ictrailuf0e/gradle-9.3.1/bin/gradle`.
If the wrapper distribution cannot be downloaded, use that binary with the same
`assembleDebug` task.

Result:

```text
app/build/outputs/apk/debug/app-debug.apk   (7.0 MB, debug)
```

Install:

```bash
adb -s 127.0.0.1:5581 install -r app/build/outputs/apk/debug/app-debug.apk
```

Install succeeded on the assigned emulator. A separate build with the final
visual tweaks was made before the final install; the APK timestamp is the same
build that was installed.

## Device

- Assigned emulator: **emulator-5580** (console port 5580). `adb` exposes it on
  `127.0.0.1:5581` in this environment because the adb server had not registered
  the console port automatically. All commands use serial `127.0.0.1:5581`.
- AVD: `WeChatInput_API_36` (Pixel 10 Pro XL profile, arm64, Android 36).
- Native screen: 1344 × 2992, density 480 dpi (`wm size` / `wm density`).
- The task-assigned Flutter emulator (`emulator-5590`) and the other task's
  emulators (5554 / 5556) were not used or modified.

Backend used by the client: `http://10.0.2.2:8787` (host `127.0.0.1:8787`).
`GET /health` returned `{"ok":true,"model":"deepseek-chat", ...}`.

## IME activation

```bash
adb -s 127.0.0.1:5581 shell ime enable com.huapohen.wechatinput/.ime.WeTypeCloneImeService
adb -s 127.0.0.1:5581 shell ime set com.huapohen.wechatinput/.ime.WeTypeCloneImeService
adb -s 127.0.0.1:5581 shell settings get secure default_input_method
# => com.huapohen.wechatinput/.ime.WeTypeCloneImeService
```

The system IME picker/settings list shows the keyboard as **微输入法**
(screenshot `12-ime-enabled-system-settings.png`). The final APK was reinstalled
and the IME was re-selected after the last build; `settings get secure
default_input_method` returned the service id.

### Typing through a real host

1. In-app host: `KeyboardTestActivity` contains an ordinary `EditText`.
   - T9 mode: tapped `6` then `4`; candidate bar showed `64` and candidates
     starting with **你** (`05-t9-candidates.png`).
   - Space with a live buffer commits the first candidate. After an earlier
     candidate committed **尼**, typing `nihao` on the QWERTY Chinese keyboard
     showed **你好**, and space committed it. The host field read **尼你好**
     (`06-candidate-committed.png`) — proof that the commit path writes into the
     host `EditText`, not a demo label.
   - Candidate tap also committed **尼** into the host field (captured before the
     final tuning); candidate long-press exposes 固定/删除/复制.
   - Keyboard modes switched via the toolbar “键盘” item; T9 and QWERTY were
     both exercised. The mode picker is captured in `09-mode-picker.png`.
2. System app: Settings → Search settings.
   - With 微输入法 selected, the keyboard appeared inside Google Settings
     (`12a-settings-ime-visible.png`).
   - Letters tapped on the IME were committed with space; `uiautomator dump`
     reported the system Settings search `EditText`
     (`com.google.android.settings.intelligence:id/open_search_view_edit_text`)
     with `text="gekko"` (`12b-settings-search-typing.png`). This is an actual
     system-app host, not the clone's own text field.

Long-press space is wired to `SpeechRecognizer`; release stops recognition and
commits (or leaves composing text, depending on “松手即发送”). The emulator has
no usable microphone input, so the full voice path was not verified audibly.

## Pages and behavior exercised

Verified by tapping through the installed app on the emulator:

- Home: header/status, 9-card carousel, 功能 cards, 2-column settings grid,
  更多 rows, adaptive tablet 4-column grid.
- Onboarding / privacy: disclaimer, mic permission, keyboard enable/select,
  consent checkbox, enter-home.
- 布局和显示: keyboard height/candidate sliders, split/border/pre-input/enter
  switches, theme chooser, API URL dialog, keyboard preview link.
- 键盘体验: host field, mode chips, engine status, system input-method links.
- 常用语 (Phrases): page opened; add/edit/delete/copy UI present; it is opened
  from the home 功能 grid (`15-phrases.png`).
- 隔空传送 (Transfer): backend list loaded (2 files), upload limit/progress
  code, SAF picker, download/open actions; a file was uploaded through the
  backend and appeared in the list (`11-transfer.png`).
- 问 AI (AI chat): opened from the keyboard toolbar, used the real backend, and
  returned a three-language translation for “今天天气很好”. Streaming, stop,
  retry/copy paths are implemented; history is local (`10-ai-chat-real-backend.png`).
- 文字工具 (Text tools): 整理 returned a real backend rewrite for
  “This is a demo sentence with some ums.” → “This is a demo sentence with some
  “ums.””; the result card shows 复制 / 应用并清空 / 撤销
  (`18-text-tools-real-backend.png`).
- 系统输入法设置: enabled service shown in Android Settings.
- Tablet: resized to 1600 × 2560 at density 320 (≈800 dp), then restored.
  `13-tablet-home.png` shows the 4-column home; `14-tablet-settings-two-pane.png`
  shows the 292 dp navigation rail + content two-pane settings layout.

Toggle persistence was checked with `run-as` after tapping the split-keyboard
switch:

```bash
adb -s 127.0.0.1:5581 shell run-as com.huapohen.wechatinput \
  cat shared_prefs/wetype_settings.xml | grep split_keyboard
# => <boolean name="split_keyboard" value="true" />
```

The API base URL is editable in 布局和显示 → API 地址; the dialog was opened and
is captured in `16-api-dialog.png`.

## Screenshots

All under `evidence/clone-android/`; see `MANIFEST.md` for one-line descriptions.

| File | Screen |
|---|---|
| 01-home-phone.png | Home, IME selected |
| 02-onboarding-privacy.png | Onboarding / privacy |
| 03-display-settings.png | Display settings + API row |
| 04-keyboard-test-t9.png | Keyboard test page, T9 |
| 05-t9-candidates.png | T9 buffer `64`, candidates with 你 |
| 06-candidate-committed.png | Host text after candidate/space commit |
| 07-qwerty.png | Full QWERTY Chinese keyboard |
| 08-qwerty-nihao.png | `nihao` → 你好 |
| 09-mode-picker.png | Keyboard mode picker |
| 10-ai-chat-real-backend.png | AI chat, real backend answer |
| 11-transfer.png | Transfer page with backend files |
| 12-ime-enabled-system-settings.png | 微输入法 in Android IME settings |
| 12a-settings-ime-visible.png | Our keyboard over Settings search |
| 12b-settings-search-typing.png | `gekko` committed into Settings search |
| 13-tablet-home.png | Tablet 4-column home |
| 14-tablet-settings-two-pane.png | Tablet two-pane settings |
| 15-phrases.png | Phrases page |
| 16-api-dialog.png | API base URL dialog |
| 17-home-settings-grid.png | Home settings grid |
| 18-text-tools-real-backend.png | Text tools 整理 result from real backend |

## Not verified / limitations

- **Not every page was individually tapped.** All mandatory page ids are in
  `Pages.kt` and route to a real activity/generic settings page; the subset
  listed above was exercised. Pages such as 按键效果, 定制工具栏, 辅助输入, 模糊拼音,
  语音, 拼写 Plus, 剪贴板, 同步, 换机助手, 单机模式, 隐私, 电脑版, 关于, 帮助, AI 录音笔,
  边写边译, 排版成图, 表情 were built but not all were opened during this
  verification run. 文字工具 was exercised end-to-end against the backend.
- **Recorder**: start/pause/stop and `SpeechRecognizer` lifecycle are implemented,
  but the emulator has no usable microphone/ASR input, so no transcript or AI
  summary was produced end-to-end. The UI surfaces recognizer errors and keeps
  save/list/delete paths.
- **Voice long-press**: code path exists and mic permission is granted, but no
  audible result was verified. The keyboard toolbar voice button and long-press
  space both call the same service method.
- **SAF upload/download from the UI** was not completed. A file was uploaded via
  `curl` and the list rendered it; the download button code uses `ApiClient` +
  FileProvider, but was not clicked.
- **Sync pairing UI** (6-digit code, push/pull clipboard/phrases/settings) was
  built against the documented backend endpoints but was not exercised.
- **Error UI** is implemented for AI, text tools, translation, recorder summary,
  transfer, sync, and backend checks (error card + retry). The bad-URL path was
  not captured because the final base URL was restored to `10.0.2.2:8787`.
- **Handwriting** is deliberately limited to direction templates + public stroke
  code prefixes; About/Help/KeyboardTest label it as such.
- **Split keyboard** is applied only to QWERTY rows on sw≥700dp; the setting
  persists, but no split-layout screenshot was captured.
- The emulator was heavily loaded by parallel builds; first-frame times ranged
  from ~6 s to ~26 s. Navigation after the first frame is normal.
- No unit-test suite; verification is manual/device-based.
- `method.xml` now marks `zh_CN` as the default subtype. The system IME settings
  screenshot was captured before that last reinstall and showed the English (US)
  subtype text; the service id and enabled state were re-checked after reinstall.

## Backend touch points (for reproduction)

```bash
curl -s http://127.0.0.1:8787/health
curl -s -F "file=@/tmp/wetype-transfer.txt" http://127.0.0.1:8787/v1/transfer/upload
```

The AI chat request used the app's Settings API URL, which is sent as
`http://10.0.2.2:8787` from the emulator. No API key exists in the client,
assets, or source (`grep` for `sk-`/`DEEPSEEK_API_KEY` in `app/src/main` found
nothing).
