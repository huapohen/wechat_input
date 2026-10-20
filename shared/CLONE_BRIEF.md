# Clone brief — 微输入法 / WeType-inspired

This is an independent interoperability/study clone. Do **not** copy Tencent
binary assets, Hermes bundles, fonts or drawables. Use the facts and rebuilt
assets in `shared/`. The app must not claim affiliation with Tencent.

## Product target

Name: **微输入法** (English subtitle: WeType-inspired Keyboard).  
Visual language: light mint background, white rounded cards, green accent,
PingFang/Noto Sans CJK, dense but calm settings pages. Use
`shared/spec/design_tokens.json`.

Both phone and tablet/iPad layouts are required. Tablet home uses 4 columns,
max content width ~1180, and a left rail or wide header; keyboard widens to a
comfortable max width and can split.

## Mandatory page map (every entry must be reachable and functional)

Home, onboarding/privacy, keyboard experience, keyboard management, layout &
display, key effects, custom toolbar, auxiliary input, fuzzy pinyin, voice
settings, voice language, voice punctuation, spelling Plus, clipboard,
cross-device sync, migration assistant, standalone mode, privacy & permissions,
desktop version, about, help & feedback, AI recorder, recorder session, file
transfer, AI chat, text tools, continuous translation, text-to-poster, phrases,
emoji.

Home order (must match the original's information architecture):

1. Header: app mark, "微信输入法" style wordmark is replaced by "微输入法";
   slogan "简洁、好用、打字快".
2. Carousel (9 cards): 文字整理 / AI 录音笔 / 多语言自由说 / 表情推荐 /
   趣味颜文字 / 问 AI / 排版成图 / 跨设备粘贴传送 / 灵动表达. Each card has
   an action and opens the matching page or a Plus gate.
3. 功能: AI 录音笔 (NEW), 隔空传送.
4. 设置 (2-column cards): 布局和显示, 按键效果, 定制工具栏, 辅助输入,
   跨设备粘贴同步, 剪贴板, 键盘管理, 语音转文字, 拼写 Plus, 单机模式,
   换机助手.
5. 更多: 隐私与权限, 电脑版, 关于, 帮助与反馈.

Every card, list row, toggle, segmented control and toolbar button must either
navigate, mutate persisted state, or perform its labelled action. No dead
buttons and no "coming soon" placeholders.

## Keyboard

Implement an in-app keyboard (Flutter / native view) that types into a focused
host field. Required modes: 九宫格拼音, 全键盘拼音, 手写, 笔画, 五笔, 双拼,
英文, 数字, 符号, Emoji. Candidate bar above the keyboard; toolbar row with:
keyboard switch, voice, clipboard, phrases, emoji, handwriting find-word, AI,
translate, text polish, settings. Long-press space starts voice; release
commits or cancels according to settings.

Use `shared/data` for real candidate lookup:

- pinyin chars + phrases; T9 digit mapping (`abc→2 … wxyz→9`);
- fuzzy pinyin pairs;
- Wubi 86 codes and stroke codes;
- phrases, emoji, English words;
- double-pinyin maps.

Candidate ranking: exact prefix, then fuzzy, then phrase > char, then frequency
and user learning. Persist selected words/fixed words locally. Deleting a
candidate should update local learning.

Handwriting may use a small template recognizer; label its scope honestly in
About/Help. Do not present a fixed demo string as recognition.

## AI / voice / backend

Backend is running at `http://127.0.0.1:8787` (Android emulator:
`http://10.0.2.2:8787`). Endpoints in `backend/app.py`. The app must have a
Settings field for API base URL. Never embed a model key in the client.

- AI chat: multi-turn, streaming if possible, stop/retry/copy, history local.
- Text tools: polish, rewrite (3 candidates), translate, summarize; preview,
  apply, undo; show real errors.
- AI recorder: start/stop/pause, live transcript using device speech
  recognition, optional AI summary; save sessions locally.
- File transfer: pick/share a file, upload to backend `/v1/transfer/upload`,
  list/download; show progress/errors; QR/配对码 UI may use a local code.
- Sync: 6-digit pairing code; clipboard/phrases/settings sync via backend;
  graceful offline state.
- Continuous translation: source field + debounced target, apply to host, clear
  turn after send.

If the backend is unreachable, show a clear error and a retry button. Do not
fabricate AI output.

## Platform deliverables

### Flutter (`clone-flutter/`)
- Flutter 3.47.2 at `/Users/lwblx/flutter/bin/flutter`.
- Android + iOS, phone + tablet adaptive.
- In-app keyboard is required; a native Android IME service is **not** required
  in this target (the native target covers it).
- Build: `flutter build apk --release`; `flutter build ios --simulator --no-codesign`.
- Test device: `emulator-5590` (Android), iOS simulator.

### Native Android (`clone-android/`)
- Kotlin, minSdk 26, compileSdk 36, targetSdk 35.
- Must include a real `InputMethodService` (`WeTypeCloneImeService`) that can be
  enabled in system settings and shows the keyboard in a host app.
- Full page map, native Views (XML + Kotlin); tablet layout.
- Build: Gradle debug APK. Test device: `emulator-5580`.
- Do not change the default IME of emulator-5554/5556.

### Native iOS (`clone-ios/`)
- SwiftUI app + Keyboard Extension. iOS 17+, iPad supported.
- Keyboard extension must be selectable in Simulator Settings; Full Access
  flow explained. If network in extension is unavailable without Full Access,
  degrade to local input.
- Share extension optional; at minimum, file import/share sheet works.
- Build with `xcodebuild -sdk iphonesimulator`. Test on iPhone 17 and iPad Pro
  13-inch simulators. If code signing prevents an IPA, deliver the simulator
  `.app` and document it.

## Environment / coordination

- Backend: port 8787, already running. Do not stop it.
- Do not modify `analysis/`, `reports/`, `evidence/runtime/` or `backend/`
  (except reading).
- Do not use `emulator-5554` or `emulator-5556` (another task owns them).
- If you need a separate emulator, use `emulator-5580` (native Android) or
  `emulator-5590` (Flutter); do not kill them.
- Build artifacts and verification screenshots go under your own folder and
  `evidence/clone-<platform>/`.
- Write `VERIFICATION.md` with exact commands, device/simulator IDs, screens
  exercised, build paths, and known limitations.

## Definition of done

1. Project builds from a clean command.
2. App installs/launches on the assigned device/simulator.
3. Home → every page → back works; no dead interaction.
4. Keyboard types Chinese/English into a host field, candidates selectable,
   modes switchable.
5. AI chat and one text tool return a real backend result (or a clear error if
   the backend is down).
6. Tablet/iPad layout is visibly adaptive.
7. At least 12 verification screenshots per platform, stored with a manifest.
8. `VERIFICATION.md` reports only what was actually exercised.
