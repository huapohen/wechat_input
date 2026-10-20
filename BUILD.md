# Build and run

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

## 3. Native Android

```bash
cd clone-android
./gradlew assembleDebug
adb -s emulator-5580 install -r app/build/outputs/apk/debug/app-debug.apk
```

## 4. Native iOS

```bash
cd clone-ios
xcodebuild -project WeTypeClone.xcodeproj -scheme WeTypeClone \
  -sdk iphonesimulator -configuration Debug build
```

## Evidence

Runtime screenshots, UI dumps and build logs are under `evidence/clone-*`.
