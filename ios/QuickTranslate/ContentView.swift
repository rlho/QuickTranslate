import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var apiKey: String = ""
    @State private var isSaved = false
    @State private var showKey = false
    @State private var translationResult: String?
    @State private var translationError: String?
    @State private var copied = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("QuickTranslate")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("英語 ↔ 日本語 翻訳")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section(header: Text("OpenAI API Key")) {
                    HStack {
                        if showKey {
                            TextField("sk-...", text: $apiKey)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .font(.system(.body, design: .monospaced))
                        } else {
                            SecureField("sk-...", text: $apiKey)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        Button(action: { showKey.toggle() }) {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: saveAPIKey) {
                        HStack {
                            Image(systemName: isSaved ? "checkmark.circle.fill" : "key.fill")
                            Text(isSaved ? "保存しました" : "APIキーを保存")
                        }
                    }
                    .disabled(apiKey.isEmpty)
                }

                Section(header: Text("使い方")) {
                    VStack(alignment: .leading, spacing: 16) {
                        StepRow(number: 1, text: "翻訳したいテキストをコピー")
                        StepRow(number: 2, text: "iPhoneの背面をダブルタップ")
                        StepRow(number: 3, text: "翻訳結果が表示される")
                        StepRow(number: 4, text: "「コピー」ボタンで結果をコピー")
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            loadAPIKey()
            checkPendingResult()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                checkPendingResult()
            }
        }
        .sheet(isPresented: .init(
            get: { translationResult != nil || translationError != nil },
            set: { if !$0 { translationResult = nil; translationError = nil; copied = false } }
        )) {
            TranslationResultSheet(
                result: translationResult,
                error: translationError,
                copied: $copied
            )
        }
    }

    private func saveAPIKey() {
        KeychainHelper.save(apiKey: apiKey)
        isSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isSaved = false
        }
    }

    private func loadAPIKey() {
        if let key = KeychainHelper.loadAPIKey() {
            apiKey = key
        }
    }

    private func checkPendingResult() {
        if let text = UserDefaults.standard.string(forKey: "pendingTranslation") {
            translationResult = text
            UserDefaults.standard.removeObject(forKey: "pendingTranslation")
            UserDefaults.standard.removeObject(forKey: "pendingOriginal")
        }
        if let error = UserDefaults.standard.string(forKey: "pendingError") {
            translationError = error
            UserDefaults.standard.removeObject(forKey: "pendingError")
        }
    }
}

struct TranslationResultSheet: View {
    let result: String?
    let error: String?
    @Binding var copied: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if let error = error {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else if let result = result {
                    Text(result)
                        .font(.title3)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                    Button(action: {
                        UIPasteboard.general.string = result
                        copied = true
                    }) {
                        HStack {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            Text(copied ? "コピーしました" : "コピー")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("翻訳結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct StepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
        }
    }
}
