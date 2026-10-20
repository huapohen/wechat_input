import SwiftUI
import UIKit

struct OnboardingView: View {
    var isFirstRun: Bool = false

    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var agreed = false
    @State private var showDecline = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                privacyCard
                stepsCard
                fullAccessCard
                actions
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .maxContent()
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("启用与隐私")
        .navigationBarTitleDisplayMode(.inline)
        .alert("需要同意隐私说明", isPresented: $showDecline) {
            Button("知道了", role: .cancel) { }
            Button("返回", role: .cancel) { }
        } message: {
            Text("核心输入、词库与云同步功能都依赖这份隐私说明。你可以先阅读隐私与权限页面，再回来同意。")
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.mintGradient)
                    Text("微")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: 58, height: 58)
                VStack(alignment: .leading, spacing: 3) {
                    Text(isFirstRun ? "欢迎使用微输入法" : "启用微输入法")
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("简洁、好用、打字快")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Text("这是一个独立的互操作性研究复刻项目，与腾讯及微信输入法无关联。所有界面、键盘与词库查询均为重新实现。")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.softMintGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "隐私承诺")
            privacyLine("输入内容默认只在本机处理；词库查询与候选排序在本地完成。", "lock.fill")
            privacyLine("只有你主动使用问 AI、文字工具、边写边译、录音总结或同步/传送时，才会向你在设置中填写的后端发起请求。", "network")
            privacyLine("App 与键盘扩展不包含任何模型 API Key；密钥只保存在后端环境变量中。", "key.slash")
            privacyLine("键盘扩展在未开启完全访问时不读取网络与麦克风，语音入口会显示明确的降级说明。", "hand.raised.fill")
            Toggle(isOn: $agreed) {
                Text("我已阅读并同意《隐私政策》与《用户协议》")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text)
            }
            .tint(Theme.accent)
            HStack(spacing: 14) {
                NavigationLink("查看隐私与权限", value: Route.privacy)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.accentDark)
                Spacer()
            }
        }
        .card()
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "启用键盘扩展", trailing: app.keyboardSeen ? "已检测到运行" : "待启用")
            stepRow(1, "打开系统“设置” → “通用” → “键盘” → “键盘”")
            stepRow(2, "点击“添加新键盘”，选择“微输入法”")
            stepRow(3, "点开微输入法，允许“完全访问”（语音、后端 AI 与同步需要）")
            stepRow(4, "在任意输入框长按地球键切换到微输入法")
            HStack(spacing: 10) {
                SecondaryButton(title: "复制启用步骤", symbol: "doc.on.doc") {
                    UIPasteboard.general.string = """
                    1. 设置 → 通用 → 键盘 → 键盘
                    2. 添加新键盘 → 微输入法
                    3. 允许完全访问
                    4. 在输入框长按地球键切换
                    """
                    app.flash("启用步骤已复制")
                }
                SecondaryButton(title: "打开系统设置", symbol: "gear") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .card()
    }

    private var fullAccessCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("完全访问")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                StatusPill(text: app.keyboardSeen ? "键盘已运行" : "未检测到键盘",
                           ok: app.keyboardSeen)
            }
            Text("完全访问只用于：语音识别、调用你配置的后端、读取 App Group 中的剪贴板/常用语/设置。关闭时基础打字、拼音、五笔、笔画、双拼、表情和数字符号仍可用；AI 与语音会显示真实错误而不是伪造结果。")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("共享容器：\(SharedStore.appGroupAvailable ? "可用" : "不可用")")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("iOS \(UIDevice.current.systemVersion)")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.muted)
            }
        }
        .card()
    }

    private var actions: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: isFirstRun ? "同意并继续" : "保存并继续", symbol: "checkmark.shield",
                          enabled: agreed || SharedStore.bool(SharedKeys.onboardingAccepted)) {
                app.acceptOnboarding()
                app.flash("已同意隐私说明")
                if isFirstRun { dismiss() }
            }
            Button {
                if SharedStore.bool(SharedKeys.onboardingAccepted) {
                    dismiss()
                } else {
                    showDecline = true
                }
            } label: {
                Text("暂不同意")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
            }
            .buttonStyle(.plain)
        }
    }

    private func privacyLine(_ text: String, _ symbol: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.accentDark)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func stepRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Theme.accent)
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
