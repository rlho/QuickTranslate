import AppIntents
import UIKit

struct TranslateTextIntent: AppIntent {
    static var title: LocalizedStringResource = "テキストを翻訳"
    static var description = IntentDescription("テキストを英語↔日本語に翻訳します")

    @Parameter(title: "テキスト")
    var text: String

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard !text.isEmpty else {
            return .result(value: "", dialog: "テキストが空です")
        }

        guard KeychainHelper.loadAPIKey() != nil else {
            return .result(value: "", dialog: "APIキーが未設定です。QuickTranslateアプリで設定してください。")
        }

        do {
            let result = try await TranslationService.shared.translate(text)
            return .result(value: result.translatedText, dialog: IntentDialog(stringLiteral: result.translatedText))
        } catch {
            return .result(value: "", dialog: IntentDialog(stringLiteral: "翻訳エラー: \(error.localizedDescription)"))
        }
    }
}

struct QuickTranslateShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TranslateTextIntent(),
            phrases: [
                "Translate with \(.applicationName)",
            ],
            shortTitle: "翻訳",
            systemImageName: "text.bubble"
        )
    }
}
