#!/usr/bin/env python3
"""Build shared dictionaries/specs consumed by Flutter, Android and iOS clones."""
from __future__ import annotations

import json
import re
import unicodedata
from pathlib import Path

from pypinyin import Style, pinyin
from pypinyin.pinyin_dict import pinyin_dict
from pypinyin.phrases_dict import phrases_dict

ROOT = Path(__file__).resolve().parents[1]
SHARED = ROOT / "shared"
SPEC = SHARED / "spec"
DATA = SHARED / "data"
SRC = SHARED / "sources"
for p in (SPEC, DATA, SRC):
    p.mkdir(parents=True, exist_ok=True)

CJK = re.compile(r"^[\u3400-\u9fff]$")


def toneless(s: str) -> str:
    s = s.replace("ü", "v").replace("Ü", "V")
    s = unicodedata.normalize("NFD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    return s.lower()


def cjk_only(s: str) -> bool:
    return bool(s) and all(CJK.match(c) for c in s)


def build_pinyin():
    chars = {}
    for cp, readings in pinyin_dict.items():
        ch = chr(cp)
        if not CJK.match(ch):
            continue
        first = readings.split(",")[0]
        chars[ch] = toneless(first)
    phrases = {}
    for word, syllables in phrases_dict.items():
        if not (2 <= len(word) <= 4 and cjk_only(word)):
            continue
        phrases[word] = [toneless(x[0]) for x in syllables if x]
    syllables_set = sorted({v for v in chars.values() if v} | {s for v in phrases.values() for s in v})
    json.dump(chars, open(DATA / "pinyin_chars.json", "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    json.dump(phrases, open(DATA / "pinyin_phrases.json", "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    json.dump(syllables_set, open(DATA / "pinyin_syllables.json", "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    print(f"pinyin: {len(chars)} chars, {len(phrases)} phrases, {len(syllables_set)} syllables")


def build_wubi():
    text = Path("/tmp/wubi86.dict.yaml").read_text(encoding="utf-8", errors="replace")
    start = text.find("\n...\n")
    body = text[start + 5 :] if start >= 0 else text
    code_map: dict[str, list[str]] = {}
    char_map: dict[str, str] = {}
    for line in body.splitlines():
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        ch, code = parts[0], parts[1].strip().lower()
        if not CJK.match(ch) or not re.fullmatch(r"[a-z]{1,5}", code):
            continue
        code_map.setdefault(code, [])
        if ch not in code_map[code] and len(code_map[code]) < 12:
            code_map[code].append(ch)
        char_map.setdefault(ch, code)
    json.dump(code_map, open(DATA / "wubi86.json", "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    json.dump(char_map, open(DATA / "wubi_char_codes.json", "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    print(f"wubi: {len(code_map)} codes, {len(char_map)} chars")
    SRC.joinpath("wubi86.dict.yaml").write_bytes(Path("/tmp/wubi86.dict.yaml").read_bytes())


def build_stroke():
    text = Path("/tmp/stroke.dict.yaml").read_text(encoding="utf-8", errors="replace")
    code_map: dict[str, list[str]] = {}
    char_map: dict[str, str] = {}
    for line in text.splitlines():
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        ch, code = parts[0], parts[1].strip().lower()
        if not CJK.match(ch) or not re.fullmatch(r"[hspnz]{1,8}", code):
            continue
        code_map.setdefault(code, [])
        if ch not in code_map[code] and len(code_map[code]) < 12:
            code_map[code].append(ch)
        char_map.setdefault(ch, code)
    json.dump(code_map, open(DATA / "stroke_codes.json", "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    json.dump(char_map, open(DATA / "stroke_char_codes.json", "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    print(f"stroke: {len(code_map)} codes, {len(char_map)} chars")
    SRC.joinpath("stroke.dict.yaml").write_bytes(Path("/tmp/stroke.dict.yaml").read_bytes())


COMMON_EN = """the be to of and a in that have I it for not on with he as you do at this but his by from
they we say her she or an will my one all would there their what so up out if about who get which go me
when make can like time no just him know take people into year your good some could them see other than
then now look only come its over think also back after use two how our work first well way even new want
because any these give day most us is are was were been being has had did does doing very many much more
need help find tell ask try keep let put mean set turn move play run call read write speak listen watch
learn teach study live love hate happy sad angry nice bad big small long short high low old young new
hello thanks please sorry yes okay okay hi bye goodbye morning evening night today tomorrow yesterday
keyboard input method voice text chat translate polish rewrite summarize message send receive copy paste
clipboard phrase emoji sticker handwriting stroke wubi pinyin english chinese number symbol space delete
settings display theme dark light sound vibration gesture swipe tap long press toolbar candidate predict
""".split()
english = sorted(set(w.lower() for w in COMMON_EN if w.isalpha()))
json.dump(english, open(DATA / "english_words.json", "w", encoding="utf-8"), ensure_ascii=False, indent=0)

EMOJI = [
    ("笑脸", "😀 😃 😄 😁 😆 😅 😂 🤣 😊 😇 🙂 😉 😍 🥰 😘 😋 😜 🤪 🤗 🤔 🤐 😴 😎 🥳 😭 😤 😡 🤯 🥺 😳 😱"),
    ("手势", "👍 👎 👏 🙌 🤝 🙏 💪 ✌️ 🤞 👌 🫶 👋 🤙 ✍️ 🖐️"),
    ("爱心", "❤️ 🧡 💛 💚 💙 💜 🖤 🤍 💔 💖 💗 💓 💞 💘"),
    ("动物", "🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐮 🐷 🐸 🐵 🐔 🐧 🐦 🦄 🐝 🦋 🐢 🐙"),
    ("食物", "🍎 🍊 🍋 🍉 🍇 🍓 🍒 🍑 🍍 🥝 🍅 🥑 🍞 🧀 🍔 🍟 🍕 🍜 🍚 🍣 🍰 🍩 ☕ 🍵 🍺"),
    ("活动", "⚽ 🏀 🏈 🎾 🏐 🎱 🎯 🎮 🎲 🎸 🎹 🎤 🎧 🎬 📷 💻 📱 ⌚ 🚗 ✈️ 🚀 🏃 🚴"),
    ("自然", "🌞 🌙 ⭐ 🌈 ☁️ 🌧️ ❄️ ⚡ 🔥 🌊 🌸 🌻 🌹 🌳 🌲 🍀"),
    ("符号", "✅ ❌ ⚠️ ❓ ❗ 💯 🔔 🔥 ✨ 🎉 🎁 💡 📌 📎 🔗"),
]
emoji = [{"category": c, "items": [x for x in s.split() if x]} for c, s in EMOJI]
json.dump(emoji, open(DATA / "emoji.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)

PHRASES = [
    ("你好", "nihao"), ("谢谢", "xiexie"), ("不客气", "bukeqi"), ("再见", "zaijian"),
    ("在吗", "zaima"), ("好的", "haode"), ("收到", "shoudao"), ("稍等", "shaodeng"),
    ("没问题", "meiwenti"), ("辛苦了", "xinkule"), ("早上好", "zaoshanghao"),
    ("晚上好", "wanshanghao"), ("晚安", "wanan"), ("生日快乐", "shengrikuaile"),
    ("新年快乐", "xinniankuaile"), ("恭喜发财", "gongxifacai"), ("我爱你", "woaini"),
    ("想你", "xiangni"), ("注意安全", "zhuyianquan"), ("一路顺风", "yilushunfeng"),
    ("我马上到", "womashangdao"), ("开完会了", "kaiwanhuile"), ("方便通话吗", "fangbiantonghuama"),
    ("发个定位", "fagedingwei"), ("转账给你", "zhuanzhanggeini"),
]
json.dump([{"text": t, "code": c} for t, c in PHRASES], open(DATA / "phrases.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)

DOUBLE = {
    "xiaobe": {
        "name": "小鹤双拼",
        "initials": {"zh": "v", "ch": "i", "sh": "u"},
        "finals": {
            "a": "a", "o": "o", "e": "e", "i": "i", "u": "u", "v": "v", "ai": "d", "ei": "w",
            "ao": "c", "ou": "z", "an": "j", "en": "f", "ang": "h", "eng": "g", "er": "r",
            "ia": "x", "iao": "n", "ie": "p", "iu": "q", "ian": "m", "in": "b", "iang": "l",
            "ing": "k", "iong": "s", "ua": "x", "uai": "k", "uan": "r", "uang": "l", "ui": "v",
            "un": "y", "uo": "o", "ve": "t", "ue": "t",
        },
    },
    "ziranma": {
        "name": "自然码",
        "initials": {"zh": "v", "ch": "i", "sh": "u"},
        "finals": {
            "a": "a", "o": "o", "e": "e", "i": "i", "u": "u", "v": "v", "ai": "l", "ei": "z",
            "ao": "k", "ou": "b", "an": "j", "en": "f", "ang": "h", "eng": "g", "er": "r",
            "ia": "w", "iao": "c", "ie": "x", "iu": "q", "ian": "m", "in": "n", "iang": "d",
            "ing": "y", "iong": "s", "ua": "w", "uai": "y", "uan": "r", "uang": "d", "ui": "v",
            "un": "p", "uo": "o", "ve": "t", "ue": "t",
        },
    },
    "microsoft": {
        "name": "微软双拼",
        "initials": {"zh": "v", "ch": "i", "sh": "u"},
        "finals": {
            "a": "a", "o": "o", "e": "e", "i": "i", "u": "u", "v": "v", "ai": "l", "ei": "z",
            "ao": "k", "ou": "b", "an": "j", "en": "f", "ang": "h", "eng": "g", "er": "r",
            "ia": "w", "iao": "c", "ie": "x", "iu": "q", "ian": "m", "in": "n", "iang": "d",
            "ing": "y", "iong": "s", "ua": "w", "uai": "y", "uan": "r", "uang": "d", "ui": "v",
            "un": "p", "uo": "o", "ve": "t", "ue": "t",
        },
    },
}
json.dump(DOUBLE, open(DATA / "double_pinyin.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)

FUZZY = {
    "pairs": [["zh", "z"], ["ch", "c"], ["sh", "s"], ["n", "l"], ["r", "l"], ["an", "ang"],
              ["en", "eng"], ["in", "ing"], ["ian", "iang"], ["uan", "uang"], ["un", "ong"],
              ["ong", "eng"], ["ai", "ei"], ["u", "v"]],
    "groups": ["zzh", "cch", "ssh", "nl", "rl", "anang", "eneng", "ining", "ianiang",
               "uanuang", "unong", "onong", "huangwang", "huifei", "gk", "hf", "ianiang"],
}
json.dump(FUZZY, open(DATA / "fuzzy_pinyin.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)

# Shared spec
tokens = {
    "name": "微输入法 · WeType-inspired",
    "colors": {
        "background": "#E6F4F2", "surface": "#FFFFFF", "surfaceAlt": "#F7FBFA",
        "accent": "#24C891", "accentDark": "#0E8A68", "accentSoft": "#DFF6EC",
        "text": "#26332F", "textSecondary": "#5F6F69", "muted": "#B8BCC5",
        "border": "#DCE7E3", "warning": "#B45309", "danger": "#B23A3A",
        "key": "#FFFFFF", "keyPressed": "#E9F7F1", "keySpecial": "#DDF2EA",
        "keyText": "#26332F", "keyboardBackground": "#EAF4F1",
    },
    "radius": {"card": 20, "button": 14, "key": 12, "sheet": 26},
    "spacing": {"xs": 4, "sm": 8, "md": 12, "lg": 16, "xl": 24, "xxl": 32},
    "typography": {"display": 30, "title": 22, "headline": 18, "body": 15, "caption": 12, "key": 20},
    "layout": {"phoneColumns": 2, "tabletColumns": 4, "maxContentWidth": 1180, "keyboardMaxWidth": 920},
}
json.dump(tokens, open(SPEC / "design_tokens.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)

layouts = json.load(open(ROOT / "analysis" / "normalized" / "keyboards.json", encoding="utf-8"))
json.dump(layouts, open(SPEC / "keyboard_layouts.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)

modes = [
    {"id": "t9", "name": "九宫格拼音", "layout": "S1ChineseT9Keyboard.json", "language": "zh"},
    {"id": "qwerty", "name": "全键盘拼音", "layout": "S2ChineseQwertyKeyboard.json", "language": "zh"},
    {"id": "handwrite", "name": "手写键盘", "layout": "HandWriteKeyboard.json", "language": "zh"},
    {"id": "stroke", "name": "笔画键盘", "layout": "S7StrokeT9Keyboard.json", "language": "zh"},
    {"id": "wubi", "name": "五笔键盘", "layout": "S17WuBiQwertyKeyboard.json", "language": "zh"},
    {"id": "doublepin", "name": "双拼键盘", "layout": "S9DoublePinQwertyKeyboard.json", "language": "zh"},
    {"id": "english", "name": "英文键盘", "layout": "S3EnglishQwertyKeyboard.json", "language": "en"},
    {"id": "number", "name": "数字键盘", "layout": "S4NumberKeyboard.json", "language": "num"},
    {"id": "symbols", "name": "符号键盘", "layout": "S5SymbolKeyboardView.json", "language": "sym"},
    {"id": "emoji", "name": "表情键盘", "layout": "S11EmojiKeyboard.json", "language": "emoji"},
]
json.dump(modes, open(SPEC / "keyboard_modes.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)

pages = [
    {"id": "home", "title": "首页", "group": "入口", "source": "SetupMain", "route": "/"},
    {"id": "onboarding", "title": "启用与隐私", "group": "入口", "source": "HldPrivacyInfoUI / HldActivationUI", "route": "/onboarding"},
    {"id": "keyboard", "title": "键盘体验", "group": "键盘", "source": "WxHldService / KeyboardView", "route": "/keyboard"},
    {"id": "keyboard_manage", "title": "键盘管理", "group": "键盘", "source": "HldSettingsKeyboardsSettingUI", "route": "/keyboard/manage"},
    {"id": "display", "title": "布局和显示", "group": "设置", "source": "SetupDisplaySetting", "route": "/settings/display"},
    {"id": "keystroke", "title": "按键效果", "group": "设置", "source": "SetupKeystrokeEffect", "route": "/settings/keystroke"},
    {"id": "toolbar", "title": "定制工具栏", "group": "设置", "source": "SetupSecondaryKeyboard", "route": "/settings/toolbar"},
    {"id": "auxiliary", "title": "辅助输入", "group": "设置", "source": "SetupAuxiliaryInput", "route": "/settings/auxiliary"},
    {"id": "fuzzy", "title": "模糊拼音", "group": "设置", "source": "SetupFuzzyPinyin", "route": "/settings/fuzzy"},
    {"id": "voice", "title": "语音转文字", "group": "设置", "source": "SetupVoiceInput", "route": "/settings/voice"},
    {"id": "voice_language", "title": "识别语言", "group": "设置", "source": "SetupLanguageRecognizeInVoice", "route": "/settings/voice/language"},
    {"id": "voice_punctuation", "title": "标点设置", "group": "设置", "source": "SetupPunctuationSettingInVoiceInput", "route": "/settings/voice/punctuation"},
    {"id": "plus", "title": "拼写 Plus", "group": "智能", "source": "SetupPlus", "route": "/settings/plus"},
    {"id": "clipboard", "title": "剪贴板", "group": "设置", "source": "SetupClipboard", "route": "/settings/clipboard"},
    {"id": "sync", "title": "跨设备粘贴同步", "group": "跨设备", "source": "GeneralDeviceSync", "route": "/settings/sync"},
    {"id": "migration", "title": "换机助手", "group": "跨设备", "source": "SetupMigrationAssistant", "route": "/settings/migration"},
    {"id": "standalone", "title": "单机模式", "group": "设置", "source": "HldStandaloneModeUI", "route": "/settings/standalone"},
    {"id": "privacy", "title": "隐私与权限", "group": "设置", "source": "PermissionAndPrivacySetting", "route": "/settings/privacy"},
    {"id": "desktop", "title": "电脑版", "group": "更多", "source": "SetupDesktop", "route": "/more/desktop"},
    {"id": "about", "title": "关于", "group": "更多", "source": "About", "route": "/more/about"},
    {"id": "help", "title": "帮助与反馈", "group": "更多", "source": "FeedbackMain", "route": "/more/help"},
    {"id": "recorder", "title": "AI 录音笔", "group": "功能", "source": "VoiceRecorderActivity", "route": "/recorder"},
    {"id": "recorder_session", "title": "录音会话", "group": "功能", "source": "VoiceRecorderSessionActivity", "route": "/recorder/session"},
    {"id": "transfer", "title": "隔空传送", "group": "功能", "source": "ImeFileTransferUI", "route": "/transfer"},
    {"id": "ai_chat", "title": "问 AI", "group": "功能", "source": "AiChatActivity", "route": "/ai"},
    {"id": "text_tools", "title": "文字工具", "group": "功能", "source": "键盘工具栏", "route": "/tools"},
    {"id": "translate", "title": "边写边译", "group": "功能", "source": "键盘工具栏", "route": "/translate"},
    {"id": "poster", "title": "排版成图", "group": "功能", "source": "排版成图", "route": "/poster"},
    {"id": "phrases", "title": "常用语", "group": "功能", "source": "常用语", "route": "/phrases"},
    {"id": "emoji", "title": "表情", "group": "功能", "source": "表情推荐", "route": "/emoji"},
]
json.dump(pages, open(SPEC / "pages.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)

print("shared data ready")


if __name__ == "__main__":
    build_pinyin()
    build_wubi()
    build_stroke()
    # The remaining JSON is written at import/run time above.
