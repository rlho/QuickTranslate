import Foundation

// MARK: - Translation Result

struct TranslationResult {
    let originalText: String
    let translatedText: String
    let sourceLang: String  // "en" or "ja"
    let targetLang: String  // "ja" or "en"

    var sourceLangDisplay: String {
        sourceLang == "en" ? "English" : "日本語"
    }

    var targetLangDisplay: String {
        targetLang == "en" ? "English" : "日本語"
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
            return "OpenAI API key not set. Click the menu bar icon '翻' → 'Set API Key...' to configure."
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .apiError(let msg):
            return "API error: \(msg)"
        case .invalidResponse:
            return "Invalid response from API"
        }
    }
}

// MARK: - OpenAI API Codable Types

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
        let type: String?
        let code: String?
    }
}

// MARK: - Translation Service

class TranslationService {
    static let shared = TranslationService()

    private let session: URLSession
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let model = "gpt-4o-mini"

    private let enToJaPrompt = "You are a translator. Translate the following English text to natural Japanese. Output ONLY the translation, nothing else."
    private let jaToEnPrompt = "You are a translator. Translate the following Japanese text to natural, casual English. Output ONLY the translation, nothing else."

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Translates the given text, auto-detecting the source language.
    /// The completion handler is always called on the main thread.
    func translate(_ text: String, completion: @escaping (Result<TranslationResult, Error>) -> Void) {
        // 1. Resolve API key
        guard let apiKey = resolveAPIKey() else {
            DispatchQueue.main.async {
                completion(.failure(TranslationError.noAPIKey))
            }
            return
        }

        // 2. Detect language
        let sourceLang = detectLanguage(text)
        let targetLang = sourceLang == "en" ? "ja" : "en"
        let systemPrompt = sourceLang == "en" ? enToJaPrompt : jaToEnPrompt

        // 3. Build the request
        let requestBody = ChatCompletionRequest(
            model: model,
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: text)
            ],
            temperature: 0.3,
            max_tokens: 2000
        )

        let bodyData: Data
        do {
            bodyData = try JSONEncoder().encode(requestBody)
        } catch {
            DispatchQueue.main.async {
                completion(.failure(TranslationError.networkError("Failed to encode request: \(error.localizedDescription)")))
            }
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        // 4. Send the request
        let task = session.dataTask(with: request) { data, response, error in
            // Handle network-level errors
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(TranslationError.networkError(error.localizedDescription)))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(TranslationError.invalidResponse))
                }
                return
            }

            // Handle non-200 status codes
            guard httpResponse.statusCode == 200 else {
                let errorMessage = self.parseAPIError(from: data, statusCode: httpResponse.statusCode)
                DispatchQueue.main.async {
                    completion(.failure(TranslationError.apiError(errorMessage)))
                }
                return
            }

            // 5. Parse the successful response
            do {
                let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
                guard let content = decoded.choices.first?.message.content else {
                    DispatchQueue.main.async {
                        completion(.failure(TranslationError.invalidResponse))
                    }
                    return
                }

                let result = TranslationResult(
                    originalText: text,
                    translatedText: content.trimmingCharacters(in: .whitespacesAndNewlines),
                    sourceLang: sourceLang,
                    targetLang: targetLang
                )

                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(TranslationError.invalidResponse))
                }
            }
        }

        task.resume()
    }

    // MARK: - Language Detection

    /// Detects whether the text is primarily Japanese or English.
    ///
    /// Counts characters that fall into Japanese Unicode ranges (Hiragana, Katakana,
    /// CJK Unified Ideographs) among all non-space, non-punctuation characters.
    /// If more than 20% are Japanese, the text is classified as Japanese.
    func detectLanguage(_ text: String) -> String {
        var japaneseCount = 0
        var significantCount = 0

        for scalar in text.unicodeScalars {
            // Skip whitespace and common punctuation
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                continue
            }
            if CharacterSet.punctuationCharacters.contains(scalar) {
                continue
            }

            significantCount += 1

            // Hiragana: U+3040 - U+309F
            // Katakana: U+30A0 - U+30FF
            // CJK Unified Ideographs: U+4E00 - U+9FFF
            let value = scalar.value
            if (0x3040...0x309F).contains(value) ||
               (0x30A0...0x30FF).contains(value) ||
               (0x4E00...0x9FFF).contains(value) {
                japaneseCount += 1
            }
        }

        guard significantCount > 0 else {
            return "en"
        }

        let japaneseRatio = Double(japaneseCount) / Double(significantCount)
        return japaneseRatio > 0.2 ? "ja" : "en"
    }

    // MARK: - Private Helpers

    /// Resolves the OpenAI API key from UserDefaults first, then environment variable.
    private func resolveAPIKey() -> String? {
        // Try UserDefaults first
        if let key = UserDefaults.standard.string(forKey: "openai_api_key"), !key.isEmpty {
            return key
        }

        // Fall back to environment variable
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty {
            return key
        }

        return nil
    }

    /// Attempts to extract a human-readable error message from an API error response.
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
