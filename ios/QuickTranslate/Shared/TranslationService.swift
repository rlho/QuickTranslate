import Foundation

// MARK: - Translation Result

struct TranslationResult {
    let originalText: String
    let translatedText: String
    let sourceLang: String
    let targetLang: String

    var sourceLangDisplay: String {
        sourceLang == "en" ? "English" : "日本語"
    }

    var targetLangDisplay: String {
        targetLang == "en" ? "English" : "日本語"
    }

    var directionLabel: String {
        "\(sourceLangDisplay) → \(targetLangDisplay)"
    }
}

// MARK: - Translation Error

enum TranslationError: LocalizedError {
    case noAPIKey
    case networkError(String)
    case apiError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "APIキーが設定されていません。ホストアプリでOpenAI APIキーを設定してください。"
        case .networkError(let msg):
            return "ネットワークエラー: \(msg)"
        case .apiError(let msg):
            return "APIエラー: \(msg)"
        case .invalidResponse:
            return "APIからの不正なレスポンス"
        }
    }
}

// MARK: - OpenAI API Types

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let max_tokens: Int
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]
    struct Choice: Decodable {
        let message: ChatMessage
    }
}

private struct APIErrorResponse: Decodable {
    let error: APIErrorDetail
    struct APIErrorDetail: Decodable {
        let message: String
    }
}

// MARK: - Translation Service

class TranslationService {
    static let shared = TranslationService()

    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let model = "gpt-4o-mini"

    private let enToJaPrompt = "You are a translator. Translate the following English text to natural Japanese. Output ONLY the translation, nothing else."
    private let jaToEnPrompt = "You are a translator. Translate the following Japanese text to natural, casual English. Output ONLY the translation, nothing else."

    private init() {}

    // MARK: - Public API (async/await)

    func translate(_ text: String) async throws -> TranslationResult {
        guard let apiKey = KeychainHelper.loadAPIKey() else {
            throw TranslationError.noAPIKey
        }

        let sourceLang = detectLanguage(text)
        let targetLang = sourceLang == "en" ? "ja" : "en"
        let systemPrompt = sourceLang == "en" ? enToJaPrompt : jaToEnPrompt

        let requestBody = ChatCompletionRequest(
            model: model,
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: text),
            ],
            temperature: 0.3,
            max_tokens: 2000
        )

        let bodyData = try JSONEncoder().encode(requestBody)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = parseAPIError(from: data, statusCode: httpResponse.statusCode)
            throw TranslationError.apiError(errorMessage)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw TranslationError.invalidResponse
        }

        return TranslationResult(
            originalText: text,
            translatedText: content.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceLang: sourceLang,
            targetLang: targetLang
        )
    }

    // MARK: - Language Detection

    func detectLanguage(_ text: String) -> String {
        var japaneseCount = 0
        var significantCount = 0

        for scalar in text.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) { continue }
            if CharacterSet.punctuationCharacters.contains(scalar) { continue }

            significantCount += 1

            let value = scalar.value
            if (0x3040...0x309F).contains(value) ||  // Hiragana
               (0x30A0...0x30FF).contains(value) ||  // Katakana
               (0x4E00...0x9FFF).contains(value) {   // CJK
                japaneseCount += 1
            }
        }

        guard significantCount > 0 else { return "en" }
        let japaneseRatio = Double(japaneseCount) / Double(significantCount)
        return japaneseRatio > 0.2 ? "ja" : "en"
    }

    // MARK: - Private

    private func parseAPIError(from data: Data, statusCode: Int) -> String {
        if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            return "(\(statusCode)) \(errorResponse.error.message)"
        }
        if let bodyString = String(data: data, encoding: .utf8), !bodyString.isEmpty {
            return "(\(statusCode)) \(bodyString)"
        }
        return "HTTP \(statusCode)"
    }
}
