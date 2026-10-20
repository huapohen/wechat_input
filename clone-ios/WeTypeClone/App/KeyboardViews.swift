import SwiftUI
import UIKit

// MARK: - Text host for the in-app keyboard

final class TextInsertionHub: ObservableObject {
    weak var textView: UITextView?

    func insert(_ text: String) {
        textView?.insertText(text)
    }

    func deleteBackward() {
        textView?.deleteBackward()
    }

    func focus() {
        textView?.becomeFirstResponder()
    }

    var context: String {
        textView?.text ?? ""
    }
}

struct TextHost: UIViewRepresentable {
    @Binding var text: String
    let hub: TextInsertionHub

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.font = UIFont.systemFont(ofSize: 16)
        view.textColor = UIColor(Theme.text)
        view.backgroundColor = UIColor(Theme.surface)
        view.layer.cornerRadius = 12
        view.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        view.delegate = context.coordinator
        view.text = text
        // Suppress the system keyboard: this page demonstrates the replacement panel.
        view.inputView = UIView(frame: .zero)
        hub.textView = view
        DispatchQueue.main.async {
            view.becomeFirstResponder()
        }
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private let parent: TextHost
        init(_ parent: TextHost) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}

// MARK: - Keyboard experience

struct KeyboardExperienceView: View {
    @EnvironmentObject private var app: AppModel
    @StateObject private var hub = TextInsertionHub()
    @State private var text = "点这里，然后用下方键盘输入。\n长按空格可以体验语音。"
    @State private var panelMode: KeyboardMode = SharedStore.defaultMode
    @State private var showSelfTest = false
    @AppStorage(SharedKeys.height, store: SharedStore.defaults) private var keyboardHeight = 320.0

    private let chineseModes: [KeyboardMode] = [.t9, .qwerty, .handwrite, .stroke, .wubi, .doublepin]

    var body: some View {
        PageShell(title: "键盘体验", subtitle: "在 App 内验证候选、模式、工具栏与上屏") {
            VStack(spacing: 14) {
                InfoBanner(text: "这是 App 内的键盘渲染。系统级键盘扩展需要在“设置 → 通用 → 键盘”中启用；启用后可在 Safari、备忘录等宿主中输入。",
                           symbol: "keyboard", tint: Theme.accentDark)

                HStack(spacing: 6) {
                    ForEach(chineseModes) { mode in
                        Button {
                            switchPanel(to: mode)
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: mode.symbol)
                                    .font(.system(size: 12, weight: .medium))
                                Text(mode.shortTitle)
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundStyle(panelMode == mode ? .white : Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(panelMode == mode ? AnyShapeStyle(Theme.mintGradient) : AnyShapeStyle(Theme.surface))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("宿主输入框")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Button("清空") { text = ""; hub.textView?.text = "" }
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.accentDark)
                        Button("复制") {
                            UIPasteboard.general.string = text
                            app.flash("已复制输入内容")
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.accentDark)
                    }
                    TextHost(text: $text, hub: hub)
                        .frame(height: 150)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 0.8))
                }
                .card(padding: 12)

                KeyboardPanel(
                    isExtension: false,
                    hasFullAccess: true,
                    onInsert: { hub.insert($0) },
                    onDelete: { hub.deleteBackward() },
                    onSpace: { hub.insert(" ") },
                    onReturn: { hub.insert("\n") },
                    onOpenApp: { app.flash("已在主 App 中") },
                    contextProvider: { hub.context }
                )
                .id(panelMode)
                .frame(height: keyboardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 0.8))

                VStack(alignment: .leading, spacing: 7) {
                    Text("可验证的能力")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("九宫格 / 全键盘拼音 / 手写模板 / 笔画 / 五笔 / 双拼 / 英文 / 数字 / 符号 / Emoji；候选栏、工具栏剪贴板与常用语、长按空格语音、完整访问权限下的 AI/翻译/整理。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .card()

                Button {
                    showSelfTest = true
                } label: {
                    Label("运行候选引擎自检", systemImage: "checkmark.seal")
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
        .sheet(isPresented: $showSelfTest) {
            CandidateSelfTestView()
                .presentationDetents([.medium, .large])
        }
        .onChange(of: panelMode) { _, mode in
            SharedStore.set(SharedKeys.defaultMode, mode.rawValue)
        }
    }

    private func switchPanel(to mode: KeyboardMode) {
        panelMode = mode
        SharedStore.set(SharedKeys.defaultMode, mode.rawValue)
        app.flash("已切换到 \(mode.title)")
    }
}

// MARK: - Keyboard management

struct KeyboardManageView: View {
    @EnvironmentObject private var app: AppModel
    @State private var enabled: Set<KeyboardMode> = Set(SharedStore.enabledModes)
    @AppStorage(SharedKeys.defaultMode, store: SharedStore.defaults) private var defaultMode = KeyboardMode.t9.rawValue
    @State private var previewMode: KeyboardMode?

    private let chineseModes: [KeyboardMode] = [.t9, .qwerty, .handwrite, .stroke, .wubi, .doublepin]
    private let otherModes: [KeyboardMode] = [.english, .number, .symbols, .emoji]

    var body: some View {
        PageShell(title: "键盘管理", subtitle: "启用键盘、设为默认并查看布局说明") {
            VStack(spacing: 14) {
                HStack {
                    StatusPill(text: "已启用 \(enabled.count) / \(KeyboardMode.allCases.count)", ok: true)
                    Spacer()
                    SecondaryButton(title: "全部启用", symbol: "checkmark.circle") {
                        enabled = Set(KeyboardMode.allCases)
                        persist()
                    }
                }

                modeSection(title: "六种中文键盘", modes: chineseModes)
                modeSection(title: "英文与符号", modes: otherModes)

                VStack(alignment: .leading, spacing: 8) {
                    Text("键盘切换键")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("键盘工具栏最左侧是切换键，可打开全部已启用键盘。长按地球键也可在系统键盘之间切换。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                    NavigationLink(value: Route.toolbar) {
                        SettingsRow(icon: "wrench.and.screwdriver", title: "定制工具栏工具顺序")
                    }
                    .buttonStyle(.plain)
                }
                .card()

                InfoBanner(text: "启用状态与默认键盘写入 App Group，扩展的“选择键盘”面板会读取同一份列表。至少保留一种键盘。")
            }
        }
        .sheet(item: $previewMode) { mode in
            NavigationStack {
                KeyboardPreviewPage(mode: mode)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { previewMode = nil }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func modeSection(title: String, modes: [KeyboardMode]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 6)
            ForEach(modes) { mode in
                HStack(spacing: 11) {
                    SettingIcon(symbol: mode.symbol)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(mode.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.text)
                            if defaultMode == mode.rawValue {
                                Text("默认")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Theme.accentDark)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Theme.accentSoft)
                                    .clipShape(Capsule())
                            }
                        }
                        Text(modeDetail(mode))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        previewMode = mode
                    } label: {
                        Image(systemName: "eye")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.accentDark)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    Button {
                        if defaultMode != mode.rawValue {
                            defaultMode = mode.rawValue
                            app.flash("默认键盘已设为 \(mode.title)")
                        }
                    } label: {
                        Image(systemName: defaultMode == mode.rawValue ? "star.fill" : "star")
                            .font(.system(size: 12))
                            .foregroundStyle(defaultMode == mode.rawValue ? Theme.accent : Theme.muted)
                            .frame(width: 26, height: 28)
                    }
                    .buttonStyle(.plain)
                    Toggle("", isOn: Binding(
                        get: { enabled.contains(mode) },
                        set: { value in
                            if value {
                                enabled.insert(mode)
                            } else if enabled.count > 1 {
                                enabled.remove(mode)
                                if defaultMode == mode.rawValue, let first = enabled.first {
                                    defaultMode = first.rawValue
                                }
                            }
                            persist()
                        }
                    ))
                    .labelsHidden()
                    .tint(Theme.accent)
                }
                .padding(.vertical, 8)
                if mode != modes.last { Divider().padding(.leading, 43) }
            }
        }
        .card(padding: 14)
    }

    private func modeDetail(_ mode: KeyboardMode) -> String {
        switch mode {
        case .t9: return "2–9 数字映射 · 九键候选"
        case .qwerty: return "26 键全拼 · 词组候选"
        case .handwrite: return "20 字方向模板 · 演示级"
        case .stroke: return "一丨丿丶折 · 6,245 编码"
        case .wubi: return "五笔 86 · 32,125 编码"
        case .doublepin: return "小鹤双拼 · 零声母兼容"
        case .english: return "QWERTY · 前缀候选"
        case .number: return "数字与小数点"
        case .symbols: return "两页中文/英文符号"
        case .emoji: return "7 列表情与最近使用"
        }
    }

    private func persist() {
        let list = KeyboardMode.allCases.filter { enabled.contains($0) }
        SharedStore.setStringArray(SharedKeys.enabledModes, list.map(\.rawValue))
        if !enabled.contains(KeyboardMode(rawValue: defaultMode) ?? .t9), let first = list.first {
            defaultMode = first.rawValue
        }
        app.flash("键盘启用状态已保存")
    }
}

struct KeyboardPreviewPage: View {
    let mode: KeyboardMode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    SettingIcon(symbol: mode.symbol)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Text(description)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .card()

                LayoutPreview(mode: mode)

                InfoBanner(text: "预览使用重建的布局事实与共享词库，不是原版截图。实际键盘会按键盘高度与宽度自适应。")
            }
            .padding(16)
            .maxContent()
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var description: String {
        switch mode {
        case .t9: return "九宫格拼音：数字 2–9 映射 abc–wxyz，候选来自本地词库。"
        case .qwerty: return "全键盘拼音：输入完整拼音或词组前缀，支持模糊拼音。"
        case .handwrite: return "手写：画板 + 20 个简单汉字的方向模板匹配。"
        case .stroke: return "笔画：横竖撇点折输入，最多五位编码。"
        case .wubi: return "五笔 86：字母编码前缀查询。"
        case .doublepin: return "双拼：小鹤方案，两键一字。"
        case .english: return "英文：QWERTY 前缀候选与首字母大写。"
        case .number: return "数字：0–9、小数点与删除。"
        case .symbols: return "符号：两页标点与符号。"
        case .emoji: return "表情：分类、最近使用与上屏。"
        }
    }
}

struct LayoutPreview: View {
    let mode: KeyboardMode

    var body: some View {
        VStack(spacing: 6) {
            if mode == .t9 {
                ForEach([["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["符号", "0", "删除"]], id: \.self) { row in
                    HStack(spacing: 5) {
                        ForEach(row, id: \.self) { key in
                            previewKey(key)
                        }
                    }
                }
            } else if mode == .qwerty || mode == .wubi || mode == .doublepin || mode == .english {
                ForEach(["qwertyuiop", "asdfghjkl", "zxcvbnm"], id: \.self) { row in
                    HStack(spacing: 5) {
                        ForEach(Array(row).map(String.init), id: \.self) { key in
                            previewKey(key.uppercased())
                        }
                    }
                }
                HStack(spacing: 5) {
                    previewKey("123")
                    previewKey("空格")
                    previewKey("换行")
                }
            } else if mode == .stroke {
                HStack(spacing: 5) {
                    ForEach(["一", "丨", "丿", "丶", "折"], id: \.self) { previewKey($0) }
                }
                HStack(spacing: 5) {
                    previewKey("清空")
                    previewKey("空格")
                    previewKey("删除")
                }
            } else if mode == .handwrite {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.surface)
                    .frame(height: 160)
                    .overlay(
                        VStack(spacing: 4) {
                            Image(systemName: "scribble")
                                .font(.system(size: 30, weight: .light))
                                .foregroundStyle(Theme.muted)
                            Text("手写画板 · 模板识别")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    )
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                HStack(spacing: 5) {
                    previewKey("一")
                    previewKey("二")
                    previewKey("十")
                    previewKey("人")
                }
            } else if mode == .number {
                ForEach([["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], [".", "0", "删除"]], id: \.self) { row in
                    HStack(spacing: 5) {
                        ForEach(row, id: \.self) { previewKey($0) }
                    }
                }
            } else if mode == .symbols {
                ForEach([["，", "。", "？", "！", "：", "；"], ["（", "）", "【", "】", "《", "》"], ["…", "—", "·", "￥", "%", "#"]], id: \.self) { row in
                    HStack(spacing: 5) {
                        ForEach(row, id: \.self) { previewKey($0) }
                    }
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(Array(["😀", "😄", "😂", "🥰", "😎", "😭", "🤔", "👍", "🙏", "🎉", "❤️", "🔥", "✨", "😴"].enumerated()), id: \.offset) { _, emoji in
                        Text(emoji)
                            .font(.system(size: 24))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(10)
        .background(Theme.keyboardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func previewKey(_ label: String) -> some View {
        Text(label)
            .font(.system(size: label.count > 1 ? 10 : 17, weight: .medium))
            .foregroundStyle(Theme.keyText)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(label == "删除" || label == "换行" || label == "空格" || label == "清空" ? Theme.keySpecial : Theme.key)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}


struct CandidateSelfTestView: View {
    @Environment(\.dismiss) private var dismiss

    private var checks: [(String, String, [String])] {
        [
            ("全键盘拼音", "nihao", Array(Lexicon.shared.candidates(for: .qwerty, input: "nihao").prefix(5))),
            ("九宫格拼音", "64", Array(Lexicon.shared.candidates(for: .t9, input: "64").prefix(5))),
            ("五笔 86", "r", Array(Lexicon.shared.candidates(for: .wubi, input: "r").prefix(5))),
            ("笔画", "hsh", Array(Lexicon.shared.candidates(for: .stroke, input: "hsh").prefix(5))),
            ("双拼（小鹤）", "nihc", Array(Lexicon.shared.candidates(for: .doublepin, input: "nihc").prefix(5))),
            ("英文", "hel", Array(Lexicon.shared.candidates(for: .english, input: "hel").prefix(5))),
            ("Emoji（笑脸）", "笑脸", Array(Lexicon.shared.emoji(matching: "笑脸").prefix(6))),
            ("手写模板", "20 字", HandwritingRecognizer.supportedCharacters),
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                Section("本地词库候选（实时查询）") {
                    ForEach(Array(checks.enumerated()), id: \.offset) { _, check in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(check.0)
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text("输入 \(check.1)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Text(check.2.isEmpty ? "无候选" : check.2.joined(separator: "  "))
                                .font(.system(size: 16))
                                .foregroundStyle(check.2.isEmpty ? Theme.warning : Theme.text)
                        }
                        .padding(.vertical, 3)
                    }
                }
                Section("说明") {
                    Text("查询直接走随包 SQLite 词库与模糊拼音设置；手写为 20 字方向模板。结果为空时会明确显示“无候选”。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .navigationTitle("候选引擎自检")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
