import SwiftUI
import UIKit
import AudioToolbox

struct KeyboardPanel: View {
    var isExtension: Bool = false
    var hasFullAccess: Bool = true
    var onInsert: (String) -> Void = { _ in }
    var onDelete: () -> Void = {}
    var onSpace: () -> Void = {}
    var onReturn: () -> Void = {}
    var onOpenApp: () -> Void = {}
    var contextProvider: () -> String = { "" }

    @State private var mode: KeyboardMode
    @State private var buffer = ""
    @State private var candidates: [String] = []
    @State private var shift = false
    @State private var symbolPage = 0
    @State private var activeTool: ToolAction?
    @State private var showVoice = false
    @State private var inlineNote: String?
    @State private var strokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []
    @State private var handwriteGuesses: [HandwritingRecognizer.Guess] = []
    @State private var emojiQuery = ""
    @State private var emojiCategory = "最近"
    @State private var spaceHeld = false

    @StateObject private var speech = SpeechCapture()

    @AppStorage(SharedKeys.sound, store: SharedStore.defaults) private var soundOn = true
    @AppStorage(SharedKeys.haptic, store: SharedStore.defaults) private var hapticRaw = HapticStrength.medium.rawValue
    @AppStorage(SharedKeys.candidateSize, store: SharedStore.defaults) private var candidateSize = 18.0
    @AppStorage(SharedKeys.numberRow, store: SharedStore.defaults) private var numberRow = false
    @AppStorage(SharedKeys.slideInput, store: SharedStore.defaults) private var slideInput = true
    @AppStorage(SharedKeys.voiceRelease, store: SharedStore.defaults) private var voiceRelease = VoiceReleaseAction.insert.rawValue
    @AppStorage(SharedKeys.voiceLanguage, store: SharedStore.defaults) private var voiceLanguage = "普通话"

    init(isExtension: Bool = false,
         hasFullAccess: Bool = true,
         onInsert: @escaping (String) -> Void = { _ in },
         onDelete: @escaping () -> Void = {},
         onSpace: @escaping () -> Void = {},
         onReturn: @escaping () -> Void = {},
         onOpenApp: @escaping () -> Void = {},
         contextProvider: @escaping () -> String = { "" }) {
        self.isExtension = isExtension
        self.hasFullAccess = hasFullAccess
        self.onInsert = onInsert
        self.onDelete = onDelete
        self.onSpace = onSpace
        self.onReturn = onReturn
        self.onOpenApp = onOpenApp
        self.contextProvider = contextProvider
        let enabled = SharedStore.enabledModes
        var preferred = SharedStore.defaultMode
        if let override = UserDefaults.standard.string(forKey: "uitest.keyboardMode"),
           let parsed = KeyboardMode(rawValue: override) {
            preferred = parsed
        }
        _mode = State(initialValue: enabled.contains(preferred) ? preferred : (enabled.first ?? .qwerty))
        let prefill = UserDefaults.standard.string(forKey: "uitest.keyboardInput") ?? ""
        _buffer = State(initialValue: prefill)
    }

    var body: some View {
        VStack(spacing: 5) {
            toolbar
            keyboardArea
        }
        .padding(.horizontal, 7)
        .padding(.top, 5)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.keyboardBackground)
        .frame(maxWidth: Theme.keyboardMaxWidth)
        .overlay(alignment: .top) {
            if let inlineNote {
                Text(inlineNote)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Theme.text.opacity(0.9))
                    .clipShape(Capsule())
                    .padding(.top, 6)
                    .onAppear {
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            await MainActor.run { withAnimation { self.inlineNote = nil } }
                        }
                    }
            }
        }
        .onAppear {
            if isExtension {
                SharedStore.set(SharedKeys.keyboardSeen, true)
                SharedStore.set(SharedKeys.keyboardFullAccess, hasFullAccess)
            }
            refreshCandidates()
        }
        .onChange(of: buffer) { _, _ in refreshCandidates() }
        .onChange(of: mode) { _, _ in
            buffer = ""
            candidates = []
            handwriteGuesses = []
            strokes = []
            shift = false
            symbolPage = 0
            refreshCandidates()
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 3) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(SharedStore.toolbarActions) { tool in
                        Button {
                            tapFeedback()
                            handleTool(tool)
                        } label: {
                            VStack(spacing: 1) {
                                Image(systemName: tool.symbol)
                                    .font(.system(size: 14, weight: .medium))
                                Text(tool.title)
                                    .font(.system(size: 8))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(activeTool == tool ? Theme.accentDark : Theme.textSecondary)
                            .frame(width: 46, height: 31)
                            .background(activeTool == tool ? Theme.accentSoft : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("tool.\(tool.rawValue)")
                    }
                }
            }
            Button {
                tapFeedback()
                activeTool = nil
                showVoice = false
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accentDark)
                    .frame(width: 36, height: 31)
                    .background(Theme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(height: 33)
    }

    private func handleTool(_ tool: ToolAction) {
        switch tool {
        case .mode:
            activeTool = .mode
        case .voice:
            beginVoice()
        case .emoji:
            setMode(.emoji)
        case .handwrite:
            setMode(.handwrite)
        case .clipboard, .phrases, .ai, .translate, .polish, .settings:
            activeTool = tool
        }
    }

    private func setMode(_ newMode: KeyboardMode) {
        activeTool = nil
        showVoice = false
        mode = newMode
        buffer = ""
        candidates = []
        SharedStore.set(SharedKeys.defaultMode, newMode.rawValue)
    }

    // MARK: - Keyboard area

    @ViewBuilder
    private var keyboardArea: some View {
        if showVoice {
            VoicePanel(speech: speech,
                       isExtension: isExtension,
                       hasFullAccess: hasFullAccess,
                       onInsert: onInsert,
                       onClose: { showVoice = false })
        } else if let tool = activeTool {
            toolPanel(tool)
        } else {
            VStack(spacing: 5) {
                if showsCandidateBar {
                    candidateBar
                }
                modeSurface
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var showsCandidateBar: Bool {
        switch mode {
        case .t9, .qwerty, .wubi, .doublepin, .english, .stroke, .handwrite: return true
        default: return false
        }
    }

    // MARK: - Candidate bar

    private var candidateBar: some View {
        HStack(spacing: 6) {
            if mode == .handwrite {
                Text(handwriteGuesses.isEmpty ? "手写" : "候选")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accentDark)
                    .padding(.horizontal, 8)
            } else {
                HStack(spacing: 3) {
                    Text(displayBuffer.isEmpty ? mode.shortTitle : displayBuffer)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    if !buffer.isEmpty {
                        Button {
                            buffer = ""
                            candidates = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.muted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 7)
                .frame(minWidth: 34, maxWidth: 92, alignment: .leading)
            }

            Divider().frame(height: 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    let items = mode == .handwrite ? handwriteGuesses.map(\.character) : candidates
                    if items.isEmpty {
                        Text(emptyCandidateHint)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 8)
                    } else {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            Button {
                                tapFeedback()
                                commitCandidate(item, index: index)
                            } label: {
                                Text(item)
                                    .font(.system(size: candidateSize, weight: index == 0 ? .semibold : .regular))
                                    .foregroundStyle(index == 0 ? Theme.accentDark : Theme.text)
                                    .padding(.horizontal, 9)
                                    .frame(minWidth: 34, minHeight: 36)
                                    .background(index == 0 ? Theme.accentSoft : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("candidate.\(index)")
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteCandidate(item)
                                } label: {
                                    Label("删除候选并降低排序", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: 38)

            if mode == .handwrite {
                Button {
                    strokes = []
                    currentStroke = []
                    handwriteGuesses = []
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 30, height: 34)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 5)
        .frame(height: 40)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var displayBuffer: String {
        switch mode {
        case .english:
            return shift ? buffer.uppercased() : buffer
        case .t9:
            return buffer
        case .stroke:
            return buffer.map { strokeLabel(String($0)) }.joined()
        default:
            return buffer
        }
    }

    private var emptyCandidateHint: String {
        switch mode {
        case .english: return "输入英文…"
        case .t9: return "按数字键输入拼音"
        case .stroke: return "一丨丿丶折"
        case .handwrite: return "在画板写一个简单字"
        case .wubi: return "五笔编码"
        case .doublepin: return "小鹤双拼"
        default: return "输入拼音…"
        }
    }

    // MARK: - Mode surfaces

    @ViewBuilder
    private var modeSurface: some View {
        switch mode {
        case .t9:
            t9Surface
        case .qwerty, .wubi, .doublepin:
            qwertySurface
        case .english:
            englishSurface
        case .number:
            numberSurface
        case .symbols:
            symbolsSurface
        case .stroke:
            strokeSurface
        case .handwrite:
            handwriteSurface
        case .emoji:
            emojiSurface
        }
    }

    private var t9Surface: some View {
        VStack(spacing: 5) {
            KeyRowView(keys: [
                t9Key("1", ".,?"),
                t9Key("2", "ABC"),
                t9Key("3", "DEF"),
            ], height: keyHeight)
            KeyRowView(keys: [
                t9Key("4", "GHI"),
                t9Key("5", "JKL"),
                t9Key("6", "MNO"),
            ], height: keyHeight)
            KeyRowView(keys: [
                t9Key("7", "PQRS"),
                t9Key("8", "TUV"),
                t9Key("9", "WXYZ"),
            ], height: keyHeight)
            KeyRowView(keys: [
                KeySpec(label: "符号", width: 1, special: true, action: { setMode(.symbols) }),
                KeySpec(label: "0", sub: "空格", width: 1, action: spaceAction),
                KeySpec(label: "删除", system: "delete.left", width: 1, special: true, action: deleteAction),
            ], height: keyHeight)
            KeyRowView(keys: [
                KeySpec(label: "中/英", width: 1.2, special: true, action: { setMode(.english) }),
                KeySpec(label: "，", width: 0.6, action: { insertDirect("，") }),
                spaceSpec(width: 3.2),
                KeySpec(label: "。", width: 0.6, action: { insertDirect("。") }),
                KeySpec(label: "换行", system: "return", width: 1.2, special: true, action: returnAction),
            ], height: keyHeight)
        }
    }

    private var qwertySurface: some View {
        VStack(spacing: 5) {
            if numberRow {
                KeyRowView(keys: "1234567890".map { ch in
                    KeySpec(label: String(ch), width: 1, action: { insertDirect(String(ch)) })
                }, height: 34)
            }
            KeyRowView(keys: "qwertyuiop".map { ch in
                KeySpec(label: shift ? String(ch).uppercased() : String(ch), width: 1,
                        action: { typeLetter(String(ch)) })
            }, height: keyHeight)
            KeyRowView(keys: "asdfghjkl".map { ch in
                KeySpec(label: shift ? String(ch).uppercased() : String(ch), width: 1,
                        action: { typeLetter(String(ch)) })
            }, height: keyHeight)
            KeyRowView(keys: [
                KeySpec(label: shift ? "⇧" : "⇧", system: shift ? "shift.fill" : "shift", width: 1.4, special: true, action: {
                    shift.toggle()
                }),
                ] + "zxcvbnm".map { ch in
                    KeySpec(label: shift ? String(ch).uppercased() : String(ch), width: 1,
                            action: { typeLetter(String(ch)) })
                } + [
                    KeySpec(label: "删除", system: "delete.left", width: 1.4, special: true, action: deleteAction),
                ], height: keyHeight)
            KeyRowView(keys: [
                KeySpec(label: "123", width: 1.2, special: true, action: { setMode(.number) }),
                KeySpec(label: "，", width: 0.7, action: { insertDirect("，") }),
                spaceSpec(width: 3.4),
                KeySpec(label: "。", width: 0.7, action: { insertDirect("。") }),
                KeySpec(label: "换行", system: "return", width: 1.2, special: true, action: returnAction),
            ], height: keyHeight)
        }
    }

    private var englishSurface: some View {
        VStack(spacing: 5) {
            if numberRow {
                KeyRowView(keys: "1234567890".map { ch in
                    KeySpec(label: String(ch), width: 1, action: { insertDirect(String(ch)) })
                }, height: 34)
            }
            KeyRowView(keys: "qwertyuiop".map { ch in
                KeySpec(label: shift ? String(ch).uppercased() : String(ch), width: 1,
                        action: { typeLetter(String(ch)) })
            }, height: keyHeight)
            KeyRowView(keys: "asdfghjkl".map { ch in
                KeySpec(label: shift ? String(ch).uppercased() : String(ch), width: 1,
                        action: { typeLetter(String(ch)) })
            }, height: keyHeight)
            KeyRowView(keys: [
                KeySpec(label: "⇧", system: shift ? "shift.fill" : "shift", width: 1.4, special: true, action: { shift.toggle() }),
                ] + "zxcvbnm".map { ch in
                    KeySpec(label: shift ? String(ch).uppercased() : String(ch), width: 1,
                            action: { typeLetter(String(ch)) })
                } + [
                    KeySpec(label: "删除", system: "delete.left", width: 1.4, special: true, action: deleteAction),
                ], height: keyHeight)
            KeyRowView(keys: [
                KeySpec(label: "123", width: 1.2, special: true, action: { setMode(.number) }),
                KeySpec(label: "，", width: 0.7, action: { insertDirect(",") }),
                spaceSpec(width: 3.4),
                KeySpec(label: ".", width: 0.7, action: { insertDirect(".") }),
                KeySpec(label: "换行", system: "return", width: 1.2, special: true, action: returnAction),
            ], height: keyHeight)
        }
    }

    private var numberSurface: some View {
        VStack(spacing: 5) {
            KeyRowView(keys: ["1", "2", "3"].map(numberKey), height: keyHeight)
            KeyRowView(keys: ["4", "5", "6"].map(numberKey), height: keyHeight)
            KeyRowView(keys: ["7", "8", "9"].map(numberKey), height: keyHeight)
            KeyRowView(keys: [
                KeySpec(label: ".", width: 1, action: { insertDirect(".") }),
                numberKey("0"),
                KeySpec(label: "删除", system: "delete.left", width: 1, special: true, action: deleteAction),
            ], height: keyHeight)
            KeyRowView(keys: [
                KeySpec(label: "符号", width: 1.2, special: true, action: { setMode(.symbols) }),
                KeySpec(label: "空格", width: 3.4, action: spaceAction),
                KeySpec(label: "换行", system: "return", width: 1.2, special: true, action: returnAction),
            ], height: keyHeight)
        }
    }

    private var symbolsSurface: some View {
        let pages: [[String]] = [
            ["，", "。", "？", "！", "：", "；", "、", "“", "”", "‘", "’", "（", "）", "【", "】", "《", "》", "…", "—", "·", "￥", "％", "＃", "＠", "／", "＼", "｜", "～", "＋", "＝"],
            ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "/", ":", ";", "(", ")", "$", "&", "*", "\"", "'", "?", "!", "[", "]", "{", "}", "<", ">", "^"],
        ]
        return VStack(spacing: 5) {
            let items = pages[symbolPage % pages.count]
            ForEach(0..<5, id: \.self) { row in
                KeyRowView(keys: (0..<6).map { col in
                    let index = row * 6 + col
                    let label = index < items.count ? items[index] : ""
                    return KeySpec(label: label, width: 1, action: { if !label.isEmpty { insertDirect(label) } })
                }, height: 34)
            }
            KeyRowView(keys: [
                KeySpec(label: symbolPage == 0 ? "1/2" : "2/2", width: 1, special: true, action: { symbolPage = (symbolPage + 1) % 2 }),
                KeySpec(label: "中/英", width: 1, special: true, action: { setMode(.qwerty) }),
                KeySpec(label: "空格", width: 3, action: spaceAction),
                KeySpec(label: "删除", system: "delete.left", width: 1, special: true, action: deleteAction),
                KeySpec(label: "换行", system: "return", width: 1, special: true, action: returnAction),
            ], height: keyHeight)
        }
    }

    private var strokeSurface: some View {
        VStack(spacing: 5) {
            KeyRowView(keys: [
                strokeKey("一", code: "h"),
                strokeKey("丨", code: "s"),
                strokeKey("丿", code: "p"),
                strokeKey("丶", code: "n"),
                strokeKey("折", code: "z"),
            ], height: keyHeight + 6)
            KeyRowView(keys: [
                KeySpec(label: "？", width: 0.8, special: true, action: { insertDirect("？") }),
                KeySpec(label: "清空", width: 1.2, special: true, action: { buffer = "" }),
                spaceSpec(width: 3.2),
                KeySpec(label: "删除", system: "delete.left", width: 1.2, special: true, action: deleteAction),
            ], height: keyHeight)
            KeyRowView(keys: [
                KeySpec(label: "中/英", width: 1.2, special: true, action: { setMode(.qwerty) }),
                KeySpec(label: "符号", width: 1.2, special: true, action: { setMode(.symbols) }),
                KeySpec(label: "换行", system: "return", width: 1.2, special: true, action: returnAction),
            ], height: keyHeight - 4)
        }
    }

    private var handwriteSurface: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.surface)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                    Path { path in
                        for stroke in strokes + [currentStroke] {
                            guard let first = stroke.first else { continue }
                            path.move(to: first)
                            for point in stroke.dropFirst() {
                                path.addLine(to: point)
                            }
                        }
                    }
                    .stroke(Theme.accentDark, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    if strokes.isEmpty && currentStroke.isEmpty {
                        VStack(spacing: 3) {
                            Text("在这里写一个简单字")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                            Text("内置 20 字方向模板 · 仅作演示级识别")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let size = geo.size
                            guard size.width > 0, size.height > 0 else { return }
                            currentStroke.append(CGPoint(x: value.location.x / size.width,
                                                         y: value.location.y / size.height))
                        }
                        .onEnded { _ in
                            if currentStroke.count > 1 {
                                strokes.append(currentStroke)
                                currentStroke = []
                                handwriteGuesses = HandwritingRecognizer.recognize(strokes: strokes)
                            } else {
                                currentStroke = []
                            }
                        }
                )
            }
            .frame(height: 150)
            HStack(spacing: 8) {
                Text("模板手写：\(HandwritingRecognizer.supportedCharacters.joined())")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Spacer()
                Button {
                    strokes = []
                    currentStroke = []
                    handwriteGuesses = []
                } label: {
                    Label("清空", systemImage: "trash")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accentDark)
            }
            .padding(.horizontal, 2)
        }
    }

    private var emojiSurface: some View {
        VStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    categoryChip("最近")
                    ForEach(Lexicon.shared.emojiCategories) { category in
                        categoryChip(category.category)
                    }
                }
            }
            .frame(height: 28)

            let items = emojiCategory == "最近"
                ? Array(SharedStore.recentEmoji.prefix(40)) + Array(Lexicon.shared.emojiCategories.first?.items.prefix(40) ?? [])
                : (Lexicon.shared.emojiCategories.first { $0.category == emojiCategory }?.items ?? [])
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 8), spacing: 2) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, emoji in
                        Button {
                            tapFeedback()
                            SharedStore.rememberEmoji(emoji)
                            onInsert(emoji)
                        } label: {
                            Text(emoji)
                                .font(.system(size: 25))
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack(spacing: 5) {
                KeyRowView(keys: [
                    KeySpec(label: "ABC", width: 1.2, special: true, action: { setMode(.qwerty) }),
                    KeySpec(label: "空格", width: 3, action: spaceAction),
                    KeySpec(label: "删除", system: "delete.left", width: 1.2, special: true, action: deleteAction),
                ], height: 38)
            }
        }
    }

    private func categoryChip(_ title: String) -> some View {
        Button {
            emojiCategory = title
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(emojiCategory == title ? .white : Theme.textSecondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(emojiCategory == title ? Theme.accent : Theme.surface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tool panels

    @ViewBuilder
    private func toolPanel(_ tool: ToolAction) -> some View {
        switch tool {
        case .mode:
            modePanel
        case .clipboard:
            clipboardPanel
        case .phrases:
            phrasesPanel
        case .ai, .translate, .polish:
            ToolAIPanel(action: tool,
                        initialContext: contextProvider(),
                        onInsert: { text in onInsert(text) },
                        onClose: { activeTool = nil })
        case .settings:
            inlineSettingsPanel
        case .voice, .emoji, .handwrite:
            EmptyView()
        }
    }

    private var modePanel: some View {
        VStack(spacing: 8) {
            HStack {
                Text("选择键盘")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Button("完成") { activeTool = nil }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.accentDark)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 94), spacing: 8)], spacing: 8) {
                ForEach(SharedStore.enabledModes) { item in
                    Button {
                        tapFeedback()
                        setMode(item)
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 19, weight: .medium))
                            Text(item.shortTitle)
                                .font(.system(size: 11, weight: .medium))
                            if let index = item.chineseIndex {
                                Text("中文 \(index + 1)")
                                    .font(.system(size: 8))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .foregroundStyle(mode == item ? .white : Theme.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(mode == item ? AnyShapeStyle(Theme.mintGradient) : AnyShapeStyle(Theme.surface))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("mode.\(item.rawValue)")
                }
            }
            Text("在“键盘管理”中启用或停用键盘。全部模式都可从工具栏切换。")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var clipboardPanel: some View {
        let items = SharedStore.clipboard
        return VStack(spacing: 6) {
            panelHeader("剪贴板", trailing: items.isEmpty ? nil : "清空") {
                SharedStore.clipboard = []
            }
            if items.isEmpty {
                EmptyStateView(symbol: "doc.on.clipboard", title: "暂无剪贴板记录", message: "在主 App 的剪贴板页添加文本后会出现在这里。")
            } else {
                ScrollView {
                    LazyVStack(spacing: 5) {
                        ForEach(items) { item in
                            Button {
                                onInsert(item.text)
                                activeTool = nil
                            } label: {
                                HStack {
                                    Text(item.text.replacingOccurrences(of: "\n", with: " "))
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.text)
                                        .lineLimit(2)
                                    Spacer()
                                    Image(systemName: "arrow.up.left")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Theme.accentDark)
                                }
                                .padding(9)
                                .background(Theme.surfaceAlt)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var phrasesPanel: some View {
        let custom = SharedStore.customPhrases.map(\.text)
        let bundled = Lexicon.shared.bundledPhrases.prefix(18).map(\.text)
        let items = custom + bundled
        return VStack(spacing: 6) {
            panelHeader("常用语", trailing: nil, trailingAction: {})
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 6)], spacing: 6) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, text in
                        Button {
                            onInsert(text)
                            activeTool = nil
                        } label: {
                            Text(text)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.text)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 4)
                                .background(Theme.surfaceAlt)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var inlineSettingsPanel: some View {
        VStack(spacing: 7) {
            panelHeader("键盘设置", trailing: nil, trailingAction: {})
            HStack {
                Text("按键声音")
                    .font(.system(size: 13))
                Spacer()
                Toggle("", isOn: $soundOn).labelsHidden().tint(Theme.accent)
            }
            HStack {
                Text("候选字大小")
                    .font(.system(size: 13))
                Slider(value: $candidateSize, in: 14...24, step: 1)
                    .frame(maxWidth: 160)
                Text("\(Int(candidateSize))")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack {
                Text("触感")
                    .font(.system(size: 13))
                Spacer()
                Picker("触感", selection: $hapticRaw) {
                    ForEach(HapticStrength.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 210)
            }
            HStack {
                Text("长按空格语音")
                    .font(.system(size: 13))
                Spacer()
                Text(hasFullAccess ? "完全访问已开启" : "需完全访问")
                    .font(.system(size: 11))
                    .foregroundStyle(hasFullAccess ? Theme.accentDark : Theme.warning)
            }
            Button {
                onOpenApp()
                inlineNote = "如未打开主 App，请从主屏幕启动微输入法"
            } label: {
                Label("打开微输入法主 App", systemImage: "arrow.up.forward.app")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Theme.mintGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func panelHeader(_ title: String, trailing: String?, trailingAction: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text)
            Spacer()
            if let trailing {
                Button(trailing, action: trailingAction)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.danger)
            }
            Button("完成") { activeTool = nil }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.accentDark)
        }
    }

    // MARK: - Voice

    private func beginVoice() {
        showVoice = true
        activeTool = nil
        guard !(isExtension && !hasFullAccess) else { return }
        Task {
            speech.reset()
            let allowed = await speech.requestAccess()
            guard allowed else { return }
            do {
                try speech.start(locale: localeIdentifier)
            } catch {
                speech.error = error.localizedDescription
            }
        }
    }

    private var localeIdentifier: String {
        switch voiceLanguage {
        case "粤语": return "zh-HK"
        case "英语": return "en-US"
        case "日语": return "ja-JP"
        case "韩语": return "ko-KR"
        case "中英混合": return "zh-CN"
        default: return "zh-CN"
        }
    }

    private func finishVoiceOnRelease() {
        guard speech.isRecording else { return }
        let action = VoiceReleaseAction(rawValue: voiceRelease) ?? .insert
        guard action != .stay else { return }
        Task {
            speech.stop()
            try? await Task.sleep(nanoseconds: 500_000_000)
            let text = speech.transcript
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                onInsert(text)
                if action == .send { onReturn() }
                showVoice = false
            } else {
                speech.error = "没有识别到语音，请重试或检查麦克风权限。"
            }
        }
    }

    // MARK: - Key helpers

    private var keyHeight: CGFloat {
        isExtension ? 40 : 41
    }

    private func t9Key(_ number: String, _ letters: String) -> KeySpec {
        KeySpec(label: number, sub: letters, width: 1,
                action: { typeBufferKey(number) })
    }

    private func numberKey(_ number: String) -> KeySpec {
        KeySpec(label: number, width: 1, action: { insertDirect(number) })
    }

    private func strokeKey(_ label: String, code: String) -> KeySpec {
        KeySpec(label: label, sub: strokeLabel(code), width: 1,
                action: { typeBufferKey(code) })
    }

    private func strokeLabel(_ code: String) -> String {
        switch code {
        case "h": return "横"
        case "s": return "竖"
        case "p": return "撇"
        case "n": return "点"
        case "z": return "折"
        default: return code
        }
    }

    private func spaceSpec(width: CGFloat) -> KeySpec {
        KeySpec(label: "空格", width: width, special: false, action: spaceAction, longPress: {
            beginVoice()
            spaceHeld = true
        }, longPressEnded: {
            if spaceHeld {
                spaceHeld = false
                finishVoiceOnRelease()
            }
        })
    }

    private func typeBufferKey(_ key: String) {
        tapFeedback()
        let limit = mode == .t9 ? 24 : 32
        guard buffer.count < limit else { return }
        buffer += key
        if mode == .t9, buffer == "1" {
            // The 1 key doubles as punctuation on the T9 pad.
        }
    }

    private func typeLetter(_ letter: String) {
        tapFeedback()
        if letter.count == 1, mode == .english {
            buffer += letter
            shift = false
        } else {
            buffer += letter
        }
        if buffer.count > 40 { buffer = String(buffer.suffix(40)) }
    }

    private func refreshCandidates() {
        guard mode != .handwrite else { return }
        let raw = buffer.lowercased()
        guard !raw.isEmpty else {
            candidates = []
            return
        }
        var values = Lexicon.shared.candidates(for: mode, input: raw)
        if mode == .english, !values.contains(raw) {
            values.append(raw)
        }
        candidates = values
    }

    private func commitCandidate(_ word: String, index: Int) {
        if mode == .handwrite {
            onInsert(word)
            SharedStore.learn(input: "handwrite", word: word)
            strokes = []
            currentStroke = []
            handwriteGuesses = []
            return
        }
        let raw = buffer
        onInsert(word)
        SharedStore.learn(input: raw, word: word)
        if mode == .english {
            buffer = ""
        } else {
            buffer = ""
        }
        candidates = []
    }

    private func deleteCandidate(_ word: String) {
        guard !buffer.isEmpty else { return }
        SharedStore.banish(input: buffer, word: word)
        candidates.removeAll { $0 == word }
    }

    private func insertDirect(_ text: String) {
        tapFeedback()
        onInsert(text)
    }

    private func spaceAction() {
        tapFeedback()
        if !buffer.isEmpty {
            if let first = candidates.first {
                commitCandidate(first, index: 0)
            } else if mode == .english || mode == .qwerty || mode == .doublepin {
                onInsert(shift ? buffer.uppercased() : buffer)
                buffer = ""
                candidates = []
            } else {
                buffer = ""
                onSpace()
            }
        } else {
            onSpace()
        }
    }

    private func returnAction() {
        tapFeedback()
        if !buffer.isEmpty, let first = candidates.first {
            commitCandidate(first, index: 0)
        }
        onReturn()
    }

    private func deleteAction() {
        tapFeedback()
        if !buffer.isEmpty {
            buffer.removeLast()
        } else {
            onDelete()
        }
    }

    private func tapFeedback() {
        if soundOn {
            AudioServicesPlaySystemSound(1104)
        }
        switch HapticStrength(rawValue: hapticRaw) ?? .medium {
        case .off: break
        case .light: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .strong: UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }
}

// MARK: - Key primitives

struct KeySpec {
    var label: String = ""
    var sub: String? = nil
    var system: String? = nil
    var width: CGFloat = 1
    var special: Bool = false
    var action: () -> Void
    var longPress: (() -> Void)? = nil
    var longPressEnded: (() -> Void)? = nil
}

struct KeyRowView: View {
    let keys: [KeySpec]
    var height: CGFloat = 44
    var spacing: CGFloat = 5

    var body: some View {
        GeometryReader { geometry in
            let total = keys.reduce(0) { $0 + $1.width }
            let unit = (geometry.size.width - spacing * CGFloat(max(0, keys.count - 1))) / max(total, 1)
            HStack(spacing: spacing) {
                ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                    KeyCap(spec: key)
                        .frame(width: max(20, unit * key.width), height: height)
                }
            }
        }
        .frame(height: height)
    }
}

struct KeyCap: View {
    let spec: KeySpec
    @State private var holding = false
    @State private var suppressTap = false

    var body: some View {
        Group {
            if spec.longPress != nil {
                labelContent
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !suppressTap { spec.action() }
                    }
                    .onLongPressGesture(minimumDuration: 0.45, maximumDistance: 24, pressing: { pressing in
                        if !pressing, holding {
                            holding = false
                            spec.longPressEnded?()
                        }
                    }, perform: {
                        holding = true
                        suppressTap = true
                        spec.longPress?()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            suppressTap = false
                        }
                    })
            } else {
                Button {
                    spec.action()
                } label: {
                    labelContent
                }
                .buttonStyle(KeyPressStyle())
            }
        }
    }

    private var accessibilityID: String {
        if let system = spec.system {
            return system == "delete.left" ? "key.delete" : "key.\(system)"
        }
        return spec.label == "空格" ? "key.space" : "key.\(spec.label)"
    }

    private var labelContent: some View {
        VStack(spacing: 0) {
            if let system = spec.system {
                Image(systemName: system).font(.system(size: 16, weight: .medium))
            } else {
                Text(spec.label)
                    .font(.system(size: spec.sub == nil ? 19 : 21, weight: .regular))
            }
            if let sub = spec.sub, !sub.isEmpty {
                Text(sub)
                    .font(.system(size: 8, weight: .medium))
                    .opacity(0.66)
            }
        }
        .foregroundStyle(Theme.keyText)
        .accessibilityIdentifier(accessibilityID)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(holding ? Theme.keyPressed : (spec.special ? Theme.keySpecial : Theme.key))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 0.6, x: 0, y: 1)
    }
}

struct KeyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Theme.keyPressed : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

// MARK: - Voice panel

struct VoicePanel: View {
    @ObservedObject var speech: SpeechCapture
    let isExtension: Bool
    let hasFullAccess: Bool
    let onInsert: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "waveform")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accentDark)
                Text("语音转文字")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Button("完成", action: onClose)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.accentDark)
            }

            if isExtension && !hasFullAccess {
                VStack(spacing: 8) {
                    InfoBanner(text: "键盘扩展需要“允许完全访问”才能使用麦克风与网络。未开启时，可从下面的本地常用语上屏。",
                               symbol: "lock.shield", tint: Theme.warning)
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 6)], spacing: 6) {
                            ForEach(Array(Lexicon.shared.bundledPhrases.prefix(12).enumerated()), id: \.offset) { _, item in
                                Button {
                                    onInsert(item.text)
                                } label: {
                                    Text(item.text)
                                        .font(.system(size: 12))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Theme.surfaceAlt)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            } else {
                ScrollView {
                    Text(speech.transcript.isEmpty ? "按住空格键或点击下方按钮开始说话…" : speech.transcript)
                        .font(.system(size: 15))
                        .foregroundStyle(speech.transcript.isEmpty ? Theme.textSecondary : Theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(maxHeight: .infinity)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                if let error = speech.error {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.warning)
                        Text(error)
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .padding(7)
                    .background(Theme.warning.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                HStack(spacing: 8) {
                    Text(timeString(speech.elapsed))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    if speech.isRecording {
                        Button {
                            speech.stop()
                        } label: {
                            Label("停止", systemImage: "stop.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Theme.danger)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            Task {
                                let ok = await speech.requestAccess()
                                guard ok else { return }
                                do { try speech.start(locale: "zh-CN") } catch { speech.error = error.localizedDescription }
                            }
                        } label: {
                            Label("开始", systemImage: "mic.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Theme.mintGradient)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        let text = speech.transcript
                        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        speech.stop()
                        onInsert(text)
                        onClose()
                    } label: {
                        Label("上屏", systemImage: "arrow.up.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.accentDark)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.accentSoft)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func timeString(_ value: TimeInterval) -> String {
        let seconds = Int(value)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - AI tool panel

struct ToolAIPanel: View {
    let action: ToolAction
    let initialContext: String
    let onInsert: (String) -> Void
    let onClose: () -> Void

    @State private var source = ""
    @State private var prompt = ""
    @State private var result = ""
    @State private var error: String?
    @State private var running = false
    @State private var target = "英文"

    var body: some View {
        VStack(spacing: 7) {
            HStack {
                Image(systemName: action.symbol)
                    .foregroundStyle(Theme.accentDark)
                Text(action.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Button("完成", action: onClose)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.accentDark)
            }

            if action == .ai {
                TextField("问 AI 任何问题，例如：帮我写一句道歉", text: $prompt)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(8)
                    .background(Theme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                TextField("要处理的文字", text: $source, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(8)
                    .background(Theme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                if action == .translate {
                    Picker("目标语言", selection: $target) {
                        Text("英文").tag("英文")
                        Text("中文").tag("中文")
                    }
                    .pickerStyle(.segmented)
                }
            }

            HStack(spacing: 8) {
                Button {
                    run()
                } label: {
                    HStack(spacing: 4) {
                        if running { ProgressView().tint(.white).scaleEffect(0.7) }
                        Text(running ? "处理中" : "开始")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Theme.mintGradient)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(running)

                if !result.isEmpty {
                    Button {
                        UIPasteboard.general.string = result
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accentDark)
                    Button {
                        onInsert(result)
                        onClose()
                    } label: {
                        Label("上屏", systemImage: "arrow.up.circle")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accentDark)
                }
                Spacer()
                Text("需完全访问 · 后端 \(SharedStore.apiBaseURL)")
                    .font(.system(size: 8))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }

            ScrollView {
                if running {
                    ProgressView("正在请求后端…")
                        .font(.system(size: 11))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
                } else if let error {
                    VStack(spacing: 8) {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.danger)
                            .multilineTextAlignment(.center)
                        Button("重试") { run() }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.accentDark)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                } else if result.isEmpty {
                    Text("结果会显示在这里。不会伪造 AI 输出；后端不可用时显示真实错误。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                } else {
                    Text(result)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onAppear {
            if action != .ai && source.isEmpty { source = initialContext }
        }
    }

    private func run() {
        running = true
        error = nil
        result = ""
        Task {
            do {
                let value: String
                switch action {
                case .ai:
                    let question = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    let text = question.isEmpty ? "帮我把下面这句话写得更自然：\(source)" : question
                    value = try await KBService.chat(prompt: text)
                case .translate:
                    value = try await KBService.translate(source, target: target == "英文" ? "en" : "zh")
                case .polish:
                    value = try await KBService.polish(source)
                default:
                    value = ""
                }
                await MainActor.run {
                    result = value
                    running = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    running = false
                }
            }
        }
    }
}
