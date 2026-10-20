import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct TransferView: View {
    @EnvironmentObject private var app: AppModel
    @AppStorage(SharedKeys.syncToken, store: SharedStore.defaults) private var token = ""
    @State private var files: [TransferFile] = []
    @State private var selectedURL: URL?
    @State private var showPicker = false
    @State private var uploading = false
    @State private var progress = 0.0
    @State private var error: String?
    @State private var status: String?
    @State private var downloaded: URL?
    @State private var showShare = false
    @State private var loadingList = false

    var body: some View {
        PageShell(title: "隔空传送", subtitle: "文件上传、列表、下载与分享") {
            VStack(spacing: 14) {
                uploadCard
                if uploading { progressCard }
                if let error { errorCard(error) }
                if let status { InfoBanner(text: status, symbol: "checkmark.circle", tint: Theme.accentDark) }
                fileList
                InfoBanner(text: "上传走 \(SharedStore.apiBaseURL)/v1/transfer/upload，支持最长 50MB；文件保存到后端本地目录。下载后可分享或存储到“文件”。")
            }
        }
        .fileImporter(isPresented: $showPicker, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedURL = url
                    status = "已选择 \(url.lastPathComponent)"
                    error = nil
                }
            case .failure(let error):
                self.error = "选择文件失败：\(error.localizedDescription)"
            }
        }
        .sheet(isPresented: $showShare) {
            if let downloaded {
                ShareSheet(items: [downloaded])
            }
        }
        .onAppear { refreshList() }
    }

    private var uploadCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SettingIcon(symbol: "paperplane.fill")
                VStack(alignment: .leading, spacing: 2) {
                    Text("选择文件")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("文档、图片、压缩包等任意文件")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                StatusPill(text: token.isEmpty ? "未配对" : "已配对", ok: !token.isEmpty)
            }

            if let selectedURL {
                HStack(spacing: 8) {
                    Image(systemName: iconName(for: selectedURL))
                        .foregroundStyle(Theme.accentDark)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(selectedURL.lastPathComponent)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        Text(fileSize(selectedURL))
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Button {
                        self.selectedURL = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Theme.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 8) {
                Button {
                    showPicker = true
                } label: {
                    Label(selectedURL == nil ? "选择文件" : "重新选择", systemImage: "folder")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accentDark)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(Theme.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)

                Button {
                    upload()
                } label: {
                    HStack(spacing: 5) {
                        if uploading { ProgressView().tint(.white).scaleEffect(0.7) }
                        Text(uploading ? "上传中" : "上传")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(selectedURL != nil && !uploading ? AnyShapeStyle(Theme.mintGradient) : AnyShapeStyle(Theme.muted))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .disabled(selectedURL == nil || uploading)

                Button {
                    uploadClipboardText()
                } label: {
                    Label("上传剪贴板文本", systemImage: "doc.on.clipboard")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .card()
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("上传进度")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.accentDark)
            }
            ProgressView(value: progress)
                .tint(Theme.accent)
        }
        .card(padding: 12)
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(Theme.danger)
            HStack(spacing: 8) {
                SecondaryButton(title: "重试上传", symbol: "arrow.clockwise") { upload() }
                    .disabled(selectedURL == nil)
                SecondaryButton(title: "刷新列表", symbol: "arrow.clockwise.circle") { refreshList() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.danger.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("远端文件")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                if loadingList { ProgressView().scaleEffect(0.7) }
                Button {
                    refreshList()
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.accentDark)
                }
                .buttonStyle(.plain)
            }
            if files.isEmpty {
                EmptyStateView(symbol: "tray", title: "还没有远端文件", message: "上传一个文件后，它会出现在这里。")
            } else {
                ForEach(files) { file in
                    HStack(spacing: 9) {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(Theme.accentDark)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(file.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)
                            Text("\(ByteCountFormatter.string(fromByteCount: Int64(file.size), countStyle: .file)) · \(file.id.prefix(8))…")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        if let sha = file.sha256, !sha.isEmpty {
                            Text(sha.prefix(6))
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(Theme.muted)
                        }
                        Button {
                            UIPasteboard.general.string = "\(SharedStore.apiBaseURL)/v1/transfer/\(file.id)"
                            app.flash("下载链接已复制")
                        } label: {
                            Image(systemName: "link")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.textSecondary)
                        Button {
                            download(file)
                        } label: {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 15))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.accentDark)
                    }
                    .padding(.vertical, 7)
                    if file.id != files.last?.id { Divider() }
                }
            }
        }
        .card(padding: 14)
    }

    private func upload() {
        guard let selectedURL else { return }
        guard !SharedStore.bool(SharedKeys.standalone) else {
            error = "单机模式已开启，上传请求被阻止。"
            return
        }
        uploading = true
        progress = 0
        error = nil
        status = nil
        Task {
            do {
                let file = try await APIClient.shared.upload(fileURL: selectedURL, token: token) { value in
                    Task { @MainActor in progress = value }
                }
                await MainActor.run {
                    uploading = false
                    progress = 1
                    status = "上传成功：\(file.name)，\(ByteCountFormatter.string(fromByteCount: Int64(file.size), countStyle: .file))"
                    self.selectedURL = nil
                    refreshList()
                    app.flash("文件已上传")
                }
            } catch {
                await MainActor.run {
                    uploading = false
                    self.error = "上传失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func uploadClipboardText() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            error = "系统剪贴板没有文本。"
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("clipboard-\(Int(Date().timeIntervalSince1970)).txt")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            selectedURL = url
            status = "已把剪贴板文本保存为临时文件，点击上传。"
        } catch {
            self.error = "创建临时文件失败：\(error.localizedDescription)"
        }
    }

    private func refreshList() {
        if SharedStore.bool(SharedKeys.standalone) { return }
        loadingList = true
        Task {
            do {
                let items = try await APIClient.shared.transferList(token: token)
                await MainActor.run {
                    files = items
                    loadingList = false
                }
            } catch {
                await MainActor.run {
                    loadingList = false
                    self.error = "读取文件列表失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func download(_ file: TransferFile) {
        Task {
            do {
                let url = try await APIClient.shared.download(id: file.id)
                await MainActor.run {
                    downloaded = url
                    showShare = true
                    status = "已下载 \(file.name)"
                }
            } catch {
                await MainActor.run { self.error = "下载失败：\(error.localizedDescription)" }
            }
        }
    }

    private func fileSize(_ url: URL) -> String {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    private func iconName(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if ["png", "jpg", "jpeg", "heic", "gif"].contains(ext) { return "photo" }
        if ["zip", "rar", "7z"].contains(ext) { return "archivebox" }
        if ["pdf"].contains(ext) { return "doc.richtext" }
        return "doc"
    }
}
