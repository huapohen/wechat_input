# Flutter clone — verification

Independent study clone. Not affiliated with Tencent. Report only covers what
was actually executed on this machine.

## Artifacts

| Item | Path | Result |
|---|---|---|
| Release APK | `clone-flutter/build/app/outputs/flutter-apk/app-release.apk` | 57 MB, builds and launches |
| APK SHA-256 | `0fd0ca2c4fc0c73d69ed166839ad195cee668f1cdb36f91c5bb43a9b39842434` | — |
| iOS simulator app | `clone-flutter/build/ios/iphonesimulator/Runner.app` | builds and launches |
| iOS bundle id | `com.huapohen.wechatInputClone` | — |
| Android package | `com.huapohen.wechat_input_clone` | — |

## Build commands

```bash
cd clone-flutter
/Users/lwblx/flutter/bin/flutter pub get

# This host has a global ~/.gradle/init.gradle that conflicts with Flutter's
# included Gradle build. The build was run with an isolated Gradle home.
GRADLE_USER_HOME=/tmp/gradle-flutter-home \
  /Users/lwblx/flutter/bin/flutter build apk --release

/Users/lwblx/flutter/bin/flutter build ios --simulator --no-codesign
```

Final results:

```text
✓ Built build/app/outputs/flutter-apk/app-release.apk (59.5MB reported by Flutter)
✓ Built build/ios/iphonesimulator/Runner.app
```

Android toolchain workarounds recorded for reproducibility:

- Gradle wrapper pinned to 8.14.3 (Flutter 3.47 minimum is 8.14).
- AGP 8.11.1, Kotlin 2.2.20.
- `shared_preferences_android` pinned to `2.4.28` via `dependency_overrides`.
  The initially resolved 2.5.1 JNI plugin produced
  `NoSuchMethodError SharedPreferencesApiRegistrar.getAll` at startup; the
  pinned build launches and persists state.
- Aliyun mirrors are used for dependency resolution because `dl.google.com`
  failed TLS on this network.

## Devices / simulators

- Android: `emulator-5592`, AVD `FlutterClone_API_36`, Android 16 (API 36).
  Port 5590 was already owned by another emulator/process, so this dedicated
  AVD was started on 5592.
- Tablet layout: same emulator resized with
  `wm size 2048x2732` + `wm density 320` (≈1024×1366 dp), which exercises the
  4-column grid and side rail.
- iOS: iPad Pro 13-inch (M5), simulator UUID
  `143E8C2B-CF0C-4902-8617-39FA2E22CC6F` (clone named
  “Flutter iPad Pro 13”), and iPhone 17, UUID
  `2D2658E5-EDF4-4474-85CD-B53C5F31B1B9` (clone “Flutter iPhone 17”).
  Separate clones were created to avoid colliding with the native iOS worker.

## What was exercised

Android release APK on `emulator-5592`:

1. Cold install (`adb install -r`) and launch; process stayed alive with no
   `FATAL EXCEPTION` / `NoSuchMethodError` in logcat.
2. First-run onboarding privacy screen rendered (`android-00-onboarding2.png`).
3. Accepted privacy → phone home rendered: header, 9-card carousel, 功能,
   设置 and 更多 (`android-01-home-final.png`).
4. Carousel manually swiped; card 7 rendered (`android-carousel.png`).
5. Tablet layout: side rail + 4-column settings grid + max-width content
   (`android-01-home-tablet.png`).
6. Keyboard page: T9 keys rendered (`android-02-keyboard-t9-fixed.png`).
7. T9 input `64426` produced the candidate `你好`
   (`android-03-t9-candidates.png`).
8. Tapping the candidate committed `你好` into the focused host TextField
   (`android-04-committed.png`).
9. Keyboard management page opened and rendered
   (`android-05-ai2.png`).
10. Transfer page opened; backend error was shown as a real error with retry,
    not fake success (`android-05-ai3.png`).
11. AI recorder page rendered, including the manual-transcript fallback and
    real system-speech availability state (`android-08-recorder.png`).
12. Real AI call: **服务设置 → 测试 AI 回复** returned `AI 回复： OK` from
    `POST /v1/ai/chat` (`android-07-ai-test.png`). This was run against a
    backend copy on port 8797 (see limitations); the app’s configured base URL
    was changed to `http://10.0.2.2:8797` through the in-app field.

iOS simulator:

- Final `Runner.app` installed and launched on the iPad simulator; onboarding
  rendered (`ios-tablet-01-final-launch.png`).
- Earlier launch on both the iPad and iPhone clones:
  `ios-tablet-00-launch.png`, `ios-phone-00-launch.png`.
- iOS keyboard/input was not re-verified after the final iOS build; the
  integration test run was blocked by a test-only import error that was then
  fixed, but the run was not repeated before wrap-up.

## Screenshot inventory

Stored in `evidence/clone-flutter/` (see `manifest.json` for exact files,
dimensions and device IDs). Meaningful run screenshots:

- `android-00-onboarding2.png`
- `android-01-home-final.png`
- `android-01-home-tablet.png`
- `android-carousel.png`
- `android-02-keyboard-t9-fixed.png`
- `android-03-t9-candidates.png`
- `android-04-committed.png`
- `android-05-ai2.png` (keyboard management)
- `android-05-ai3.png` (transfer page backend error)
- `android-07-ai-test.png` (real AI reply `OK`)
- `android-08-recorder.png`
- `ios-tablet-01-final-launch.png`
- `ios-tablet-00-launch.png`
- `ios-phone-00-launch.png`

## Limitations / blockers

1. **Backend port conflict.** While work was in progress, the FastAPI backend
   that had answered on `127.0.0.1:8787` was replaced by a Python
   `BaseHTTP` server that returns `501 Unsupported method ('GET')` for all
   routes (PID 72642). The app correctly showed the 501 error. To complete the
   AI verification, a second copy of the provided FastAPI backend was started
   on port 8797 (`WETYPE_PORT=8797`) and the app’s service URL was pointed at
   `http://10.0.2.2:8797`. The 8787 listener was not stopped.
2. **Toolbar tap verification incomplete.** T9 keys and candidate selection
   were verified by touch. Automated taps on the toolbar row did not navigate
   during this run; the toolbar code is present and wired, but this report does
   not claim verified toolbar navigation. The AI call was verified through the
   service-settings test button instead.
3. **iOS coverage short of 6 interaction screenshots.** Only launch/onboarding
   screens were captured on iOS (3 images). The iOS app builds and launches;
   deeper iOS screens were not captured before the wrap-up request.
4. **Integration test.** `integration_test/app_test.dart` and
   `test_driver/integration_test.dart` exist and cover route walking, T9/QWERTY
   typing, AI and text tools. The first `flutter drive` attempt failed on a
   test-only missing `HomePage` import; that import was fixed, but the test was
   not re-run. No pass is claimed.
5. **Toolbar/feature breadth.** The full page map is routed and built, but this
   report only lists screens actually seen in the screenshots above.
6. **No API key in the client.** Source/assets/Android/iOS trees were scanned
   for `sk-` / `DEEPSEEK_API_KEY`; only the backend holds the key. The optional
   app token field is not a model key.
7. **System keyboard not replaced.** The in-app keyboard is bound to focused
   Flutter TextFields only; this target does not ship an Android
   `InputMethodService` or iOS keyboard extension.

## Reproduction notes

- Install:
  `adb -s emulator-5592 install -r clone-flutter/build/app/outputs/flutter-apk/app-release.apk`
- Launch:
  `adb -s emulator-5592 shell am start -n com.huapohen.wechat_input_clone/.MainActivity`
- iOS install:
  `xcrun simctl install 143E8C2B-CF0C-4902-8617-39FA2E22CC6F clone-flutter/build/ios/iphonesimulator/Runner.app`
- iOS launch:
  `xcrun simctl launch 143E8C2B-CF0C-4902-8617-39FA2E22CC6F com.huapohen.wechatInputClone`
