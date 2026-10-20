import Foundation
import SwiftUI

enum SharedKeys {
    static let appGroup = "group.com.huapohen.wechatinput"

    static let apiBase = "api.base_url"
    static let onboardingAccepted = "onboarding.accepted"
    static let keyboardSeen = "kb.seen"
    static let keyboardFullAccess = "kb.full_access"
    static let enabledModes = "kb.enabled_modes"
    static let defaultMode = "kb.default_mode"
    static let fuzzyPairs = "kb.fuzzy_pairs"
    static let height = "kb.height"
    static let candidateSize = "kb.candidate_size"
    static let numberRow = "kb.number_row"
    static let slideInput = "kb.slide_input"
    static let emojiKey = "kb.emoji_key"
    static let sidebar = "kb.sidebar"
    static let darkMode = "kb.dark_mode"
    static let theme = "kb.theme"
    static let pinyinPosition = "kb.pinyin_position"
    static let sound = "kb.sound"
    static let haptic = "kb.haptic"
    static let bubble = "kb.bubble"
    static let toolbar = "kb.toolbar"
    static let learning = "kb.learning"
    static let learned = "kb.learned"
    static let banished = "kb.banished"

    static let auxReturnSends = "aux.return_sends"
    static let auxSpaceBetween = "aux.space_between"
    static let auxVerification = "aux.verification"
    static let auxAutoCapital = "aux.auto_capital"
    static let auxDoubleSpace = "aux.double_space"

    static let voiceLongPress = "voice.long_press"
    static let voiceRelease = "voice.release"
    static let voiceSmart = "voice.smart"
    static let voiceOffline = "voice.offline"
    static let voiceStandby = "voice.standby"
    static let voiceShowIcon = "voice.show_icon"
    static let voiceLanguage = "voice.language"
    static let voicePunctuation = "voice.punctuation"
    static let voicePunctuationStyle = "voice.punctuation_style"

    static let plusEnabled = "plus.enabled"
    static let plusSmartSpelling = "plus.smart_spelling"
    static let plusMiniProgram = "plus.miniprogram"
    static let plusEmojiPack = "plus.emoji_pack"
    static let plusEmoji = "plus.emoji"
    static let plusKaomoji = "plus.kaomoji"
    static let plusSpellCheck = "plus.spell_check"
    static let plusDynamic = "plus.dynamic"

    static let clipboardEnabled = "clipboard.enabled"
    static let clipboardLimit = "clipboard.limit"
    static let clipboardHistory = "clipboard.history"

    static let customPhrases = "phrases.custom"
    static let syncToken = "sync.token"
    static let syncCode = "sync.code"
    static let syncName = "sync.name"
    static let standalone = "standalone.enabled"
    static let chatHistory = "ai.history"
    static let transferHistory = "transfer.history"
    static let recentEmoji = "emoji.recent"
    static let feedbackHistory = "feedback.history"

    static let defaultBaseURL = "http://127.0.0.1:8787"
}

final class SharedStore {
    static let defaults: UserDefaults = {
        let store = UserDefaults(suiteName: SharedKeys.appGroup) ?? UserDefaults.standard
        store.register(defaults: defaultsValues)
        return store
    }()

    static let defaultsValues: [String: Any] = {
        let modes = KeyboardMode.allCases.map(\.rawValue)
        return [
            SharedKeys.apiBase: SharedKeys.defaultBaseURL,
            SharedKeys.onboardingAccepted: false,
            SharedKeys.keyboardSeen: false,
            SharedKeys.keyboardFullAccess: false,
            SharedKeys.enabledModes: modes,
            SharedKeys.defaultMode: KeyboardMode.t9.rawValue,
            SharedKeys.fuzzyPairs: ["zh-z", "ch-c", "sh-s"],
            SharedKeys.height: 320.0,
            SharedKeys.candidateSize: 18.0,
            SharedKeys.numberRow: false,
            SharedKeys.slideInput: true,
            SharedKeys.emojiKey: true,
            SharedKeys.sidebar: false,
            SharedKeys.darkMode: "跟随系统",
            SharedKeys.theme: "薄荷绿",
            SharedKeys.pinyinPosition: PinyinPosition.candidateBar.rawValue,
            SharedKeys.sound: true,
            SharedKeys.haptic: HapticStrength.medium.rawValue,
            SharedKeys.bubble: true,
            SharedKeys.toolbar: ToolAction.allCases.map(\.rawValue),
            SharedKeys.learning: true,
            SharedKeys.learned: [String: Int](),
            SharedKeys.banished: [String](),
            SharedKeys.auxReturnSends: true,
            SharedKeys.auxSpaceBetween: true,
            SharedKeys.auxVerification: true,
            SharedKeys.auxAutoCapital: true,
            SharedKeys.auxDoubleSpace: true,
            SharedKeys.voiceLongPress: true,
            SharedKeys.voiceRelease: VoiceReleaseAction.insert.rawValue,
            SharedKeys.voiceSmart: true,
            SharedKeys.voiceOffline: true,
            SharedKeys.voiceStandby: "15 秒",
            SharedKeys.voiceShowIcon: true,
            SharedKeys.voiceLanguage: "普通话",
            SharedKeys.voicePunctuation: true,
            SharedKeys.voicePunctuationStyle: PunctuationStyle.chinese.rawValue,
            SharedKeys.plusEnabled: true,
            SharedKeys.plusSmartSpelling: true,
            SharedKeys.plusMiniProgram: true,
            SharedKeys.plusEmojiPack: true,
            SharedKeys.plusEmoji: true,
            SharedKeys.plusKaomoji: true,
            SharedKeys.plusSpellCheck: false,
            SharedKeys.plusDynamic: true,
            SharedKeys.clipboardEnabled: true,
            SharedKeys.clipboardLimit: 50,
            SharedKeys.clipboardHistory: [[String: Any]](),
            SharedKeys.customPhrases: [[String: Any]](),
            SharedKeys.syncToken: "",
            SharedKeys.syncCode: "",
            SharedKeys.syncName: "微输入法 iOS",
            SharedKeys.standalone: false,
            SharedKeys.chatHistory: [[String: Any]](),
            SharedKeys.transferHistory: [[String: Any]](),
            SharedKeys.recentEmoji: [String](),
            SharedKeys.feedbackHistory: [[String: Any]](),
        ]
    }()

    static var appGroupAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedKeys.appGroup) != nil
    }

    static func resetAll() {
        guard let domain = Bundle.main.bundleIdentifier else { return }
        defaults.removePersistentDomain(forName: domain)
        defaults.register(defaults: defaultsValues)
    }

    static func string(_ key: String) -> String {
        defaults.string(forKey: key) ?? ""
    }

    static func set(_ key: String, _ value: String) {
        defaults.set(value, forKey: key)
    }

    static func bool(_ key: String) -> Bool {
        defaults.bool(forKey: key)
    }

    static func set(_ key: String, _ value: Bool) {
        defaults.set(value, forKey: key)
    }

    static func int(_ key: String) -> Int {
        defaults.integer(forKey: key)
    }

    static func set(_ key: String, _ value: Int) {
        defaults.set(value, forKey: key)
    }

    static func double(_ key: String) -> Double {
        defaults.double(forKey: key)
    }

    static func set(_ key: String, _ value: Double) {
        defaults.set(value, forKey: key)
    }

    static func stringArray(_ key: String) -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    static func setStringArray(_ key: String, _ value: [String]) {
        defaults.set(value, forKey: key)
    }

    static func codable<T: Codable>(_ key: String, fallback: T) -> T {
        guard let data = defaults.data(forKey: key) else { return fallback }
        return (try? JSONDecoder().decode(T.self, from: data)) ?? fallback
    }

    static func setCodable<T: Codable>(_ key: String, _ value: T) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    static var enabledModes: [KeyboardMode] {
        let raw = stringArray(SharedKeys.enabledModes)
        let modes = raw.compactMap(KeyboardMode.init(rawValue:))
        return modes.isEmpty ? KeyboardMode.allCases : modes
    }

    static var defaultMode: KeyboardMode {
        KeyboardMode(rawValue: string(SharedKeys.defaultMode)) ?? .t9
    }

    static var toolbarActions: [ToolAction] {
        let raw = stringArray(SharedKeys.toolbar)
        let actions = raw.compactMap(ToolAction.init(rawValue:))
        return actions.isEmpty ? ToolAction.allCases : actions
    }

    static var fuzzyPairs: Set<String> {
        Set(stringArray(SharedKeys.fuzzyPairs))
    }

    static var apiBaseURL: String {
        let raw = string(SharedKeys.apiBase).trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? SharedKeys.defaultBaseURL : raw
    }

    static var clipboard: [ClipItem] {
        get { codable(SharedKeys.clipboardHistory, fallback: [ClipItem]()) }
        set {
            let limited = Array(newValue.prefix(max(1, int(SharedKeys.clipboardLimit))))
            setCodable(SharedKeys.clipboardHistory, limited)
        }
    }

    static var customPhrases: [PhraseEntry] {
        get { codable(SharedKeys.customPhrases, fallback: [PhraseEntry]()) }
        set { setCodable(SharedKeys.customPhrases, newValue) }
    }

    static var chatHistory: [ChatTurn] {
        get { codable(SharedKeys.chatHistory, fallback: [ChatTurn]()) }
        set { setCodable(SharedKeys.chatHistory, Array(newValue.suffix(120))) }
    }

    static var recorderSessionsURL: URL {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedKeys.appGroup) {
            return container.appendingPathComponent("recorder_sessions.json")
        }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("recorder_sessions.json")
    }

    static var recorderSessions: [RecorderSession] {
        get {
            guard let data = try? Data(contentsOf: recorderSessionsURL) else { return [] }
            return (try? JSONDecoder().decode([RecorderSession].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                try? data.write(to: recorderSessionsURL, options: .atomic)
            }
        }
    }

    static func learnedBoost(input: String, word: String) -> Int {
        let dict = defaults.dictionary(forKey: SharedKeys.learned) as? [String: Int] ?? [:]
        return dict["\(input)|\(word)"] ?? 0
    }

    static func learn(input: String, word: String) {
        guard bool(SharedKeys.learning), !input.isEmpty else { return }
        var dict = defaults.dictionary(forKey: SharedKeys.learned) as? [String: Int] ?? [:]
        let key = "\(input)|\(word)"
        dict[key] = min(99, (dict[key] ?? 0) + 1)
        defaults.set(dict, forKey: SharedKeys.learned)
    }

    static func banish(input: String, word: String) {
        var banned = stringArray(SharedKeys.banished)
        let key = "\(input)|\(word)"
        if !banned.contains(key) {
            banned.append(key)
            if banned.count > 400 { banned.removeFirst(banned.count - 400) }
            setStringArray(SharedKeys.banished, banned)
        }
        var dict = defaults.dictionary(forKey: SharedKeys.learned) as? [String: Int] ?? [:]
        dict.removeValue(forKey: key)
        defaults.set(dict, forKey: SharedKeys.learned)
    }

    static func isBanished(input: String, word: String) -> Bool {
        stringArray(SharedKeys.banished).contains("\(input)|\(word)")
    }

    static func clearLearning() {
        defaults.set([String: Int](), forKey: SharedKeys.learned)
        defaults.set([String](), forKey: SharedKeys.banished)
    }

    static var recentEmoji: [String] {
        get { stringArray(SharedKeys.recentEmoji) }
        set { setStringArray(SharedKeys.recentEmoji, Array(newValue.prefix(60))) }
    }

    static func rememberEmoji(_ emoji: String) {
        var recent = recentEmoji
        recent.removeAll { $0 == emoji }
        recent.insert(emoji, at: 0)
        recentEmoji = recent
    }

    static func addToClipboard(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var items = clipboard
        items.removeAll { $0.text == trimmed }
        items.insert(ClipItem(text: trimmed), at: 0)
        clipboard = items
    }
}


