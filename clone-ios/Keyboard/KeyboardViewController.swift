import UIKit
import SwiftUI

@objc(KeyboardViewController)
final class KeyboardViewController: UIInputViewController {
    private var hostingController: UIHostingController<AnyView>?
    private var heightConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Theme.keyboardBackground)

        let panel = KeyboardPanel(
            isExtension: true,
            hasFullAccess: hasFullAccess,
            onInsert: { [weak self] text in
                self?.textDocumentProxy.insertText(text)
            },
            onDelete: { [weak self] in
                self?.textDocumentProxy.deleteBackward()
            },
            onSpace: { [weak self] in
                self?.textDocumentProxy.insertText(" ")
            },
            onReturn: { [weak self] in
                self?.textDocumentProxy.insertText("\n")
            },
            onOpenApp: { [weak self] in
                self?.openContainingApp()
            },
            contextProvider: { [weak self] in
                self?.textDocumentProxy.documentContextBeforeInput ?? ""
            }
        )

        let host = UIHostingController(rootView: AnyView(panel))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let height = CGFloat(SharedStore.double(SharedKeys.height))
        let constraint = view.heightAnchor.constraint(equalToConstant: max(280, min(390, height)))
        constraint.priority = UILayoutPriority(999)
        constraint.isActive = true
        heightConstraint = constraint
        hostingController = host
        SharedStore.set(SharedKeys.keyboardSeen, true)
        SharedStore.set(SharedKeys.keyboardFullAccess, hasFullAccess)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        SharedStore.set(SharedKeys.keyboardFullAccess, hasFullAccess)
        let height = CGFloat(SharedStore.double(SharedKeys.height))
        heightConstraint?.constant = max(280, min(390, height))
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        hostingController?.view.frame = view.bounds
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        // The SwiftUI panel owns candidate state; host changes only affect the
        // surrounding document, so no controller-side rebuild is required.
    }

    private func openContainingApp() {
        guard let url = URL(string: "wetype://keyboard") else { return }
        extensionContext?.open(url) { _ in }
    }
}
