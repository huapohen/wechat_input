#!/usr/bin/env python3
"""Independently open the native Android clone's home pages and capture proof.

Requires the debug APK installed and the app launchable. Uses UI text taps, so
it exercises the real home navigation rather than direct activity intents.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "evidence" / "clone-android" / "pages"
OUT.mkdir(parents=True, exist_ok=True)
ADB = os.environ.get("ADB", str(Path.home() / "Library/Android/sdk/platform-tools/adb"))
S = os.environ.get("ANDROID_SERIAL", "")
PKG = "com.huapohen.wechatinput"


def resolve_serial() -> str:
    if S:
        return S
    out = subprocess.run([ADB, "devices"], capture_output=True, text=True).stdout
    for candidate in ("emulator-5580", "127.0.0.1:5581"):
        if candidate in out:
            return candidate
    return "emulator-5580"

PAGES = [
    ("布局和显示", "display"),
    ("按键效果", "keystroke"),
    ("定制工具栏", "toolbar"),
    ("辅助输入", "auxiliary"),
    ("跨设备粘贴同步", "sync"),
    ("剪贴板", "clipboard"),
    ("键盘管理", "keyboard_manage"),
    ("语音转文字", "voice"),
    ("拼写 Plus", "plus"),
    ("单机模式", "standalone"),
    ("换机助手", "migration"),
    ("隐私与权限", "privacy"),
    ("电脑版", "desktop"),
    ("关于", "about"),
    ("帮助与反馈", "help"),
    ("AI 录音笔", "recorder"),
    ("隔空传送", "transfer"),
    ("键盘体验", "keyboard"),
    ("常用语", "phrases"),
]


def run(args, timeout=30):
    return subprocess.run([ADB, "-s", S, *args], capture_output=True, text=True, timeout=timeout)


def dump():
    run(["shell", "uiautomator", "dump", "/sdcard/ui.xml"])
    run(["pull", "/sdcard/ui.xml", str(OUT / "_ui.xml")])
    path = OUT / "_ui.xml"
    try:
        root = ET.parse(path).getroot()
    except Exception:
        return []
    rows = []
    for n in root.iter("node"):
        text = (n.get("text") or "").strip()
        desc = (n.get("content-desc") or "").strip()
        if not text and not desc:
            continue
        b = n.get("bounds", "")
        m = re.findall(r"\d+", b)
        if len(m) != 4:
            continue
        x1, y1, x2, y2 = map(int, m)
        rows.append((text or desc, (x1 + x2) // 2, (y1 + y2) // 2, x2 - x1, y2 - y1))
    return rows


def find(title, rows):
    for text, x, y, w, h in rows:
        if text == title or text.startswith(title + " ") or text.startswith(title + "\n"):
            return x, y
    for text, x, y, w, h in rows:
        if title in text and w > 80:
            return x, y
    return None


def tap(x, y):
    run(["shell", "input", "tap", str(x), str(y)])


def back():
    run(["shell", "input", "keyevent", "4"])


def home():
    # Leave a detail/keyboard page if present; do not press back from home.
    for _ in range(3):
        if ".MainActivity" in focus():
            break
        run(["shell", "input", "keyevent", "4"])
        time.sleep(0.6)
    if ".MainActivity" not in focus():
        run(["shell", "am", "start", "-n", f"{PKG}/.MainActivity", "--activity-clear-top"])
    time.sleep(0.8)
    # Pull the list to the top.
    for _ in range(3):
        run(["shell", "input", "swipe", "672", "700", "672", "2400", "250"])
        time.sleep(0.25)


def focus():
    out = run(["shell", "dumpsys", "window"]).stdout
    m = re.search(r"mCurrentFocus=Window\{[^ ]+ u0 ([^}]+)\}", out)
    return m.group(1) if m else ""


def main():
    global S
    S = resolve_serial()
    result = {"serial": S, "package": PKG, "pages": []}
    home()
    for title, pid in PAGES:
        found = None
        for attempt in range(7):
            rows = dump()
            pos = find(title, rows)
            if pos:
                found = pos
                break
            run(["shell", "input", "swipe", "672", "2300", "672", "800", "350"])
            time.sleep(0.4)
        entry = {"title": title, "id": pid, "found": bool(found)}
        if not found:
            result["pages"].append(entry)
            continue
        tap(*found)
        time.sleep(1.6)
        entry["focus"] = focus()
        with open(OUT / f"{pid}.png", "wb") as f:
            subprocess.run([ADB, "-s", S, "exec-out", "screencap", "-p"], stdout=f, check=False)
        rows = dump()
        entry["texts"] = [r[0] for r in rows[:12]]
        entry["not_implemented"] = any("页面未实现" in t for t, *_ in rows)
        result["pages"].append(entry)
        back()
        time.sleep(0.8)
        home()
    (OUT / "coverage.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2)[:6000])


if __name__ == "__main__":
    main()
