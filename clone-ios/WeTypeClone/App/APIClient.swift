import Foundation
import UniformTypeIdentifiers

struct APIChatMessage: Codable, Hashable {
    var role: String
    var content: String
}

struct HealthKey: Codable {
    var configured: Bool?
    var prefix: String?
    var sha256_12: String?
    var length: Int?
}

struct HealthResponse: Codable {
    var ok: Bool
    var model: String
    var base_url: String?
    var asr: String?
    var key: HealthKey?
}

struct SummaryResponse: Codable {
    var text: String
    var summary: String?
    var bullets: [String]?
}

struct PairPeer: Codable {
    var token: String?
    var name: String?
}

struct PairResponse: Codable {
    var token: String
    var code: String
    var peer: PairPeer?
}

struct RemoteClipItem: Codable, Hashable {
    var text: String
    var created: Double?
    var sha256: String?
}

struct RemoteItemList: Codable {
    var items: [RemoteClipItem]
}

struct TransferList: Codable {
    var items: [TransferFile]
}

enum APIError: LocalizedError {
    case invalidURL
    case http(Int, String)
    case empty
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "API 地址无效，请在设置中检查后端地址。"
        case .http(let code, let message):
            return "后端错误 \(code)：\(message)"
        case .empty:
            return "后端没有返回可用内容。"
        case .decoding(let message):
            return "响应解析失败：\(message)"
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    private let session = URLSession(configuration: .default)

    var baseURL: String {
        SharedStore.apiBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func url(_ path: String) throws -> URL {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        return url
    }

    private func request(_ path: String, method: String = "GET", body: Any? = nil, timeout: TimeInterval = 60) throws -> URLRequest {
        var request = URLRequest(url: try url(path))
        request.httpMethod = method
        request.timeoutInterval = timeout
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    private func checked(_ data: Data, _ response: URLResponse) throws -> Data {
        guard let http = response as? HTTPURLResponse else { return data }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            var message = String(text.prefix(400))
            if let envelope = try? JSONDecoder().decode([String: String].self, from: data),
               let detail = envelope["detail"] {
                message = detail
            }
            throw APIError.http(http.statusCode, message)
        }
        return data
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        return try checked(data, response)
    }

    // MARK: - Health

    func health() async throws -> HealthResponse {
        let request = try request("/health", timeout: 8)
        let data = try await data(for: request)
        return try JSONDecoder().decode(HealthResponse.self, from: data)
    }

    // MARK: - Chat

    func chat(messages: [APIChatMessage], stream: Bool = false,
              onDelta: ((String) -> Void)? = nil) async throws -> String {
        let body: [String: Any] = [
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "stream": stream,
            "temperature": 0.7,
            "max_tokens": 1200,
        ]
        var req = try request("/v1/ai/chat", method: "POST", body: body, timeout: 120)
        if stream {
            req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            let (bytes, response) = try await session.bytes(for: req)
            guard let http = response as? HTTPURLResponse else { throw APIError.empty }
            guard (200..<300).contains(http.statusCode) else {
                var text = ""
                for try await line in bytes.lines { text += line + "\n" }
                throw APIError.http(http.statusCode, String(text.prefix(400)))
            }
            var output = ""
            var event = ""
            for try await line in bytes.lines {
                if line.hasPrefix("event:") {
                    event = line.replacingOccurrences(of: "event:", with: "").trimmingCharacters(in: .whitespaces)
                    continue
                }
                guard line.hasPrefix("data:") else { continue }
                let payload = line.replacingOccurrences(of: "data:", with: "").trimmingCharacters(in: .whitespaces)
                if payload == "[DONE]" { break }
                if event == "error" {
                    throw APIError.http(502, payload)
                }
                if let data = payload.data(using: .utf8),
                   let chunk = try? JSONDecoder().decode([String: String].self, from: data),
                   let delta = chunk["text"] {
                    output += delta
                    onDelta?(delta)
                }
                if event == "done" { break }
            }
            guard !output.isEmpty else { throw APIError.empty }
            return output
        } else {
            let data = try await data(for: req)
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let text = object["text"] as? String, !text.isEmpty else { throw APIError.empty }
            return text
        }
    }

    // MARK: - Text tools

    func polish(_ text: String) async throws -> String {
        let req = try request("/v1/ai/polish", method: "POST", body: ["text": text], timeout: 90)
        let data = try await data(for: req)
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = object["text"] as? String, !value.isEmpty else { throw APIError.empty }
        return value
    }

    func rewrite(_ text: String, style: String, count: Int = 3) async throws -> [String] {
        let req = try request("/v1/ai/rewrite", method: "POST", body: [
            "text": text, "style": style, "count": count,
        ], timeout: 90)
        let data = try await data(for: req)
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = object["candidates"] as? [String], !candidates.isEmpty else { throw APIError.empty }
        return candidates
    }

    func translate(_ text: String, source: String = "auto", target: String) async throws -> String {
        let req = try request("/v1/ai/translate", method: "POST", body: [
            "text": text, "source": source, "target": target,
        ], timeout: 90)
        let data = try await data(for: req)
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = object["text"] as? String, !value.isEmpty else { throw APIError.empty }
        return value
    }

    func summary(_ text: String) async throws -> SummaryResponse {
        let req = try request("/v1/ai/summary", method: "POST", body: ["text": text], timeout: 120)
        let data = try await data(for: req)
        return try JSONDecoder().decode(SummaryResponse.self, from: data)
    }

    // MARK: - Sync

    func pair(code: String, name: String) async throws -> PairResponse {
        let req = try request("/v1/sync/pair", method: "POST", body: ["code": code, "name": name], timeout: 20)
        let data = try await data(for: req)
        return try JSONDecoder().decode(PairResponse.self, from: data)
    }

    func pushClipboard(token: String, texts: [String]) async throws -> [RemoteClipItem] {
        let body: [String: Any] = [
            "token": token,
            "items": texts.map { ["text": $0] },
        ]
        let req = try request("/v1/sync/clipboard", method: "POST", body: body, timeout: 30)
        let data = try await data(for: req)
        return try JSONDecoder().decode(RemoteItemList.self, from: data).items
    }

    func fetchClipboard(token: String) async throws -> [RemoteClipItem] {
        let encoded = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token
        let req = try request("/v1/sync/clipboard?token=\(encoded)", timeout: 30)
        let data = try await data(for: req)
        return try JSONDecoder().decode(RemoteItemList.self, from: data).items
    }

    func pushPhrases(token: String, phrases: [PhraseEntry]) async throws -> [RemoteClipItem] {
        let body: [String: Any] = [
            "token": token,
            "items": phrases.map { ["text": $0.text, "code": $0.code] },
        ]
        let req = try request("/v1/sync/phrases", method: "POST", body: body, timeout: 30)
        let data = try await data(for: req)
        return try JSONDecoder().decode(RemoteItemList.self, from: data).items
    }

    func pushSettings(token: String, payload: [String: Any]) async throws {
        let req = try request("/v1/sync/settings", method: "POST", body: ["token": token, "payload": payload], timeout: 30)
        _ = try await data(for: req)
    }

    func fetchSettings(token: String) async throws -> [String: Any] {
        let encoded = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token
        let req = try request("/v1/sync/settings?token=\(encoded)", timeout: 30)
        let data = try await data(for: req)
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = object["payload"] as? [String: Any] else { return [:] }
        return payload
    }

    // MARK: - Transfer

    func transferList(token: String) async throws -> [TransferFile] {
        var path = "/v1/transfer/list"
        if !token.isEmpty {
            let encoded = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token
            path += "?token=\(encoded)"
        }
        let req = try request(path, timeout: 30)
        let data = try await data(for: req)
        return try JSONDecoder().decode(TransferList.self, from: data).items
    }

    func upload(fileURL: URL, token: String, onProgress: @escaping (Double) -> Void) async throws -> TransferFile {
        let accessed = fileURL.startAccessingSecurityScopedResource()
        defer { if accessed { fileURL.stopAccessingSecurityScopedResource() } }
        let fileData = try Data(contentsOf: fileURL)
        let boundary = "Boundary-\(UUID().uuidString)"
        var componentPath = "/v1/transfer/upload"
        if !token.isEmpty {
            let encoded = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token
            componentPath += "?token=\(encoded)"
        }
        var req = try request(componentPath, method: "POST", timeout: 180)
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let mime = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let delegate = UploadProgressDelegate(onProgress: onProgress)
        let uploadSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { uploadSession.invalidateAndCancel() }
        let (data, response) = try await uploadSession.upload(for: req, from: body)
        let checkedData = try checked(data, response)
        return try JSONDecoder().decode(TransferFile.self, from: checkedData)
    }

    func download(id: String) async throws -> URL {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let req = try request("/v1/transfer/\(encoded)", timeout: 120)
        let (temp, response) = try await session.download(for: req)
        _ = try checked(Data(), response)
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(id)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.copyItem(at: temp, to: destination)
        return destination
    }
}

final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate {
    private let onProgress: (Double) -> Void

    init(onProgress: @escaping (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        onProgress(min(1, Double(totalBytesSent) / Double(totalBytesExpectedToSend)))
    }
}
