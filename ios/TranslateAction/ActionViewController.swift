import UIKit
import SwiftUI
import MobileCoreServices

class ActionViewController: UIViewController {
    private var inputText: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        extractText { [weak self] text in
            guard let self = self else { return }
            self.inputText = text ?? ""
            self.setupSwiftUIView()
        }
    }

    private func setupSwiftUIView() {
        let translateView = TranslateActionView(
            inputText: inputText,
            onDone: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            }
        )

        let hostingController = UIHostingController(rootView: translateView)
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        hostingController.didMove(toParent: self)
    }

    private func extractText(completion: @escaping (String?) -> Void) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            completion(nil)
            return
        }

        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(kUTTypePlainText as String) {
                    provider.loadItem(forTypeIdentifier: kUTTypePlainText as String, options: nil) { item, _ in
                        DispatchQueue.main.async {
                            completion(item as? String)
                        }
                    }
                    return
                }
            }
        }
        completion(nil)
    }
}
