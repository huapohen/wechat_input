import SwiftUI
import UIKit

// MARK: - AI chat

struct AIChatView: View {
    @EnvironmentObject private var app: AppModel
    @State private var messages: [ChatTurn] = SharedStore.chatHistory
    @State private var input = ""
    @State private var streamingText = ""
    @State private var isStreaming = false
    @State private var error: String?
    @State private var lastPrompt = ""
    @State private var streamTask: Task<Void, Never>?

    private let suggestions = [
        "帮我把这句话写得更正式：明天开会别忘了带材料",
        "用三句话解释什么是输入法候选排序",
        "写一条 60 字以内的产品更新公告",
        "把“今天辛苦了”翻译成自然的英文",
    ]

    var body: some View {
        PageShell(title: "问 AI", subtitle: "多轮对话、流式响应、停止/重试/复制") {
            VStack(spacing: 12) {
                statusBar
                if let error {
                    errorBanner(error)
                }
                if messages.isEmpty && streamingText.isEmpty {
                    emptyState
                } else {
                    conversation
                }
                inputBar
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        UIPasteboard.general.string = messages.map { "\($0.role == "user" ? "我" : "AI")：\($0.content)" }.joined(separator: "\n\n")
                        app.flash("对话已复制")
                    } label: {
                        Label("复制全部", systemImage: "doc.on.doc")
                    }
                    Button(role: .destructive) {
                        messages = []
                        SharedStore.chatHistory = []
                        app.flash("对话历史已清空")
                    } label: {
                        Label("清空历史", systemImage: "trash")
                    }
                    Button {
                        Task { await app.refreshStatus() }
                    } label: {
                        Label("重新检查后端", systemImage: "network")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onDisappear {
            streamTask?.cancel()
        }
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            StatusPill(text: app.backendStatus.label, ok: app.backendStatus.ok)
            Text(SharedStore.apiBaseURL)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            Spacer()
            if app.standalone {
                Text("单机模式：已阻止网络")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.warning)
            } else if !app.plusEnabled {
                Text("拼写 Plus 已关闭")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.warning)
            }
        }
        .padding(.horizontal, 4)
    }

    private func errorBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.warning)
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            HStack(spacing: 8) {
                SecondaryButton(title: "重试", symbol: "arrow.clockwise") {
                    send(lastPrompt.isEmpty ? nil : lastPrompt)
                }
                SecondaryButton(title: "检查后端", symbol: "network") {
                    Task { await app.refreshStatus() }
                }
            }
        }
        .padding(11)
        .background(Theme.warning.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Theme.accent)
                Text("问点什么")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text("回答来自你在设置中配置的后端。没有 API Key 不会返回伪造内容。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 7) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        input = suggestion
                    } label: {
                        HStack {
                            Text(suggestion)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.text)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "arrow.up.left")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.accentDark)
                        }
                        .padding(9)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(messages) { message in
                        messageBubble(message, streaming: false)
                            .id(message.id)
                    }
                    if !streamingText.isEmpty || isStreaming {
                        messageBubble(ChatTurn(role: "assistant", content: streamingText), streaming: true)
                            .id("streaming")
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 4)
            }
            .frame(minHeight: 260, maxHeight: 520)
            .onChange(of: messages.count) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: streamingText) { _, _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private func messageBubble(_ message: ChatTurn, streaming: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == "user" { Spacer(minLength: 40) }
            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Text(message.role == "user" ? "我" : "AI")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(message.role == "user" ? Theme.accentDark : Theme.textSecondary)
                    if !streaming {
                        Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 8))
                            .foregroundStyle(Theme.muted)
                    }
                }
                Text(message.content.isEmpty ? "…" : message.content)
                    .font(.system(size: 13))
                    .foregroundStyle(message.role == "user" ? .white : Theme.text)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(message.role == "user" ? AnyShapeStyle(Theme.mintGradient) : AnyShapeStyle(Theme.surface))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        if streaming {
                            ProgressView()
                                .scaleEffect(0.5)
                                .padding(3)
                        }
                    }
                if !streaming && message.role == "assistant" {
                    Button {
                        UIPasteboard.general.string = message.content
                        app.flash("回答已复制")
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                            .font(.system(size: 9))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.textSecondary)
                }
            }
            if message.role != "user" { Spacer(minLength: 40) }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 7) {
            if app.standalone || !app.plusEnabled {
                HStack(spacing: 8) {
                    Image(systemName: app.standalone ? "externaldrive" : "sparkles")
                        .foregroundStyle(Theme.warning)
                    Text(app.standalone ? "单机模式已开启，AI 请求被阻止。" : "拼写 Plus 已关闭，AI 入口不可用。")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Button(app.standalone ? "关闭单机" : "开启 Plus") {
                        if app.standalone { app.setStandalone(false) } else { app.setPlus(true) }
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.accentDark)
                }
                .padding(8)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField("问 AI…", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(isStreaming)
                if isStreaming {
                    Button {
                        streamTask?.cancel()
                        isStreaming = false
                        if !streamingText.isEmpty {
                            messages.append(ChatTurn(role: "assistant", content: streamingText + "\n（已停止）"))
                            SharedStore.chatHistory = messages
                            streamingText = ""
                        }
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(Theme.danger)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        send(input)
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(canSend ? AnyShapeStyle(Theme.mintGradient) : AnyShapeStyle(Theme.muted))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("ai.send")
                    .disabled(!canSend)
                }
            }
        }
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isStreaming && !app.standalone && app.plusEnabled
    }

    private func send(_ override: String?) {
        let prompt = (override ?? input).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isStreaming else { return }
        guard !app.standalone else {
            error = "单机模式已开启，AI 请求被阻止。"
            return
        }
        guard app.plusEnabled else {
            error = "拼写 Plus 已关闭，请先开启。"
            return
        }
        if override == nil {
            messages.append(ChatTurn(role: "user", content: prompt))
            SharedStore.chatHistory = messages
        }
        input = ""
        lastPrompt = prompt
        error = nil
        streamingText = ""
        isStreaming = true

        let apiMessages = messages.suffix(20).compactMap { turn -> APIChatMessage? in
            guard turn.role == "user" || turn.role == "assistant" else { return nil }
            return APIChatMessage(role: turn.role, content: turn.content)
        }
        streamTask = Task {
            do {
                let full = try await APIClient.shared.chat(messages: apiMessages, stream: true) { delta in
                    Task { @MainActor in
                        streamingText += delta
                    }
                }
                await MainActor.run {
                    messages.append(ChatTurn(role: "assistant", content: full))
                    SharedStore.chatHistory = messages
                    streamingText = ""
                    isStreaming = false
                }
            } catch {
                await MainActor.run {
                    if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                        if !streamingText.isEmpty {
                            messages.append(ChatTurn(role: "assistant", content: streamingText + "\n（已停止）"))
                            SharedStore.chatHistory = messages
                        }
                        streamingText = ""
                        isStreaming = false
                        return
                    }
                    self.error = "请求失败：\(error.localizedDescription)"
                    isStreaming = false
                    if !streamingText.isEmpty {
                        messages.append(ChatTurn(role: "assistant", content: streamingText + "\n（中断）"))
                        SharedStore.chatHistory = messages
                        streamingText = ""
                    }
                }
            }
        }
    }
}

// MARK: - Text tools

struct TextToolsView: View {
    @EnvironmentObject private var app: AppModel
    @State private var mode = "润色"
    @State private var input = ""
    @State private var output = ""
    @State private var candidates: [String] = []
    @State private var error: String?
    @State private var running = false
    @State private var undo: [String] = []
    @State private var target = "英文"
    @State private var style = "自然"

    private let modes = ["润色", "改写", "翻译", "摘要"]

    var body: some View {
        PageShell(title: "文字工具", subtitle: "润色、改写、翻译、摘要，带预览与撤销") {
            VStack(spacing: 13) {
                Picker("工具", selection: $mode) {
                    ForEach(modes, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("原文")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text("\(input.count) 字")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Theme.muted)
                    }
                    TextField("粘贴或输入要处理的文字…", text: $input, axis: .vertical)
                        .lineLimit(4...9)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                }

                if mode == "改写" || mode == "翻译" {
                    HStack(spacing: 10) {
                        if mode == "改写" {
                            Picker("语气", selection: $style) {
                                ForEach(["自然", "正式", "简洁", "热情", "轻松"], id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.accentDark)
                        }
                        if mode == "翻译" {
                            Picker("目标", selection: $target) {
                                ForEach(["英文", "中文", "日文"], id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.accentDark)
                        }
                        Spacer()
                    }
                }

                HStack(spacing: 9) {
                    Button {
                        run()
                    } label: {
                        HStack(spacing: 5) {
                            if running { ProgressView().tint(.white).scaleEffect(0.7) }
                            Text(running ? "处理中…" : "开始处理")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(canRun ? AnyShapeStyle(Theme.mintGradient) : AnyShapeStyle(Theme.muted))
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tools.run")
                    .disabled(!canRun)
                    SecondaryButton(title: "清空", symbol: "xmark") {
                        input = ""
                        output = ""
                        candidates = []
                        error = nil
                    }
                    Spacer()
                    if app.standalone {
                        Text("单机模式")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Theme.warning)
                    }
                }

                if let error {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.danger)
                        SecondaryButton(title: "重试", symbol: "arrow.clockwise") { run() }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Theme.danger.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if !candidates.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("改写候选")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        ForEach(Array(candidates.enumerated()), id: \.offset) { index, candidate in
                            Button {
                                output = candidate
                            } label: {
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Theme.accentDark)
                                        .frame(width: 18, height: 18)
                                        .background(Theme.accentSoft)
                                        .clipShape(Circle())
                                    Text(candidate)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.text)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    if output == candidate {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Theme.accent)
                                    }
                                }
                                .padding(9)
                                .background(Theme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !output.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text("结果")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Text("\(output.count) 字")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Theme.muted)
                        }
                        Text(output)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.text)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        HStack(spacing: 8) {
                            SecondaryButton(title: "应用到原文", symbol: "arrow.down.doc") {
                                undo.append(input)
                                input = output
                                app.flash("已应用到原文，可撤销")
                            }
                            SecondaryButton(title: "撤销", symbol: "arrow.uturn.backward") {
                                if let last = undo.popLast() {
                                    input = last
                                    output = ""
                                    candidates = []
                                }
                            }
                            .disabled(undo.isEmpty)
                            SecondaryButton(title: "复制", symbol: "doc.on.doc") {
                                UIPasteboard.general.string = output
                                app.flash("结果已复制")
                            }
                            Spacer()
                        }
                    }
                    .card(padding: 12)
                }

                InfoBanner(text: "所有结果都来自 \(SharedStore.apiBaseURL) 的真实响应；失败时显示后端错误与重试，不生成假结果。")
            }
        }
    }

    private var canRun: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !running && !app.standalone
    }

    private func run() {
        guard canRun else { return }
        running = true
        error = nil
        output = ""
        candidates = []
        let text = input
        Task {
            do {
                switch mode {
                case "润色":
                    let value = try await APIClient.shared.polish(text)
                    await MainActor.run { output = value; running = false }
                case "改写":
                    let values = try await APIClient.shared.rewrite(text, style: style, count: 3)
                    await MainActor.run {
                        candidates = values
                        output = values.first ?? ""
                        running = false
                    }
                case "翻译":
                    let value = try await APIClient.shared.translate(text, target: target == "英文" ? "en" : (target == "日文" ? "ja" : "zh"))
                    await MainActor.run { output = value; running = false }
                case "摘要":
                    let response = try await APIClient.shared.summary(text)
                    await MainActor.run {
                        var lines = [response.summary ?? ""]
                        lines.append(contentsOf: response.bullets ?? [])
                        output = lines.filter { !$0.isEmpty }.joined(separator: "\n")
                        running = false
                    }
                default:
                    running = false
                }
            } catch {
                await MainActor.run {
                    self.error = "处理失败：\(error.localizedDescription)"
                    running = false
                }
            }
        }
    }
}
