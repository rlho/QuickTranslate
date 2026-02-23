import SwiftUI

struct TranslateActionView: View {
    let inputText: String
    let onDone: () -> Void

    @State private var result: TranslationResult?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var copied = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else if let result = result {
                        resultView(result)
                    } else if inputText.isEmpty {
                        emptyView
                    }
                }
                .padding()
            }
            .navigationTitle("翻訳")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了", action: onDone)
                        .fontWeight(.semibold)
                }
            }
        }
        .task {
            guard !inputText.isEmpty else { return }
            await performTranslation()
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("翻訳中...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.cursor")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("テキストが選択されていません")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private func resultView(_ result: TranslationResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Direction label
            HStack {
                Image(systemName: "arrow.right")
                Text(result.directionLabel)
            }
            .font(.subheadline)
            .foregroundColor(.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)

            // Original text
            VStack(alignment: .leading, spacing: 4) {
                Text("原文")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(result.originalText)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }

            // Translated text
            VStack(alignment: .leading, spacing: 4) {
                Text("翻訳")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(result.translatedText)
                    .font(.body)
                    .fontWeight(.semibold)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }

            // Copy button
            Button(action: copyResult) {
                HStack {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    Text(copied ? "コピーしました" : "翻訳結果をコピー")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Actions

    private func performTranslation() async {
        isLoading = true
        errorMessage = nil

        do {
            result = try await TranslationService.shared.translate(inputText)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func copyResult() {
        guard let text = result?.translatedText else { return }
        UIPasteboard.general.string = text
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }
}
