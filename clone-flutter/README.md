# 微输入法 · Flutter 通用复刻

Independent, study-only reconstruction of a WeType-style keyboard companion.
Not affiliated with Tencent; no Tencent binaries, fonts or drawables are used.

## What is implemented

- Full home information architecture: 9-card auto-scrolling carousel, 功能,
  设置 and 更多 groups, all rows navigable.
- Onboarding/privacy, display, key effects, custom toolbar, auxiliary input,
  fuzzy pinyin, voice settings/language/punctuation, spelling Plus, clipboard,
  cross-device sync, migration assistant, standalone mode, privacy &
  permissions, desktop page, about, help & feedback.
- AI recorder with real system speech recognition states, manual transcript,
  local sessions and backend summaries; AI chat with streaming, stop, retry and
  copy; text tools (polish/rewrite/translate/summary); continuous translation;
  text-to-poster; phrases; emoji; file transfer with progress.
- In-app keyboard bound to focused text hosts: T9, QWERTY pinyin, handwriting,
  stroke, Wubi, double pinyin, English, number, symbols and emoji, with a
  candidate bar, toolbar, fuzzy pinyin, user learning, fixed/deleted words and
  long-press-space voice.
- Adaptive phone/tablet layouts: 2/4-column home grid, 1180 max content width,
  side rail on wide screens, keyboard max width 920.

## Backend

The AI/transfer/sync features call the local replacement backend:

- Android emulator default: `http://10.0.2.2:8787`
- iOS simulator default: `http://127.0.0.1:8787`

Change it in-app under **服务设置** (home header gear). The client never embeds
a model key.

## Build

```bash
/Users/lwblx/flutter/bin/flutter pub get
/Users/lwblx/flutter/bin/flutter build apk --release
/Users/lwblx/flutter/bin/flutter build ios --simulator --no-codesign
```

This workstation has a global Gradle init script that conflicts with Flutter's
included plugin build. Android builds here use an isolated Gradle home:

```bash
GRADLE_USER_HOME=/tmp/gradle-flutter-home \
  /Users/lwblx/flutter/bin/flutter build apk --release
```

## Verification

See `VERIFICATION.md` and `../evidence/clone-flutter/`. The integration test
(`integration_test/app_test.dart`) walks the route map, types Chinese and
English into the host field, and exercises the live backend.
