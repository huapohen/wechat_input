import Foundation

struct KBMessage: Codable {
    var role: String
    var content: String
}

struct KBResponse: Codable {
    var text: String?
    var candidates: [String]?
    var error: String?
}

enum KBServiceError: LocalizedError {
    case badURL
    case http(Int, String)
    case empty

    var errorDescription: String? {
        switch self {
        case .badURL: return "后端地址无效，请在主 App 设置中修改 API 地址。"
        case .http(let code, let body): return "后端返回 \(code)：\(body)"
        case .empty: return "后端没有返回内容。"
        }
    }
}

enum KBService {
    static var baseURL: URL? {
        URL(string: SharedStore.apiBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    static func post(_ path: String, body: [String: Any]) async throws -> Data {
        guard let base = baseURL, let url = URL(string: path, relativeTo: base) else { throw KBServiceError.badURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return data }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw KBServiceError.http(http.statusCode, String(body.prefix(260)))
        }
        return data
    }

    static func chat(prompt: String) async throws -> String {
        let body: [String: Any] = [
            "messages": [
                ["role": "system", "content": "你是输入法内的写作助手。回答简洁，只给可以直接上屏的文本，不解释。"],
                ["role": "user", "content": prompt],
            ],
            "stream": false,
            "max_tokens": 600,
        ]
        let data = try await post("/v1/ai/chat", body: body)
        let response = try JSONDecoder().decode(KBResponse.self, from: data)
        guard let text = response.text, !text.isEmpty else { throw KBServiceError.empty }
        return text
    }

    static func polish(_ text: String) async throws -> String {
        let data = try await post("/v1/ai/polish", body: ["text": text])
        let response = try JSONDecoder().decode(KBResponse.self, from: data)
        guard let value = response.text, !value.isEmpty else { throw KBServiceError.empty }
        return value
    }

    static func translate(_ text: String, target: String) async throws -> String {
        let data = try await post("/v1/ai/translate", body: [
            "text": text,
            "source": "auto",
            "target": target,
        ])
        let response = try JSONDecoder().decode(KBResponse.self, from: data)
        guard let value = response.text, !value.isEmpty else { throw KBServiceError.empty }
        return value
    }

    static func isReachable() async -> Bool {
        guard let base = baseURL, let url = URL(string: "/health", relativeTo: base) else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 4
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
