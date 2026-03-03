import SwiftUI

@main
struct QuickTranslateApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var showCopyToast = false
    @State private var copiedText = ""

    var body: some Scene {
        WindowGroup {
            ContentView()
                .overlay {
                    if showCopyToast {
                        CopyToast(text: copiedText)
                    }
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        checkPendingCopy()
                    }
                }
                .onOpenURL { url in
                    if url.scheme == "quicktranslate", url.host == "copy" {
                        checkPendingCopy()
                    }
                }
        }
    }

    private func checkPendingCopy() {
        let shared = UserDefaults(suiteName: "group.com.quicktranslate.shared")
        guard let text = shared?.string(forKey: "pendingCopy"), !text.isEmpty else { return }

        UIPasteboard.general.string = text
        shared?.removeObject(forKey: "pendingCopy")

        copiedText = text
        withAnimation { showCopyToast = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { showCopyToast = false }
        }
    }
}

struct CopyToast: View {
    let text: String

    var body: some View {
        VStack {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("コピーしました")
                        .fontWeight(.semibold)
                        .font(.subheadline)
                }
                Text(text)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .shadow(radius: 8)
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.top, 60)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
