import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct LexiconPhrase: Codable, Hashable {
    var text: String
    var code: String = ""
}

struct FuzzyFile: Codable {
    var pairs: [[String]]
    var groups: [String]?
}

struct DoublePinyinScheme: Codable {
    var name: String
    var initials: [String: String]
    var finals: [String: String]
}

final class Lexicon {
    static let shared = Lexicon()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.huapohen.wechatinput.lexicon")
    private(set) var emojiCategories: [EmojiCategory] = []
    private(set) var fuzzyPairs: [[String]] = []
    private(set) var doublePinyin: [String: DoublePinyinScheme] = [:]
    private(set) var bundledPhrases: [LexiconPhrase] = []

    private init() {
        openDatabase()
        loadEmoji()
        loadFuzzy()
        loadDoublePinyin()
        loadPhrases()
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    private func openDatabase() {
        if let url = Bundle.main.url(forResource: "lexicon", withExtension: "sqlite") {
            if sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
                db = nil
            }
        }
        if db == nil, let fallback = Bundle(for: Lexicon.self).url(forResource: "lexicon", withExtension: "sqlite") {
            if sqlite3_open_v2(fallback.path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
                db = nil
            }
        }
        sqlite3_busy_timeout(db, 400)
    }

    private func loadJSON<T: Decodable>(_ name: String, _ type: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func loadEmoji() {
        emojiCategories = loadJSON("emoji", [EmojiCategory].self) ?? []
    }

    private func loadFuzzy() {
        fuzzyPairs = (loadJSON("fuzzy_pinyin", FuzzyFile.self)?.pairs) ?? []
    }

    private func loadDoublePinyin() {
        doublePinyin = loadJSON("double_pinyin", [String: DoublePinyinScheme].self) ?? [:]
    }

    private func loadPhrases() {
        bundledPhrases = loadJSON("phrases", [LexiconPhrase].self) ?? []
    }

    var allEmoji: [String] {
        emojiCategories.flatMap(\.items)
    }

    func emoji(matching query: String) -> [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return allEmoji }
        let matchedCategories = emojiCategories.filter { $0.category.contains(q) }.flatMap(\.items)
        if !matchedCategories.isEmpty { return matchedCategories }
        return allEmoji.filter { $0.contains(q) }
    }

    // MARK: - SQL helpers

    private func rows(_ sql: String, _ binds: [String], limit: Int) -> [String] {
        guard let db else { return [] }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        for (index, bind) in binds.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), bind, -1, SQLITE_TRANSIENT)
        }
        var result: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW && result.count < limit {
            if let pointer = sqlite3_column_text(statement, 0) {
                result.append(String(cString: pointer))
            }
        }
        return result
    }

    func scalar(_ sql: String) -> Int {
        guard let db else { return 0 }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(statement) }
        if sqlite3_step(statement) == SQLITE_ROW {
            return Int(sqlite3_column_int(statement, 0))
        }
        return 0
    }

    // MARK: - Candidates

    func candidates(for mode: KeyboardMode, input: String, limit: Int = 18) -> [String] {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !raw.isEmpty else { return [] }
        var results: [String]

        switch mode {
        case .t9:
            results = t9Candidates(raw, limit: limit)
        case .qwerty:
            results = pinyinCandidates(raw, limit: limit)
        case .wubi:
            results = rows("SELECT c FROM wubi WHERE code LIKE ? ORDER BY length(code), rowid LIMIT \(limit)",
                           ["\(raw)%"], limit: limit)
        case .stroke:
            results = rows("SELECT c FROM stroke WHERE code LIKE ? ORDER BY length(code), rowid LIMIT \(limit)",
                           ["\(raw)%"], limit: limit)
        case .doublepin:
            results = pinyinCandidates(decodeDoublePinyin(raw), limit: limit)
        case .english:
            results = rows("SELECT w FROM english WHERE w LIKE ? ORDER BY length(w), w LIMIT \(limit)",
                           ["\(raw)%"], limit: limit)
        case .emoji:
            results = emoji(matching: raw)
        case .handwrite, .number, .symbols:
            results = []
        }

        results = results.filter { !SharedStore.isBanished(input: raw, word: $0) }

        let unique = results.reduce(into: [String]()) { acc, item in
            if !acc.contains(item) { acc.append(item) }
        }

        return unique.enumerated().sorted { lhs, rhs in
            let lb = SharedStore.learnedBoost(input: raw, word: lhs.element)
            let rb = SharedStore.learnedBoost(input: raw, word: rhs.element)
            if lb == rb { return lhs.offset < rhs.offset }
            return lb > rb
        }.map(\.element)
    }

    private func pinyinCandidates(_ input: String, limit: Int) -> [String] {
        let q = input.replacingOccurrences(of: "'", with: "")
        guard !q.isEmpty else { return [] }
        var phrases: [String] = []
        var chars: [String] = []
        let variants = fuzzyVariants(q)
        for (index, variant) in variants.enumerated() {
            let variantLimit = index == 0 ? limit : max(4, limit / 2)
            phrases += rows("SELECT text FROM phrases WHERE py = ? ORDER BY length(text) LIMIT \(variantLimit)",
                            [variant], limit: variantLimit)
            phrases += rows("SELECT text FROM phrases WHERE py LIKE ? ORDER BY length(text), freq ASC LIMIT \(variantLimit)",
                            ["\(variant)%"], limit: variantLimit)
            chars += rows("SELECT c FROM chars WHERE py = ? ORDER BY freq ASC LIMIT \(variantLimit)",
                          [variant], limit: variantLimit)
            chars += rows("SELECT c FROM chars WHERE py LIKE ? ORDER BY freq ASC LIMIT \(variantLimit)",
                          ["\(variant)%"], limit: variantLimit)
        }
        var merged = phrases
        merged.append(contentsOf: chars)
        return merged
    }

    private func t9Candidates(_ input: String, limit: Int) -> [String] {
        let digits = input.filter(\.isNumber)
        guard !digits.isEmpty else { return [] }
        var merged = rows("SELECT text FROM phrases WHERE t9 = ? ORDER BY length(text) LIMIT \(limit)",
                          [digits], limit: limit)
        merged += rows("SELECT text FROM phrases WHERE t9 LIKE ? ORDER BY length(text), freq ASC LIMIT \(limit)",
                       ["\(digits)%"], limit: limit)
        merged += rows("""
            SELECT c FROM chars WHERE py IN (
                SELECT py FROM t9 WHERE digits LIKE ? LIMIT 220
            ) ORDER BY freq ASC LIMIT \(limit)
            """, ["\(digits)%"], limit: limit)
        return merged
    }

    private func decodeDoublePinyin(_ input: String) -> String {
        guard let scheme = doublePinyin["xiaobe"] else { return input }
        var result = ""
        let chars = Array(input)
        var index = 0
        while index < chars.count {
            let first = String(chars[index])
            if index + 1 < chars.count {
                let second = String(chars[index + 1])
                let initial = scheme.initials[first] ?? first
                let final = scheme.finals[second] ?? second
                result += initial + final
                index += 2
            } else {
                result += scheme.initials[first] ?? first
                index += 1
            }
        }
        return result
    }

    func fuzzyVariants(_ input: String) -> [String] {
        var variants = [input]
        let enabled = SharedStore.fuzzyPairs
        for pair in fuzzyPairs where pair.count >= 2 {
            let key = "\(pair[0])-\(pair[1])"
            guard enabled.contains(key) else { continue }
            let a = pair[0]
            let b = pair[1]
            for existing in variants.prefix(6) {
                if existing.contains(a) {
                    let swapped = existing.replacingOccurrences(of: a, with: b)
                    if swapped != existing { variants.append(swapped) }
                }
                if existing.contains(b) {
                    let swapped = existing.replacingOccurrences(of: b, with: a)
                    if swapped != existing { variants.append(swapped) }
                }
            }
            if variants.count >= 9 { break }
        }
        return Array(variants.prefix(9))
    }

    var charCount: Int { scalar("SELECT COUNT(*) FROM chars") }
    var phraseCount: Int { scalar("SELECT COUNT(*) FROM phrases") }
    var wubiCount: Int { scalar("SELECT COUNT(*) FROM wubi") }
    var strokeCount: Int { scalar("SELECT COUNT(*) FROM stroke") }
}
