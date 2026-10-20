import SwiftUI
import Combine

enum Route: String, CaseIterable, Hashable, Identifiable {
    case home
    case onboarding
    case keyboard
    case keyboardManage
    case display
    case keystroke
    case toolbar
    case auxiliary
    case fuzzy
    case voice
    case voiceLanguage
    case voicePunctuation
    case plus
    case clipboard
    case sync
    case migration
    case standalone
    case privacy
    case desktop
    case about
    case help
    case recorder
    case recorderSession
    case transfer
    case aiChat
    case textTools
    case translate
    case poster
    case phrases
    case emoji

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "首页"
        case .onboarding: return "启用与隐私"
        case .keyboard: return "键盘体验"
        case .keyboardManage: return "键盘管理"
        case .display: return "布局和显示"
        case .keystroke: return "按键效果"
        case .toolbar: return "定制工具栏"
        case .auxiliary: return "辅助输入"
        case .fuzzy: return "模糊拼音"
        case .voice: return "语音转文字"
        case .voiceLanguage: return "识别语言"
        case .voicePunctuation: return "标点设置"
        case .plus: return "拼写 Plus"
        case .clipboard: return "剪贴板"
        case .sync: return "跨设备粘贴同步"
        case .migration: return "换机助手"
        case .standalone: return "单机模式"
        case .privacy: return "隐私与权限"
        case .desktop: return "电脑版"
        case .about: return "关于"
        case .help: return "帮助与反馈"
        case .recorder: return "AI 录音笔"
        case .recorderSession: return "录音会话"
        case .transfer: return "隔空传送"
        case .aiChat: return "问 AI"
        case .textTools: return "文字工具"
        case .translate: return "边写边译"
        case .poster: return "排版成图"
        case .phrases: return "常用语"
        case .emoji: return "表情"
        }
    }

    var group: String {
        switch self {
        case .home, .onboarding: return "入口"
        case .keyboard, .keyboardManage: return "键盘"
        case .display, .keystroke, .toolbar, .auxiliary, .fuzzy, .voice,
             .voiceLanguage, .voicePunctuation, .clipboard, .standalone, .privacy:
            return "设置"
        case .plus: return "智能"
        case .sync, .migration: return "跨设备"
        case .desktop, .about, .help: return "更多"
        case .recorder, .recorderSession, .transfer, .aiChat, .textTools,
             .translate, .poster, .phrases, .emoji:
            return "功能"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .onboarding: return "checkmark.shield"
        case .keyboard: return "keyboard"
        case .keyboardManage: return "square.grid.3x3.fill"
        case .display: return "rectangle.3.group"
        case .keystroke: return "hand.tap"
        case .toolbar: return "wrench.and.screwdriver"
        case .auxiliary: return "text.cursor"
        case .fuzzy: return "character.bubble"
        case .voice: return "mic.fill"
        case .voiceLanguage: return "globe"
        case .voicePunctuation: return "textformat"
        case .plus: return "sparkles"
        case .clipboard: return "doc.on.clipboard"
        case .sync: return "arrow.triangle.2.circlepath"
        case .migration: return "arrow.left.arrow.right"
        case .standalone: return "externaldrive"
        case .privacy: return "lock.shield"
        case .desktop: return "desktopcomputer"
        case .about: return "info.circle"
        case .help: return "questionmark.bubble"
        case .recorder: return "waveform"
        case .recorderSession: return "doc.text"
        case .transfer: return "paperplane"
        case .aiChat: return "bubble.left.and.bubble.right"
        case .textTools: return "wand.and.stars"
        case .translate: return "character.book.closed"
        case .poster: return "photo.on.rectangle"
        case .phrases: return "text.bubble"
        case .emoji: return "face.smiling"
        }
    }
}

enum BackendStatus: Equatable {
    case unknown
    case checking
    case online(String)
    case offline(String)

    var label: String {
        switch self {
        case .unknown: return "未检查"
        case .checking: return "检查中"
        case .online(let model): return "在线 · \(model)"
        case .offline: return "离线"
        }
    }

    var ok: Bool {
        if case .online = self { return true }
        return false
    }

    var detail: String {
        switch self {
        case .unknown: return "尚未连接后端"
        case .checking: return "正在连接后端…"
        case .online(let model): return "后端在线，模型 \(model)"
        case .offline(let message): return message
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var showOnboarding: Bool = !SharedStore.bool(SharedKeys.onboardingAccepted)
    @Published var toast: String?
    @Published var backendStatus: BackendStatus = .unknown
    @Published var plusEnabled: Bool = SharedStore.bool(SharedKeys.plusEnabled)
    @Published var standalone: Bool = SharedStore.bool(SharedKeys.standalone)
    @Published var keyboardSeen: Bool = SharedStore.bool(SharedKeys.keyboardSeen)
    @Published var pendingRoute: Route?
    @Published var path = NavigationPath()

    private var toastTask: Task<Void, Never>?

    init() {
        if let routeID = UserDefaults.standard.string(forKey: "uitest.route"),
           let route = Route(rawValue: routeID) {
            pendingRoute = route
        }
    }

    func flash(_ message: String) {
        toastTask?.cancel()
        withAnimation { toast = message }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if !Task.isCancelled {
                await MainActor.run { withAnimation { self.toast = nil } }
            }
        }
    }

    func acceptOnboarding() {
        SharedStore.set(SharedKeys.onboardingAccepted, true)
        showOnboarding = false
    }

    func setPlus(_ enabled: Bool) {
        plusEnabled = enabled
        SharedStore.set(SharedKeys.plusEnabled, enabled)
    }

    func setStandalone(_ enabled: Bool) {
        standalone = enabled
        SharedStore.set(SharedKeys.standalone, enabled)
        if enabled {
            flash("单机模式已开启：AI 与同步请求会先提示离线")
        }
    }

    func refreshStatus() async {
        backendStatus = .checking
        do {
            let health = try await APIClient.shared.health()
            keyboardSeen = SharedStore.bool(SharedKeys.keyboardSeen)
            backendStatus = health.ok ? .online(health.model) : .offline("服务未就绪")
        } catch {
            backendStatus = .offline(error.localizedDescription)
        }
    }

    func open(_ route: Route) {
        if case .home = route {
            path = NavigationPath()
        } else {
            path.append(route)
        }
    }

    func handle(url: URL) {
        guard url.scheme == "wetype" else { return }
        let key = (url.host ?? url.path.replacingOccurrences(of: "/", with: ""))
        if key == "route" {
            let identifier = url.path.replacingOccurrences(of: "/", with: "")
            if let route = Route(rawValue: identifier) {
                pendingRoute = route
            }
            return
        }
        if let route = Route(rawValue: key) {
            pendingRoute = route
            return
        }
        switch key {
        case "keyboard", "keyboardSetting": pendingRoute = .keyboard
        case "voiceRecorder", "recorder": pendingRoute = .recorder
        case "launchFileTransfer", "transfer": pendingRoute = .transfer
        case "aiChat", "ai": pendingRoute = .aiChat
        case "mainSetting", "home": pendingRoute = .home
        case "privacy": pendingRoute = .privacy
        default: break
        }
    }
}
