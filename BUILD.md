# Build and run

All paths are relative to `rea/wechat_input`.

## 1. Backend

```bash
cd backend
python3 -m venv venv
venv/bin/pip install -r requirements.txt
export DEEPSEEK_API_KEY='sk-...'      # or let app.py read /Users/lwblx/Documents/ds_api
venv/bin/python app.py                # 0.0.0.0:8787
curl http://127.0.0.1:8787/health
```

Android emulator uses `http://10.0.2.2:8787`; iOS simulator uses
`http://127.0.0.1:8787`. Physical devices use the Mac LAN IP. The app also
accepts a base URL in Settings.

## 2. Flutter

```bash
cd clone-flutter
/Users/lwblx/flutter/bin/flutter pub get
/Users/lwblx/flutter/bin/flutter build apk --release
/Users/lwblx/flutter/bin/flutter build ios --simulator --no-codesign
```

This host needs an isolated Gradle home (`GRADLE_USER_HOME=/tmp/gradle-flutter-home`)
and the pinned `shared_preferences_android: 2.4.28` override. The Flutter SDK's
included Gradle plugin was locally relaxed from `FAIL_ON_PROJECT_REPOS` to
`PREFER_PROJECT` to work around the Gradle 8.14/9.x repository-mode conflict;
a standard Flutter SDK may build without that change. The verified APK SHA-256
is in `VERIFICATION.md` and `artifacts/SHA256SUMS`.

## 3. Native Android

```bash
cd clone-android
./gradlew assembleDebug
adb -s emulator-5580 install -r app/build/outputs/apk/debug/app-debug.apk
adb -s emulator-5580 shell ime enable com.huapohen.wechatinput/.ime.WeTypeCloneImeService
adb -s emulator-5580 shell ime set com.huapohen.wechatinput/.ime.WeTypeCloneImeService
```

Open the app → 键盘体验, or use Android Settings search. The IME is named
**微输入法**. Verified with a real system Settings `EditText`.

## 4. Native iOS

```bash
cd clone-ios
python3 scripts/generate_project.py   # regenerates the committed .xcodeproj
xcodebuild -project WeTypeClone.xcodeproj -scheme WeTypeClone \
  -sdk iphonesimulator -configuration Debug build
```

Install the `.app` on the simulator, then Settings → General → Keyboard →
Keyboards → Add New Keyboard → 微输入法. Full Access is optional for local
input; enable it for network/voice inside the extension.

For the keyboard host test:

```bash
cd clone-ios
./scripts/serve_host.sh     # http://127.0.0.1:8899, UTF-8 page
```

## 5. Artifacts

```bash
shasum -a 256 -c artifacts/SHA256SUMS
```

| Artifact | Path |
|---|---|
| Flutter APK | `artifacts/flutter/wechat-input-flutter.apk` |
| Android native APK | `artifacts/android/wechat-input-android.apk` |
| iOS simulator app | `artifacts/ios/WeTypeClone-simulator.app.zip` |
| Flutter iOS app | `artifacts/flutter/WeTypeRunner-simulator.app.zip` |

## 6. Verification evidence

- `reports/implementation.html` / `.md` — final matrix and galleries.
- `clone-flutter/VERIFICATION.md`
- `clone-android/VERIFICATION.md`
- `clone-ios/VERIFICATION.md`
- `evidence/clone-*` — screenshots, manifests, backend smoke JSON.
