#!/usr/bin/env python3
"""Normalize REA/APK observations into report-ready JSON.

Inputs are the saved analysis artifacts in analysis/. This script never talks to
the device or the network; it is deterministic over the committed evidence.
"""
from __future__ import annotations

import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AN = ROOT / "analysis"
OUT = AN / "normalized"
OUT.mkdir(parents=True, exist_ok=True)
ANDROID = "{http://schemas.android.com/apk/res/android}"


def load(path: Path):
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def dump(name, value):
    (OUT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def package_summary():
    p = load(AN / "package.json")
    r = p["normalized_result"]
    return {
        "package_name": r["package_name"],
        "version_name": r["version_name"],
        "version_code": r["version_code"],
        "min_sdk": r["min_sdk"],
        "target_sdk": r["target_sdk"],
        "permissions": r["permissions"],
        "evidence_id": p.get("evidence_id"),
        "sha256": p["subject"]["digest"]["sha256"],
        "bytes": (ROOT / "targets" / "wechat-android-4.0.0.apk").stat().st_size,
        "engine": r.get("engine"),
    }


def components():
    tree = ET.parse(AN / "apktool" / "AndroidManifest.xml")
    root = tree.getroot()
    app = root.find("application")
    rows = []
    for tag in ("activity", "activity-alias", "service", "receiver", "provider"):
        for el in app.findall(tag):
            name = el.get(ANDROID + "name", "")
            if not name.startswith("com.tencent.wetype"):
                continue
            filters = []
            for f in el.findall("intent-filter"):
                actions = [a.get(ANDROID + "name") for a in f.findall("action")]
                cats = [c.get(ANDROID + "name") for c in f.findall("category")]
                data = []
                for d in f.findall("data"):
                    data.append({k.split("}")[-1]: v for k, v in d.attrib.items()})
                filters.append({"actions": actions, "categories": cats, "data": data})
            rows.append({
                "type": tag,
                "name": name,
                "exported": el.get(ANDROID + "exported"),
                "process": el.get(ANDROID + "process"),
                "permission": el.get(ANDROID + "permission"),
                "label": el.get(ANDROID + "label"),
                "filters": filters,
            })
    return rows


def rn_modules():
    src = (AN / "hbc" / "setup.js").read_text(encoding="utf-8", errors="replace")
    start = src.find("r2['WeTypeBundles'] = r5;")
    bstart = src.find("r1['BundleNames'] = r0;", start)
    mend = src.find("r1['ModuleNames'] = r0;", bstart)

    def pairs(block):
        return {key: value for value, key in re.findall(
            r"r2 = '([^']+)';\s*\n\s*r0\['([^']+)'\] = r2;", block)}

    bundles = pairs(src[start:bstart])
    modules = pairs(src[bstart:mend])
    sstart = src.find("r4 = {};\n    r5 = 'mainSetting';")
    send = src.find("r2['SchemeAction'] = r4;")
    schemes = {key: value for value, key in re.findall(
        r"r5 = '([^']+)';\s*\n\s*r4\['([^']+)'\] = r5;", src[sstart:send])}
    return {"bundles": bundles, "modules": modules, "scheme_actions": schemes}


def keyboard_specs():
    rows = []
    for p in sorted((AN / "apk" / "assets" / "keyboard" / "output").glob("*.json")):
        d = json.load(open(p, encoding="utf-8"))
        cfg = d["config"]
        lines = []
        for li, line in enumerate(d["keys"]):
            keys = []
            for k in line:
                def one(key, default=None):
                    v = k.get(key)
                    if isinstance(v, list) and v:
                        return v[0]
                    return v if v is not None else default
                keys.append({
                    "id": one("id", ""),
                    "main_text": one("mainText", ""),
                    "float_text": one("floatText", ""),
                    "type": one("type", 1),
                    "width": one("width", None),
                    "height": one("height", None),
                    "main_text_size": one("mainTextSize", None),
                    "bg_corner": one("bgCorner", 16),
                    "clickable": one("clickable", True),
                })
            h = cfg.get("lineHeight", [0])[0] if cfg.get("lineHeight") else None
            lh = cfg.get("lineHeightLandscape", [h])[0] if cfg.get("lineHeightLandscape") else h
            lines.append({"index": li, "line_height": h, "line_height_landscape": lh, "keys": keys})
        rows.append({
            "file": p.name,
            "name": cfg.get("name", [None])[0],
            "is_t9": cfg.get("isT9", [None])[0],
            "vwidth": cfg.get("vWidth", [None])[0],
            "vheight": cfg.get("vHeight", [None])[0],
            "line_count": len(lines),
            "lines": lines,
            "key_count": sum(len(line["keys"]) for line in lines),
        })
    return rows


def settings():
    out = {}
    for p in sorted(AN.glob("model-com.tencent*.json")):
        r = load(p)["normalized_result"]
        name = r["class_name"].split(".")[-1]
        fields = []
        for f in r.get("fields", []):
            if f["name"] == "Companion":
                continue
            fields.append({"name": f["name"], "type": f.get("reported_type")})
        methods = []
        for m in r.get("methods", []):
            if m["name"].startswith("<"):
                continue
            methods.append({"name": m["name"], "signature": m["reported_signature"], "overloads": m["overload_index"]})
        out[name] = {"fields": fields, "methods": methods}
    return out


def native_strings():
    tree = ET.parse(AN / "apktool" / "res" / "values" / "strings.xml")
    out = []
    for s in tree.getroot().findall("string"):
        text = "".join(s.itertext()).strip()
        if text:
            out.append({"name": s.get("name"), "value": text})
    return out


def evidence_index():
    rows = []
    for p in sorted(AN.glob("*.json")):
        if p.name in {"package.json", "classes.json", "resources.json"}:
            continue
        try:
            d = load(p)
        except Exception:
            continue
        if not isinstance(d, dict) or "evidence_id" not in d:
            continue
        r = d.get("normalized_result") or {}
        rows.append({
            "file": p.name,
            "evidence_id": d.get("evidence_id"),
            "operation": d.get("operation"),
            "class_name": r.get("class_name"),
            "method": (r.get("method") or {}).get("name") if isinstance(r.get("method"), dict) else None,
            "confidence": d.get("confidence"),
            "limitations": d.get("limitations", []),
            "sha256": (d.get("subject") or {}).get("digest", {}).get("sha256"),
        })
    # Include the class inventory and package inventory.
    for name in ("package.json", "classes.json"):
        d = load(AN / name)
        rows.append({
            "file": name,
            "evidence_id": d.get("evidence_id"),
            "operation": d.get("operation"),
            "class_name": None,
            "method": None,
            "confidence": d.get("confidence"),
            "limitations": d.get("limitations", []),
            "sha256": (d.get("subject") or {}).get("digest", {}).get("sha256"),
        })
    return rows


def screenshots():
    base_old = ROOT.parent / "wechat_stt" / "evidence" / "original-ui"
    base_ios = base_old / "ios-mirror-20261019"
    rows = []
    parity = base_old / "parity-20261018"
    for i, d in enumerate(sorted([x for x in parity.iterdir() if x.is_dir()]), 1):
        png = d / "screen.png"
        if png.exists():
            rows.append({
                "src": str(png),
                "group": "android-20261018",
                "label": f"{i:02d} {d.name.split('-', 1)[1].replace('-', ' ')}",
                "step": d.name,
            })
    for name, label in [
        ("home/screen.png", "原版首页"),
        ("toolbar/screen.png", "候选栏"),
        ("start/screen.png", "首次启动"),
        ("input-result/screen.png", "上屏结果"),
        ("t9-candidates/screen.png", "九宫格候选"),
        ("keyboard-modes/screen.png", "键盘选择"),
        ("tools-panel/screen.png", "工具栏面板"),
    ]:
        p = base_old / name
        if p.exists():
            rows.append({"src": str(p), "group": "android-keyboard", "label": label, "step": name})
    for p in sorted((ROOT / "evidence" / "runtime").glob("*.png")):
        if p.parent.name == "_invalid":
            continue
        rows.append({"src": str(p), "group": "android-20261020", "label": p.stem.replace("-", " "), "step": p.stem})
    for p in sorted(base_ios.glob("*.png")):
        rows.append({"src": str(p), "group": "ios-20261019", "label": p.stem.replace("-", " "), "step": p.stem})
    return rows


def main():
    pkg = package_summary()
    dump("package.json", pkg)
    comp = components()
    dump("components.json", comp)
    rn = rn_modules()
    dump("modules.json", rn)
    kb = keyboard_specs()
    dump("keyboards.json", kb)
    st = settings()
    dump("settings.json", st)
    ns = native_strings()
    dump("strings.json", ns)
    ev = evidence_index()
    dump("evidence.json", ev)
    shots = screenshots()
    dump("screenshots.json", shots)
    metrics = {
        "total_classes": load(AN / "classes.json")["normalized_result"]["total_classes"],
        "app_classes": len([x for x in load(AN / "classes.json")["normalized_result"]["matches"] if x.startswith("com.tencent.wetype")]),
        "keyboard_layouts": len(kb),
        "native_strings": len(ns),
        "screenshots": len(shots),
        "rea_evidence": len(ev),
        "rn_modules": len(rn["modules"]),
        "scheme_actions": len(rn["scheme_actions"]),
        "components": len(comp),
        "hermes_bundles": sorted([p.name for p in (AN / "apktool" / "assets").glob("*.hbc")]),
        "native_libs": len(list((AN / "apktool" / "lib").glob("*/**/*.so"))),
        "assets_files": len(list((AN / "apktool" / "assets").glob("**/*"))),
    }
    dump("metrics.json", metrics)
    print(json.dumps(metrics, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
