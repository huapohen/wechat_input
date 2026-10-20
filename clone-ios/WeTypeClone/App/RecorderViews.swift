import SwiftUI
import UIKit

struct RecorderView: View {
    @EnvironmentObject private var app: AppModel
    @StateObject private var speech = SpeechCapture()
    @State private var title = ""
    @State private var sessions: [RecorderSession] = SharedStore.recorderSessions
    @State private var summary = ""
    @State private var summaryBullets: [String] = []
    @State private var summarizing = false
    @State private var error: String?
    @State private var showManual = false
    @State private var manualText = ""
    @State private var savedMessage: String?

    var body: some View {
        PageShell(title: "AI 录音笔", subtitle: "设备语音转写、暂停、保存与后端总结") {
            VStack(spacing: 14) {
                statusHeader
                liveCard
                controls
                if let error {
                    errorCard(error)
                }
                summaryCard
                sessionsSection
                InfoBanner(text: "转写使用 SFSpeechRecognizer；模拟器可能没有可用识别器，此时会显示真实错误。摘要来自配置的后端，不会伪造结果。")
            }
        }
        .sheet(isPresented: $showManual) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 10) {
                    Text("手动文字稿")
                        .font(.system(size: 14, weight: .semibold))
                    Text("当模拟器没有设备语音时，可以用文字稿完成会话与 AI 摘要流程。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                    TextEditor(text: $manualText)
                        .font(.system(size: 14))
                        .frame(minHeight: 220)
                        .padding(6)
                        .background(Theme.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(16)
                .navigationTitle("手动文字稿")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showManual = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存会话") {
                            saveManual()
                            showManual = false
                        }
                        .disabled(manualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var statusHeader: some View {
        HStack(spacing: 9) {
            StatusPill(text: speech.isRecording ? (speech.isPaused ? "已暂停" : "录音中") : "待机",
                       ok: speech.isRecording)
            StatusPill(text: app.backendStatus.label, ok: app.backendStatus.ok)
            Spacer()
            NavigationLink(value: Route.recorderSession) {
                Label("最近会话", systemImage: "doc.text")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.accentDark)
            }
        }
        .padding(.horizontal, 4)
    }

    private var liveCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                TextField("会话标题", text: $title)
                    .font(.system(size: 15, weight: .semibold))
                    .textFieldStyle(.plain)
                Text(timeString(speech.elapsed))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(speech.isRecording ? Theme.accentDark : Theme.textSecondary)
            }
            Divider()
            ScrollView {
                Text(speech.transcript.isEmpty ? "实时转写会显示在这里…" : speech.transcript)
                    .font(.system(size: 14))
                    .foregroundStyle(speech.transcript.isEmpty ? Theme.textSecondary : Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 130, maxHeight: 260)
        }
        .card()
    }

    private var controls: some View {
        HStack(spacing: 9) {
            if speech.isRecording {
                Button {
                    if speech.isPaused {
                        do { try speech.resume() } catch { self.error = error.localizedDescription }
                    } else {
                        speech.pause()
                    }
                } label: {
                    Label(speech.isPaused ? "继续" : "暂停", systemImage: speech.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accentDark)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(Theme.accentSoft)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    speech.stop()
                } label: {
                    Label("停止", systemImage: "stop.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(Theme.danger)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    start()
                } label: {
                    Label("开始录音", systemImage: "mic.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.mintGradient)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                SecondaryButton(title: "手动文字稿", symbol: "text.cursor") {
                    showManual = true
                }
            }
            Spacer()
            Button {
                saveCurrent()
            } label: {
                Label("保存会话", systemImage: "tray.and.arrow.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(speech.transcript.isEmpty ? Theme.muted : Theme.accentDark)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(speech.transcript.isEmpty ? Theme.surfaceAlt : Theme.accentSoft)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(speech.transcript.isEmpty)
        }
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(Theme.danger)
            HStack(spacing: 8) {
                SecondaryButton(title: "重试授权", symbol: "arrow.clockwise") {
                    start()
                }
                SecondaryButton(title: "查看权限", symbol: "lock.shield") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.danger.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("AI 总结")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                if summarizing { ProgressView().scaleEffect(0.7) }
                Button {
                    summarize()
                } label: {
                    Label("生成摘要", systemImage: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.accentDark)
                }
                .buttonStyle(.plain)
                .disabled(speech.transcript.isEmpty || summarizing || app.standalone)
            }
            if !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text)
                    .textSelection(.enabled)
                ForEach(summaryBullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 6) {
                        Circle().fill(Theme.accent).frame(width: 5, height: 5).padding(.top, 5)
                        Text(bullet)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Button {
                    UIPasteboard.general.string = summary + "\n" + summaryBullets.joined(separator: "\n")
                    app.flash("摘要已复制")
                } label: {
                    Label("复制摘要", systemImage: "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.accentDark)
                }
                .buttonStyle(.plain)
            } else {
                Text("停止录音后，点击“生成摘要”把转写交给后端整理。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("本机会话")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("\(sessions.count) 个")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary)
            }
            if sessions.isEmpty {
                EmptyStateView(symbol: "waveform", title: "暂无录音会话", message: "开始录音或手动输入文字稿。")
            } else {
                ForEach(sessions) { session in
                    NavigationLink {
                        RecorderSessionView(sessionID: session.id)
                    } label: {
                        HStack(spacing: 10) {
                            SettingIcon(symbol: "waveform")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Theme.text)
                                Text("\(session.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(timeString(session.duration)) · \(session.transcript.count) 字")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            if !session.summary.isEmpty {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.accent)
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.muted)
                        }
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                    if session.id != sessions.last?.id { Divider().padding(.leading, 42) }
                }
            }
        }
        .card(padding: 14)
    }

    private func start() {
        error = nil
        Task {
            let ok = await speech.requestAccess()
            guard ok else {
                await MainActor.run { error = speech.error }
                return
            }
            do {
                try speech.start(locale: SpeechLocale.from(SharedStore.string(SharedKeys.voiceLanguage)))
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
        }
    }

    private func saveCurrent() {
        let transcript = speech.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { return }
        if speech.isRecording { speech.stop() }
        let session = RecorderSession(title: title.isEmpty ? defaultTitle() : title,
                                      transcript: transcript,
                                      summary: summary,
                                      bullets: summaryBullets,
                                      duration: speech.elapsed)
        sessions.insert(session, at: 0)
        SharedStore.recorderSessions = sessions
        app.flash("录音会话已保存")
        title = ""
        summary = ""
        summaryBullets = []
        speech.reset()
        savedMessage = "已保存：\(session.title)"
    }

    private func saveManual() {
        let text = manualText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let session = RecorderSession(title: "手动文字稿 \(Date().formatted(date: .omitted, time: .shortened))",
                                      transcript: text)
        sessions.insert(session, at: 0)
        SharedStore.recorderSessions = sessions
        manualText = ""
        app.flash("文字稿会话已保存")
    }

    private func summarize() {
        let text = speech.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard !SharedStore.bool(SharedKeys.standalone) else {
            error = "单机模式已开启，总结请求被阻止。"
            return
        }
        summarizing = true
        error = nil
        Task {
            do {
                let response = try await APIClient.shared.summary(text)
                await MainActor.run {
                    summary = response.summary ?? response.text
                    summaryBullets = response.bullets ?? []
                    summarizing = false
                }
            } catch {
                await MainActor.run {
                    self.error = "摘要失败：\(error.localizedDescription)"
                    summarizing = false
                }
            }
        }
    }

    private func defaultTitle() -> String {
        "录音 \(Date().formatted(date: .abbreviated, time: .shortened))"
    }

    private func timeString(_ value: TimeInterval) -> String {
        let seconds = Int(value)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

enum SpeechLocale {
    static func from(_ name: String) -> String {
        switch name {
        case "粤语": return "zh-HK"
        case "英语": return "en-US"
        case "日语": return "ja-JP"
        case "韩语": return "ko-KR"
        default: return "zh-CN"
        }
    }
}

struct RecorderSessionRouteView: View {
    @State private var latest: RecorderSession?

    var body: some View {
        Group {
            if let latest {
                RecorderSessionView(sessionID: latest.id)
            } else {
                PageShell(title: "录音会话", subtitle: "还没有保存的会话") {
                    EmptyStateView(symbol: "waveform", title: "暂无录音会话",
                                   message: "先到 AI 录音笔开始一次录音或手动文字稿。")
                    NavigationLink(value: Route.recorder) {
                        Text("去 AI 录音笔")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 11)
                            .background(Theme.mintGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear { latest = SharedStore.recorderSessions.first }
    }
}

struct RecorderSessionView: View {
    let sessionID: UUID
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var session: RecorderSession?
    @State private var error: String?
    @State private var summarizing = false
    @State private var showDelete = false

    var body: some View {
        PageShell(title: "录音会话", subtitle: session?.title ?? "") {
            if let session {
                VStack(spacing: 14) {
                    HStack(spacing: 8) {
                        StatusPill(text: session.createdAt.formatted(date: .abbreviated, time: .shortened), ok: true)
                        StatusPill(text: timeString(session.duration), ok: true)
                        Spacer()
                        if !session.summary.isEmpty {
                            StatusPill(text: "已总结", ok: true)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("转写")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Text(session.transcript)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.text)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("AI 摘要")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            Spacer()
                            if summarizing { ProgressView().scaleEffect(0.7) }
                            Button {
                                summarize()
                            } label: {
                                Label(session.summary.isEmpty ? "生成摘要" : "重新生成", systemImage: "sparkles")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.accentDark)
                            }
                            .buttonStyle(.plain)
                            .disabled(summarizing || app.standalone)
                        }
                        if session.summary.isEmpty {
                            Text("尚无摘要。")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            Text(session.summary)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.text)
                                .textSelection(.enabled)
                            ForEach(session.bullets, id: \.self) { bullet in
                                HStack(alignment: .top, spacing: 6) {
                                    Circle().fill(Theme.accent).frame(width: 5, height: 5).padding(.top, 5)
                                    Text(bullet)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                    }
                    .card()

                    if let error {
                        InfoBanner(text: error, symbol: "exclamationmark.triangle", tint: Theme.warning)
                    }

                    HStack(spacing: 8) {
                        SecondaryButton(title: "复制全文", symbol: "doc.on.doc") {
                            UIPasteboard.general.string = session.transcript + "\n\n" + session.summary
                            app.flash("会话已复制")
                        }
                        ShareLink(item: session.transcript + "\n\n" + session.summary) {
                            Label("分享", systemImage: "square.and.arrow.up")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.accentDark)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Theme.accentSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        SecondaryButton(title: "删除会话", symbol: "trash") {
                            showDelete = true
                        }
                        Spacer()
                    }
                }
            } else {
                EmptyStateView(symbol: "doc.text", title: "会话不存在", message: "它可能已被删除。")
            }
        }
        .onAppear { load() }
        .alert("删除这个会话？", isPresented: $showDelete) {
            Button("删除", role: .destructive) {
                var sessions = SharedStore.recorderSessions
                sessions.removeAll { $0.id == sessionID }
                SharedStore.recorderSessions = sessions
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
    }

    private func load() {
        session = SharedStore.recorderSessions.first { $0.id == sessionID }
    }

    private func summarize() {
        guard let session else { return }
        guard !SharedStore.bool(SharedKeys.standalone) else {
            error = "单机模式已开启，总结请求被阻止。"
            return
        }
        summarizing = true
        error = nil
        Task {
            do {
                let response = try await APIClient.shared.summary(session.transcript)
                await MainActor.run {
                    var updated = session
                    updated.summary = response.summary ?? response.text
                    updated.bullets = response.bullets ?? []
                    self.session = updated
                    var sessions = SharedStore.recorderSessions
                    if let index = sessions.firstIndex(where: { $0.id == sessionID }) {
                        sessions[index] = updated
                        SharedStore.recorderSessions = sessions
                    }
                    summarizing = false
                    app.flash("摘要已生成")
                }
            } catch {
                await MainActor.run {
                    self.error = "摘要失败：\(error.localizedDescription)"
                    summarizing = false
                }
            }
        }
    }

    private func timeString(_ value: TimeInterval) -> String {
        let seconds = Int(value)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
