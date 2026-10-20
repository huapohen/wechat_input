import Foundation
import CoreGraphics

/// A deliberately small, honest template recognizer for simple characters.
/// It compares the direction sequence of each drawn stroke with 20 hand-written
/// templates. It is not a full CJK handwriting model; the UI labels its scope.
enum HandwritingRecognizer {
    static let supportedCharacters = ["一", "二", "三", "十", "人", "大", "小", "口", "日", "中",
                                      "上", "下", "山", "木", "火", "水", "手", "心", "女", "田"]

    private static let templates: [String: [String]] = [
        "一": ["E"],
        "二": ["E", "E"],
        "三": ["E", "E", "E"],
        "十": ["E", "S"],
        "人": ["Z", "Q"],
        "大": ["E", "Z", "Q"],
        "小": ["S", "Z", "Q"],
        "口": ["S", "EN", "E"],
        "日": ["S", "EN", "E", "E"],
        "中": ["S", "EN", "E", "S"],
        "上": ["S", "E", "E"],
        "下": ["E", "S", "Q"],
        "山": ["S", "SE", "S"],
        "木": ["E", "S", "Z", "Q"],
        "火": ["Z", "Z", "Z", "Q"],
        "水": ["S", "EZ", "Z", "Q"],
        "手": ["Z", "E", "E", "S"],
        "心": ["Z", "EQ", "Z", "Z"],
        "女": ["ZQ", "Z", "E"],
        "田": ["S", "EN", "E", "S", "E"],
    ]

    struct Guess: Hashable {
        let character: String
        let score: Double
    }

    static func recognize(strokes: [[CGPoint]]) -> [Guess] {
        let drawn = strokes.compactMap(directions)
        guard !drawn.isEmpty else { return [] }

        var guesses: [Guess] = []
        for (character, template) in templates {
            let distance = editDistance(drawn, template)
            let length = max(drawn.count, template.count)
            let strokePenalty = Double(abs(drawn.count - template.count)) * 0.4
            let raw = 1.0 - (Double(distance) + strokePenalty) / Double(max(1, length) + 2)
            if raw > 0.18 {
                guesses.append(Guess(character: character, score: raw))
            }
        }
        return guesses.sorted { $0.score > $1.score }.prefix(6).map { $0 }
    }

    private static func directions(_ stroke: [CGPoint]) -> String? {
        guard stroke.count >= 2 else { return nil }
        var points: [CGPoint] = []
        for point in stroke {
            if let last = points.last, hypot(point.x - last.x, point.y - last.y) < 0.012 {
                continue
            }
            points.append(point)
        }
        guard points.count >= 2 else { return nil }

        var output = ""
        var lastDirection: Character?
        for index in 1..<points.count {
            let dx = points[index].x - points[index - 1].x
            let dy = points[index].y - points[index - 1].y
            guard hypot(dx, dy) > 0.018 else { continue }
            let refined: Character
            if abs(dx) > abs(dy) * 1.8 {
                refined = dx > 0 ? "E" : "W"
            } else if abs(dy) > abs(dx) * 1.8 {
                refined = dy > 0 ? "S" : "N"
            } else if dx > 0 && dy > 0 {
                refined = "Q"
            } else if dx < 0 && dy > 0 {
                refined = "Z"
            } else if dx > 0 && dy < 0 {
                refined = "R"
            } else {
                refined = "T"
            }
            if refined != lastDirection {
                output.append(refined)
                lastDirection = refined
            }
        }
        return output.isEmpty ? nil : output
    }

    private static func editDistance(_ lhs: [String], _ rhs: [String]) -> Int {
        var previous = Array(0...rhs.count)
        for (i, left) in lhs.enumerated() {
            var current = [i + 1]
            for (j, right) in rhs.enumerated() {
                let substitution = previous[j] + (left == right ? 0 : 1)
                current.append(min(previous[j + 1] + 1, current[j] + 1, substitution))
            }
            previous = current
        }
        return previous.last ?? 0
    }
}
