import SwiftUI
import UIKit
import Photos
import UniformTypeIdentifiers

// MARK: - Continuous translation

struct TranslateView: View {
    @EnvironmentObject private var app: AppModel
    @State private var source = ""
    @State private var translated = ""
    @State private var sourceLang = "中文"
    @State private var targetLang = "英文"
    @State private var autoTranslate = true
    @State private var running = false
    @State private var error: String?
    @State private var debounceTask: Task<Void, Never>?
    @State private var turns: [TranslationTurn] = []

    private let languages = ["中文", "英文", "日文"]

    var body: some View {
        PageShell(title: "边写边译", subtitle: "输入停顿后自动翻译，发送后清空本轮") {
            VStack(spacing: 13) {
                HStack(spacing: 8) {
                    Picker("源语言", selection: $sourceLang) {
                        ForEach(languages, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.accentDark)
                    Button {
                        swap()
                    } label: {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.accentDark)
                            .frame(width: 34, height: 30)
                            .background(Theme.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    Picker("目标语言", selection: $targetLang) {
                        ForEach(languages, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.accentDark)
                    Spacer()
                    Toggle("自动", isOn: $autoTranslate)
                        .labelsHidden()
                        .tint(Theme.accent)
                }
                .padding(10)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 11))

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("原文")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text("\(source.count) 字")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Theme.muted)
                    }
                    TextField("输入一句话，停顿后自动翻译…", text: $source, axis: .vertical)
                        .lineLimit(3...8)
                        .font(.system(size: 15))
                        .padding(11)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("译文 · \(targetLang)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        if running { ProgressView().scaleEffect(0.7) }
                    }
                    ScrollView {
                        Text(translated.isEmpty ? "译文会显示在这里。" : translated)
                            .font(.system(size: 15))
                            .foregroundStyle(translated.isEmpty ? Theme.textSecondary : Theme.text)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(11)
                    }
                    .frame(minHeight: 90, maxHeight: 200)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                }

                HStack(spacing: 8) {
                    SecondaryButton(title: "立即翻译", symbol: "character.book.closed") {
                        requestTranslation()
                    }
                    SecondaryButton(title: "发送到剪贴板", symbol: "paperplane") {
                        guard !translated.isEmpty else { return }
                        UIPasteboard.general.string = translated
                        turns.insert(TranslationTurn(source: source, target: translated), at: 0)
                        source = ""
                        translated = ""
                        app.flash("译文已发送到剪贴板，本轮已清空")
                    }
                    SecondaryButton(title: "复制译文", symbol: "doc.on.doc") {
                        UIPasteboard.general.string = translated
                        app.flash("译文已复制")
                    }
                    Spacer()
                }

                if let error {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.danger)
                        SecondaryButton(title: "重试", symbol: "arrow.clockwise") { requestTranslation() }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Theme.danger.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if !turns.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("本轮历史")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            Spacer()
                            Button("清空") { turns = [] }
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.danger)
                        }
                        ForEach(turns) { turn in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(turn.source)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(2)
                                Text(turn.target)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.text)
                                    .lineLimit(2)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.surfaceAlt)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .card(padding: 12)
                }

                InfoBanner(text: "自动翻译在停止输入 700ms 后触发；请求失败会保留原文并显示真实错误。翻译请求发送到 \(SharedStore.apiBaseURL)。")
            }
        }
        .onChange(of: source) { _, _ in schedule() }
        .onChange(of: targetLang) { _, _ in schedule() }
        .onChange(of: sourceLang) { _, _ in schedule() }
        .onDisappear { debounceTask?.cancel() }
    }

    private func schedule() {
        debounceTask?.cancel()
        guard autoTranslate else { return }
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            translated = ""
            error = nil
            return
        }
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            if Task.isCancelled { return }
            await translate(text)
        }
    }

    private func requestTranslation() {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        Task { await translate(text) }
    }

    private func translate(_ text: String) async {
        if SharedStore.bool(SharedKeys.standalone) {
            await MainActor.run { error = "单机模式已开启，翻译请求被阻止。" }
            return
        }
        await MainActor.run { running = true; error = nil }
        do {
            let value = try await APIClient.shared.translate(text, source: code(sourceLang), target: code(targetLang))
            await MainActor.run {
                translated = value
                running = false
            }
        } catch {
            await MainActor.run {
                self.error = "翻译失败：\(error.localizedDescription)"
                running = false
            }
        }
    }

    private func code(_ language: String) -> String {
        switch language {
        case "中文": return "zh"
        case "英文": return "en"
        case "日文": return "ja"
        default: return "zh"
        }
    }

    private func swap() {
        let oldSource = source
        source = translated
        translated = oldSource
        let oldLang = sourceLang
        sourceLang = targetLang
        targetLang = oldLang
    }
}

// MARK: - Poster

enum PosterTemplate: String, CaseIterable, Identifiable {
    case mint = "薄荷"
    case sunset = "晚霞"
    case ink = "墨黑"
    case ocean = "海盐"

    var id: String { rawValue }

    var colors: [Color] {
        switch self {
        case .mint: return [Color(hex: "0E8A68"), Color(hex: "2ED6A1")]
        case .sunset: return [Color(hex: "C05A3E"), Color(hex: "F0B86E")]
        case .ink: return [Color(hex: "1B2422"), Color(hex: "3A4A46")]
        case .ocean: return [Color(hex: "1B5E6B"), Color(hex: "66B6C6")]
        }
    }

    var textColor: Color {
        self == .sunset ? Color(hex: "2E211B") : .white
    }
}

struct PosterView: View {
    @EnvironmentObject private var app: AppModel
    @State private var text = "保持热爱，奔赴山海。\n把每一次输入，都变成表达。"
    @State private var template: PosterTemplate = .mint
    @State private var fontSize = 56.0
    @State private var showMark = true
    @State private var rendered: UIImage?
    @State private var showShare = false
    @State private var error: String?

    var body: some View {
        PageShell(title: "排版成图", subtitle: "把一段话排成 3:4 可分享海报") {
            VStack(spacing: 14) {
                ZStack {
                    PosterCanvas(text: text, template: template, fontSize: fontSize * 0.34, showMark: showMark)
                        .aspectRatio(3.0 / 4.0, contentMode: .fit)
                        .frame(maxWidth: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Color.black.opacity(0.15), radius: 16, y: 8)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    Text("文案")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    TextField("输入要排版的文字…", text: $text, axis: .vertical)
                        .lineLimit(3...7)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                VStack(spacing: 0) {
                    HStack {
                        Text("模板")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.text)
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach(PosterTemplate.allCases) { item in
                                Button {
                                    template = item
                                } label: {
                                    Circle()
                                        .fill(LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 24, height: 24)
                                        .overlay(Circle().stroke(template == item ? Theme.text : Color.clear, lineWidth: 2))
                                        .overlay(Circle().stroke(Color.white, lineWidth: 1).padding(2))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 9)
                    Divider()
                    HStack {
                        Text("字号")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.text)
                        Slider(value: $fontSize, in: 34...88, step: 2)
                            .tint(Theme.accent)
                        Text("\(Int(fontSize))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 26)
                    }
                    .padding(.vertical, 9)
                    Divider()
                    ToggleRow(title: "显示页脚", subtitle: "微输入法 · 排版成图", isOn: $showMark)
                }
                .card(padding: 14)

                HStack(spacing: 9) {
                    SecondaryButton(title: "示例文案", symbol: "text.quote") {
                        text = ["保持热爱，奔赴山海。\n把每一次输入，都变成表达。",
                                "慢慢来，比较快。\n今天也要好好说话。",
                                "所有的不期而遇，\n都是蓄谋已久的惊喜。"].randomElement() ?? ""
                    }
                    SecondaryButton(title: "生成图片", symbol: "photo.badge.arrow.down") {
                        render()
                    }
                    if rendered != nil {
                        SecondaryButton(title: "分享", symbol: "square.and.arrow.up") {
                            showShare = true
                        }
                        SecondaryButton(title: "保存相册", symbol: "square.and.arrow.down") {
                            saveToPhotos()
                        }
                    }
                    Spacer()
                }

                if let error {
                    InfoBanner(text: error, symbol: "exclamationmark.triangle", tint: Theme.warning)
                }

                if let rendered {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("已生成 \(Int(rendered.size.width)) × \(Int(rendered.size.height)) 图片")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textSecondary)
                        Image(uiImage: rendered)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: 12)
                }

                InfoBanner(text: "渲染使用 SwiftUI ImageRenderer，在本机生成 1080×1440 PNG；保存相册需要“添加照片”权限，拒绝时会显示错误。")
            }
        }
        .sheet(isPresented: $showShare) {
            if let rendered {
                ShareSheet(items: [rendered])
            }
        }
    }

    private func render() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = "请先输入文案。"
            return
        }
        error = nil
        let canvas = PosterCanvas(text: trimmed, template: template, fontSize: fontSize, showMark: showMark)
            .frame(width: 1080, height: 1440)
        let renderer = ImageRenderer(content: canvas)
        renderer.scale = 1
        if let image = renderer.uiImage {
            rendered = image
            app.flash("海报已生成")
        } else {
            error = "图片渲染失败，请调整文案后重试。"
        }
    }

    private func saveToPhotos() {
        guard let rendered else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in error = "相册权限未开启，请到系统设置允许“添加照片”。" }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: rendered)
            } completionHandler: { success, saveError in
                Task { @MainActor in
                    if success {
                        app.flash("已保存到相册")
                    } else {
                        error = "保存失败：\(saveError?.localizedDescription ?? "未知错误")"
                    }
                }
            }
        }
    }
}

struct PosterCanvas: View {
    let text: String
    let template: PosterTemplate
    let fontSize: Double
    let showMark: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: template.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(Color.white.opacity(0.09))
                .frame(width: 420, height: 420)
                .offset(x: 220, y: -240)
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 260, height: 260)
                .offset(x: -180, y: 280)
            VStack(alignment: .leading, spacing: 0) {
                Text("“")
                    .font(.system(size: fontSize * 1.7, weight: .regular, design: .serif))
                    .foregroundStyle(template.textColor.opacity(0.5))
                    .frame(height: fontSize * 1.2)
                Text(text)
                    .font(.system(size: fontSize, weight: .semibold, design: .serif))
                    .foregroundStyle(template.textColor)
                    .lineSpacing(fontSize * 0.25)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                if showMark {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(template.textColor.opacity(0.9))
                            .frame(width: 18, height: 18)
                            .overlay(Text("微").font(.system(size: 10, weight: .bold)).foregroundStyle(template.colors.first ?? .black))
                        Text("微输入法 · 排版成图")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(template.textColor.opacity(0.8))
                    }
                }
            }
            .padding(48)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
