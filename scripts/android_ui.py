#!/usr/bin/env python3
"""Small adb UI helper used to capture original-app and clone evidence.

Commands:
  dump [name]              save UI XML and print visible labels with bounds
  shot NAME                save a PNG under evidence/runtime
  tap-text TEXT [INDEX]    tap the first/last matching visible text
  tap-desc TEXT            tap a matching content-description
  tap X Y                  tap coordinates
  key CODE                 send a key event name or number
  text TEXT                input text (spaces escaped)
  swipe X1 Y1 X2 Y2 [MS]
"""
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ROOT / "evidence" / "runtime"
ADB = os.environ.get("ADB", str(Path.home() / "Library/Android/sdk/platform-tools/adb"))
SERIAL = os.environ.get("ANDROID_SERIAL", "emulator-5554")


def run(args, capture=False):
    cmd = [ADB, "-s", SERIAL, *args]
    return subprocess.run(cmd, text=True, capture_output=capture, check=False)


def dump(name="ui"):
    RUNTIME.mkdir(parents=True, exist_ok=True)
    run(["shell", "uiautomator", "dump", "/sdcard/ui.xml"])
    run(["pull", "/sdcard/ui.xml", str(RUNTIME / f"{name}.xml")])
    path = RUNTIME / f"{name}.xml"
    if not path.exists():
        print("no ui dump")
        return []
    root = ET.parse(path).getroot()
    out = []
    for n in root.iter("node"):
        text = (n.get("text") or "").strip()
        desc = (n.get("content-desc") or "").strip()
        if text or desc:
            b = n.get("bounds", "")
            out.append((text or desc, b, n.get("clickable") == "true"))
            print(f"{text or desc}  {b}  clickable={n.get('clickable')}")
    return out


def bounds_center(bounds):
    m = re.findall(r"\d+", bounds)
    if len(m) != 4:
        return None
    x1, y1, x2, y2 = map(int, m)
    return (x1 + x2) // 2, (y1 + y2) // 2


def tap_text(text, index=-1):
    items = dump("_tap")
    matches = [b for t, b, _ in items if t == text or text in t]
    if not matches:
        print(f"text not found: {text}")
        return 1
    x, y = bounds_center(matches[index])
    print(f"tap {text} at {x},{y}")
    run(["shell", "input", "tap", str(x), str(y)])
    return 0


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    cmd, *args = sys.argv[1:]
    if cmd == "dump":
        dump(args[0] if args else "ui")
    elif cmd == "shot":
        RUNTIME.mkdir(parents=True, exist_ok=True)
        name = args[0] if args else "shot"
        with open(RUNTIME / f"{name}.png", "wb") as f:
            subprocess.run([ADB, "-s", SERIAL, "exec-out", "screencap", "-p"], stdout=f, check=True)
        print(RUNTIME / f"{name}.png")
    elif cmd == "tap-text":
        return tap_text(args[0], int(args[1]) if len(args) > 1 else -1)
    elif cmd == "tap-desc":
        items = dump("_tap")
        matches = [b for t, b, _ in items if t == args[0]]
        if not matches:
            print("desc not found")
            return 1
        x, y = bounds_center(matches[0])
        run(["shell", "input", "tap", str(x), str(y)])
    elif cmd == "tap":
        run(["shell", "input", "tap", args[0], args[1]])
    elif cmd == "key":
        run(["shell", "input", "keyevent", args[0]])
    elif cmd == "text":
        run(["shell", "input", "text", args[0].replace(" ", "%s")])
    elif cmd == "swipe":
        run(["shell", "input", "swipe", *args])
    else:
        print(__doc__)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
