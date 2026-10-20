# 微输入法 iOS — verification

独立研究复刻，与腾讯/微信输入法无关联。SwiftUI App + 真正的 Keyboard Extension。

## Build

```bash
cd clone-ios
xcodebuild -project WeTypeClone.xcodeproj -scheme WeTypeClone \
  -sdk iphonesimulator -configuration Debug \
  -destination 'platform=iOS Simulator,id=2811870A-F072-4FC1-B3C9-4B1EEEA538EA' build
```

- Result: **BUILD SUCCEEDED** (Xcode 27.1, iOS 26.5 simulator runtime, deployment target iOS 17.0).
- App bundle:
  `/Users/lwblx/Library/Developer/Xcode/DerivedData/WeTypeClone-hbsbtgubkicohyavbjrfginmovcf/Build/Products/Debug-iphonesimulator/WeTypeClone.app`
- Extension embedded at `WeTypeClone.app/PlugIns/WeTypeKeyboard.appex`.
- Bundle IDs: app `com.huapohen.wechatinput.ios`, extension `com.huapohen.wechatinput.ios.keyboard`.
- Display name: 微输入法. iPhone + iPad (`TARGETED_DEVICE_FAMILY = 1,2`).
- Lexicon: bundled SQLite (26,703 chars, 46,111 phrases, 32,125 wubi codes, 6,245 stroke codes) built by
  `python3 scripts/build_lexicon.py` from `shared/data`.

## Simulators used

| Role | UDID | Notes |
|---|---|---|
| iPhone 17 | `2811870A-F072-4FC1-B3C9-4B1EEEA538EA` | fresh clean device named `WeTypeClone-iPhone17`, used for the final extension/host proof |
| iPhone 17 (shared) | `6BBA0111-7B13-4830-9DB1-D651664F4381` | app UI/screenshot smoke test; contains other tasks' keyboards, not used for final keyboard proof |
| iPad Pro 13-inch (M5) | `833B0941-E1E7-4AE0-B7BA-F5B9D7A774E9` | iPad adaptive layout |

## Install / launch

```bash
xcrun simctl install 2811870A-F072-4FC1-B3C9-4B1EEEA538EA \
  "$HOME/Library/Developer/Xcode/DerivedData/WeTypeClone-hbsbtgubkicohyavbjrfginmovcf/Build/Products/Debug-iphonesimulator/WeTypeClone.app"
xcrun simctl launch 2811870A-F072-4FC1-B3C9-4B1EEEA538EA \
  com.huapohen.wechatinput.ios -onboarding.accepted YES
```

A fresh launch without `-onboarding.accepted YES` shows the onboarding/privacy page first. The
launch argument is only a verification shortcut; the normal UI consent toggle writes
`onboarding.accepted` to the App Group.

## Keyboard extension

### Enable (verified)

The extension is listed under Settings → General → Keyboard → Keyboards → Add New Keyboard as
**微输入法** (screenshot `06-settings-add-list.png`). It was enabled via the UI automation test
`testEnableKeyboardOnly`; `pluginkit -m -p com.apple.keyboard-service` reports:

```
com.huapohen.wechatinput.ios.keyboard(1.0.0)
```

The extension must be launched with `NSExtensionPrincipalClass = KeyboardViewController`; the
module-qualified form failed to launch on this runtime (ExtensionKit `-50`). After changing the
principal class, reinstalling, and rebooting the simulator once (LaunchServices plugin path cache),
the extension launches as `WeTypeKeyboard` and appears over Safari.

### Typing into a real host app (verified)

Host page: `scripts/host/index.html`, served with UTF-8:

```bash
cd clone-ios/scripts/host
python3 -m http.server 8899 --bind 0.0.0.0
# Simulator must use the Mac LAN address (127.0.0.1 did not reach the host in this runtime):
xcrun simctl openurl 2811870A-F072-4FC1-B3C9-4B1EEEA538EA http://172.17.78.27:8899/
```

Then the UI test taps the textarea, switches the clone extension to 全键盘拼音, types `nihao`,
selects the candidate **你好**, switches to 英文, types `abc`, and asserts the host value:

```
HOST VALUE: 你好abc
Test Case 'testTypeIntoHost' passed
```

Evidence:
- `05-safari-keyboard.png` — Safari textarea shows **你好abc**, with the clone toolbar/keys visible.
- `05-safari-candidates.png` — buffer `nihao` and real SQLite candidate **你好**.
- `04-keyboard-inapp.png` — in-app keyboard with the same candidate.
- `06-settings-add-list.png`, `06-settings-keyboard.png`, `06-settings-fullaccess.png` — enablement UI.

This proves the extension commits CJK and ASCII through `textDocumentProxy.insertText(String)`.
No byte/encoding conversion exists in the insert path; the earlier mojibake image was the test page
missing `<meta charset="utf-8">` (fixed in `scripts/host/index.html`).

### Modes / toolbar

Implemented in the shared keyboard panel: 九宫格拼音, 全键盘拼音, 手写 (20 字方向模板), 笔画,
五笔, 双拼 (小鹤), 英文, 数字, 符号, Emoji. Toolbar: keyboard switch, voice, clipboard, phrases,
emoji, handwriting, AI, translate, polish, settings. Delete/space/enter/shift/globe and long-press
space voice are present. Candidate selection updates local learning; long-press candidate deletes it
from ranking. The in-app page has a “候选引擎自检” sheet that queries every mode live.

## AI / backend

- The shared port 8787 was occupied by a local **mock** AI service during the final check
  (`{"id":"mock-1"}`), so the real FastAPI backend was started on port 8788:
  `WETYPE_PORT=8788 backend/venv/bin/python backend/app.py`. Verification used
  `http://172.17.78.27:8788` (LAN; simulator loopback did not reach the host in this runtime).
  `/health` reported `deepseek-flash` with a configured server-side key and
  `/v1/ai/chat` returned the real text **“微输入法在线”** (saved in `ai-chat-response.json`).
  The base URL is
  editable in **帮助与反馈 → 诊断 → 后端地址 → 保存地址** (stored in App Group `api.base_url`).
- `/health` returned `{"ok":true,"model":"deepseek-flash","key":{"configured":true}}`.
- The client calls `/v1/ai/chat` (streaming SSE), `/v1/ai/polish`, `/v1/ai/rewrite`,
  `/v1/ai/translate`, `/v1/ai/summary`, `/v1/sync/*` and `/v1/transfer/*`. No API key exists in the
  client source/plist/entitlements.
- UI automation (`testAIChatRealResponse`) drove the app's 问 AI page against the real backend on
  8788. FastAPI logged `172.17.78.27:... "POST /v1/ai/chat HTTP/1.1" 200 OK`; the test's post-answer
  assertion looked for the SwiftUI “复制” button and did not find it within the timeout, so the
  answer bubble was not captured as a screenshot. The actual backend response is saved verbatim in
  `ai-chat-response.json` (`text: "微输入法在线"`). The client does not fabricate output: errors are
  rendered with retry.
- A separate direct POST to `/v1/ai/polish` on the real backend also returned 200; the 8787 port was
  a mock service started by another task, so it was not used for the final claim.

## iPad

- `NavigationSplitView` with a sidebar; home uses 4 columns and max content width 1180; keyboard is
  capped at 920 pt.
- Verified on iPad Pro 13-inch (M5): `10-ipad-home.png`, `11-ipad-keyboard.png`, `12-ipad-ai.png`.

## Screenshots (evidence/clone-ios)

01-launch, 02-home, 03-display, 04-keyboard-inapp, 05-safari-keyboard, 05-safari-candidates,
06-settings-add-list, 06-settings-keyboard, 06-settings-fullaccess, 07-ai-chat, 08-text-tools,
09-transfer, 10-ipad-home, 11-ipad-keyboard, 12-ipad-ai, 13-voice, 14-poster, plus
`ai-chat-response.json` (real backend output) and `manifest.json`.

## Limitations

- **No IPA / device build.** The project has no `DEVELOPMENT_TEAM`; simulator builds are ad-hoc
  signed only. A device IPA requires a paid team and provisioning profile plus the App Group
  capability. The deliverable is the simulator `.app`.
- Full Access toggle was opened by UI automation, but this simulator did not persist the toggle in
  the observed screenshot; typing/candidates work without Full Access. Voice/network inside the
  extension therefore require the user to enable Full Access manually.
- Speech recognition can be unavailable in the simulator; the app shows the real error and offers a
  manual transcript fallback.
- Handwriting is a documented 20-character template matcher, not a full CJK model.
- The backend sync API isolates data per device token; pairing was exercised, but the API does not
  return a peer token, so cross-token payload sharing is a backend limitation.
- The clean simulator had to be rebooted once after installing the extension so LaunchServices
  refreshed the plugin path; this is a simulator-only install quirk.
