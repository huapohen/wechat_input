import SwiftUI
import UIKit

// MARK: - Phrases

struct PhrasesView: View {
    @EnvironmentObject private var app: AppModel
    @State private var custom: [PhraseEntry] = SharedStore.customPhrases
    @State private var showAdd = false
    @State private var newText = ""
    @State private var newCode = ""
    @State private var search = ""

    private var bundled: [LexiconPhrase] {
        let all = Lexicon.shared.bundledPhrases
        guard !search.isEmpty else { return Array(all.prefix(60)) }
        return all.filter { $0.text.contains(search) || $0.code.contains(search.lowercased()) }
    }

    var body: some View {
        PageShell(title: "常用语", subtitle: "自定义短语、词库短语与键盘上屏") {
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    TextField("搜索常用语", text: $search)
                        .font(.system(size: 13))
                        .padding(8)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    Button {
                        showAdd = true
                    } label: {
                        Label("新增", systemImage: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.mintGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                }

                if !custom.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("我的常用语")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        ForEach(custom) { entry in
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.text)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Theme.text)
                                    if !entry.code.isEmpty {
                                        Text(entry.code)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(Theme.muted)
                                    }
                                }
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = entry.text
                                    app.flash("已复制：" + entry.text)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Theme.accentDark)
                                Button {
                                    custom.removeAll { $0.id == entry.id }
                                    SharedStore.customPhrases = custom
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Theme.danger)
                            }
                            .padding(9)
                            .background(Theme.surfaceAlt)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                        }
                    }
                    .card(padding: 14)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("词库常用语")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Spacer()
                        Text("\(bundled.count) 条")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 7)], spacing: 7) {
                        ForEach(Array(bundled.enumerated()), id: \.offset) { _, phrase in
                            Button {
                                UIPasteboard.general.string = phrase.text
                                app.flash("已复制：" + phrase.text)
                            } label: {
                                VStack(spacing: 2) {
                                    Text(phrase.text)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.text)
                                        .lineLimit(1)
                                    if !phrase.code.isEmpty {
                                        Text(phrase.code)
                                            .font(.system(size: 8, design: .monospaced))
                                            .foregroundStyle(Theme.muted)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(Theme.surfaceAlt)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .card(padding: 14)

                NavigationLink(value: Route.sync) {
                    SettingsRow(icon: "arrow.triangle.2.circlepath", title: "同步常用语", subtitle: "推送到配对后端")
                }
                .buttonStyle(.plain)
                .card(padding: 14)

                InfoBanner(text: "自定义常用语通过 App Group 与键盘扩展共享，键盘工具栏的“常用语”面板可直接上屏。")
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                Form {
                    Section("内容") {
                        TextField("例如：收到，我稍后回复", text: $newText, axis: .vertical)
                        TextField("触发编码（可选，例如 shoudao）", text: $newCode)
                            .textInputAutocapitalization(.never)
                    }
                }
                .navigationTitle("新增常用语")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showAdd = false; newText = ""; newCode = "" }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            custom.insert(PhraseEntry(text: trimmed, code: newCode, custom: true), at: 0)
                            SharedStore.customPhrases = custom
                            showAdd = false
                            newText = ""
                            newCode = ""
                            app.flash("常用语已添加")
                        }
                        .disabled(newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Emoji

struct EmojiView: View {
    @EnvironmentObject private var app: AppModel
    @State private var query = ""
    @State private var category = "最近"
    @State private var recents: [String] = SharedStore.recentEmoji

    private let kaomoji = [
        "(＾▽＾)", "(￣▽￣)", "(｡•́︿•̀｡)", "(๑•̀ㅂ•́)و✧", "ヾ(≧▽≦*)o",
        "(ง •_•)ง", "(´･ω･`)", "(づ｡◕‿‿◕｡)づ", "┬─┬ノ( º _ ºノ)", "( ͡° ͜ʖ ͡°)",
    ]

    private var categories: [String] {
        ["最近"] + Lexicon.shared.emojiCategories.map(\.category) + ["颜文字"]
    }

    private var items: [String] {
        if !query.isEmpty { return Lexicon.shared.emoji(matching: query) }
        if category == "最近" {
            return recents.isEmpty ? Array(Lexicon.shared.emojiCategories.first?.items.prefix(40) ?? []) : recents
        }
        if category == "颜文字" { return kaomoji }
        return Lexicon.shared.emojiCategories.first { $0.category == category }?.items ?? []
    }

    var body: some View {
        PageShell(title: "表情", subtitle: "分类、搜索、最近使用与颜文字") {
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.textSecondary)
                    TextField("搜索表情分类，如“笑脸”", text: $query)
                        .font(.system(size: 13))
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(9)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(categories, id: \.self) { item in
                            Button {
                                category = item
                                query = ""
                            } label: {
                                Text(item)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(category == item ? .white : Theme.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(category == item ? Theme.accent : Theme.surface)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, emoji in
                        Button {
                            UIPasteboard.general.string = emoji
                            SharedStore.rememberEmoji(emoji)
                            recents = SharedStore.recentEmoji
                            app.flash("已复制 \(emoji)")
                        } label: {
                            Text(emoji)
                                .font(.system(size: category == "颜文字" ? 11 : 28))
                                .frame(maxWidth: .infinity)
                                .frame(height: category == "颜文字" ? 46 : 52)
                                .background(Theme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 10) {
                    SecondaryButton(title: "在键盘中使用", symbol: "keyboard") {
                        SharedStore.set(SharedKeys.defaultMode, KeyboardMode.emoji.rawValue)
                        app.flash("键盘默认模式已设为表情")
                    }
                    SecondaryButton(title: "清空最近", symbol: "clock.arrow.circlepath") {
                        SharedStore.recentEmoji = []
                        recents = []
                    }
                    Spacer()
                }

                InfoBanner(text: "表情与颜文字来自随包数据；点击会复制到系统剪贴板并记入“最近”。键盘内的表情面板可直接上屏。")
            }
        }
        .onAppear { recents = SharedStore.recentEmoji }
    }
}
