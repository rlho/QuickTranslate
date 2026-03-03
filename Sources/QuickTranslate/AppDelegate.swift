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

        let shortcutItem = NSMenuItem(title: "⌘⇧O to translate selected text", action: nil, keyEquivalent: "")
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
        let axTrusted = AXIsProcessTrusted()

        // Try Accessibility API first (doesn't touch clipboard)
        if axTrusted, let text = getSelectedTextViaAccessibility(),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            translate(text)
            return
        }

        // Fallback: simulate Cmd+C
        let pasteboard = NSPasteboard.general
        let previousChangeCount = pasteboard.changeCount

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.simulateCopy()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let newContent = pasteboard.string(forType: .string)
                let changed = pasteboard.changeCount != previousChangeCount

                if changed, let text = newContent, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.translate(text)
                } else if !axTrusted {
                    PopupWindow.showError("アクセシビリティ権限が必要です。\nシステム設定 → プライバシーとセキュリティ → アクセシビリティ で QuickTranslate を許可してください。")
                } else {
                    PopupWindow.showError("テキストを選択してから ⌘⇧O を押してください。")
                }
            }
        }
    }

    private func getSelectedTextViaAccessibility() -> String? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedApp: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success else {
            return nil
        }

        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedApp as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success else {
            return nil
        }

        var selectedText: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedText) == .success else {
            return nil
        }

        return selectedText as? String
    }

    private func simulateCopy() {
        let source = CGEventSource(stateID: .privateState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
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
        let appDefaults = UserDefaults(suiteName: "com.quicktranslate.app")
        if let existing = appDefaults?.string(forKey: "openai_api_key"), !existing.isEmpty {
            inputField.stringValue = existing
        }
        alert.accessoryView = inputField

        NSApp.activate(ignoringOtherApps: true)
        alert.window.makeFirstResponder(inputField)

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let key = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                appDefaults?.set(key, forKey: "openai_api_key")
            }
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
