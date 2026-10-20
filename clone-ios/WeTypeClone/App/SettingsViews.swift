import SwiftUI
import UIKit
import AVFoundation
import Speech
import AudioToolbox

// MARK: - Layout & display

struct DisplaySettingsView: View {
    @AppStorage(SharedKeys.candidateSize, store: SharedStore.defaults) private var candidateSize = 18.0
    @AppStorage(SharedKeys.height, store: SharedStore.defaults) private var keyboardHeight = 320.0
    @AppStorage(SharedKeys.numberRow, store: SharedStore.defaults) private var numberRow = false
    @AppStorage(SharedKeys.slideInput, store: SharedStore.defaults) private var slideInput = true
    @AppStorage(SharedKeys.emojiKey, store: SharedStore.defaults) private var emojiKey = true
    @AppStorage(SharedKeys.sidebar, store: SharedStore.defaults) private var sidebar = false
    @AppStorage(SharedKeys.theme, store: SharedStore.defaults) private var theme = "薄荷绿"
    @AppStorage(SharedKeys.darkMode, store: SharedStore.defaults) private var darkMode = "跟随系统"
    @AppStorage(SharedKeys.pinyinPosition, store: SharedStore.defaults) private var pinyinPosition = PinyinPosition.candidateBar.rawValue

    var body: some View {
        PageShell(title: "布局和显示", subtitle: "候选大小、键盘高度、主题与拼音位置") {
            VStack(spacing: 14) {
                previewCard
                VStack(spacing: 0) {
                    sliderRow("候选字大小", value: $candidateSize, range: 14...26, step: 1, suffix: "pt")
                    Divider()
                    sliderRow("键盘高度", value: $keyboardHeight, range: 280...380, step: 10, suffix: "pt")
                    Divider()
                    ToggleRow(title: "数字键盘", subtitle: "在中文键盘顶部显示数字行", isOn: $numberRow)
                    Divider()
                    ToggleRow(title: "上滑输入", subtitle: "上滑按键输入符号与数字", isOn: $slideInput)
                    Divider()
                    ToggleRow(title: "Emoji 键", subtitle: "在底栏显示表情键", isOn: $emojiKey)
                    Divider()
                    ToggleRow(title: "九宫格侧边栏", subtitle: "在九宫格右侧显示符号快捷列", isOn: $sidebar)
                }
                .card(padding: 14)

                VStack(spacing: 0) {
                    ChoiceRow(title: "键盘主题", subtitle: "重建的薄荷色视觉语言", options: ["薄荷绿", "浅蓝", "暖白", "跟随系统"], selection: $theme)
                    Divider()
                    ChoiceRow(title: "深色模式", subtitle: "仅影响键盘与设置的外观偏好", options: ["跟随系统", "浅色", "深色"], selection: $darkMode)
                    Divider()
                    ChoiceRow(title: "拼音显示位置", subtitle: "输入中的拼音显示在哪里", options: PinyinPosition.allCases.map(\.rawValue), selection: $pinyinPosition)
                }
                .card(padding: 14)

                InfoBanner(text: "这些偏好通过 App Group 写入共享 UserDefaults，键盘扩展会读取同一份设置。若修改后键盘未立即刷新，切换到其他输入框即可。")
            }
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("候选预览")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(Int(keyboardHeight)) pt")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.muted)
            }
            HStack(spacing: 6) {
                Text("ni")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.accentDark)
                Divider().frame(height: 18)
                ForEach(Array(["你", "尼", "呢", "泥", "拟"].enumerated()), id: \.offset) { index, item in
                    Text(item)
                        .font(.system(size: candidateSize, weight: index == 0 ? .semibold : .regular))
                        .foregroundStyle(index == 0 ? Theme.accentDark : Theme.text)
                        .padding(.horizontal, 5)
                        .background(index == 0 ? Theme.accentSoft : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                Spacer()
            }
            .padding(9)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            HStack(spacing: 4) {
                ForEach(0..<9) { _ in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.key)
                        .frame(height: 24)
                }
            }
            .padding(5)
            .background(Theme.keyboardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .card(alt: true)
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("\(Int(value.wrappedValue)) \(suffix)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
            }
            Slider(value: value, in: range, step: step)
                .tint(Theme.accent)
        }
        .padding(.vertical, 9)
    }
}

// MARK: - Keystroke

struct KeystrokeSettingsView: View {
    @AppStorage(SharedKeys.sound, store: SharedStore.defaults) private var soundOn = true
    @AppStorage(SharedKeys.haptic, store: SharedStore.defaults) private var haptic = HapticStrength.medium.rawValue
    @AppStorage(SharedKeys.bubble, store: SharedStore.defaults) private var bubble = true
    @State private var pulse = false

    var body: some View {
        PageShell(title: "按键效果", subtitle: "声音、触感与按键气泡") {
            VStack(spacing: 14) {
                VStack(spacing: 0) {
                    ToggleRow(title: "按键声音", subtitle: "点击键盘时播放系统按键音", isOn: $soundOn)
                    Divider()
                    ChoiceRow(title: "触感强度", subtitle: "支持设备上的轻/中/强反馈", options: HapticStrength.allCases.map(\.rawValue), selection: $haptic)
                    Divider()
                    ToggleRow(title: "按键气泡", subtitle: "按下时显示放大的按键字符预览", isOn: $bubble)
                }
                .card(padding: 14)

                VStack(spacing: 12) {
                    HStack {
                        Text("试一试")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Spacer()
                        Text("会真实播放声音与触感")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Button {
                        fire()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(pulse ? Theme.accentSoft : Theme.surface)
                                .frame(width: 94, height: 58)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accent.opacity(pulse ? 0.8 : 0.25), lineWidth: 1.4))
                            Text("按 键")
                                .font(.system(size: 19, weight: .medium))
                                .foregroundStyle(Theme.text)
                        }
                    }
                    .buttonStyle(.plain)
                    Text(bubble ? "气泡预览已开启" : "气泡预览已关闭")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity)
                .card()

                InfoBanner(text: "键盘扩展中的声音与触感受系统“键盘反馈”设置影响；iOS 可能限制第三方键盘的触感强度。")
            }
        }
    }

    private func fire() {
        if soundOn { AudioServicesPlaySystemSound(1104) }
        switch HapticStrength(rawValue: haptic) ?? .medium {
        case .off: break
        case .light: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .strong: UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        withAnimation(.easeOut(duration: 0.12)) { pulse = true }
        Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            await MainActor.run { withAnimation { pulse = false } }
        }
    }
}

// MARK: - Toolbar

struct ToolbarSettingsView: View {
    @EnvironmentObject private var app: AppModel
    @State private var tools: [ToolAction] = SharedStore.toolbarActions

    var body: some View {
        PageShell(title: "定制工具栏", subtitle: "决定键盘上方显示哪些工具，顺序可调整") {
            VStack(spacing: 14) {
                toolbarPreview
                VStack(spacing: 0) {
                    ForEach(Array(tools.enumerated()), id: \.element) { index, tool in
                        HStack(spacing: 10) {
                            SettingIcon(symbol: tool.symbol)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(tool.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Theme.text)
                                Text("位置 \(index + 1)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Button {
                                move(index, by: -1)
                            } label: {
                                Image(systemName: "chevron.up")
                                    .frame(width: 28, height: 28)
                            }
                            .disabled(index == 0)
                            .buttonStyle(.plain)
                            .foregroundStyle(index == 0 ? Theme.muted : Theme.accentDark)
                            Button {
                                move(index, by: 1)
                            } label: {
                                Image(systemName: "chevron.down")
                                    .frame(width: 28, height: 28)
                            }
                            .disabled(index == tools.count - 1)
                            .buttonStyle(.plain)
                            .foregroundStyle(index == tools.count - 1 ? Theme.muted : Theme.accentDark)
                            Toggle("", isOn: Binding(
                                get: { tools.contains(tool) },
                                set: { included in
                                    if included {
                                        if !tools.contains(tool) { tools.append(tool) }
                                    } else if tools.count > 1 {
                                        tools.removeAll { $0 == tool }
                                    }
                                }
                            ))
                            .labelsHidden()
                            .tint(Theme.accent)
                        }
                        .padding(.vertical, 8)
                        if index < tools.count - 1 { Divider().padding(.leading, 42) }
                    }
                }
                .card(padding: 14)

                VStack(spacing: 0) {
                    ForEach(ToolAction.allCases.filter { !tools.contains($0) }) { tool in
                        Button {
                            tools.append(tool)
                        } label: {
                            HStack {
                                SettingIcon(symbol: tool.symbol, color: Theme.muted)
                                Text(tool.title)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(Theme.accentDark)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .card(padding: 14)

                HStack {
                    SecondaryButton(title: "全部显示", symbol: "eye") {
                        tools = ToolAction.allCases
                        persist()
                    }
                    SecondaryButton(title: "恢复默认", symbol: "arrow.counterclockwise") {
                        tools = ToolAction.allCases
                        persist()
                        app.flash("已恢复默认工具栏")
                    }
                }
            }
        }
    }

    private var toolbarPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("键盘预览")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tools) { tool in
                        VStack(spacing: 2) {
                            Image(systemName: tool.symbol)
                                .font(.system(size: 13))
                            Text(tool.title)
                                .font(.system(size: 8))
                        }
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 42, height: 30)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                }
                .padding(6)
            }
            .background(Theme.keyboardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .card(alt: true)
    }

    private func move(_ index: Int, by offset: Int) {
        let target = index + offset
        guard tools.indices.contains(index), tools.indices.contains(target) else { return }
        tools.swapAt(index, target)
        persist()
    }

    private func persist() {
        SharedStore.setStringArray(SharedKeys.toolbar, tools.map(\.rawValue))
    }
}

// MARK: - Auxiliary

struct AuxiliaryInputView: View {
    @AppStorage(SharedKeys.auxReturnSends, store: SharedStore.defaults) private var returnSends = true
    @AppStorage(SharedKeys.auxSpaceBetween, store: SharedStore.defaults) private var spaceBetween = true
    @AppStorage(SharedKeys.auxVerification, store: SharedStore.defaults) private var verification = true
    @AppStorage(SharedKeys.auxAutoCapital, store: SharedStore.defaults) private var autoCapital = true
    @AppStorage(SharedKeys.auxDoubleSpace, store: SharedStore.defaults) private var doubleSpace = true

    var body: some View {
        PageShell(title: "辅助输入", subtitle: "让输入更顺手的细节开关") {
            VStack(spacing: 14) {
                VStack(spacing: 0) {
                    ToggleRow(title: "回车发送", subtitle: "在聊天输入框中回车直接发送", isOn: $returnSends)
                    Divider()
                    ToggleRow(title: "中英文/数字间空格", subtitle: "在中文与英文、数字之间自动补空格", isOn: $spaceBetween)
                    Divider()
                    ToggleRow(title: "验证码", subtitle: "识别短信验证码并快速上屏（受系统限制）", isOn: $verification)
                    Divider()
                    ToggleRow(title: "首字母大写", subtitle: "英文句首自动大写", isOn: $autoCapital)
                    Divider()
                    ToggleRow(title: "双击空格句号", subtitle: "英文模式连续两次空格插入句号", isOn: $doubleSpace)
                }
                .card(padding: 14)

                NavigationLink(value: Route.fuzzy) {
                    SettingsRow(icon: "character.bubble", title: "模糊拼音", subtitle: "zh/z、ch/c、sh/s 等模糊匹配")
                }
                .buttonStyle(.plain)
                .card(padding: 14)

                InfoBanner(text: "这些开关由主 App 与键盘扩展共享。验证码与发送行为还受宿主 App 的键盘类型限制。")
            }
        }
    }
}

// MARK: - Fuzzy pinyin

struct FuzzyPinyinView: View {
    @EnvironmentObject private var app: AppModel
    @State private var enabled: Set<String> = SharedStore.fuzzyPairs

    private let pairs: [(String, String, String)] = [
        ("zh-z", "zh ↔ z", "知道 zhidao / zidao"),
        ("ch-c", "ch ↔ c", "吃饭 chifan / cifan"),
        ("sh-s", "sh ↔ s", "时候 shihou / sihou"),
        ("n-l", "n ↔ l", "牛奶 niunai / liulai"),
        ("r-l", "r ↔ l", "然后 ranhou / lanhou"),
        ("an-ang", "an ↔ ang", "安全 anquan / angquan"),
        ("en-eng", "en ↔ eng", "认真 renzhen / rengzheng"),
        ("in-ing", "in ↔ ing", "拼音 pinyin / pingyin"),
        ("ian-iang", "ian ↔ iang", "见面 jianmian / jiangmian"),
        ("uan-uang", "uan ↔ uang", "观光 guanguang"),
        ("un-ong", "un ↔ ong", "困难 kunnan / kongnan"),
        ("ong-eng", "ong ↔ eng", "中国 zhongguo / zhengguo"),
        ("ai-ei", "ai ↔ ei", "爱情 aiqing / eiqing"),
        ("u-v", "u ↔ ü", "绿色 lüse / luse"),
    ]

    var body: some View {
        PageShell(title: "模糊拼音", subtitle: "为不标准的拼音提供候选容错") {
            VStack(spacing: 14) {
                HStack {
                    StatusPill(text: "已启用 \(enabled.count) 组", ok: true)
                    Spacer()
                    SecondaryButton(title: "全部开启", symbol: "checkmark.circle") {
                        enabled = Set(pairs.map(\.0))
                        persist()
                    }
                    SecondaryButton(title: "全部关闭", symbol: "circle.slash") {
                        enabled = []
                        persist()
                    }
                }

                VStack(spacing: 0) {
                    ForEach(pairs, id: \.0) { pair in
                        ToggleRow(title: pair.1, subtitle: pair.2,
                                  isOn: Binding(get: { enabled.contains(pair.0) },
                                                set: { value in
                                                    if value { enabled.insert(pair.0) } else { enabled.remove(pair.0) }
                                                    persist()
                                                }))
                        if pair.0 != pairs.last?.0 { Divider() }
                    }
                }
                .card(padding: 14)

                InfoBanner(text: "模糊拼音立即用于键盘扩展的候选查询：开启后会生成有限的拼写变体，并优先显示精确匹配。候选被删除时会写入本地学习黑名单。")
            }
        }
    }

    private func persist() {
        SharedStore.setStringArray(SharedKeys.fuzzyPairs, Array(enabled))
        app.flash("模糊拼音设置已保存")
    }
}

// MARK: - Voice

struct VoiceSettingsView: View {
    @AppStorage(SharedKeys.voiceLongPress, store: SharedStore.defaults) private var longPress = true
    @AppStorage(SharedKeys.voiceRelease, store: SharedStore.defaults) private var release = VoiceReleaseAction.insert.rawValue
    @AppStorage(SharedKeys.voiceSmart, store: SharedStore.defaults) private var smart = true
    @AppStorage(SharedKeys.voiceOffline, store: SharedStore.defaults) private var offline = true
    @AppStorage(SharedKeys.voiceStandby, store: SharedStore.defaults) private var standby = "15 秒"
    @AppStorage(SharedKeys.voiceShowIcon, store: SharedStore.defaults) private var showIcon = true
    @AppStorage(SharedKeys.voiceLanguage, store: SharedStore.defaults) private var language = "普通话"
    @AppStorage(SharedKeys.voicePunctuation, store: SharedStore.defaults) private var punctuation = true

    var body: some View {
        PageShell(title: "语音转文字", subtitle: "长按空格说话，松手按你的习惯处理") {
            VStack(spacing: 14) {
                VStack(spacing: 0) {
                    ToggleRow(title: "长按空格语音", subtitle: "在键盘上长按空格开始录音", isOn: $longPress)
                    Divider()
                    ChoiceRow(title: "松手动作", subtitle: "松开空格后的行为", options: VoiceReleaseAction.allCases.map(\.rawValue), selection: $release)
                    Divider()
                    ToggleRow(title: "智能整理", subtitle: "自动去除口水词并补全标点（需要后端）", isOn: $smart)
                    Divider()
                    ToggleRow(title: "离线语音", subtitle: "优先使用设备端识别（可用时）", isOn: $offline)
                    Divider()
                    ChoiceRow(title: "录音待机", subtitle: "无语音输入后自动结束", options: ["10 秒", "15 秒", "30 秒", "不自动结束"], selection: $standby)
                    Divider()
                    ToggleRow(title: "显示语音图标", subtitle: "在键盘工具栏显示语音按钮", isOn: $showIcon)
                }
                .card(padding: 14)

                VStack(spacing: 0) {
                    NavigationLink(value: Route.voiceLanguage) {
                        SettingsRow(icon: "globe", title: "识别语言", value: language)
                    }
                    .buttonStyle(.plain)
                    Divider()
                    NavigationLink(value: Route.voicePunctuation) {
                        SettingsRow(icon: "textformat", title: "标点设置", value: punctuation ? "自动标点" : "关闭")
                    }
                    .buttonStyle(.plain)
                    Divider()
                    NavigationLink(value: Route.recorder) {
                        SettingsRow(icon: "waveform", title: "打开 AI 录音笔", subtitle: "使用同一套设备语音识别与后端总结")
                    }
                    .buttonStyle(.plain)
                }
                .card(padding: 14)

                VStack(alignment: .leading, spacing: 8) {
                    Text("当前权限")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    HStack {
                        StatusPill(text: micStatus, ok: micOK)
                        StatusPill(text: speechStatus, ok: speechOK)
                        Spacer()
                    }
                    SecondaryButton(title: "打开系统设置", symbol: "gear") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                .card()

                InfoBanner(text: "模拟器可能不提供可用的设备语音识别。此时页面会显示真实错误，不会伪造转写结果。键盘扩展需要“完全访问”才能使用麦克风。")
            }
        }
    }

    private var micOK: Bool {
        AVAudioSession.sharedInstance().recordPermission == .granted
    }

    private var micStatus: String {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted: return "麦克风已授权"
        case .denied: return "麦克风被拒绝"
        case .undetermined: return "麦克风未授权"
        @unknown default: return "麦克风未知"
        }
    }

    private var speechOK: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    private var speechStatus: String {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return "语音识别已授权"
        case .denied: return "语音识别被拒绝"
        case .restricted: return "语音识别受限"
        case .notDetermined: return "语音识别未授权"
        @unknown default: return "语音识别未知"
        }
    }
}

struct VoiceLanguageView: View {
    @AppStorage(SharedKeys.voiceLanguage, store: SharedStore.defaults) private var language = "普通话"
    @EnvironmentObject private var app: AppModel

    private let languages: [(String, String, String)] = [
        ("普通话", "zh-CN", "普通话（简体中文）"),
        ("粤语", "zh-HK", "粤语（香港）"),
        ("英语", "en-US", "English (US)"),
        ("日语", "ja-JP", "日本語"),
        ("韩语", "ko-KR", "한국어"),
        ("中英混合", "zh-CN", "中英混说（设备支持时）"),
    ]

    var body: some View {
        PageShell(title: "识别语言", subtitle: "选择语音转文字使用的设备识别语言") {
            VStack(spacing: 14) {
                VStack(spacing: 0) {
                    ForEach(languages, id: \.0) { item in
                        Button {
                            language = item.0
                            app.flash("识别语言已切换为\(item.0)")
                        } label: {
                            HStack(spacing: 12) {
                                SettingIcon(symbol: "globe", color: Theme.accentDark)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.2)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Theme.text)
                                    Text(item.1)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                                if language == item.0 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                            .padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)
                        if item.0 != languages.last?.0 { Divider().padding(.leading, 44) }
                    }
                }
                .card(padding: 14)
                InfoBanner(text: "识别语言由 SFSpeechRecognizer 提供。若设备未安装对应语言或模拟器不支持，录音页会显示“当前设备暂不可用”的真实错误。")
            }
        }
    }
}

struct VoicePunctuationView: View {
    @AppStorage(SharedKeys.voicePunctuation, store: SharedStore.defaults) private var punctuation = true
    @AppStorage(SharedKeys.voicePunctuationStyle, store: SharedStore.defaults) private var style = PunctuationStyle.chinese.rawValue
    @State private var trailingPeriod = true

    var body: some View {
        PageShell(title: "标点设置", subtitle: "语音转写后的标点处理") {
            VStack(spacing: 14) {
                VStack(spacing: 0) {
                    ToggleRow(title: "自动标点", subtitle: "根据停顿与语义补全标点", isOn: $punctuation)
                    Divider()
                    ChoiceRow(title: "标点风格", subtitle: "中文、英文或混合", options: PunctuationStyle.allCases.map(\.rawValue), selection: $style)
                    Divider()
                    ToggleRow(title: "句末自动句号", subtitle: "一段话结束时补上句号", isOn: $trailingPeriod)
                }
                .card(padding: 14)

                VStack(alignment: .leading, spacing: 8) {
                    Text("转换示例")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(example)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.text)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .card()

                InfoBanner(text: "设备语音识别通常已包含标点。这里的选择用于键语音上屏与录音会话的本地后处理，不改变原始识别文本。")
            }
        }
    }

    private var example: String {
        switch PunctuationStyle(rawValue: style) ?? .chinese {
        case .chinese: return "我们下午三点开会，记得带上方案。"
        case .english: return "Let's meet at 3 PM, remember to bring the proposal."
        case .mixed: return "我们 3 PM 开会, 记得带上 proposal。"
        }
    }
}

// MARK: - Plus

struct PlusSettingsView: View {
    @EnvironmentObject private var app: AppModel
    @AppStorage(SharedKeys.plusSmartSpelling, store: SharedStore.defaults) private var smartSpelling = true
    @AppStorage(SharedKeys.plusMiniProgram, store: SharedStore.defaults) private var miniProgram = true
    @AppStorage(SharedKeys.plusEmojiPack, store: SharedStore.defaults) private var emojiPack = true
    @AppStorage(SharedKeys.plusEmoji, store: SharedStore.defaults) private var emoji = true
    @AppStorage(SharedKeys.plusKaomoji, store: SharedStore.defaults) private var kaomoji = true
    @AppStorage(SharedKeys.plusSpellCheck, store: SharedStore.defaults) private var spellCheck = false
    @AppStorage(SharedKeys.plusDynamic, store: SharedStore.defaults) private var dynamic = true

    var body: some View {
        PageShell(title: "拼写 Plus", subtitle: "智能拼写与表达增强，所有开关本地生效") {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(Theme.mintGradient)
                        Image(systemName: "sparkles")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("拼写 Plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Text(app.plusEnabled ? "已开启" : "已关闭")
                            .font(.system(size: 11))
                            .foregroundStyle(app.plusEnabled ? Theme.accentDark : Theme.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(get: { app.plusEnabled }, set: { app.setPlus($0) }))
                        .labelsHidden()
                        .tint(Theme.accent)
                }
                .card()

                VStack(spacing: 0) {
                    ToggleRow(title: "智能拼写", subtitle: "根据上下文调整候选顺序", isOn: $smartSpelling)
                    Divider()
                    ToggleRow(title: "小程序", subtitle: "在键盘工具栏显示小程序入口", isOn: $miniProgram)
                    Divider()
                    ToggleRow(title: "表情包", subtitle: "推荐常用表情包", isOn: $emojiPack)
                    Divider()
                    ToggleRow(title: "Emoji", subtitle: "在候选栏推荐 Emoji", isOn: $emoji)
                    Divider()
                    ToggleRow(title: "颜文字", subtitle: "提供趣味颜文字候选", isOn: $kaomoji)
                    Divider()
                    ToggleRow(title: "拼写检查", subtitle: "英文输入时提示拼写问题", isOn: $spellCheck)
                    Divider()
                    ToggleRow(title: "灵动表达", subtitle: "根据场景提供表达建议", isOn: $dynamic)
                }
                .card(padding: 14)
                .disabled(!app.plusEnabled)
                .opacity(app.plusEnabled ? 1 : 0.55)

                VStack(spacing: 0) {
                    NavigationLink(value: Route.aiChat) {
                        SettingsRow(icon: "bubble.left.and.bubble.right", title: "问 AI", subtitle: "多轮对话、流式响应、复制与重试")
                    }
                    .buttonStyle(.plain)
                    Divider()
                    NavigationLink(value: Route.textTools) {
                        SettingsRow(icon: "wand.and.stars", title: "文字工具", subtitle: "润色、改写、翻译、摘要")
                    }
                    .buttonStyle(.plain)
                    Divider()
                    NavigationLink(value: Route.emoji) {
                        SettingsRow(icon: "face.smiling", title: "表情与颜文字", subtitle: "表情分类、最近使用")
                    }
                    .buttonStyle(.plain)
                    Divider()
                    NavigationLink(value: Route.phrases) {
                        SettingsRow(icon: "text.bubble", title: "常用语", subtitle: "自定义短语与键盘上屏")
                    }
                    .buttonStyle(.plain)
                    Divider()
                    NavigationLink(value: Route.translate) {
                        SettingsRow(icon: "character.book.closed", title: "边写边译", subtitle: "输入停顿后自动翻译")
                    }
                    .buttonStyle(.plain)
                    Divider()
                    NavigationLink(value: Route.poster) {
                        SettingsRow(icon: "photo.on.rectangle", title: "排版成图", subtitle: "把文字排成可分享海报")
                    }
                    .buttonStyle(.plain)
                    Divider()
                    NavigationLink(value: Route.toolbar) {
                        SettingsRow(icon: "wrench.and.screwdriver", title: "灵动表达工具栏", subtitle: "调整键盘上方的工具顺序")
                    }
                    .buttonStyle(.plain)
                }
                .card(padding: 14)

                HStack(spacing: 8) {
                    StatusPill(text: "本地词库 \(Lexicon.shared.phraseCount) 条", ok: true)
                    StatusPill(text: "五笔 \(Lexicon.shared.wubiCount) 条", ok: true)
                    Spacer()
                }
                Button {
                    let chars = Lexicon.shared.charCount
                    let phrases = Lexicon.shared.phraseCount
                    app.flash("词库自检完成：\(chars) 字 / \(phrases) 词")
                } label: {
                    Label("检查本地词库", systemImage: "checkmark.seal")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accentDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Standalone

struct StandaloneView: View {
    @EnvironmentObject private var app: AppModel
    @State private var offlineMode = SharedStore.bool(SharedKeys.standalone)
    @State private var checkResult: String?

    var body: some View {
        PageShell(title: "单机模式", subtitle: "无需联网，使用内置词库与本地输入") {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        SettingIcon(symbol: "externaldrive.fill", color: Theme.accentDark)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("单机模式")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            Text("关闭 AI、同步与传送的网络请求")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: $offlineMode)
                            .labelsHidden()
                            .tint(Theme.accent)
                            .onChange(of: offlineMode) { _, value in
                                app.setStandalone(value)
                            }
                    }
                    Text("开启后：拼音、五笔、笔画、双拼、手写模板、英文、数字、符号、Emoji、常用语与剪贴板历史仍可用。AI 页面会明确提示离线，并提供关闭单机模式的按钮。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                }
                .card()

                VStack(spacing: 0) {
                    LocalStatRow(title: "拼音字库", value: "\(Lexicon.shared.charCount) 字")
                    Divider()
                    LocalStatRow(title: "词组与短语", value: "\(Lexicon.shared.phraseCount) 条")
                    Divider()
                    LocalStatRow(title: "五笔编码", value: "\(Lexicon.shared.wubiCount) 条")
                    Divider()
                    LocalStatRow(title: "笔画编码", value: "\(Lexicon.shared.strokeCount) 条")
                    Divider()
                    LocalStatRow(title: "App Group", value: SharedStore.appGroupAvailable ? "可用" : "受限")
                }
                .card(padding: 14)

                HStack {
                    SecondaryButton(title: "检查词库", symbol: "checkmark.seal") {
                        checkResult = "内置词库可读：\(Lexicon.shared.phraseCount) 条词组，\(Lexicon.shared.charCount) 个单字。"
                    }
                    SecondaryButton(title: "测试后端", symbol: "network") {
                        Task {
                            do {
                                let health = try await APIClient.shared.health()
                                checkResult = "后端在线：\(health.model)，语音提供方 \(health.asr ?? "device")。"
                            } catch {
                                checkResult = "后端不可用：\(error.localizedDescription)"
                            }
                        }
                    }
                }

                if let checkResult {
                    InfoBanner(text: checkResult, symbol: "checkmark.circle", tint: Theme.accentDark)
                }

                InfoBanner(text: "iOS 键盘扩展本身不能下载模型文件；这里的“离线”指使用随包词库并停止网络请求。设备语音识别是否离线取决于系统识别的本地可用性。",
                           symbol: "info.circle", tint: Theme.warning)
            }
        }
    }
}

private struct LocalStatRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Theme.text)
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 9)
    }
}

// MARK: - Privacy

struct PrivacyView: View {
    @EnvironmentObject private var app: AppModel
    @State private var showClearLearning = false
    @State private var showClearClipboard = false
    @State private var showClearChat = false
    @State private var showClearRecorder = false

    var body: some View {
        PageShell(title: "隐私与权限", subtitle: "看清每一项权限和本地数据") {
            VStack(spacing: 14) {
                VStack(spacing: 0) {
                    PermissionRow(title: "麦克风", status: micStatus, ok: micOK,
                                  detail: "录音笔与语音输入")
                    Divider()
                    PermissionRow(title: "语音识别", status: speechStatus, ok: speechOK,
                                  detail: "设备端 Speech 框架")
                    Divider()
                    PermissionRow(title: "键盘完全访问", status: SharedStore.bool(SharedKeys.keyboardFullAccess) ? "已开启" : "未开启",
                                  ok: SharedStore.bool(SharedKeys.keyboardFullAccess),
                                  detail: "网络、麦克风与共享容器")
                    Divider()
                    PermissionRow(title: "键盘运行检测", status: SharedStore.bool(SharedKeys.keyboardSeen) ? "检测到" : "未检测到",
                                  ok: SharedStore.bool(SharedKeys.keyboardSeen),
                                  detail: "由键盘首次显示时写入")
                }
                .card(padding: 14)

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("打开系统设置", systemImage: "gear")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accentDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 9) {
                    Text("我们如何处理数据")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    privacyBullet("词库、模糊拼音、学习记录、剪贴板、常用语与录音会话默认保存在设备本地；App 与键盘通过 App Group 共享。")
                    privacyBullet("AI 聊天、文字工具、边写边译、录音总结、同步与传送只在你主动触发时发送到设置中配置的后端地址。")
                    privacyBullet("后端持有模型密钥；客户端源码与 Info.plist 中没有 API Key。")
                    privacyBullet("删除候选会降低本地排序；清理学习记录会移除所有学习权重。")
                    privacyBullet("这是独立研究复刻项目，不上传遥测，不接入腾讯服务。")
                }
                .card()

                VStack(spacing: 0) {
                    dataAction("清除输入学习", "删除学习权重与候选黑名单", "trash", .red) { showClearLearning = true }
                    Divider()
                    dataAction("清除剪贴板历史", "仅删除本地历史，不影响系统剪贴板", "doc.on.clipboard", .red) { showClearClipboard = true }
                    Divider()
                    dataAction("清除 AI 对话历史", "删除本机保存的多轮对话", "bubble.left.and.bubble.right", .red) { showClearChat = true }
                    Divider()
                    dataAction("清除录音会话", "删除本机录音会话与摘要", "waveform", .red) { showClearRecorder = true }
                }
                .card(padding: 14)

                Text("隐私政策版本 1.0 · 2026-10-20\n本说明适用于微输入法研究复刻项目的 iOS App 与键盘扩展。")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .alert("清除输入学习？", isPresented: $showClearLearning) {
            Button("清除", role: .destructive) {
                SharedStore.clearLearning()
                app.flash("已清除输入学习")
            }
            Button("取消", role: .cancel) {}
        }
        .alert("清除剪贴板历史？", isPresented: $showClearClipboard) {
            Button("清除", role: .destructive) {
                SharedStore.clipboard = []
                app.flash("已清除剪贴板历史")
            }
            Button("取消", role: .cancel) {}
        }
        .alert("清除 AI 对话？", isPresented: $showClearChat) {
            Button("清除", role: .destructive) {
                SharedStore.chatHistory = []
                app.flash("已清除 AI 对话历史")
            }
            Button("取消", role: .cancel) {}
        }
        .alert("清除录音会话？", isPresented: $showClearRecorder) {
            Button("清除", role: .destructive) {
                SharedStore.recorderSessions = []
                app.flash("已清除录音会话")
            }
            Button("取消", role: .cancel) {}
        }
    }

    private func privacyBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Circle().fill(Theme.accent).frame(width: 5, height: 5).padding(.top, 5)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func dataAction(_ title: String, _ subtitle: String, _ symbol: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SettingIcon(symbol: symbol, color: color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(color)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }

    private var micOK: Bool { AVAudioSession.sharedInstance().recordPermission == .granted }
    private var micStatus: String {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted: return "已授权"
        case .denied: return "已拒绝"
        case .undetermined: return "未授权"
        @unknown default: return "未知"
        }
    }
    private var speechOK: Bool { SFSpeechRecognizer.authorizationStatus() == .authorized }
    private var speechStatus: String {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return "已授权"
        case .denied: return "已拒绝"
        case .restricted: return "受限"
        case .notDetermined: return "未授权"
        @unknown default: return "未知"
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let status: String
    let ok: Bool
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.text)
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            StatusPill(text: status, ok: ok)
        }
        .padding(.vertical, 9)
    }
}

// MARK: - Desktop

struct DesktopView: View {
    @EnvironmentObject private var app: AppModel
    @State private var code = SharedStore.string(SharedKeys.syncCode)
    @State private var qrImage: UIImage?

    var body: some View {
        PageShell(title: "电脑版", subtitle: "桌面端在本复刻项目中没有独立安装包") {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 10) {
                        Image(systemName: "desktopcomputer")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(Theme.accentDark)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("电脑版说明")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            Text("不提供虚构下载按钮")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Text("本项目的交付范围是 iOS App 与键盘扩展。电脑端不附带安装包，也不声称存在官方桌面客户端。你可以用下面的本地配对码与二维码把手机上的文字和文件接力到同一后端的其他设备。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .card()

                VStack(spacing: 12) {
                    Text("本地接力码")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Text(code.isEmpty ? "------" : code)
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.text)
                        .tracking(6)
                    if let qrImage {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 168, height: 168)
                            .padding(10)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    HStack(spacing: 10) {
                        SecondaryButton(title: "生成新接力码", symbol: "arrow.triangle.2.circlepath") {
                            generate()
                        }
                        SecondaryButton(title: "复制接力码", symbol: "doc.on.doc") {
                            UIPasteboard.general.string = code
                            app.flash("接力码已复制")
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .card()

                NavigationLink(value: Route.transfer) {
                    SettingsRow(icon: "paperplane", title: "打开隔空传送", subtitle: "上传文件到后端并下载")
                }
                .buttonStyle(.plain)
                .card(padding: 14)

                NavigationLink(value: Route.sync) {
                    SettingsRow(icon: "arrow.triangle.2.circlepath", title: "跨设备粘贴同步", subtitle: "六位配对码与剪贴板同步")
                }
                .buttonStyle(.plain)
                .card(padding: 14)

                InfoBanner(text: "二维码内容为 wetype://pair?code=…，由本机 Core Image 生成，不依赖外部服务。")
            }
        }
        .onAppear {
            if code.count != 6 { generate() } else { renderQR() }
        }
    }

    private func generate() {
        code = String(format: "%06d", Int.random(in: 0...999999))
        SharedStore.set(SharedKeys.syncCode, code)
        renderQR()
    }

    private func renderQR() {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return }
        filter.setValue(Data("wetype://pair?code=\(code)".utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let context = CIContext()
        if let cg = context.createCGImage(scaled, from: scaled.extent) {
            qrImage = UIImage(cgImage: cg)
        }
    }
}

// MARK: - About

struct AboutView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    var body: some View {
        PageShell(title: "关于", subtitle: "版本、词库与许可") {
            VStack(spacing: 14) {
                VStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Theme.mintGradient)
                        Text("微")
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 86, height: 86)
                    .shadow(color: Theme.accent.opacity(0.25), radius: 12, y: 5)
                    Text("微输入法")
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("WeType-inspired Keyboard · 独立研究复刻")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                    Text("版本 \(version) (\(build))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity)
                .card()

                VStack(spacing: 0) {
                    LocalStatRow(title: "单字词库", value: "\(Lexicon.shared.charCount)")
                    Divider()
                    LocalStatRow(title: "词组词库", value: "\(Lexicon.shared.phraseCount)")
                    Divider()
                    LocalStatRow(title: "五笔编码", value: "\(Lexicon.shared.wubiCount)")
                    Divider()
                    LocalStatRow(title: "笔画编码", value: "\(Lexicon.shared.strokeCount)")
                    Divider()
                    LocalStatRow(title: "Emoji 分类", value: "\(Lexicon.shared.emojiCategories.count)")
                    Divider()
                    LocalStatRow(title: "App Group", value: SharedStore.appGroupAvailable ? "可用" : "受限")
                    Divider()
                    LocalStatRow(title: "后端", value: app.backendStatus.label)
                }
                .card(padding: 14)

                VStack(alignment: .leading, spacing: 9) {
                    Text("能力边界")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("手写识别为 20 个简单汉字的方向模板匹配，不是完整的 CJK 手写模型。语音识别使用系统 SFSpeechRecognizer，模拟器可能不可用。AI、翻译、摘要与同步依赖可配置的后端；后端不可用时显示真实错误与重试。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("本项目与腾讯及微信输入法无关联，未使用原版 APK/IPA、Hermes bundle、字体或图片。键盘布局与视觉根据公开界面事实重新实现。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .card()

                VStack(spacing: 0) {
                    NavigationLink(value: Route.privacy) {
                        SettingsRow(icon: "lock.shield", title: "隐私政策")
                    }
                    .buttonStyle(.plain)
                    Divider()
                    NavigationLink(value: Route.help) {
                        SettingsRow(icon: "questionmark.bubble", title: "帮助与反馈")
                    }
                    .buttonStyle(.plain)
                    Divider()
                    SettingsRow(icon: "text.book.closed", title: "词库来源", subtitle: "shared/data 事实数据，随包分发", showsChevron: false)
                    Divider()
                    SettingsRow(icon: "shippingbox", title: "第三方 SDK", subtitle: "无；仅使用 Apple 系统框架", showsChevron: false)
                }
                .card(padding: 14)

                HStack(spacing: 10) {
                    SecondaryButton(title: "复制版本信息", symbol: "doc.on.doc") {
                        UIPasteboard.general.string = """
                        微输入法 \(version) (\(build))
                        iPhone/iPad · iOS \(UIDevice.current.systemVersion)
                        词库 \(Lexicon.shared.charCount) 字 / \(Lexicon.shared.phraseCount) 词
                        后端 \(SharedStore.apiBaseURL)
                        """
                        app.flash("版本信息已复制")
                    }
                    ShareLink(item: "微输入法 \(version) — 独立研究复刻的 iOS 输入法与键盘扩展") {
                        Label("分享", systemImage: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.accentDark)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Theme.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }
}
