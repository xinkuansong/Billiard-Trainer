import SwiftUI
import UIKit

/// Shared sizing for keyboard dismissal in SwiftUI and UIKit.
enum BTKeyboardDismissMetrics {
    static let symbolSize: CGFloat = 24
    static let buttonWidth: CGFloat = 56
    static let buttonHeight: CGFloat = 44
    static let symbolName = "keyboard.chevron.compact.down"
}

/// Number only explicit Return presses. Wrapping, paste and marked-text composition stay native.
enum NoteNumbering {
    struct Edit {
        let range: NSRange
        let replacement: String
    }

    static func edit(text: String, range: NSRange, replacement: String) -> Edit? {
        let source = text as NSString
        guard range.location <= source.length, NSMaxRange(range) <= source.length else { return nil }
        let lineRange = source.lineRange(for: NSRange(location: range.location, length: 0))
        let line = source.substring(with: lineRange).trimmingCharacters(in: .newlines)
        guard let match = line.range(of: "^[0-9]+\\. ", options: .regularExpression),
              let number = Int(line[match].dropLast(2)), number < Int.max else { return nil }
        let prefixLength = String(line[match]).utf16.count
        let isEmpty = line[match.upperBound...].trimmingCharacters(in: .whitespaces).isEmpty
        if replacement == "\n" {
            if isEmpty {
                return Edit(range: NSRange(location: lineRange.location, length: line.utf16.count), replacement: "")
            }
            guard range.location >= lineRange.location + prefixLength else { return nil }
            return Edit(range: range, replacement: "\n\(number + 1). ")
        }
        if replacement.isEmpty, range.length == 1, isEmpty,
           NSMaxRange(range) == lineRange.location + prefixLength {
            return Edit(range: NSRange(location: lineRange.location, length: prefixLength), replacement: "")
        }
        return nil
    }
}

struct BTNumberedNoteEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var expandsWithContent = false
    var identifier: String
    var dismissIdentifier: String? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        // Match Typography.btCallout / btBody, which use the standard 16 / 17 pt scale.
        view.font = UIFont.preferredFont(forTextStyle: expandsWithContent ? .callout : .body,
                                        compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
        view.adjustsFontForContentSizeCategory = false
        view.textColor = UIColor(named: "btText") ?? .label
        view.tintColor = UIColor(named: "btPrimary") ?? .systemGreen
        view.isScrollEnabled = !expandsWithContent
        view.keyboardDismissMode = .interactive
        view.textContainerInset = expandsWithContent ? .zero : UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        view.textContainer.lineFragmentPadding = 0
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.accessibilityIdentifier = identifier
        view.text = text
        if let dismissIdentifier {
            let toolbar = UIToolbar()
            toolbar.sizeToFit()
            toolbar.tintColor = view.tintColor
            let dismiss = UIButton(type: .system)
            dismiss.tintColor = view.tintColor
            dismiss.setImage(UIImage(systemName: BTKeyboardDismissMetrics.symbolName,
                                     withConfiguration: UIImage.SymbolConfiguration(
                                        pointSize: BTKeyboardDismissMetrics.symbolSize, weight: .semibold)), for: .normal)
            dismiss.addTarget(context.coordinator, action: #selector(Coordinator.dismissKeyboard), for: .touchUpInside)
            NSLayoutConstraint.activate([
                dismiss.widthAnchor.constraint(equalToConstant: BTKeyboardDismissMetrics.buttonWidth),
                dismiss.heightAnchor.constraint(equalToConstant: BTKeyboardDismissMetrics.buttonHeight)
            ])
            dismiss.accessibilityLabel = "收起键盘"
            dismiss.accessibilityIdentifier = dismissIdentifier
            toolbar.items = [UIBarButtonItem(systemItem: .flexibleSpace), UIBarButtonItem(customView: dismiss)]
            view.inputAccessoryView = toolbar
        }
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        if view.markedTextRange == nil, view.text != text {
            let selection = view.selectedRange
            view.text = text
            view.selectedRange = NSRange(location: min(selection.location, (text as NSString).length), length: 0)
        }
        if isFocused && !view.isFirstResponder {
            DispatchQueue.main.async { [weak view] in
                guard context.coordinator.parent.isFocused else { return }
                view?.becomeFirstResponder()
            }
        } else if !isFocused && view.isFirstResponder {
            view.resignFirstResponder()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard expandsWithContent, let width = proposal.width else { return nil }
        return CGSize(width: width, height: max(28, uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: BTNumberedNoteEditor
        weak var view: UITextView?
        private var seededEmptyNote = false
        init(_ parent: BTNumberedNoteEditor) { self.parent = parent }

        @objc func dismissKeyboard() { view?.resignFirstResponder() }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused = true
            if textView.text.isEmpty {
                seededEmptyNote = true
                textView.text = "1. "
                textView.selectedRange = NSRange(location: 3, length: 0)
                parent.text = textView.text
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if seededEmptyNote && textView.text == "1. " { textView.text = "" }
            parent.text = textView.text
            parent.isFocused = false
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            textView.invalidateIntrinsicContentSize()
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard textView.markedTextRange == nil,
                  let edit = NoteNumbering.edit(text: textView.text, range: range, replacement: text) else { return true }
            let updated = (textView.text as NSString).replacingCharacters(in: edit.range, with: edit.replacement)
            apply(updated, selection: NSRange(location: edit.range.location + edit.replacement.utf16.count, length: 0), to: textView)
            return false
        }

        private func apply(_ text: String, selection: NSRange, to textView: UITextView) {
            let oldText = textView.text ?? ""
            let oldSelection = textView.selectedRange
            textView.undoManager?.registerUndo(withTarget: self) { [weak textView] target in
                guard let textView else { return }
                target.apply(oldText, selection: oldSelection, to: textView)
            }
            textView.text = text
            textView.selectedRange = selection
            textViewDidChange(textView)
            textView.scrollRangeToVisible(selection)
        }
    }
}
