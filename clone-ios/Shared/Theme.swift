import SwiftUI

enum Theme {
    static let background = Color(hex: "E6F4F2")
    static let surface = Color(hex: "FFFFFF")
    static let surfaceAlt = Color(hex: "F7FBFA")
    static let accent = Color(hex: "24C891")
    static let accentDark = Color(hex: "0E8A68")
    static let accentSoft = Color(hex: "DFF6EC")
    static let text = Color(hex: "26332F")
    static let textSecondary = Color(hex: "5F6F69")
    static let muted = Color(hex: "B8BCC5")
    static let border = Color(hex: "DCE7E3")
    static let warning = Color(hex: "B45309")
    static let danger = Color(hex: "B23A3A")
    static let key = Color(hex: "FFFFFF")
    static let keyPressed = Color(hex: "E9F7F1")
    static let keySpecial = Color(hex: "DDF2EA")
    static let keyText = Color(hex: "26332F")
    static let keyboardBackground = Color(hex: "EAF4F1")

    static let cardRadius: CGFloat = 20
    static let buttonRadius: CGFloat = 14
    static let keyRadius: CGFloat = 12
    static let sheetRadius: CGFloat = 26

    static let maxContentWidth: CGFloat = 1180
    static let keyboardMaxWidth: CGFloat = 920

    static var mintGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: "2ED6A1"), Color(hex: "12A97D")],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var softMintGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: "F0FBF7"), Color(hex: "DFF6EC")],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b, a: Double
        switch cleaned.count {
        case 8:
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        default:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

struct CardStyle: ViewModifier {
    var padding: CGFloat = 16
    var alt: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(alt ? Theme.surfaceAlt : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .stroke(Theme.border.opacity(0.7), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.035), radius: 10, x: 0, y: 4)
    }
}

extension View {
    func card(padding: CGFloat = 16, alt: Bool = false) -> some View {
        modifier(CardStyle(padding: padding, alt: alt))
    }

    func pageBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
    }

    func maxContent() -> some View {
        frame(maxWidth: Theme.maxContentWidth)
            .frame(maxWidth: .infinity)
    }
}

struct PageShell<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.text)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.top, 8)
                content
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 40)
            .maxContent()
        }
        .scrollIndicators(.hidden)
        .pageBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.text)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.top, 6)
    }
}

struct SettingIcon: View {
    let symbol: String
    var color: Color = Theme.accentDark

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 32, height: 32)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var tint: Color = Theme.accentDark
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            SettingIcon(symbol: icon, color: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

struct ToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.accent)
        }
        .padding(.vertical, 9)
    }
}

struct ChoiceRow: View {
    let title: String
    var subtitle: String? = nil
    let options: [String]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.text)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 9)
    }
}

struct ToggleListCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .card(padding: 14)
    }
}

struct InfoBanner: View {
    let text: String
    var symbol: String = "info.circle.fill"
    var tint: Color = Theme.accentDark

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(tint.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

struct PrimaryButton: View {
    let title: String
    var symbol: String? = nil
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(enabled ? AnyShapeStyle(Theme.mintGradient) : AnyShapeStyle(Theme.muted))
            .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct SecondaryButton: View {
    let title: String
    var symbol: String? = nil
    var tint: Color = Theme.accentDark
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(tint.opacity(0.11))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct StatusPill: View {
    let text: String
    var ok: Bool = true

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(ok ? Theme.accent : Theme.warning)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ok ? Theme.accentDark : Theme.warning)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background((ok ? Theme.accent : Theme.warning).opacity(0.11))
        .clipShape(Capsule())
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Theme.muted)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.text.opacity(0.9))
            .clipShape(Capsule())
            .shadow(radius: 8)
            .padding(.bottom, 24)
    }
}
