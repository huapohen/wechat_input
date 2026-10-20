import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Clipboard

struct ClipboardView: View {
    @EnvironmentObject private var app: AppModel
    @AppStorage(SharedKeys.clipboardEnabled, store: SharedStore.defaults) private var enabled = true
    @AppStorage(SharedKeys.clipboardLimit, store: SharedStore.defaults) private var limit = 50
    @State private var items: [ClipItem] = SharedStore.clipboard

    var body: some View {
        PageShell(title: "剪贴板", subtitle: "历史记录、快速粘贴与跨设备接力") {
            VStack(spacing: 14) {
                VStack(spacing: 0) {
                    ToggleRow(title: "记录剪贴板", subtitle: "把复制的文本保存在本机历史中", isOn: $enabled)
                    Divider()
                    HStack {
                        Text("保留条数")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.text)
                        Spacer()
                        Picker("保留条数", selection: $limit) {
                            Text("20").tag(20)
                            Text("50").tag(50)
                            Text("100").tag(100)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 170)
                    }
                    .padding(.vertical, 10)
                }
                .card(padding: 14)

                HStack(spacing: 10) {
                    SecondaryButton(title: "添加当前剪贴板", symbol: "plus.circle") {
                        if let text = UIPasteboard.general.string, !text.isEmpty {
                            SharedStore.addToClipboard(text)
                            items = SharedStore.clipboard
                            app.flash("已加入剪贴板历史")
                        } else {
                            app.flash("系统剪贴板为空")
                        }
                    }
                    SecondaryButton(title: "清空历史", symbol: "trash") {
                        SharedStore.clipboard = []
                        items = []
                        app.flash("剪贴板历史已清空")
                    }
                    Spacer()
                }

                if items.isEmpty {
                    EmptyStateView(symbol: "doc.on.clipboard", title: "还没有记录",
                                   message: "复制文本，或点“添加当前剪贴板”。")
                        .card()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            VStack(alignment: .leading, spacing: 7) {
                                Text(item.text)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.text)
                                    .lineLimit(3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                HStack {
                                    Text(item.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 9))
                                        .foregroundStyle(Theme.muted)
                                    Spacer()
                                    Button {
                                        UIPasteboard.general.string = item.text
                                        app.flash("已复制")
                                    } label: {
                                        Label("复制", systemImage: "doc.on.doc")
                                            .font(.system(size: 10))
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(Theme.accentDark)
                                    Button {
                                        items.remove(at: index)
                                        SharedStore.clipboard = items
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                            .font(.system(size: 10))
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(Theme.danger)
                                }
                            }
                            .padding(.vertical, 9)
                            if item.id != items.last?.id { Divider() }
                        }
                    }
                    .card(padding: 14)
                }

                NavigationLink(value: Route.sync) {
                    SettingsRow(icon: "arrow.triangle.2.circlepath", title: "跨设备粘贴同步",
                                subtitle: "把剪贴板推送到后端或从配对设备拉取")
                }
                .buttonStyle(.plain)
                .card(padding: 14)

                InfoBanner(text: "“状态栏快速粘贴”在 iOS 上不可用；第三方键盘只能通过工具栏的剪贴板面板插入历史文本。读取系统剪贴板可能触发 iOS 的粘贴授权提示。")
            }
        }
        .onAppear { items = SharedStore.clipboard }
        .onChange(of: limit) { _, _ in
            SharedStore.clipboard = SharedStore.clipboard
            items = SharedStore.clipboard
        }
    }
}

// MARK: - Sync

struct SyncView: View {
    @EnvironmentObject private var app: AppModel
    @AppStorage(SharedKeys.syncToken, store: SharedStore.defaults) private var token = ""
    @AppStorage(SharedKeys.syncCode, store: SharedStore.defaults) private var savedCode = ""
    @State private var code = ""
    @State private var peer = ""
    @State private var busy = false
    @State private var status: String?
    @State private var remote: [RemoteClipItem] = []

    var body: some View {
        PageShell(title: "跨设备粘贴同步", subtitle: "六位配对码、剪贴板与设置同步") {
            VStack(spacing: 14) {
                pairingCard
                if !token.isEmpty { actionsCard }
                if !remote.isEmpty { remoteCard }
                if let status {
                    InfoBanner(text: status, symbol: status.contains("失败") || status.contains("错误") ? "exclamationmark.triangle" : "checkmark.circle",
                               tint: status.contains("失败") || status.contains("错误") ? Theme.warning : Theme.accentDark)
                }
                InfoBanner(text: "同步请求发送到设置中的后端地址。后端按设备 token 存储剪贴板与设置；两台设备各自配对后拥有独立 token。配对会返回已有 peer 信息，但后端接口不返回 peer token，因此跨设备读取需要相同 token 或后端扩展。")
            }
        }
        .onAppear {
            if savedCode.count == 6 { code = savedCode }
        }
    }

    private var pairingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SettingIcon(symbol: "arrow.triangle.2.circlepath", color: Theme.accentDark)
                VStack(alignment: .leading, spacing: 2) {
                    Text(token.isEmpty ? "未配对" : "已配对")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(token.isEmpty ? "输入 6 位配对码" : "配对码 \(savedCode) · \(peer.isEmpty ? "等待设备" : peer)")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                StatusPill(text: token.isEmpty ? "离线" : "已连接", ok: !token.isEmpty)
            }

            HStack(spacing: 8) {
                TextField("6 位数字", text: $code)
                    .keyboardType(.numberPad)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .frame(width: 130)
                    .padding(.vertical, 9)
                    .background(Theme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onChange(of: code) { _, value in
                        code = String(value.filter(\.isNumber).prefix(6))
                    }
                Button {
                    pair()
                } label: {
                    HStack(spacing: 5) {
                        if busy { ProgressView().tint(.white).scaleEffect(0.7) }
                        Text(token.isEmpty ? "配对" : "重新配对")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(code.count == 6 ? AnyShapeStyle(Theme.mintGradient) : AnyShapeStyle(Theme.muted))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(code.count != 6 || busy)
                Spacer()
            }

            HStack(spacing: 8) {
                Button {
                    code = String(format: "%06d", Int.random(in: 0...999999))
                    savedCode = code
                    app.flash("已生成配对码，可在另一台设备输入")
                } label: {
                    Label("生成配对码", systemImage: "number")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accentDark)
                if !token.isEmpty {
                    Button {
                        UIPasteboard.general.string = token
                        app.flash("同步 token 已复制")
                    } label: {
                        Label("复制 token", systemImage: "doc.on.doc")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accentDark)
                }
            }
        }
        .card()
    }

    private var actionsCard: some View {
        VStack(spacing: 0) {
            syncAction("推送剪贴板", "把本机历史发送到后端", "arrow.up.circle") {
                pushClipboard()
            }
            Divider()
            syncAction("拉取剪贴板", "读取同一 token 的远端历史", "arrow.down.circle") {
                pullClipboard()
            }
            Divider()
            syncAction("同步常用语", "推送自定义常用语", "text.bubble") {
                pushPhrases()
            }
            Divider()
            syncAction("推送设置", "同步模糊拼音、工具栏与显示偏好", "gearshape.2") {
                pushSettings()
            }
            Divider()
            syncAction("拉取设置", "应用同一 token 的远端设置", "arrow.down.to.line") {
                pullSettings()
            }
        }
        .card(padding: 14)
    }

    private func syncAction(_ title: String, _ subtitle: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SettingIcon(symbol: symbol)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }

    private var remoteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("远端剪贴板")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text)
            ForEach(Array(remote.enumerated()), id: \.offset) { _, item in
                HStack {
                    Text(item.text)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = item.text
                        SharedStore.addToClipboard(item.text)
                        app.flash("已复制并加入本机历史")
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accentDark)
                }
                .padding(8)
                .background(Theme.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .card(padding: 14)
    }

    private func guardOnline() -> Bool {
        if SharedStore.bool(SharedKeys.standalone) {
            status = "单机模式已开启，同步请求被阻止。请到单机模式页关闭后再试。"
            return false
        }
        return true
    }

    private func pair() {
        guard guardOnline() else { return }
        busy = true
        status = nil
        Task {
            do {
                let response = try await APIClient.shared.pair(code: code, name: SharedStore.string(SharedKeys.syncName))
                await MainActor.run {
                    token = response.token
                    savedCode = response.code
                    peer = response.peer?.name ?? "未发现对端"
                    busy = false
                    status = "配对成功。设备 token 已保存；peer：\(peer)。"
                    app.flash("配对成功")
                }
            } catch {
                await MainActor.run {
                    busy = false
                    status = "配对失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func pushClipboard() {
        guard guardOnline() else { return }
        let texts = SharedStore.clipboard.map(\.text)
        guard !texts.isEmpty else { status = "本机剪贴板历史为空。"; return }
        Task {
            do {
                let items = try await APIClient.shared.pushClipboard(token: token, texts: texts)
                await MainActor.run {
                    remote = items
                    status = "已推送 \(texts.count) 条剪贴板文本。"
                }
            } catch {
                await MainActor.run { status = "推送失败：\(error.localizedDescription)" }
            }
        }
    }

    private func pullClipboard() {
        guard guardOnline() else { return }
        Task {
            do {
                let items = try await APIClient.shared.fetchClipboard(token: token)
                await MainActor.run {
                    remote = items
                    for item in items.reversed() { SharedStore.addToClipboard(item.text) }
                    status = "拉取到 \(items.count) 条远端文本，已合并到本机历史。"
                }
            } catch {
                await MainActor.run { status = "拉取失败：\(error.localizedDescription)" }
            }
        }
    }

    private func pushPhrases() {
        guard guardOnline() else { return }
        let phrases = SharedStore.customPhrases
        guard !phrases.isEmpty else { status = "自定义常用语为空，请先在常用语页添加。"; return }
        Task {
            do {
                let items = try await APIClient.shared.pushPhrases(token: token, phrases: phrases)
                await MainActor.run { status = "已同步 \(items.count) 条常用语。" }
            } catch {
                await MainActor.run { status = "常用语同步失败：\(error.localizedDescription)" }
            }
        }
    }

    private func pushSettings() {
        guard guardOnline() else { return }
        let payload: [String: Any] = [
            "fuzzy": SharedStore.stringArray(SharedKeys.fuzzyPairs),
            "toolbar": SharedStore.stringArray(SharedKeys.toolbar),
            "height": SharedStore.double(SharedKeys.height),
            "candidate": SharedStore.double(SharedKeys.candidateSize),
            "plus": SharedStore.bool(SharedKeys.plusEnabled),
            "voiceLanguage": SharedStore.string(SharedKeys.voiceLanguage),
        ]
        Task {
            do {
                try await APIClient.shared.pushSettings(token: token, payload: payload)
                await MainActor.run { status = "设置已推送到后端。" }
            } catch {
                await MainActor.run { status = "设置同步失败：\(error.localizedDescription)" }
            }
        }
    }

    private func pullSettings() {
        guard guardOnline() else { return }
        Task {
            do {
                let payload = try await APIClient.shared.fetchSettings(token: token)
                await MainActor.run {
                    if let fuzzy = payload["fuzzy"] as? [String] {
                        SharedStore.setStringArray(SharedKeys.fuzzyPairs, fuzzy)
                    }
                    if let toolbar = payload["toolbar"] as? [String] {
                        SharedStore.setStringArray(SharedKeys.toolbar, toolbar)
                    }
                    if let height = payload["height"] as? Double {
                        SharedStore.set(SharedKeys.height, height)
                    }
                    if let candidate = payload["candidate"] as? Double {
                        SharedStore.set(SharedKeys.candidateSize, candidate)
                    }
                    if let plus = payload["plus"] as? Bool {
                        app.setPlus(plus)
                    }
                    if let language = payload["voiceLanguage"] as? String {
                        SharedStore.set(SharedKeys.voiceLanguage, language)
                    }
                    status = payload.isEmpty ? "远端没有保存设置。" : "已拉取并应用远端设置。"
                    app.flash(payload.isEmpty ? "远端没有设置" : "远端设置已应用")
                }
            } catch {
                await MainActor.run { status = "拉取设置失败：\(error.localizedDescription)" }
            }
        }
    }
}

// MARK: - Migration

struct MigrationView: View {
    @EnvironmentObject private var app: AppModel
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var document: SettingsBackupDocument?
    @State private var result: String?
    @AppStorage(SharedKeys.syncCode, store: SharedStore.defaults) private var code = ""

    var body: some View {
        PageShell(title: "换机助手", subtitle: "导出、导入与配对，不依赖私有云") {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Theme.accentDark)
                        Text("迁移说明")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.text)
                    }
                    Text("导出会生成一个 JSON 文件，包含显示偏好、语音语言、模糊拼音、工具栏、拼写 Plus 与配对码。不会导出录音、AI 对话或剪贴板内容。新设备导入后立即生效。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .card()

                VStack(spacing: 0) {
                    actionRow("导出设置", "生成可分享的 JSON 备份", "square.and.arrow.up") {
                        document = SettingsBackupDocument(data: backupData())
                        showExporter = true
                    }
                    Divider()
                    actionRow("导入设置", "从文件选择器读取 JSON 备份", "square.and.arrow.down") {
                        showImporter = true
                    }
                    Divider()
                    actionRow("复制备份 JSON", "把备份文本放入系统剪贴板", "doc.on.doc") {
                        UIPasteboard.general.string = String(data: backupData(), encoding: .utf8)
                        app.flash("备份 JSON 已复制")
                    }
                    Divider()
                    actionRow("从剪贴板导入", "解析剪贴板中的备份 JSON", "doc.on.clipboard") {
                        guard let text = UIPasteboard.general.string, let data = text.data(using: .utf8) else {
                            result = "系统剪贴板没有可解析的文本。"
                            return
                        }
                        apply(data)
                    }
                }
                .card(padding: 14)

                VStack(spacing: 0) {
                    SettingsRow(icon: "number", title: "当前配对码", value: code.isEmpty ? "未生成" : code)
                    Divider()
                    NavigationLink(value: Route.sync) {
                        SettingsRow(icon: "arrow.triangle.2.circlepath", title: "跨设备同步", subtitle: "配对后推送剪贴板与设置")
                    }
                    .buttonStyle(.plain)
                }
                .card(padding: 14)

                if let result {
                    InfoBanner(text: result, symbol: "info.circle", tint: result.contains("失败") ? Theme.warning : Theme.accentDark)
                }

                InfoBanner(text: "iOS 没有第三方输入法可用的系统级“一键换机”接口；这里用文件与剪贴板完成可复核的显式迁移。")
            }
        }
        .fileExporter(isPresented: $showExporter, document: document, contentType: .json,
                      defaultFilename: "wetype-settings-backup") { response in
            switch response {
            case .success: result = "设置备份已导出。"
            case .failure(let error): result = "导出失败：\(error.localizedDescription)"
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { response in
            switch response {
            case .success(let url):
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    apply(data)
                } else {
                    result = "无法读取所选文件。"
                }
            case .failure(let error):
                result = "导入失败：\(error.localizedDescription)"
            }
        }
    }

    private func actionRow(_ title: String, _ subtitle: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SettingIcon(symbol: symbol)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }

    private func backupData() -> Data {
        let payload: [String: Any] = [
            "schema": 1,
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "fuzzy": SharedStore.stringArray(SharedKeys.fuzzyPairs),
            "toolbar": SharedStore.stringArray(SharedKeys.toolbar),
            "height": SharedStore.double(SharedKeys.height),
            "candidate": SharedStore.double(SharedKeys.candidateSize),
            "theme": SharedStore.string(SharedKeys.theme),
            "darkMode": SharedStore.string(SharedKeys.darkMode),
            "pinyinPosition": SharedStore.string(SharedKeys.pinyinPosition),
            "voiceLanguage": SharedStore.string(SharedKeys.voiceLanguage),
            "voiceRelease": SharedStore.string(SharedKeys.voiceRelease),
            "plus": SharedStore.bool(SharedKeys.plusEnabled),
            "syncCode": SharedStore.string(SharedKeys.syncCode),
            "apiBase": SharedStore.string(SharedKeys.apiBase),
        ]
        return (try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])) ?? Data()
    }

    private func apply(_ data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            result = "导入失败：JSON 格式不正确。"
            return
        }
        var applied = 0
        if let fuzzy = object["fuzzy"] as? [String] {
            SharedStore.setStringArray(SharedKeys.fuzzyPairs, fuzzy); applied += 1
        }
        if let toolbar = object["toolbar"] as? [String] {
            SharedStore.setStringArray(SharedKeys.toolbar, toolbar); applied += 1
        }
        if let height = object["height"] as? Double {
            SharedStore.set(SharedKeys.height, height); applied += 1
        }
        if let candidate = object["candidate"] as? Double {
            SharedStore.set(SharedKeys.candidateSize, candidate); applied += 1
        }
        for (jsonKey, sharedKey) in [("theme", SharedKeys.theme), ("darkMode", SharedKeys.darkMode),
                                     ("pinyinPosition", SharedKeys.pinyinPosition),
                                     ("voiceLanguage", SharedKeys.voiceLanguage),
                                     ("voiceRelease", SharedKeys.voiceRelease),
                                     ("syncCode", SharedKeys.syncCode),
                                     ("apiBase", SharedKeys.apiBase)] {
            if let value = object[jsonKey] as? String {
                SharedStore.set(sharedKey, value); applied += 1
            }
        }
        if let plus = object["plus"] as? Bool {
            app.setPlus(plus); applied += 1
        }
        result = applied == 0 ? "没有识别到可导入的设置。" : "已导入 \(applied) 项设置。"
        app.flash(result ?? "")
    }
}

struct SettingsBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Help & feedback

struct FeedbackEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var category: String
    var text: String
    var contact: String
    var date: Date = Date()
}

struct HelpView: View {
    @EnvironmentObject private var app: AppModel
    @AppStorage(SharedKeys.apiBase, store: SharedStore.defaults) private var apiBase = SharedKeys.defaultBaseURL
    @State private var baseDraft = SharedStore.apiBaseURL
    @State private var category = "键盘启用"
    @State private var feedback = ""
    @State private var contact = ""
    @State private var entries: [FeedbackEntry] = SharedStore.codable(SharedKeys.feedbackHistory, fallback: [FeedbackEntry]())
    @State private var diagnosis: String?

    private let faqs: [(String, String)] = [
        ("如何在系统里启用微输入法键盘？", "打开“设置 → 通用 → 键盘 → 键盘 → 添加新键盘”，选择“微输入法”。然后在输入框长按地球键切换。首次使用建议允许完全访问，以便语音、AI 与共享剪贴板工作。"),
        ("为什么键盘里 AI/语音提示需要完全访问？", "iOS 限制第三方键盘的网络与麦克风访问。没有完全访问时，基础输入、候选、表情、数字与符号仍然可用；AI 与语音会显示真实错误，不会伪造输出。"),
        ("拼音候选是怎么来的？", "随包 SQLite 词库包含 26,703 个单字、46,111 条词组与短语、32,125 条五笔编码与 6,245 条笔画编码。九宫格按 2–9 数字映射，双拼使用小鹤方案，模糊拼音按你开启的组生成有限变体。"),
        ("问 AI 返回错误怎么办？", "在设置里确认 API 地址（模拟器默认 http://127.0.0.1:8787），点击“测试后端”。错误会原样显示并提供重试；如果后端未启动，不会显示假答案。"),
        ("手写识别支持多少字？", "内置 20 个简单汉字的方向模板匹配：一二十人大 小口日中上下山木火水手心女田。它不是完整手写模型，页面上已明确标注。"),
        ("配对码同步为什么看不到另一台设备的数据？", "后端 /v1/sync/* 按设备 token 隔离。配对会返回 peer 信息，但不会返回 peer token；本复刻版实现了配对、推送、拉取与设置同步，跨 token 共享需要后端扩展。"),
        ("模拟器里语音识别不可用？", "SFSpeechRecognizer 在模拟器上可能没有可用识别器。App 会显示“当前设备暂不可用”的真实错误。请使用真机，或改为文字输入。"),
        ("如何迁移到新设备？", "在换机助手中导出 JSON 备份，在新设备用文件选择器或剪贴板导入。录音、AI 对话和剪贴板不会随备份导出。"),
    ]

    var body: some View {
        PageShell(title: "帮助与反馈", subtitle: "常见问题、诊断与本地反馈") {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(faqs.enumerated()), id: \.offset) { index, faq in
                        DisclosureGroup {
                            Text(faq.1)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.top, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } label: {
                            Text(faq.0)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.text)
                                .multilineTextAlignment(.leading)
                        }
                        .tint(Theme.accentDark)
                        .padding(.vertical, 9)
                        if index < faqs.count - 1 { Divider() }
                    }
                }
                .card(padding: 14)

                VStack(alignment: .leading, spacing: 10) {
                    Text("反馈")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Picker("分类", selection: $category) {
                        ForEach(["键盘启用", "候选词库", "AI 功能", "语音", "同步/传送", "界面", "其他"], id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.accentDark)

                    TextField("描述你遇到的问题", text: $feedback, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.system(size: 13))
                        .padding(9)
                        .background(Theme.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    TextField("联系方式（可选）", text: $contact)
                        .font(.system(size: 12))
                        .padding(9)
                        .background(Theme.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 9))

                    HStack(spacing: 8) {
                        SecondaryButton(title: "保存反馈", symbol: "tray.and.arrow.down") {
                            saveFeedback()
                        }
                        SecondaryButton(title: "用邮件发送", symbol: "envelope") {
                            sendMail()
                        }
                        SecondaryButton(title: "复制", symbol: "doc.on.doc") {
                            UIPasteboard.general.string = feedbackText
                            app.flash("反馈内容已复制")
                        }
                    }
                }
                .card()

                if !entries.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("本机反馈记录")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            Spacer()
                            Button("清空") {
                                entries = []
                                SharedStore.setCodable(SharedKeys.feedbackHistory, entries)
                            }
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.danger)
                        }
                        ForEach(entries) { entry in
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(entry.category) · \(entry.date.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.muted)
                                Text(entry.text)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.text)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.surfaceAlt)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .card(padding: 14)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("诊断")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Spacer()
                        StatusPill(text: app.backendStatus.label, ok: app.backendStatus.ok)
                    }
                    TextField("后端地址，例如 http://127.0.0.1:8787", text: $baseDraft)
                        .font(.system(size: 11, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(8)
                        .background(Theme.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    HStack(spacing: 8) {
                        SecondaryButton(title: "保存地址", symbol: "checkmark") {
                            let trimmed = baseDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            apiBase = trimmed.isEmpty ? SharedKeys.defaultBaseURL : trimmed
                            baseDraft = apiBase
                            app.flash("API 地址已保存")
                        }
                        SecondaryButton(title: "恢复默认", symbol: "arrow.counterclockwise") {
                            apiBase = SharedKeys.defaultBaseURL
                            baseDraft = apiBase
                        }
                    }
                    Text("共享容器：\(SharedStore.appGroupAvailable ? "可用" : "不可用") · 键盘运行：\(SharedStore.bool(SharedKeys.keyboardSeen) ? "是" : "否") · 完全访问：\(SharedStore.bool(SharedKeys.keyboardFullAccess) ? "是" : "否")")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                    if let diagnosis {
                        Text(diagnosis)
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    HStack(spacing: 8) {
                        SecondaryButton(title: "测试后端", symbol: "network") {
                            Task {
                                do {
                                    let health = try await APIClient.shared.health()
                                    diagnosis = "后端在线：\(health.model)，ASR \(health.asr ?? "device")，密钥配置 \(health.key?.configured == true ? "是" : "否")。"
                                } catch {
                                    diagnosis = "后端错误：\(error.localizedDescription)"
                                }
                            }
                        }
                        SecondaryButton(title: "复制诊断", symbol: "doc.on.doc") {
                            UIPasteboard.general.string = diagnostics
                            app.flash("诊断信息已复制")
                        }
                    }
                }
                .card()
            }
        }
    }

    private var feedbackText: String {
        "【微输入法反馈】\n分类：\(category)\n内容：\(feedback)\n联系方式：\(contact)\n\(diagnostics)"
    }

    private var diagnostics: String {
        """
        版本 1.0.0
        设备 \(UIDevice.current.model) · iOS \(UIDevice.current.systemVersion)
        API \(SharedStore.apiBaseURL)
        后端 \(app.backendStatus.label)
        App Group \(SharedStore.appGroupAvailable)
        键盘运行 \(SharedStore.bool(SharedKeys.keyboardSeen))
        完全访问 \(SharedStore.bool(SharedKeys.keyboardFullAccess))
        """
    }

    private func saveFeedback() {
        guard !feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            app.flash("请先填写反馈内容")
            return
        }
        entries.insert(FeedbackEntry(category: category, text: feedback, contact: contact), at: 0)
        entries = Array(entries.prefix(50))
        SharedStore.setCodable(SharedKeys.feedbackHistory, entries)
        feedback = ""
        app.flash("反馈已保存在本机")
    }

    private func sendMail() {
        guard !feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            app.flash("请先填写反馈内容")
            return
        }
        let subject = "微输入法反馈 · \(category)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = feedbackText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:support@example.invalid?subject=\(subject)&body=\(body)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            UIPasteboard.general.string = feedbackText
            app.flash("没有可用邮件客户端，反馈已复制")
        }
    }
}
