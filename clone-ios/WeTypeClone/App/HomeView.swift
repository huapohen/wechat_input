import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var carouselIndex = 0
    @State private var showPlusGate = false

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && sizeClass == .regular
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if !app.keyboardSeen {
                    onboardingBanner
                }
                carouselSection
                featuresSection
                settingsSection
                moreSection
                footer
            }
            .padding(.horizontal, isPad ? 30 : 16)
            .padding(.bottom, 50)
            .padding(.top, 8)
            .maxContent()
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showPlusGate) {
            PlusGateView()
                .environmentObject(app)
                .presentationDetents([.medium, .large])
        }
        .onAppear {
            app.keyboardSeen = SharedStore.bool(SharedKeys.keyboardSeen)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Theme.mintGradient)
                Text("微")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 54, height: 54)
            .shadow(color: Theme.accent.opacity(0.25), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text("微输入法")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.text)
                Text("简洁、好用、打字快")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 6)

            NavigationLink(value: Route.keyboard) {
                HStack(spacing: 5) {
                    Image(systemName: "keyboard")
                    Text("试键盘")
                        .lineLimit(1)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.accentDark)
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(Theme.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.border, lineWidth: 0.8))
            }
            .buttonStyle(.plain)
        }
    }

    private var onboardingBanner: some View {
        NavigationLink(value: Route.onboarding) {
            HStack(spacing: 11) {
                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.accentDark)
                    .frame(width: 38, height: 38)
                    .background(Theme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("启用微输入法键盘")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("在系统设置中添加键盘扩展，并允许完全访问")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Text("去启用")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accentDark)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(12)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.accent.opacity(0.25), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }

    private var carouselSection: some View {
        VStack(spacing: 9) {
            TabView(selection: $carouselIndex) {
                ForEach(Array(carouselItems.enumerated()), id: \.offset) { index, item in
                    carouselCard(item)
                        .padding(.horizontal, 2)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: isPad ? 205 : 180)

            HStack(spacing: 5) {
                ForEach(carouselItems.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == carouselIndex ? Theme.accent : Theme.muted.opacity(0.45))
                        .frame(width: index == carouselIndex ? 16 : 6, height: 6)
                        .animation(.easeInOut(duration: 0.2), value: carouselIndex)
                        .onTapGesture { carouselIndex = index }
                }
                Spacer()
                Text("\(carouselIndex + 1) / \(carouselItems.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private func carouselCard(_ item: CarouselItem) -> some View {
        if item.requiresPlus && !app.plusEnabled {
            Button {
                showPlusGate = true
            } label: {
                CarouselCardBody(item: item)
            }
            .buttonStyle(.plain)
        } else if let route = item.route {
            NavigationLink(value: route) {
                CarouselCardBody(item: item)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                showPlusGate = true
            } label: {
                CarouselCardBody(item: item)
            }
            .buttonStyle(.plain)
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "功能")
            HStack(spacing: 12) {
                featureCard(route: .recorder,
                            symbol: "waveform",
                            title: "AI 录音笔",
                            subtitle: "录音精准转写 · AI 实时总结",
                            badge: "NEW")
                featureCard(route: .transfer,
                            symbol: "paperplane.fill",
                            title: "隔空传送",
                            subtitle: "文件与文字跨设备接力",
                            badge: nil)
            }
        }
    }

    private func featureCard(route: Route, symbol: String, title: String, subtitle: String, badge: String?) -> some View {
        NavigationLink(value: route) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.accentDark)
                        .frame(width: 34, height: 34)
                        .background(Theme.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Spacer()
                    if let badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Theme.accent)
                            .clipShape(Capsule())
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(Theme.border.opacity(0.7), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "设置", trailing: "\(settingsItems.count) 项")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: isPad ? 4 : 2),
                      spacing: 12) {
                ForEach(settingsItems, id: \.route) { item in
                    NavigationLink(value: item.route) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: item.symbol)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Theme.accentDark)
                                    .frame(width: 31, height: 31)
                                    .background(Theme.accentSoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Theme.muted)
                            }
                            Text(item.title)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)
                            Text(item.subtitle)
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(11)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Theme.border.opacity(0.65), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var moreSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "更多")
            VStack(spacing: 0) {
                ForEach(Array(moreItems.enumerated()), id: \.offset) { index, item in
                    NavigationLink(value: item.route) {
                        SettingsRow(icon: item.symbol, title: item.title, subtitle: item.subtitle, value: nil)
                    }
                    .buttonStyle(.plain)
                    if index < moreItems.count - 1 {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .card(padding: 13)
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                StatusPill(text: app.backendStatus.label, ok: app.backendStatus.ok)
                StatusPill(text: SharedStore.appGroupAvailable ? "App Group 已共享" : "共享容器受限",
                           ok: SharedStore.appGroupAvailable)
                Spacer()
                Text("v1.0.0 (1)")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.muted)
            }
            Text("微输入法是一个独立的互操作性研究复刻项目，与腾讯及微信输入法无关联。界面与键盘均为重新实现，未使用原版二进制、字体或素材。")
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .padding(.top, 4)
    }

    private var carouselItems: [CarouselItem] {
        [
            CarouselItem(title: "文字整理", subtitle: "润色、改写、翻译与摘要，一次完成", symbol: "wand.and.stars", colors: ["12A97D", "24C891"], route: .textTools, requiresPlus: false, badge: "AI"),
            CarouselItem(title: "AI 录音笔", subtitle: "录音精准转写 · AI 实时总结", symbol: "waveform", colors: ["0E8A68", "2ED6A1"], route: .recorder, requiresPlus: false, badge: "NEW"),
            CarouselItem(title: "多语言自由说", subtitle: "普通话、粤语、英语等识别语言", symbol: "globe.asia.australia.fill", colors: ["1F8A70", "3AC7A2"], route: .voiceLanguage, requiresPlus: false, badge: nil),
            CarouselItem(title: "表情推荐", subtitle: "按场景找到合适的表情与颜文字", symbol: "face.smiling", colors: ["D98E3A", "F0B86E"], route: .emoji, requiresPlus: false, badge: nil),
            CarouselItem(title: "趣味颜文字", subtitle: "一行字也能有表情", symbol: "textformat.alt", colors: ["6A7FDB", "9BA9F2"], route: .plus, requiresPlus: false, badge: nil),
            CarouselItem(title: "问 AI", subtitle: "在键盘旁直接提问与上屏", symbol: "bubble.left.and.bubble.right.fill", colors: ["3A6FD8", "6FA8FF"], route: .aiChat, requiresPlus: true, badge: "PLUS"),
            CarouselItem(title: "排版成图", subtitle: "把一段话排成可分享的海报", symbol: "photo.on.rectangle.angled", colors: ["A05BC7", "C98BE0"], route: .poster, requiresPlus: false, badge: nil),
            CarouselItem(title: "跨设备粘贴传送", subtitle: "六位配对码连接设备与文件", symbol: "arrow.triangle.2.circlepath", colors: ["277A8E", "51B4C4"], route: .transfer, requiresPlus: false, badge: nil),
            CarouselItem(title: "灵动表达", subtitle: "定制工具栏与上屏动作", symbol: "hand.draw.fill", colors: ["B35C7A", "E096AC"], route: .toolbar, requiresPlus: false, badge: nil),
        ]
    }

    private var settingsItems: [SettingsTile] {
        [
            SettingsTile(route: .display, title: "布局和显示", subtitle: "高度、候选、主题", symbol: "rectangle.3.group"),
            SettingsTile(route: .keystroke, title: "按键效果", subtitle: "声音、触感、气泡", symbol: "hand.tap"),
            SettingsTile(route: .toolbar, title: "定制工具栏", subtitle: "排序与显示工具", symbol: "wrench.and.screwdriver"),
            SettingsTile(route: .auxiliary, title: "辅助输入", subtitle: "发送、空格、验证码", symbol: "text.cursor"),
            SettingsTile(route: .sync, title: "跨设备粘贴同步", subtitle: "配对码与剪贴板", symbol: "arrow.triangle.2.circlepath"),
            SettingsTile(route: .clipboard, title: "剪贴板", subtitle: "历史记录与快速粘贴", symbol: "doc.on.clipboard"),
            SettingsTile(route: .keyboardManage, title: "键盘管理", subtitle: "六种中文输入方式", symbol: "square.grid.3x3.fill"),
            SettingsTile(route: .voice, title: "语音转文字", subtitle: "长按空格、松手动作", symbol: "mic.fill"),
            SettingsTile(route: .plus, title: "拼写 Plus", subtitle: "智能拼写与表情能力", symbol: "sparkles"),
            SettingsTile(route: .standalone, title: "单机模式", subtitle: "离线词库与网络说明", symbol: "externaldrive"),
            SettingsTile(route: .migration, title: "换机助手", subtitle: "导出与导入设置", symbol: "arrow.left.arrow.right"),
        ]
    }

    private var moreItems: [MoreItem] {
        [
            MoreItem(route: .privacy, title: "隐私与权限", subtitle: "麦克风、语音识别与完全访问", symbol: "lock.shield"),
            MoreItem(route: .desktop, title: "电脑版", subtitle: "桌面端说明与配对", symbol: "desktopcomputer"),
            MoreItem(route: .about, title: "关于", subtitle: "版本、词库与许可", symbol: "info.circle"),
            MoreItem(route: .help, title: "帮助与反馈", subtitle: "常见问题与本地反馈", symbol: "questionmark.bubble"),
        ]
    }
}

private struct CarouselItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    let colors: [String]
    let route: Route?
    let requiresPlus: Bool
    let badge: String?
}

private struct SettingsTile {
    let route: Route
    let title: String
    let subtitle: String
    let symbol: String
}

private struct MoreItem {
    let route: Route
    let title: String
    let subtitle: String
    let symbol: String
}

private struct CarouselCardBody: View {
    let item: CarouselItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: item.colors.map { Color(hex: $0) },
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 210, height: 210)
                .offset(x: 200, y: -60)
            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 140, height: 140)
                .offset(x: 265, y: 75)
            Image(systemName: item.symbol)
                .font(.system(size: 92, weight: .light))
                .foregroundStyle(Color.white.opacity(0.13))
                .offset(x: 230, y: -20)

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(item.badge ?? "微输入法")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
                Text(item.title)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(item.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Text(item.requiresPlus ? "开启拼写 Plus 后使用" : "立即体验")
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.top, 2)
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 14, y: 7)
    }
}

struct PlusGateView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Theme.accentSoft).frame(width: 74, height: 74)
                    Image(systemName: "sparkles")
                        .font(.system(size: 31, weight: .semibold))
                        .foregroundStyle(Theme.accentDark)
                }
                Text("开启拼写 Plus")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.text)
                Text("拼写 Plus 提供智能拼写、表情与颜文字推荐、问 AI 等能力。它是本地开关，不会上传你的输入内容；只有你主动使用 AI 功能时才会请求后端。")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                PrimaryButton(title: "开启拼写 Plus", symbol: "checkmark") {
                    app.setPlus(true)
                    app.flash("拼写 Plus 已开启")
                    dismiss()
                }
                NavigationLink(value: Route.plus) {
                    Text("查看拼写 Plus 设置")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.accentDark)
                }
                .simultaneousGesture(TapGesture().onEnded { dismiss() })
            }
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .navigationDestination(for: Route.self) { route in
                RouteView(route: route)
            }
        }
    }
}
