import AppKit

class PopupWindow {

    private static var panel: NSPanel?
    private static var globalMonitor: Any?
    private static var localMonitor: Any?

    // MARK: - Public API

    /// Shows the translation result in a floating panel.
    static func show(original: String, translated: String, sourceLang: String, targetLang: String) {
        // Dismiss any existing panel first.
        hide()

        // --- Panel ---

        let panelWidth: CGFloat  = 420
        let panelHeight: CGFloat = 280

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.titled, .closable, .fullSizeContentView, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .utilityWindow
        panel.center()

        // --- Background (vibrancy) ---

        let visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))
        visualEffect.material = .popover
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.autoresizingMask = [.width, .height]
        panel.contentView = visualEffect

        // --- Content stack ---

        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 10
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.edgeInsets = NSEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        visualEffect.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: visualEffect.topAnchor, constant: 28),
            contentStack.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
        ])

        // 1. Language direction label
        let langLabel = makeLabel("\(sourceLang)  \u{2192}  \(targetLang)", size: 11, weight: .medium, color: .secondaryLabelColor)
        contentStack.addArrangedSubview(langLabel)

        // 2. Original text
        let originalField = makeWrappingLabel(original, size: 13, weight: .regular, color: .secondaryLabelColor, maxLines: 3)
        contentStack.addArrangedSubview(originalField)

        // 3. Separator
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalTo: contentStack.widthAnchor, constant: -40).isActive = true

        // 4. Translated text
        let translatedField = makeWrappingLabel(translated, size: 15, weight: .semibold, color: .textColor, maxLines: 6)
        contentStack.addArrangedSubview(translatedField)

        // Spacer to push buttons to the bottom
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        contentStack.addArrangedSubview(spacer)

        // 5. Bottom button bar
        let buttonBar = NSStackView()
        buttonBar.orientation = .horizontal
        buttonBar.spacing = 10
        buttonBar.translatesAutoresizingMaskIntoConstraints = false

        let copyButton  = makeButton(title: "Copy", action: #selector(PopupActions.copyTranslation(_:)))
        copyButton.tag = 1
        let closeButton = makeButton(title: "Close", action: #selector(PopupActions.closePanel(_:)))

        // Store the translated text in the copy button's identifier so we can retrieve it.
        copyButton.identifier = NSUserInterfaceItemIdentifier(translated)

        buttonBar.addArrangedSubview(NSView()) // leading spacer
        buttonBar.addArrangedSubview(copyButton)
        buttonBar.addArrangedSubview(closeButton)
        contentStack.addArrangedSubview(buttonBar)
        buttonBar.widthAnchor.constraint(equalTo: contentStack.widthAnchor, constant: -40).isActive = true

        // --- Show ---

        panel.orderFrontRegardless()
        self.panel = panel

        // --- Monitors ---

        // Escape to close (local monitor so it works when the panel is key)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape
                PopupWindow.hide()
                return nil
            }
            return event
        }

        // Click outside to close
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            PopupWindow.hide()
        }
    }

    /// Shows a simple error message in the popup.
    static func showError(_ message: String) {
        hide()

        let panelWidth: CGFloat  = 380
        let panelHeight: CGFloat = 160

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.titled, .closable, .fullSizeContentView, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.center()

        let visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))
        visualEffect.material = .popover
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.autoresizingMask = [.width, .height]
        panel.contentView = visualEffect

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        visualEffect.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: visualEffect.topAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
        ])

        let errorIcon = makeLabel("Error", size: 12, weight: .bold, color: .systemRed)
        stack.addArrangedSubview(errorIcon)

        let messageField = makeWrappingLabel(message, size: 13, weight: .regular, color: .textColor, maxLines: 4)
        stack.addArrangedSubview(messageField)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        stack.addArrangedSubview(spacer)

        let buttonBar = NSStackView()
        buttonBar.orientation = .horizontal
        buttonBar.spacing = 10
        buttonBar.translatesAutoresizingMaskIntoConstraints = false

        let closeButton = makeButton(title: "Close", action: #selector(PopupActions.closePanel(_:)))
        buttonBar.addArrangedSubview(NSView())
        buttonBar.addArrangedSubview(closeButton)
        stack.addArrangedSubview(buttonBar)
        buttonBar.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40).isActive = true

        panel.orderFrontRegardless()
        self.panel = panel

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                PopupWindow.hide()
                return nil
            }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            PopupWindow.hide()
        }
    }

    /// Dismisses the panel and removes event monitors.
    static func hide() {
        panel?.close()
        panel = nil
        if let gm = globalMonitor {
            NSEvent.removeMonitor(gm)
            globalMonitor = nil
        }
        if let lm = localMonitor {
            NSEvent.removeMonitor(lm)
            localMonitor = nil
        }
    }

    // MARK: - View Helpers

    private static func makeLabel(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.isSelectable = false
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private static func makeWrappingLabel(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, maxLines: Int) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = NSFont.systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.isEditable = false
        field.isSelectable = true
        field.maximumNumberOfLines = maxLines
        field.lineBreakMode = .byWordWrapping
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }

    private static func makeButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: PopupActions.shared, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
}

// MARK: - Button Actions

/// Separate class to act as the target for button actions, because
/// static methods on PopupWindow cannot be used as `@objc` selectors easily.
private class PopupActions: NSObject {
    static let shared = PopupActions()

    @objc func copyTranslation(_ sender: NSButton) {
        if let translated = sender.identifier?.rawValue, !translated.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(translated, forType: .string)
        }

        // Brief visual feedback
        let originalTitle = sender.title
        sender.title = "Copied!"
        sender.isEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            sender.title = originalTitle
            sender.isEnabled = true
        }
    }

    @objc func closePanel(_ sender: Any?) {
        PopupWindow.hide()
    }
}
