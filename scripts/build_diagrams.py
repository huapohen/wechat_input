#!/usr/bin/env python3
"""Generate static SVG diagrams for the WeChat Input analysis report.

Graphviz is used for relationship diagrams; keyboard previews are rendered
directly from the extracted layout geometry.
"""
from __future__ import annotations

import json
import subprocess
import textwrap
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AN = ROOT / "analysis" / "normalized"
OUT = ROOT / "reports" / "assets"
OUT.mkdir(parents=True, exist_ok=True)
DOT = "/opt/homebrew/bin/dot"

FONT = "Helvetica, PingFang SC, Noto Sans CJK SC, sans-serif"
INK = "#26332F"
MUTED = "#5F6F69"
GREEN = "#24C891"
GREEN_DARK = "#0E8A68"
BG = "#E6F4F2"
LINE = "#9AAEA8"


def run_dot(name: str, dot_source: str):
    dot_path = OUT / f"{name}.dot"
    svg_path = OUT / f"{name}.svg"
    dot_path.write_text(dot_source, encoding="utf-8")
    subprocess.run([DOT, "-Tsvg", str(dot_path), "-o", str(svg_path)], check=True)
    return svg_path


def esc(s: str) -> str:
    return (s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n"))


def architecture():
    return textwrap.dedent(f'''
    digraph architecture {{
      graph [rankdir=TB, splines=ortho, nodesep=0.26, ranksep=0.5, bgcolor="transparent", fontname="{FONT}", pad="0.12"];
      node [shape=box, style="rounded,filled", fontname="{FONT}", fontsize=9.5, color="#B8C8C3", fillcolor="#FFFFFF", penwidth=1.1, margin="0.12,0.07"];
      edge [color="{LINE}", arrowsize=0.6, fontname="{FONT}", fontsize=7.5, fontcolor="{MUTED}"];

      subgraph cluster_main {{
        label="Main process  (com.tencent.wetype)"; fontsize=10; fontcolor="{GREEN_DARK}"; color="#B9DED4"; style="rounded,dashed";
        main [label="ImeMainSettingActivity\\nlauncher + wetype:// deep links", fillcolor="#E9FBF5"];
        home [label="SetupMain · React Native\\nhome, feature grid, settings list", fillcolor="#E9FBF5"];
        setup [label="Setup* RN modules\\nDisplay · Keystroke · Voice · Plus\\nAuxiliary · Fuzzy · Clipboard\\nKeyboardSelect · Migration"];
        general [label="GeneralDeviceSync\\nMigrationAssistant", fillcolor="#F4F9FF"];
        feedback [label="FeedbackMain\\nhelp / feedback chat", fillcolor="#F4F9FF"];
        rn [label="Hermes bundles\\nsetup.hbc · general.hbc\\nfeedback.hbc · platform.hbc"];
        main -> home [label="loadReactApplication"];
        home -> setup [label="navigation"];
        home -> general;
        home -> feedback;
        rn -> home [style=dashed, label="assets"];
      }}

      subgraph cluster_hld {{
        label=":hld process  (IME + media)"; fontsize=10; fontcolor="#7A4CC2"; color="#DCD0F5"; style="rounded,dashed";
        ime [label="WxHldService\\nInputMethodService", fillcolor="#F3ECFF"];
        kb [label="KeyboardView\\n36 JSON layouts", fillcolor="#F3ECFF"];
        cand [label="Candidate engine\\ncomposition · ranking · learning", fillcolor="#F3ECFF"];
        voice [label="VoiceRecorderActivity\\nVoiceRecorderService", fillcolor="#FFF4E8"];
        transfer [label="ImeFileTransferUI\\nFileTransferService", fillcolor="#FFF4E8"];
        aichat [label="AiChatActivity\\nWebView + bottom input", fillcolor="#FFF4E8"];
        kbmgr [label="HldSettingsKeyboardsSettingUI\\nHldChooseKeyboardUI"];
        ime -> kb;
        kb -> cand;
        ime -> voice;
        ime -> transfer;
        ime -> aichat;
        ime -> kbmgr;
      }}

      subgraph cluster_assets {{
        label="APK assets / native"; fontsize=10; fontcolor="{MUTED}"; color="#D6E2DE"; style="rounded,dashed";
        layouts [label="assets/keyboard/output\\n36 layout JSON"];
        dict [label="assets/config/beta\\nword / pinyin / TTS bins"];
        libs [label="57 arm64 libraries\\nlibime_net · libwetap_business\\nlibvoiceopus · libwechatvoicesilk\\nlibreactnative · libhermes"];
        layouts -> kb [style=dashed, label="data-driven"];
        dict -> cand [style=dashed];
        libs -> ime [style=dashed, label="JNI"];
      }}

      subgraph cluster_cloud {{
        label="Tencent services — NOT usable by the clone"; fontsize=10; fontcolor="#B23A3A"; color="#F0C9C9"; style="rounded,dashed";
        cdn [label="wetype.wxqcloud.qq.com\\nwxkeyboardcms CDN\\narticle / help pages"];
        sync [label="device sync / migration\\nRequestSync · RequestMigration"];
        aiweb [label="AI chat WebView backend\\nRequestChat protobuf"];
        tsf [label="weread.qq.com/wetype/devicetransfer\\nfile transfer landing"];
        cdn -> home [style=dashed, color="#D88", label="config / help"];
        sync -> general [style=dashed, color="#D88"];
        aiweb -> aichat [style=dashed, color="#D88"];
        tsf -> transfer [style=dashed, color="#D88"];
      }}

      subgraph cluster_own {{
        label="Replacement backend (this project)"; fontsize=10; fontcolor="{GREEN_DARK}"; color="#B9E6D9"; style="rounded,dashed";
        api [label="Local API\\n/v1/ai · /v1/asr · /v1/sync · /v1/transfer", fillcolor="#E9FBF5"];
        llm [label="DeepSeek API\\n(OpenAI-compatible)", fillcolor="#E9FBF5"];
        store [label="SQLite / object store", fillcolor="#E9FBF5"];
        api -> llm;
        api -> store;
        aichat -> api [style=dashed, color="{GREEN}", label="replacement"];
        sync -> api [style=dashed, color="{GREEN}", label="replacement"];
      }}
    }}
    ''')


def routes_high():
    return textwrap.dedent(f'''
    digraph routes_high {{
      graph [rankdir=LR, splines=spline, nodesep=0.3, ranksep=0.55, bgcolor="transparent", fontname="{FONT}", pad="0.15"];
      node [shape=box, style="rounded,filled", fontname="{FONT}", fontsize=9, color="#B8C8C3", fillcolor="#FFFFFF", penwidth=1.0, margin="0.12,0.06"];
      edge [color="{LINE}", arrowsize=0.6, fontsize=7.5, fontcolor="{MUTED}"];
      entry [label="Privacy / activation\\nHldPrivacyInfoUI · HldActivationUI", fillcolor="#FFF7E6"];
      home [label="Home\\nSetupMain", fillcolor="#E9FBF5", penwidth=1.8];
      key [label="键盘\\nKeyboard settings", fillcolor="#F3ECFF"];
      look [label="布局与显示\\nKeystroke / Display", fillcolor="#EAF4FF"];
      smart [label="拼写 Plus\\nAI / text tools", fillcolor="#E9FBF5"];
      cross [label="跨设备\\nSync / migration", fillcolor="#F4F9FF"];
      more [label="更多\\nPrivacy / desktop / about / help", fillcolor="#F8F8F8"];
      feat [label="功能\\nAI recorder / file transfer", fillcolor="#FFF4E8"];
      tools [label="Keyboard toolbar\\nAI · polish · translate · clipboard\\nphrases · emoji · handwriting"];
      modes [label="Six Chinese modes\\nT9 · QWERTY · handwriting\\nstroke · Wubi · double-pin"];
      entry -> home [label="accept + enable IME"];
      home -> key; home -> look; home -> smart; home -> cross; home -> more; home -> feat;
      key -> modes;
      key -> tools [label="in-keyboard"];
      smart -> tools;
      feat -> aichat [label="AiChat WebView"];
      feat -> recorder [label="VoiceRecorderActivity"];
      feat -> transfer [label="ImeFileTransferUI"];
      aichat [shape=box, fillcolor="#FFF4E8", label="AI chat\\nWebView"];
      recorder [shape=box, fillcolor="#FFF4E8", label="Recorder\\nlist / session"];
      transfer [shape=box, fillcolor="#FFF4E8", label="File transfer\\nQR / devices"];
    }}
    ''')


def routes_detail():
    return textwrap.dedent(f'''
    digraph routes_detail {{
      graph [rankdir=LR, splines=spline, nodesep=0.22, ranksep=0.45, bgcolor="transparent", fontname="{FONT}", pad="0.1"];
      node [shape=box, style="rounded,filled", fontname="{FONT}", fontsize=7.8, color="#B8C8C3", fillcolor="#FFFFFF", penwidth=0.9, margin="0.09,0.045"];
      edge [color="#A9BBB5", arrowsize=0.5, fontsize=6.8, fontcolor="{MUTED}"];

      home [label="Home / SetupMain", fillcolor="#E9FBF5", penwidth=1.6];
      subgraph cluster_set {{
        label="RN settings"; fontsize=9; fontcolor="{MUTED}"; color="#D6E2DE"; style="rounded,dashed";
        display [label="SetupDisplaySetting\\n布局和显示"]; keystroke [label="SetupKeystrokeEffect\\n按键效果"];
        toolbar [label="SetupSecondaryKeyboard\\n定制工具栏"]; auxiliary [label="SetupAuxiliaryInput\\n辅助输入"];
        fuzzy [label="SetupFuzzyPinyin\\n模糊拼音"]; voice [label="SetupVoiceInput\\n语音转文字"];
        plus [label="SetupPlus\\n拼写Plus"]; clipboard [label="SetupClipboard\\n剪贴板"];
        kbsel [label="SetupKeyboardSelect\\n键盘选择"]; migration [label="SetupMigrationAssistant\\n换机助手"];
        sync [label="GeneralDeviceSync\\n跨设备粘贴同步"]; desktop [label="SetupDesktop\\n电脑版"];
        about [label="About\\n关于"]; help [label="FeedbackMain\\n帮助与反馈"];
        privacy [label="PermissionAndPrivacySetting\\n隐私与权限"];
        lang [label="SetupLanguageRecognizeInVoice\\n识别语言"]; punct [label="SetupPunctuationSettingInVoiceInput\\n标点设置"];
        standby [label="SetupRecordingStandbyTime\\n录音待机"]; voiceicon [label="SetupShowVoiceIconInVoiceInput\\n语音图标"];
        pluspage [label="Plus sub-switches\\nsmart · sticker · emoji\\nkaomoji · rewrite · polish\\nposter · ask AI"];
      }}
      subgraph cluster_native {{
        label="Native pages"; fontsize=9; fontcolor="{MUTED}"; color="#D6E2DE"; style="rounded,dashed";
        kbmgr [label="HldSettingsKeyboardsSettingUI\\n键盘管理"]; choose [label="HldChooseKeyboardUI\\n键盘选择"];
        standalone [label="HldStandaloneModeUI\\n单机模式"]; recorder [label="VoiceRecorderActivity\\nAI 录音笔"];
        session [label="VoiceRecorderSessionActivity\\n录音会话"]; transfer [label="ImeFileTransferUI\\n隔空传送"];
        aichat [label="AiChatActivity\\n问 AI（WebView）"]; activation [label="HldActivationUI\\n启用引导"];
        privacyui [label="HldPrivacyInfoUI\\n隐私说明"]; aboutui [label="HldSettingsAboutUI\\n关于"];
        feedbackui [label="HldFeedbackUI\\n我要反馈"]; web [label="HldWebViewUI\\n帮助文章"];
      }}
      subgraph cluster_tools {{
        label="Keyboard"; fontsize=9; fontcolor="{MUTED}"; color="#D6E2DE"; style="rounded,dashed";
        ime [label="WxHldService\\nIME"]; t9 [label="T9 / QWERTY\\nEnglish / number\\nsymbol / emoji"];
        hand [label="Handwrite / stroke\\nWubi / double-pin"]; panel [label="Tool panel"];
        ask [label="问 AI"]; polish [label="文字整理"]; translate [label="边写边译"];
        phrase [label="常用语"]; clip [label="剪贴板"]; emoji [label="表情推荐"];
      }}
      home -> display; home -> keystroke; home -> toolbar; home -> auxiliary; home -> voice; home -> plus; home -> clipboard; home -> kbsel; home -> sync; home -> migration; home -> standalone; home -> kbmgr; home -> recorder; home -> transfer; home -> desktop; home -> about; home -> help; home -> privacy;
      voice -> lang; voice -> punct; voice -> standby; voice -> voiceicon;
      auxiliary -> fuzzy;
      plus -> pluspage;
      sync -> clipboard;
      kbsel -> choose; kbsel -> kbmgr;
      kbmgr -> choose;
      help -> feedbackui; about -> aboutui;
      privacy -> privacyui;
      desktop -> web;
      ime -> t9; ime -> hand; ime -> panel;
      panel -> ask; panel -> polish; panel -> translate; panel -> phrase; panel -> clip; panel -> emoji;
      ask -> aichat; polish -> aichat; translate -> aichat;
      recorder -> session;
      activation -> home; privacyui -> home;
      web -> help [style=dashed];
    }}
    ''')


def keyboard_fsm():
    return textwrap.dedent(f'''
    digraph keyboard_fsm {{
      graph [rankdir=LR, splines=spline, nodesep=0.35, ranksep=0.5, bgcolor="transparent", fontname="{FONT}", pad="0.15"];
      node [shape=box, style="rounded,filled", fontname="{FONT}", fontsize=9, color="#B8C8C3", fillcolor="#FFFFFF", penwidth=1.1, margin="0.12,0.07"];
      edge [color="{LINE}", arrowsize=0.65, fontsize=8, fontcolor="{MUTED}"];
      idle [label="Idle\\nhost field focused", fillcolor="#E9FBF5"];
      comp [label="Composing\\npinyin / stroke / code buffer", fillcolor="#F3ECFF"];
      cand [label="Candidates\\nranking + learning", fillcolor="#F3ECFF"];
      commit [label="Commit\\nsetComposingText / commitText", fillcolor="#E9FBF5"];
      voice [label="Voice listening\\npartial transcript", fillcolor="#FFF4E8"];
      final [label="Final transcript\\npunct + optional polish", fillcolor="#FFF4E8"];
      panel [label="Tool panel\\nAI · translate · clipboard · phrases"];
      switch [label="Mode switch\\nT9/QWERTY/handwrite/stroke\\nWubi/double-pin/symbol/emoji"];
      idle -> comp [label="letter / digit / stroke"];
      comp -> cand [label="segmentation + lookup"];
      cand -> commit [label="tap candidate / space"];
      cand -> comp [label="edit / delete"];
      commit -> idle [label="host accepts"];
      idle -> voice [label="long-press space / mic"];
      voice -> voice [label="partial result"];
      voice -> final [label="release / stop"];
      final -> commit [label="insert"];
      idle -> panel [label="toolbar"];
      panel -> voice [label="voice"];
      panel -> switch;
      switch -> idle;
      panel -> idle [label="close"];
    }}
    ''')


def ai_flow():
    return textwrap.dedent(f'''
    digraph ai_flow {{
      graph [rankdir=LR, splines=ortho, nodesep=0.3, ranksep=0.55, bgcolor="transparent", fontname="{FONT}", pad="0.15"];
      node [shape=box, style="rounded,filled", fontname="{FONT}", fontsize=9, color="#B8C8C3", fillcolor="#FFFFFF", penwidth=1.1, margin="0.12,0.07"];
      edge [color="{LINE}", arrowsize=0.6, fontsize=7.5, fontcolor="{MUTED}"];

      subgraph cluster_orig {{
        label="Original path — not reproducible"; fontsize=10; fontcolor="#B23A3A"; color="#F0C9C9"; style="rounded,dashed";
        kbd [label="Keyboard / text tool\\nselection + command"]; native [label="Java/Kotlin bridge\\nRequestChat / Dispatch"];
        net [label="libime_net.so\\nprotobuf + signing"]; web [label="AiChat WebView\\nremote page", fillcolor="#FFF4E8"];
        cloud [label="Tencent cloud\\nno public API", fillcolor="#FFE9E9"];
        kbd -> native -> net -> cloud;
        kbd -> web -> cloud [style=dashed];
      }}
      subgraph cluster_new {{
        label="Replacement path — configured by URL"; fontsize=10; fontcolor="{GREEN_DARK}"; color="#B9E6D9"; style="rounded,dashed";
        app [label="Flutter / Android / iOS\\nAI chat, polish, translate", fillcolor="#E9FBF5"];
        api [label="Own backend\\n/v1/ai/chat · /v1/ai/polish\\n/v1/ai/translate · /v1/asr", fillcolor="#E9FBF5"];
        llm [label="DeepSeek API\\nOpenAI-compatible", fillcolor="#E9FBF5"];
        key [label="Server-side key\\nenv only", fillcolor="#FFF7E6"];
        app -> api [label="SSE / JSON"];
        api -> llm;
        key -> api [style=dashed];
      }}
    }}
    ''')


def reconstruction():
    return textwrap.dedent(f'''
    digraph reconstruction {{
      graph [rankdir=LR, splines=ortho, nodesep=0.3, ranksep=0.55, bgcolor="transparent", fontname="{FONT}", pad="0.15"];
      node [shape=box, style="rounded,filled", fontname="{FONT}", fontsize=9, color="#B8C8C3", fillcolor="#FFFFFF", penwidth=1.1, margin="0.12,0.07"];
      edge [color="{LINE}", arrowsize=0.6, fontsize=7.5, fontcolor="{MUTED}"];
      spec [label="Shared spec\\nkeyboard layouts · pinyin / Wubi\\ndictionaries · design tokens", fillcolor="#E9FBF5"];
      flutter [label="Flutter universal\\nAndroid + iOS\\nphone + tablet", fillcolor="#EAF4FF"];
      android [label="Native Android\\nKotlin IME + app\\nphone + tablet", fillcolor="#F3ECFF"];
      ios [label="Native iOS\\nSwiftUI + keyboard extension\\niPhone + iPad", fillcolor="#FFF4E8"];
      backend [label="Backend\\nAI · ASR · sync · transfer", fillcolor="#E9FBF5"];
      spec -> flutter; spec -> android; spec -> ios;
      flutter -> backend; android -> backend; ios -> backend;
      flutter -> apk [label="APK"]; flutter -> sim [label="iOS simulator / archive"];
      android -> apk2 [label="APK"]; ios -> ipa [label="IPA / simulator"];
      apk [shape=note]; apk2 [shape=note]; sim [shape=note]; ipa [shape=note];
    }}
    ''')


KEY_LABELS = {
    "delete": "⌫", "space": "空格", "enter": "换行", "newline_clear": "换行",
    "symbol": "符号", "num": "123", "emoji": "☺", "chSwitch": "中/英",
    "shift": "⇧", "search": "搜索", "send": "发送", "back": "返回",
}


def keyboard_svg(spec):
    width = 540
    height = int(spec["vheight"] * width / spec["vwidth"]) + 48
    margin = 14
    gap = 5
    inner_w = width - 2 * margin
    line_count = len(spec["lines"])
    line_h = (height - 48 - 2 * margin - gap * (line_count - 1)) / max(line_count, 1)
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" role="img">',
        f'<rect width="{width}" height="{height}" rx="16" fill="#E6F4F2"/>',
        f'<text x="{margin}" y="26" font-family="{FONT}" font-size="13" font-weight="700" fill="{INK}">{spec["file"].replace("Keyboard.json", "")}</text>',
        f'<text x="{width-margin}" y="26" text-anchor="end" font-family="{FONT}" font-size="9" fill="{MUTED}">{spec["key_count"]} keys · {spec["vwidth"]}×{spec["vheight"]}</text>',
    ]
    y = 38 + margin
    for line in spec["lines"]:
        keys = [k for k in line["keys"] if "recycle" not in (k.get("id") or "").lower()]
        keys = [k for k in keys if k.get("width") != 0 or k.get("main_text")] or keys
        if not keys:
            keys = line["keys"]
        widths = [float(k.get("width") or 0) for k in keys]
        if sum(widths) <= 0:
            widths = [1] * len(keys)
        total = sum(widths)
        x = margin
        for k, w in zip(keys, widths):
            kw = inner_w * w / total - gap
            if kw < 12:
                kw = inner_w / len(keys) - gap
            label = k.get("main_text") or KEY_LABELS.get(k.get("id", ""), "")
            if not label:
                kid = (k.get("id", "") or "").lower()
                if "delete" in kid:
                    label = "DEL"
                elif "space" in kid:
                    label = "空格"
                elif "enter" in kid or "newline" in kid:
                    label = "换行"
                elif "symbol" in kid:
                    label = "符号"
                elif "num" in kid:
                    label = "123"
                elif "emoji" in kid:
                    label = "表情"
                else:
                    label = (k.get("id", "") or "").split("_")[-1][:6]
            fill = "#FFFFFF"
            fg = INK
            if k.get("id") in {"enter", "search", "send"}:
                fill, fg = GREEN, "#FFFFFF"
            elif k.get("type") == 2 and k.get("id") in {"symbol", "num", "chSwitch"}:
                fill, fg = "#EAF4FF", "#2A5D8A"
            if k.get("id") == "space":
                fill, fg = "#F7F9F8", MUTED
            parts.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{kw:.1f}" height="{line_h:.1f}" rx="8" fill="{fill}" stroke="#DCE7E3" stroke-width="0.8"/>')
            size = 12 if len(label) <= 3 else 9
            parts.append(f'<text x="{x+kw/2:.1f}" y="{y+line_h/2+size*0.35:.1f}" text-anchor="middle" font-family="{FONT}" font-size="{size}" font-weight="600" fill="{fg}">{esc(label)}</text>')
            x += kw + gap
        y += line_h + gap
    parts.append("</svg>")
    return "\n".join(parts)


def settings_er():
    return textwrap.dedent(f'''
    digraph settings_er {{
      graph [rankdir=LR, splines=ortho, nodesep=0.25, ranksep=0.5, bgcolor="transparent", fontname="{FONT}", pad="0.12"];
      node [shape=record, style="rounded,filled", fontname="{FONT}", fontsize=8.5, color="#B8C8C3", fillcolor="#FFFFFF", penwidth=1.0];
      edge [color="{LINE}", arrowsize=0.6, fontsize=7, fontcolor="{MUTED}"];
      main [label="{{MainSettingInfo|37 fields|isEnablePlusMode · isEnableAssociating\lisEnableEnglishAutoCorrect · isEnableFuzzyPinyin\lisEnableStandaloneMode · isClipboardEnableState\lisEnableVoiceRecorder · isSupportAskAI\lcandidateWordSize · swipeUpInputMode}}", fillcolor="#E9FBF5"];
      plus [label="{{PlusItemInfo|10 switches|smart spelling · spelling correct\lsticker · small emoji · kaomoji\lrewrite · text polish · poster\lask AI · quick send}}", fillcolor="#F3ECFF"];
      voice [label="{{VoiceInputInfo|offline speech · long-press\lrelease-to-send · smart polish\lpunctuation · language · dialect\licon show time}}", fillcolor="#FFF4E8"];
      key [label="{{KeystrokeEffectInfo|sound · volume\lvibrate · level\lfollow system}}", fillcolor="#EAF4FF"];
      display [label="{{DisplaySettingInfo|candidateWordGear}}", fillcolor="#EAF4FF"];
      fuzzy [label="{{FuzzyPinyinInfo|20 pairs|zzh · cch · ssh\lnl · rl · anang · eneng\lining · ianiang · uanuang …}}", fillcolor="#F4F9FF"];
      theme [label="{{ColorThemeInfo|colorThemeMode}}", fillcolor="#F8F8F8"];
      main -> plus [label="plusItemInfo"];
      main -> voice [label="voiceInputInfo"];
      main -> key [label="keystrokeEffectInfo"];
      main -> display [label="display"];
      main -> fuzzy [label="fuzzyPinyinInfo"];
      main -> theme [label="colorThemeInfo"];
    }}
    ''')

def sequence_svg(name, actors, messages):
    width = 980
    left = 40
    step = (width - 2 * left) / max(len(actors) - 1, 1)
    xs = [left + i * step for i in range(len(actors))]
    top = 36
    row = 54
    height = top + 62 + row * len(messages) + 30
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" font-family="{FONT}">',
           f'<rect width="{width}" height="{height}" rx="16" fill="#FFFFFF"/>']
    # actor boxes
    for i, a in enumerate(actors):
        x = xs[i]
        w = 150
        out.append(f'<rect x="{x-w/2:.1f}" y="{top-24}" width="{w}" height="34" rx="9" fill="#E9FBF5" stroke="#B9DED4"/>')
        out.append(f'<text x="{x}" y="{top-2}" text-anchor="middle" font-size="10.5" font-weight="700" fill="{INK}">{esc(a)}</text>')
        out.append(f'<line x1="{x}" y1="{top+10}" x2="{x}" y2="{height-22}" stroke="#D6E2DE" stroke-width="1" stroke-dasharray="3 4"/>')
    y = top + 58
    idx = {a: i for i, a in enumerate(actors)}
    for msg in messages:
        frm, to, label, kind = msg
        fi = idx.get(frm, frm) if isinstance(frm, str) else frm
        ti = idx.get(to, to) if isinstance(to, str) else to
        x1, x2 = xs[fi], xs[ti]
        color = {"req":"#0E8A68", "res":"#2A5D8A", "local":"#7A4CC2", "note":"#B45309"}.get(kind, "#5F6F69")
        out.append(f'<line x1="{x1}" y1="{y}" x2="{x2}" y2="{y}" stroke="{color}" stroke-width="1.4" marker-end="url(#arrow)"/>')
        mid = (x1 + x2) / 2
        out.append(f'<text x="{mid}" y="{y-8}" text-anchor="middle" font-size="9.5" fill="{color}">{esc(label)}</text>')
        if ti == fi:
            out.append(f'<path d="M{x1},{y} q40,-20 0,-34" fill="none" stroke="{color}" stroke-width="1.3" marker-end="url(#arrow)"/>')
        y += row
    out.insert(1, '<defs><marker id="arrow" markerWidth="7" markerHeight="7" refX="6" refY="3.5" orient="auto"><path d="M0,0 L7,3.5 L0,7 z" fill="#7A8A85"/></marker></defs>')
    out.append('</svg>')
    return "\n".join(out)

def ai_sequence():
    return sequence_svg("ai-sequence",
        ["用户", "键盘/文字工具", "客户端", "自有后端", "DeepSeek"],
        [("用户", 1, "选中文本，点「问 AI」", "local"),
         (1, 2, "携带 source/text 打开 AI 页", "req"),
         (2, 3, "POST /v1/ai/chat (SSE)", "req"),
         (3, 4, "上游 chat/completions", "req"),
         (4, 3, "token 流", "res"),
         (3, 2, "SSE data:{text}", "res"),
         (2, 2, "渲染 / 停止 / 重试", "local"),
         (2, 1, "复制 / 插入到宿主", "res"),
         (1, 0, "显示结果，保留本地历史", "note")])

def voice_sequence():
    return sequence_svg("voice-sequence",
        ["用户", "IME / 键盘", "系统 ASR", "AI 整理", "宿主输入框"],
        [("用户", "IME / 键盘", "长按空格 / 点麦克风", "local"),
         ("IME / 键盘", "系统 ASR", "申请权限 / start", "req"),
         ("系统 ASR", "IME / 键盘", "partial transcript", "res"),
         ("IME / 键盘", "宿主输入框", "partial 预览（不提交）", "local"),
         ("用户", "IME / 键盘", "松手 / 停止", "req"),
         ("IME / 键盘", "系统 ASR", "stop", "req"),
         ("系统 ASR", "IME / 键盘", "final + 标点", "res"),
         ("IME / 键盘", "AI 整理", "可选智能整理", "req"),
         ("AI 整理", "IME / 键盘", "整理结果", "res"),
         ("IME / 键盘", "宿主输入框", "commitText / 替换范围", "req"),
         ("IME / 键盘", "宿主输入框", "取消：恢复进入前文本", "note")])


def main():
    run_dot("architecture", architecture())
    run_dot("routes-high", routes_high())
    run_dot("routes-detail", routes_detail())
    run_dot("keyboard-fsm", keyboard_fsm())
    run_dot("ai-flow", ai_flow())
    run_dot("reconstruction", reconstruction())
    run_dot("settings-er", settings_er())
    (OUT / "ai-sequence.svg").write_text(ai_sequence(), encoding="utf-8")
    (OUT / "voice-sequence.svg").write_text(voice_sequence(), encoding="utf-8")
    specs = {s["file"]: s for s in json.load(open(AN / "keyboards.json", encoding="utf-8"))}
    selected = {
        "S1ChineseT9Keyboard.json": "keyboard-t9",
        "S2ChineseQwertyKeyboard.json": "keyboard-qwerty",
        "S7StrokeT9Keyboard.json": "keyboard-stroke",
        "S17WuBiQwertyKeyboard.json": "keyboard-wubi",
        "S9DoublePinQwertyKeyboard.json": "keyboard-doublepin",
        "S5SymbolKeyboardView.json": "keyboard-symbols",
        "S11EmojiKeyboard.json": "keyboard-emoji",
        "HandWriteKeyboard.json": "keyboard-handwrite",
    }
    for fname, out in selected.items():
        if fname in specs:
            (OUT / f"{out}.svg").write_text(keyboard_svg(specs[fname]), encoding="utf-8")
    print("wrote diagrams to", OUT)


if __name__ == "__main__":
    main()
