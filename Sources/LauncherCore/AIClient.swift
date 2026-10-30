import Foundation

public enum AIProviderKind: String, Codable, CaseIterable, Sendable {
    case claude
    case gemini

    public var defaultModel: String {
        switch self {
        case .claude:
            return "claude-sonnet-5-5"
        case .gemini:
            return "gemini-2.5-flash"
        }
    }

    /// Models offered in the settings list; any other id can still be typed in by hand.
    public var suggestedModels: [String] {
        switch self {
        case .claude:
            return ["claude-sonnet-5-5", "claude-opus-5-5", "claude-haiku-5-5"]
        case .gemini:
            return ["gemini-2.5-flash", "gemini-2.5-pro"]
        }
    }

    public var displayName: String {
        switch self {
        case .claude:
            return "Claude"
        case .gemini:
            return "Gemini"
        }
    }
}

public enum AIError: Error, LocalizedError, Sendable, Equatable {
    case missingKey
    case http(status: Int, message: String)
    case badResponse
    case badPlan(String)
    case truncated

    public var errorDescription: String? {
        switch self {
        case .missingKey:
            return "API key is required"
        case .http(let status, let message):
            if status == 401 || status == 403 {
                return "The API key was rejected"
            }
            if status == 429 {
                return "The rate limit is reached"
            }
            let truncated = message.count > 200 ? String(message.prefix(200)) : message
            if truncated.isEmpty {
                return "HTTP error \(status)"
            }
            return "HTTP \(status): \(truncated)"
        case .badResponse:
            return "Invalid response from AI provider"
        case .badPlan(let message):
            return message
        case .truncated:
            return "The AI answer was cut off. Try a shorter description."
        }
    }
}

public protocol AIChatClient: Sendable {
    func complete(system: String, user: String) async throws -> String
}

public struct ClaudeClient: AIChatClient {
    public let apiKey: String
    public let model: String
    public let session: URLSession

    public init(apiKey: String, model: String = AIProviderKind.claude.defaultModel, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    public func complete(system: String, user: String) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AIError.badResponse
        }
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 8192,
            "system": system,
            "messages": [
                ["role": "user", "content": user]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.badResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            var message = ""
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorObj = json["error"] as? [String: Any],
               let msg = errorObj["message"] as? String {
                message = msg
            }
            throw AIError.http(status: httpResponse.statusCode, message: message)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw AIError.badResponse
        }

        if (json["stop_reason"] as? String) == "max_tokens" {
            throw AIError.truncated
        }

        let answer = content
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined()

        guard !answer.isEmpty else {
            throw AIError.badResponse
        }
        return answer
    }
}

public struct GeminiClient: AIChatClient {
    public let apiKey: String
    public let model: String
    public let session: URLSession

    public init(apiKey: String, model: String = AIProviderKind.gemini.defaultModel, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    public func complete(system: String, user: String) async throws -> String {
        let escapedModel = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? model
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(escapedModel):generateContent") else {
            throw AIError.badResponse
        }
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let payload: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": system]]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": [["text": user]]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "maxOutputTokens": 8192,
                "thinkingConfig": ["thinkingBudget": 0]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.badResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            var message = ""
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorObj = json["error"] as? [String: Any],
               let msg = errorObj["message"] as? String {
                message = msg
            }
            throw AIError.http(status: httpResponse.statusCode, message: message)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw AIError.badResponse
        }

        if (firstCandidate["finishReason"] as? String) == "MAX_TOKENS" {
            throw AIError.truncated
        }

        let answer = parts.compactMap { $0["text"] as? String }.joined()
        guard !answer.isEmpty else {
            throw AIError.badResponse
        }
        return answer
    }
}

public func makeAIClient(kind: AIProviderKind, apiKey: String, model: String?) throws -> AIChatClient {
    let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedKey.isEmpty else {
        throw AIError.missingKey
    }
    let chosenModel: String
    if let model = model?.trimmingCharacters(in: .whitespacesAndNewlines), !model.isEmpty {
        chosenModel = model
    } else {
        chosenModel = kind.defaultModel
    }
    switch kind {
    case .claude:
        return ClaudeClient(apiKey: trimmedKey, model: chosenModel)
    case .gemini:
        return GeminiClient(apiKey: trimmedKey, model: chosenModel)
    }
}

/// Stands in for the AI: returns a saved reply, so the Modrinth side can be tested without a key.
public struct SavedAnswerClient: AIChatClient {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public func complete(system: String, user: String) async throws -> String { text }
}
