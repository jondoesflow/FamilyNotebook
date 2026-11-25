import SwiftUI
import UIKit

/// A calm, menu-free writing surface: format with the bar above the keyboard,
/// tap ☐ to tick a to-do, and lists continue when you press return.
struct RichTextEditor: UIViewRepresentable {
    @Binding var text: NSAttributedString
    var isEditable: Bool = true
    var onFocusChange: (Bool) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.isScrollEnabled = false
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.allowsEditingTextAttributes = true
        tv.adjustsFontForContentSizeCategory = false
        tv.typingAttributes = Typography.typing
        tv.attributedText = text
        tv.tintColor = Theme.uiAccent
        tv.keyboardDismissMode = .interactive
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.inputAccessoryView = context.coordinator.makeToolbar()
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        tv.addGestureRecognizer(tap)
        context.coordinator.textView = tv
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        context.coordinator.parent = self
        tv.isEditable = isEditable
        if !context.coordinator.isEditing, !tv.attributedText.isEqual(to: text) {
            tv.attributedText = text
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width - 40
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(size.height, 160))
    }

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: RichTextEditor
        weak var textView: UITextView?
        var isEditing = false
        private var buttons: [String: UIButton] = [:]

        init(_ parent: RichTextEditor) { self.parent = parent }

        // MARK: Delegate

        func textViewDidBeginEditing(_ textView: UITextView) {
            isEditing = true
            parent.onFocusChange(true)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isEditing = false
            parent.onFocusChange(false)
            push(textView)
        }

        func textViewDidChange(_ textView: UITextView) {
            redecorate(textView)
            push(textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            refreshToolbarState()
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard text == "\n" else { return true }
            let ns = textView.textStorage.string as NSString
            let para = ns.paragraphRange(for: NSRange(location: range.location, length: 0))
            let line = ns.substring(with: para).trimmingCharacters(in: .newlines)
            let prefixes = [RichTextCodec.unchecked, RichTextCodec.checked, RichTextCodec.bullet]
            guard let prefix = prefixes.first(where: { line.hasPrefix($0 + " ") }) else {
                // Leaving a heading returns to body text.
                if (textView.typingAttributes[.nbHeading] as? Bool) == true {
                    insert("\n", in: textView, at: range, attributes: Typography.typing)
                    return false
                }
                return true
            }
            if line.count <= 2 {
                // Empty list item: end the list.
                textView.textStorage.replaceCharacters(in: NSRange(location: para.location, length: min(2, para.length)), with: "")
                textView.selectedRange = NSRange(location: para.location, length: 0)
                textViewDidChange(textView)
                return false
            }
            let next = prefix == RichTextCodec.checked ? RichTextCodec.unchecked : prefix
            insert("\n\(next) ", in: textView, at: range, attributes: Typography.typing)
            return false
        }

        private func insert(_ string: String, in tv: UITextView, at range: NSRange, attributes: [NSAttributedString.Key: Any]) {
            tv.textStorage.replaceCharacters(in: range, with: NSAttributedString(string: string, attributes: attributes))
            tv.selectedRange = NSRange(location: range.location + (string as NSString).length, length: 0)
            tv.typingAttributes = attributes
            textViewDidChange(tv)
        }

        private func push(_ tv: UITextView) {
            parent.text = NSAttributedString(attributedString: tv.attributedText)
        }

        private func redecorate(_ tv: UITextView) {
            let selected = tv.selectedRange
            let typing = tv.typingAttributes
            RichTextCodec.decorate(tv.textStorage)
            tv.selectedRange = selected
            tv.typingAttributes = typing
        }

        // MARK: Tap to tick

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            checkboxIndex(at: g.location(in: g.view)) != nil
        }

        private func checkboxIndex(at point: CGPoint) -> Int? {
            guard let tv = textView else { return nil }
            var p = point
            p.x -= tv.textContainerInset.left
            p.y -= tv.textContainerInset.top
            let lm = tv.layoutManager
            let glyph = lm.glyphIndex(for: p, in: tv.textContainer)
            let rect = lm.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: tv.textContainer)
            guard rect.insetBy(dx: -10, dy: -6).contains(p) else { return nil }
            let index = lm.characterIndexForGlyph(at: glyph)
            let ns = tv.textStorage.string as NSString
            guard index < ns.length else { return nil }
            let ch = ns.substring(with: NSRange(location: index, length: 1))
            guard ch == RichTextCodec.checked || ch == RichTextCodec.unchecked else { return nil }
            return index
        }

        @objc func handleTap(_ g: UITapGestureRecognizer) {
            guard let tv = textView, let index = checkboxIndex(at: g.location(in: tv)) else { return }
            let ns = tv.textStorage.string as NSString
            let current = ns.substring(with: NSRange(location: index, length: 1))
            let replacement = current == RichTextCodec.checked ? RichTextCodec.unchecked : RichTextCodec.checked
            let attrs = tv.textStorage.attributes(at: index, effectiveRange: nil)
            tv.textStorage.replaceCharacters(in: NSRange(location: index, length: 1),
                                             with: NSAttributedString(string: replacement, attributes: attrs))
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            redecorate(tv)
            push(tv)
        }

        // MARK: Toolbar

        func makeToolbar() -> UIView {
            let bar = UIInputView(frame: CGRect(x: 0, y: 0, width: 320, height: 48), inputViewStyle: .keyboard)
            bar.allowsSelfSizing = true
            let stack = UIStackView()
            stack.axis = .horizontal
            stack.distribution = .equalSpacing
            stack.alignment = .center
            stack.translatesAutoresizingMaskIntoConstraints = false

            let items: [(String, String, Selector)] = [
                ("bold", "bold", #selector(toggleBold)),
                ("italic", "italic", #selector(toggleItalic)),
                ("underline", "underline", #selector(toggleUnderline)),
                ("strike", "strikethrough", #selector(toggleStrike)),
                ("heading", "textformat.size.larger", #selector(toggleHeading)),
                ("quote", "text.quote", #selector(toggleQuote)),
                ("bullet", "list.bullet", #selector(toggleBullet)),
                ("check", "checklist", #selector(toggleChecklist)),
                ("done", "keyboard.chevron.compact.down", #selector(dismiss)),
            ]
            for (key, symbol, action) in items {
                let b = UIButton(type: .system)
                var config = UIButton.Configuration.plain()
                config.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .medium))
                config.baseForegroundColor = Theme.uiInk
                config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
                config.background.cornerRadius = 8
                b.configuration = config
                b.addTarget(self, action: action, for: .touchUpInside)
                b.accessibilityLabel = key
                buttons[key] = b
                stack.addArrangedSubview(b)
            }
            bar.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 8),
                stack.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -8),
                stack.topAnchor.constraint(equalTo: bar.topAnchor, constant: 2),
                stack.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -2),
                bar.heightAnchor.constraint(equalToConstant: 48),
            ])
            return bar
        }

        private func refreshToolbarState() {
            guard let tv = textView else { return }
            let attrs = currentAttributes(tv)
            let traits = (attrs[.font] as? UIFont)?.fontDescriptor.symbolicTraits ?? []
            let heading = (attrs[.nbHeading] as? Bool) ?? false
            let quote = (attrs[.nbQuote] as? Bool) ?? false
            setActive("bold", traits.contains(.traitBold) && !heading)
            setActive("italic", traits.contains(.traitItalic) && !quote)
            setActive("underline", ((attrs[.underlineStyle] as? Int) ?? 0) != 0)
            setActive("strike", ((attrs[.strikethroughStyle] as? Int) ?? 0) != 0)
            setActive("heading", heading)
            setActive("quote", quote)
        }

        private func setActive(_ key: String, _ on: Bool) {
            guard let b = buttons[key], var c = b.configuration else { return }
            c.baseForegroundColor = on ? Theme.uiAccent : Theme.uiInk
            c.background.backgroundColor = on ? Theme.uiAccent.withAlphaComponent(0.14) : .clear
            b.configuration = c
        }

        private func currentAttributes(_ tv: UITextView) -> [NSAttributedString.Key: Any] {
            let r = tv.selectedRange
            if r.length == 0 || tv.textStorage.length == 0 { return tv.typingAttributes }
            return tv.textStorage.attributes(at: min(r.location, tv.textStorage.length - 1), effectiveRange: nil)
        }

        /// Toggle a style on the selection (or on what you type next if nothing is selected).
        private func toggle(_ change: (inout [NSAttributedString.Key: Any], Bool) -> Void, isOn: ([NSAttributedString.Key: Any]) -> Bool) {
            guard let tv = textView else { return }
            let r = tv.selectedRange
            let turnOn = !isOn(currentAttributes(tv))
            if r.length == 0 {
                var attrs = tv.typingAttributes
                change(&attrs, turnOn)
                tv.typingAttributes = attrs
            } else {
                tv.textStorage.beginEditing()
                tv.textStorage.enumerateAttributes(in: r) { attrs, sub, _ in
                    var a = attrs
                    change(&a, turnOn)
                    tv.textStorage.setAttributes(a, range: sub)
                }
                tv.textStorage.endEditing()
                tv.selectedRange = r
                push(tv)
            }
            UISelectionFeedbackGenerator().selectionChanged()
            refreshToolbarState()
        }

        private static func rebuildFont(_ a: inout [NSAttributedString.Key: Any], bold: Bool? = nil, italic: Bool? = nil) {
            let traits = (a[.font] as? UIFont)?.fontDescriptor.symbolicTraits ?? []
            let heading = (a[.nbHeading] as? Bool) ?? false
            a[.font] = Typography.font(bold: bold ?? traits.contains(.traitBold),
                                       italic: italic ?? traits.contains(.traitItalic),
                                       heading: heading)
        }

        @objc func toggleBold() {
            toggle({ a, on in Self.rebuildFont(&a, bold: on) },
                   isOn: { (($0[.font] as? UIFont)?.fontDescriptor.symbolicTraits ?? []).contains(.traitBold) })
        }

        @objc func toggleItalic() {
            toggle({ a, on in Self.rebuildFont(&a, italic: on) },
                   isOn: { (($0[.font] as? UIFont)?.fontDescriptor.symbolicTraits ?? []).contains(.traitItalic) })
        }

        @objc func toggleUnderline() {
            toggle({ a, on in if on { a[.underlineStyle] = NSUnderlineStyle.single.rawValue } else { a.removeValue(forKey: .underlineStyle) } },
                   isOn: { (($0[.underlineStyle] as? Int) ?? 0) != 0 })
        }

        @objc func toggleStrike() {
            toggle({ a, on in if on { a[.strikethroughStyle] = NSUnderlineStyle.single.rawValue } else { a.removeValue(forKey: .strikethroughStyle) } },
                   isOn: { (($0[.strikethroughStyle] as? Int) ?? 0) != 0 })
        }

        /// Paragraph-level styles apply to whole lines.
        private func toggleParagraph(key: NSAttributedString.Key) {
            guard let tv = textView else { return }
            let ns = tv.textStorage.string as NSString
            let para = ns.paragraphRange(for: tv.selectedRange)
            let on = !((currentAttributes(tv)[key] as? Bool) ?? false)
            let heading = key == .nbHeading ? on : false
            let quote = key == .nbQuote ? on : false
            let attrs = Typography.attributes(heading: heading, quote: quote)
            if para.length > 0 {
                tv.textStorage.beginEditing()
                tv.textStorage.setAttributes(attrs, range: para)
                tv.textStorage.endEditing()
            }
            tv.typingAttributes = attrs
            redecorate(tv)
            push(tv)
            UISelectionFeedbackGenerator().selectionChanged()
            refreshToolbarState()
        }

        @objc func toggleHeading() { toggleParagraph(key: .nbHeading) }
        @objc func toggleQuote() { toggleParagraph(key: .nbQuote) }

        private func toggleLinePrefix(_ prefix: String) {
            guard let tv = textView else { return }
            let storage = tv.textStorage
            let ns = storage.string as NSString
            let para = ns.paragraphRange(for: tv.selectedRange)
            let line = ns.substring(with: para)
            let all = [RichTextCodec.unchecked, RichTextCodec.checked, RichTextCodec.bullet]
            var cursor = tv.selectedRange.location
            if let existing = all.first(where: { line.hasPrefix($0 + " ") }) {
                storage.replaceCharacters(in: NSRange(location: para.location, length: 2), with: "")
                cursor = max(para.location, cursor - 2)
                if existing != prefix && !(existing == RichTextCodec.checked && prefix == RichTextCodec.unchecked) {
                    storage.insert(NSAttributedString(string: prefix + " ", attributes: Typography.typing), at: para.location)
                    cursor += 2
                }
            } else {
                storage.insert(NSAttributedString(string: prefix + " ", attributes: Typography.typing), at: para.location)
                cursor += 2
            }
            tv.selectedRange = NSRange(location: min(cursor, storage.length), length: 0)
            tv.typingAttributes = Typography.typing
            redecorate(tv)
            push(tv)
            UISelectionFeedbackGenerator().selectionChanged()
        }

        @objc func toggleBullet() { toggleLinePrefix(RichTextCodec.bullet) }
        @objc func toggleChecklist() { toggleLinePrefix(RichTextCodec.unchecked) }
        @objc func dismiss() { textView?.resignFirstResponder() }
    }
}
