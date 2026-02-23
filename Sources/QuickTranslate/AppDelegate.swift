import AppKit
import Carbon
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem!
    var hotkeyManager: HotkeyManager!

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupHotkey()
        DispatchQueue.main.async { [weak self] in
            self?.checkAccessibilityPermissions()
        }
    }

    // MARK: Accessibility

    private func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.title = "翻"
            button.font = NSFont.monospacedSystemFont(ofSize: 16, weight: .medium)
            button.imagePosition = .noImage
        }

        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "QuickTranslate v1.0", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        let shortcutItem = NSMenuItem(title: "⌘⇧T to translate selected text", action: nil, keyEquivalent: "")
        shortcutItem.isEnabled = false
        menu.addItem(shortcutItem)

        menu.addItem(NSMenuItem.separator())

        let apiKeyItem = NSMenuItem(title: "Set API Key...", action: #selector(promptForAPIKey), keyEquivalent: "")
        apiKeyItem.target = self
        menu.addItem(apiKeyItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: Hotkey

    private func setupHotkey() {
        hotkeyManager = HotkeyManager { [weak self] in
            self?.handleHotkey()
        }
    }

    // MARK: Hotkey Handler

    func handleHotkey() {
        let pasteboard = NSPasteboard.general
        let previousChangeCount = pasteboard.changeCount

        simulateCopy()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let newContent = pasteboard.string(forType: .string)
            let changed = pasteboard.changeCount != previousChangeCount

            if changed, let text = newContent, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.translate(text)
            } else if let text = newContent, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.translate(text)
            } else {
                PopupWindow.showError("テキストを選択してから ⌘⇧T を押してください。")
            }
        }
    }

    private func simulateCopy() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)
    }

    private func translate(_ text: String) {
        TranslationService.shared.translate(text) { result in
            switch result {
            case .success(let translation):
                PopupWindow.show(
                    original: text,
                    translated: translation.translatedText,
                    sourceLang: translation.sourceLangDisplay,
                    targetLang: translation.targetLangDisplay
                )
            case .failure(let error):
                PopupWindow.showError(error.localizedDescription)
            }
        }
    }

    // MARK: Menu Actions

    @objc private func promptForAPIKey() {
        let alert = NSAlert()
        alert.messageText = "Set OpenAI API Key"
        alert.informativeText = "Enter your OpenAI API key. It will be stored locally in app preferences."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let inputField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        inputField.placeholderString = "sk-..."
        if let existing = UserDefaults.standard.string(forKey: "openai_api_key"), !existing.isEmpty {
            inputField.stringValue = existing
        }
        alert.accessoryView = inputField

        NSApp.activate(ignoringOtherApps: true)
        alert.window.makeFirstResponder(inputField)

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let key = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                UserDefaults.standard.set(key, forKey: "openai_api_key")
            }
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
