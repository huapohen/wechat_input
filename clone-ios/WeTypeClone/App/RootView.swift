import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var sidebar: Route? = .home

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && sizeClass == .regular
    }

    var body: some View {
        Group {
            if isPad {
                splitView
            } else {
                phoneView
            }
        }
        .tint(Theme.accentDark)
        .overlay(alignment: .bottom) {
            if let toast = app.toast {
                ToastView(message: toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $app.showOnboarding) {
            NavigationStack {
                OnboardingView(isFirstRun: true)
                    .navigationDestination(for: Route.self) { route in
                        RouteView(route: route)
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("稍后") { app.showOnboarding = false }
                        }
                    }
            }
            .interactiveDismissDisabled(false)
        }
        .task {
            await app.refreshStatus()
            app.keyboardSeen = SharedStore.bool(SharedKeys.keyboardSeen)
            if let route = app.pendingRoute {
                app.open(route)
                app.pendingRoute = nil
            }
        }
        .onOpenURL { app.handle(url: $0) }
        .onChange(of: app.pendingRoute) { _, route in
            guard let route else { return }
            app.open(route)
            app.pendingRoute = nil
        }
    }

    private var phoneView: some View {
        NavigationStack(path: $app.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    RouteView(route: route)
                }
        }
    }

    private var splitView: some View {
        NavigationSplitView {
            List(selection: $sidebar) {
                Section("微输入法") {
                    sidebarRow(.home)
                    sidebarRow(.onboarding)
                }
                Section("键盘") {
                    sidebarRow(.keyboard)
                    sidebarRow(.keyboardManage)
                }
                Section("功能") {
                    sidebarRow(.recorder)
                    sidebarRow(.transfer)
                    sidebarRow(.aiChat)
                    sidebarRow(.textTools)
                    sidebarRow(.translate)
                    sidebarRow(.poster)
                    sidebarRow(.phrases)
                    sidebarRow(.emoji)
                }
                Section("设置") {
                    sidebarRow(.display)
                    sidebarRow(.keystroke)
                    sidebarRow(.toolbar)
                    sidebarRow(.auxiliary)
                    sidebarRow(.fuzzy)
                    sidebarRow(.voice)
                    sidebarRow(.plus)
                    sidebarRow(.clipboard)
                    sidebarRow(.sync)
                    sidebarRow(.migration)
                    sidebarRow(.standalone)
                    sidebarRow(.privacy)
                }
                Section("更多") {
                    sidebarRow(.desktop)
                    sidebarRow(.about)
                    sidebarRow(.help)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("微输入法")
            .scrollContentBackground(.hidden)
            .background(Theme.background)
        } detail: {
            NavigationStack(path: $app.path) {
                RouteView(route: sidebar ?? .home)
                    .navigationDestination(for: Route.self) { route in
                        RouteView(route: route)
                    }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private func sidebarRow(_ route: Route) -> some View {
        Label(route.title, systemImage: route.symbol)
            .tag(route)
    }
}

struct RouteView: View {
    let route: Route

    var body: some View {
        switch route {
        case .home:
            HomeView()
        case .onboarding:
            OnboardingView(isFirstRun: false)
        case .keyboard:
            KeyboardExperienceView()
        case .keyboardManage:
            KeyboardManageView()
        case .display:
            DisplaySettingsView()
        case .keystroke:
            KeystrokeSettingsView()
        case .toolbar:
            ToolbarSettingsView()
        case .auxiliary:
            AuxiliaryInputView()
        case .fuzzy:
            FuzzyPinyinView()
        case .voice:
            VoiceSettingsView()
        case .voiceLanguage:
            VoiceLanguageView()
        case .voicePunctuation:
            VoicePunctuationView()
        case .plus:
            PlusSettingsView()
        case .clipboard:
            ClipboardView()
        case .sync:
            SyncView()
        case .migration:
            MigrationView()
        case .standalone:
            StandaloneView()
        case .privacy:
            PrivacyView()
        case .desktop:
            DesktopView()
        case .about:
            AboutView()
        case .help:
            HelpView()
        case .recorder:
            RecorderView()
        case .recorderSession:
            RecorderSessionRouteView()
        case .transfer:
            TransferView()
        case .aiChat:
            AIChatView()
        case .textTools:
            TextToolsView()
        case .translate:
            TranslateView()
        case .poster:
            PosterView()
        case .phrases:
            PhrasesView()
        case .emoji:
            EmojiView()
        }
    }
}
