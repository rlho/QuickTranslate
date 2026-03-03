import AppIntents
import Foundation
import UIKit

struct TranslateTextIntent: AppIntent, ForegroundContinuableIntent {
    static var title: LocalizedStringResource = "テキストを翻訳"
    static var description = IntentDescription("テキストを英語↔日本語に翻訳します")

    @Parameter(title: "テキスト")
    var text: String

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard !text.isEmpty else {
            return .result(value: "", dialog: "テキストが空です")
        }

        guard KeychainHelper.loadAPIKey() != nil else {
            return .result(value: "", dialog: "APIキーが未設定です。QuickTranslateアプリで設定してください。")
        }

        let result: TranslationResult
        do {
            result = try await TranslationService.shared.translate(text)
        } catch {
            return .result(value: "", dialog: IntentDialog(stringLiteral: "翻訳エラー: \(error.localizedDescription)"))
        }

        // 共有ストレージに保存
        let shared = UserDefaults(suiteName: "group.com.quicktranslate.shared")
        shared?.set(result.translatedText, forKey: "pendingCopy")

        // 確認ダイアログで翻訳結果を表示（Copy / Done）
        do {
            try await requestConfirmation(
                result: .result(
                    value: result.translatedText,
                    dialog: IntentDialog(stringLiteral: result.translatedText)
                ),
                confirmationActionName: .custom(acceptLabel: "Copy", acceptAlternatives: [], denyLabel: "Done", denyAlternatives: [], destructive: false)
            )
        } catch {
            // ユーザーがDoneを押した → pendingCopy削除して終了
            shared?.removeObject(forKey: "pendingCopy")
            return .result(value: result.translatedText, dialog: IntentDialog(stringLiteral: result.translatedText))
        }

        // ユーザーがCopyを押した → アプリをフォアグラウンドに移行してコピー
        // pendingCopyはUserDefaultsに保存済み。アプリ側のcheckPendingCopy()でコピー＋トースト表示
        try await requestToContinueInForeground()

        UIPasteboard.general.string = result.translatedText
        shared?.removeObject(forKey: "pendingCopy")

        return .result(value: result.translatedText, dialog: "コピーしました")
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
