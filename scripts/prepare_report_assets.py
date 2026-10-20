#!/usr/bin/env python3
"""Copy runtime evidence into the report and build gallery thumbnails."""
from __future__ import annotations

import json
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "reports" / "assets"
IMG = OUT / "images"
THUMB = OUT / "thumbs"
IMG.mkdir(parents=True, exist_ok=True)
THUMB.mkdir(parents=True, exist_ok=True)

GROUPS = {
    "android-20261018": "Android · 原版运行截图 · 2026-10-18",
    "android-keyboard": "Android · 键盘与工具栏 · 2026-10-18",
    "android-20261020": "Android · 原版运行截图 · 2026-10-20",
    "ios-20261019": "iOS · iPhone Mirroring 可见界面 · 2026-10-19",
}

CAPTIONS = {
    "01-home": "首次启动：启用引导（第一步/第二步）",
    "02-ime-picker": "系统输入法选择器：Gboard / 微信输入法 / 轻语输入法",
    "03-home": "首页：文字整理轮播卡 + 功能/设置分组",
    "04-ai-recorder-entry": "AI 录音笔入口：录音精准转写 · AI 实时总结",
    "05-home-return": "首页：问 AI 轮播卡（支持 DeepSeek-R1 文案）",
    "06-home-settings": "首页设置区：布局/按键/工具栏/辅助输入/跨设备/剪贴板",
    "07-layout-display": "布局和显示：候选字大小、数字键盘、上滑输入、Emoji",
    "08-layout-display-bottom": "布局和显示：键盘高度、九宫格侧边栏、深色模式",
    "09-layout-display-end": "布局和显示：主题模式、拼音显示位置",
    "10-home-settings-return": "返回首页并保持滚动位置",
    "11-key-effects": "按键效果：声音、触感强度、按键气泡",
    "12-home-bottom": "首页下半：辅助输入、跨设备、剪贴板、键盘管理",
    "13-home-end": "首页底部：更多入口（隐私、电脑版、关于、帮助与反馈）",
    "14-speech-settings": "语音转文字设置：标点、长按空格、松手发送、智能整理、离线语音",
    "15-home-before-plus": "首页：拼写 Plus 入口与设置项",
    "16-plus-settings": "拼写 Plus：智能拼写、小程序、表情包、Emoji、颜文字、拼写检查、灵动表达等",
    "17-home-return": "从拼写 Plus 返回首页",
    "18-offline-mode": "单机模式：无需联网、下载本地词库与离线语音模型",
    "19-home-return": "从单机模式返回首页",
    "20-privacy-permissions": "隐私与权限：输入法状态、个人词典、麦克风等",
    "21-home-return": "从隐私与权限返回首页",
    "22-home-assist-entry": "首页：辅助输入入口",
    "23-assist-input": "辅助输入：回车发送、中英文/数字间空格、验证码",
    "24-assist-input-bottom": "辅助输入：首字母大写、双击空格句号、模糊拼音",
    "25-keyboard-same-host": "键盘与同一宿主：候选上屏结果",
    "26-keyboard-empty-current": "空输入状态下的键盘与候选栏",
    "27-tools-page-one": "键盘工具栏第一页",
    "28-tools-page-two": "键盘工具栏第二页",
    "29-tools-after-cancel": "关闭工具栏后的宿主状态",
    "30-tools-second-page": "键盘工具栏第二页（实际页次）",
    "31-tools-third-page": "键盘工具栏第三页",
    "32-tools-last-page": "键盘工具栏最后一页",
    "33-carousel-01": "首页轮播 01：文字整理",
    "34-carousel-02": "首页轮播 02：AI 录音笔",
    "35-carousel-03": "首页轮播 03：多语言自由说大模型",
    "36-carousel-04": "首页轮播 04：表情推荐",
    "37-carousel-05": "首页轮播 05：趣味颜文字",
    "38-carousel-06": "首页轮播 06：问 AI",
    "39-carousel-07": "首页轮播 07：排版成图",
    "40-carousel-08": "首页轮播 08：跨设备粘贴传送",
    "41-carousel-09": "首页轮播 09：灵动表达",
    "42-expression-carousel-cta": "灵动表达轮播 CTA",
    "home/screen.png": "原版首页（独立截图）",
    "toolbar/screen.png": "候选栏与工具入口",
    "start/screen.png": "首次启动画面",
    "input-result/screen.png": "候选上屏结果",
    "t9-candidates/screen.png": "九宫格拼音候选",
    "keyboard-modes/screen.png": "键盘选择：六种中文模式",
    "tools-panel/screen.png": "键盘工具栏面板",
    "00-launch": "首次隐私协议（2026-10-20 复采）",
    "10-privacy": "隐私协议：同意并继续",
    "21-home-top": "首页顶部：轮播卡与功能入口（2026-10-20）",
    "22-home-mid": "首页设置区（2026-10-20）",
    "23-home-bottom": "首页底部：更多入口（2026-10-20）",
    "24-home-bottom-return": "从更多页面返回首页",
    "30-layout-top": "布局和显示：顶部（2026-10-20）",
    "31-layout-mid": "布局和显示：键盘高度与侧边栏",
    "32-layout-bottom": "布局和显示：主题与拼音显示",
    "33-key-effects": "按键效果：声音/触感/气泡（2026-10-20）",
    "34-key-effects-bottom": "按键效果：下半",
    "35-custom-toolbar": "定制工具栏：图标预览面板",
    "36-auxiliary-top": "辅助输入：上半（2026-10-20）",
    "37-auxiliary-bottom": "辅助输入：验证码、大写、双击空格",
    "38-device-sync": "跨设备粘贴传送：关联设备、匹配码、传文件",
    "39-clipboard": "剪贴板设置：状态栏快速粘贴、历史记录",
    "40-keyboard-manage": "键盘管理：六种中文键盘与键盘切换键",
    "41-voice-top": "语音转文字设置（2026-10-20）",
    "42-voice-bottom": "语音转文字：离线语音、智能整理",
    "43-plus-top": "拼写 Plus 设置（2026-10-20）",
    "44-plus-bottom": "拼写 Plus：下半",
    "45-standalone": "单机模式：离线说明与启用条件",
    "46-migration": "换机助手",
    "50-privacy": "隐私与权限（2026-10-20）",
    "51-desktop": "电脑版入口",
    "52-about": "关于微信输入法",
    "53-feedback": "帮助与反馈",
    "60-recorder-entry": "AI 录音笔入口（2026-10-20）",
    "61-file-transfer": "隔空传送：需开启拼写 Plus",
    "70-askai-card": "首页轮播：问 AI",
    "71-askai-open": "问 AI 的拼写 Plus 门槛弹层",
    "72-askai-after-plus": "开启拼写 Plus 后返回首页",
    "80-try-edit": "直接启动试用编辑页（未导出，失败）",
    "81-keyboard-t9": "设置搜索宿主中的微信输入法：九宫格候选",
    "82-keyboard-t9": "微信输入法：九宫格拼音候选栏",
    "83-keyboard-t9-settled": "微信输入法：候选栏稳定态",
    "deeplink-wetype___aiChat": "深链 wetype://aiChat：回到首页轮播",
    "deeplink-wetype___voiceRecorder": "深链 wetype://voiceRecorder：录音笔列表",
    "deeplink-wetype___launchFileTransfer": "深链 wetype://launchFileTransfer：隔空传送",
}

IOS_CAPTIONS = {
    "01-home-lower": "iOS 首页下半：设置项",
    "02-home-top": "iOS 首页顶部",
    "03-layout-top": "iOS 布局和显示",
    "04-layout-height-sidebar": "iOS 键盘高度与侧边栏",
    "05-home-top-rested": "iOS 首页顶部（静止态）",
    "06-key-effects": "iOS 按键效果",
    "07-toolbar-open-blurred": "iOS 键盘工具栏（模糊背景）",
    "08-home-settings-middle": "iOS 首页设置区",
    "09-voice-settings": "iOS 语音设置",
    "10-voice-no-jump": "iOS 语音入口（未跳转）",
    "11-standalone": "iOS 单机模式",
    "12-spelling-plus": "iOS 拼写 Plus",
    "13-spelling-plus-bottom": "iOS 拼写 Plus 下半",
    "14-home-more": "iOS 首页更多",
    "15-about-version": "iOS 关于与版本",
    "16-keyboard-management": "iOS 键盘管理",
    "17-auxiliary-input-top": "iOS 辅助输入顶部",
    "18-auxiliary-input-middle": "iOS 辅助输入中部",
    "19-auxiliary-input-correction": "iOS 辅助输入纠错项",
    "20-auxiliary-input-bottom": "iOS 辅助输入底部",
}


def clean_step(step: str) -> str:
    return step.replace("/", "_")


def main():
    rows = json.load(open(ROOT / "analysis" / "normalized" / "screenshots.json", encoding="utf-8"))
    out = []
    for row in rows:
        src = Path(row["src"])
        if not src.exists():
            continue
        group = row["group"]
        step = row["step"]
        name = clean_step(step)
        ext = ".jpg" if group == "ios-20261019" else ".png"
        full = IMG / group / f"{name}{ext}"
        thumb = THUMB / group / f"{name}.jpg"
        full.parent.mkdir(parents=True, exist_ok=True)
        thumb.parent.mkdir(parents=True, exist_ok=True)
        if not full.exists():
            shutil.copy2(src, full)
        im = Image.open(full)
        im = im.convert("RGB")
        im.thumbnail((360, 900))
        im.save(thumb, "JPEG", quality=82)
        if group == "ios-20261019":
            caption = IOS_CAPTIONS.get(name.replace(".", "-"), row["label"])
        else:
            caption = CAPTIONS.get(step, CAPTIONS.get(name, row["label"]))
        out.append({
            "group": group,
            "group_label": GROUPS[group],
            "step": step,
            "name": name,
            "caption": caption,
            "full": str(full.relative_to(ROOT / "reports")),
            "thumb": str(thumb.relative_to(ROOT / "reports")),
            "width": Image.open(full).width,
            "height": Image.open(full).height,
        })
    (OUT / "screenshots.json").write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"prepared {len(out)} images")


if __name__ == "__main__":
    main()
