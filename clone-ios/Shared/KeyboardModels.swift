import Foundation
import SwiftUI

enum KeyboardMode: String, CaseIterable, Codable, Identifiable, Hashable {
    case t9, qwerty, handwrite, stroke, wubi, doublepin, english, number, symbols, emoji

    var id: String { rawValue }

    var title: String {
        switch self {
        case .t9: return "九宫格拼音"
        case .qwerty: return "全键盘拼音"
        case .handwrite: return "手写"
        case .stroke: return "笔画"
        case .wubi: return "五笔"
        case .doublepin: return "双拼"
        case .english: return "英文"
        case .number: return "数字"
        case .symbols: return "符号"
        case .emoji: return "表情"
        }
    }

    var shortTitle: String {
        switch self {
        case .t9: return "九宫格"
        case .qwerty: return "全键盘"
        case .handwrite: return "手写"
        case .stroke: return "笔画"
        case .wubi: return "五笔"
        case .doublepin: return "双拼"
        case .english: return "英文"
        case .number: return "数字"
        case .symbols: return "符号"
        case .emoji: return "表情"
        }
    }

    var symbol: String {
        switch self {
        case .t9: return "square.grid.3x3.fill"
        case .qwerty: return "keyboard"
        case .handwrite: return "scribble"
        case .stroke: return "character"
        case .wubi: return "square.grid.2x2"
        case .doublepin: return "rectangle.split.2x1"
        case .english: return "textformat.abc"
        case .number: return "number"
        case .symbols: return "textformat"
        case .emoji: return "face.smiling"
        }
    }

    var isChinese: Bool {
        switch self {
        case .t9, .qwerty, .handwrite, .stroke, .wubi, .doublepin: return true
        default: return false
        }
    }

    var chineseIndex: Int? {
        switch self {
        case .t9: return 0
        case .qwerty: return 1
        case .handwrite: return 2
        case .stroke: return 3
        case .wubi: return 4
        case .doublepin: return 5
        default: return nil
        }
    }
}

enum ToolAction: String, CaseIterable, Codable, Identifiable {
    case mode, voice, clipboard, phrases, emoji, handwrite, ai, translate, polish, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mode: return "切换键盘"
        case .voice: return "语音"
        case .clipboard: return "剪贴板"
        case .phrases: return "常用语"
        case .emoji: return "表情"
        case .handwrite: return "手写找字"
        case .ai: return "问 AI"
        case .translate: return "翻译"
        case .polish: return "文字整理"
        case .settings: return "键盘设置"
        }
    }

    var symbol: String {
        switch self {
        case .mode: return "keyboard"
        case .voice: return "mic.fill"
        case .clipboard: return "doc.on.clipboard"
        case .phrases: return "text.bubble"
        case .emoji: return "face.smiling"
        case .handwrite: return "scribble"
        case .ai: return "sparkles"
        case .translate: return "character.book.closed"
        case .polish: return "wand.and.stars"
        case .settings: return "gearshape"
        }
    }
}

struct ClipItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var text: String
    var date: Date = Date()
}

struct PhraseEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var text: String
    var code: String = ""
    var custom: Bool = true
}

struct RecorderSession: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var transcript: String
    var summary: String = ""
    var bullets: [String] = []
    var createdAt: Date = Date()
    var duration: TimeInterval = 0
}

struct LearnedEntry: Codable, Hashable {
    var input: String
    var word: String
    var count: Int
}

struct ChatTurn: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var role: String
    var content: String
    var createdAt: Date = Date()
    var error: Bool = false
}

struct TransferFile: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var size: Int
    var sha256: String?
    var created: Double?
}

struct TranslationTurn: Identifiable, Hashable {
    var id = UUID()
    var source: String
    var target: String
}

struct EmojiCategory: Codable, Identifiable, Hashable {
    var category: String
    var items: [String]
    var id: String { category }
}

enum PunctuationStyle: String, CaseIterable, Identifiable {
    case chinese = "中文标点"
    case english = "英文标点"
    case mixed = "混合"
    var id: String { rawValue }
}

enum VoiceReleaseAction: String, CaseIterable, Identifiable {
    case insert = "松手上屏"
    case send = "松手发送"
    case stay = "松手停留"
    var id: String { rawValue }
}

enum HapticStrength: String, CaseIterable, Identifiable {
    case off = "关闭"
    case light = "轻"
    case medium = "中"
    case strong = "强"
    var id: String { rawValue }
}

enum PinyinPosition: String, CaseIterable, Identifiable {
    case inline = "键盘内"
    case candidateBar = "候选栏"
    case hidden = "不显示"
    var id: String { rawValue }
}
