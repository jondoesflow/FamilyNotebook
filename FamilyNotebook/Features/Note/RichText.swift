import UIKit

/// The note body is stored as a list of styled runs (JSON) rather than RTF, so it
/// round-trips perfectly between devices, adapts to light/dark mode and exports to Markdown.
struct RichRun: Codable, Equatable {
    var text: String
    var b: Bool? = nil   // bold
    var i: Bool? = nil   // italic
    var u: Bool? = nil   // underline
    var s: Bool? = nil   // strikethrough
    var h: Bool? = nil   // heading
    var q: Bool? = nil   // quote
    var c: Bool? = nil   // code block
    var d: Bool? = nil   // divider
}

extension NSAttributedString.Key {
    static let nbHeading = NSAttributedString.Key("nb.heading")
    static let nbQuote = NSAttributedString.Key("nb.quote")
    static let nbCode = NSAttributedString.Key("nb.code")
    static let nbDivider = NSAttributedString.Key("nb.divider")
}

enum Typography {
    static let bodySize: CGFloat = 18
    static let headingSize: CGFloat = 24

    static func font(bold: Bool, italic: Bool, heading: Bool) -> UIFont {
        let size = heading ? headingSize : bodySize
        let base = UIFont.systemFont(ofSize: size, weight: heading ? .bold : .regular)
        var descriptor = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
        var traits: UIFontDescriptor.SymbolicTraits = []
        if bold || heading { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        if !traits.isEmpty, let d = descriptor.withSymbolicTraits(traits) { descriptor = d }
        return UIFont(descriptor: descriptor, size: size)
    }

    static let dividerText = "✦   ✦   ✦"

    static func paragraph(heading: Bool, quote: Bool, code: Bool = false, divider: Bool = false) -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        if divider {
            p.alignment = .center
            p.paragraphSpacing = 14
            p.paragraphSpacingBefore = 6
            return p
        }
        if code {
            p.lineSpacing = 3
            p.paragraphSpacing = 2
            p.firstLineHeadIndent = 12
            p.headIndent = 12
            return p
        }
        p.lineSpacing = heading ? 2 : 5
        p.paragraphSpacing = heading ? 6 : 8
        if quote {
            p.firstLineHeadIndent = 18
            p.headIndent = 18
        }
        return p
    }

    static func attributes(bold: Bool = false, italic: Bool = false, underline: Bool = false,
                           strike: Bool = false, heading: Bool = false, quote: Bool = false,
                           code: Bool = false, divider: Bool = false) -> [NSAttributedString.Key: Any] {
        if code {
            return [.font: UIFont.monospacedSystemFont(ofSize: 15, weight: .regular),
                    .foregroundColor: Theme.uiInk,
                    .backgroundColor: Theme.uiDynamic(0xEFEBE3, 0x2A2926),
                    .paragraphStyle: paragraph(heading: false, quote: false, code: true),
                    .nbCode: true]
        }
        if divider {
            return [.font: UIFont.systemFont(ofSize: 14, weight: .regular),
                    .foregroundColor: Theme.uiInkSecondary,
                    .kern: 2,
                    .paragraphStyle: paragraph(heading: false, quote: false, divider: true),
                    .nbDivider: true]
        }
        var a: [NSAttributedString.Key: Any] = [
            .font: font(bold: bold, italic: italic || quote, heading: heading),
            .foregroundColor: quote ? Theme.uiInkSecondary : Theme.uiInk,
            .paragraphStyle: paragraph(heading: heading, quote: quote),
        ]
        if underline { a[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if strike { a[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        if heading { a[.nbHeading] = true }
        if quote { a[.nbQuote] = true }
        return a
    }

    static var typing: [NSAttributedString.Key: Any] { attributes() }
}

enum RichTextCodec {
    static let unchecked = "☐"
    static let checked = "☑"
    static let bullet = "•"

    static func runs(from s: NSAttributedString) -> [RichRun] {
        var runs: [RichRun] = []
        s.enumerateAttributes(in: NSRange(location: 0, length: s.length)) { attrs, range, _ in
            let text = (s.string as NSString).substring(with: range)
            let font = attrs[.font] as? UIFont
            let traits = font?.fontDescriptor.symbolicTraits ?? []
            let heading = (attrs[.nbHeading] as? Bool) ?? false
            let quote = (attrs[.nbQuote] as? Bool) ?? false
            let code = (attrs[.nbCode] as? Bool) ?? false
            let divider = (attrs[.nbDivider] as? Bool) ?? false
            var run = RichRun(text: text)
            if code || divider {
                if code { run.c = true } else { run.d = true }
                if var last = runs.last, last.c == run.c, last.d == run.d {
                    last.text += run.text
                    runs[runs.count - 1] = last
                } else {
                    runs.append(run)
                }
                return
            }
            if traits.contains(.traitBold) && !heading { run.b = true }
            if traits.contains(.traitItalic) && !quote { run.i = true }
            if ((attrs[.underlineStyle] as? Int) ?? 0) != 0 { run.u = true }
            if ((attrs[.strikethroughStyle] as? Int) ?? 0) != 0 { run.s = true }
            if heading { run.h = true }
            if quote { run.q = true }
            if var last = runs.last, last.b == run.b, last.i == run.i, last.u == run.u,
               last.s == run.s, last.h == run.h, last.q == run.q, last.c == nil, last.d == nil {
                last.text += run.text
                runs[runs.count - 1] = last
            } else {
                runs.append(run)
            }
        }
        return runs
    }

    static func attributed(from runs: [RichRun]) -> NSAttributedString {
        let out = NSMutableAttributedString()
        for r in runs {
            out.append(NSAttributedString(string: r.text, attributes: Typography.attributes(
                bold: r.b ?? false, italic: r.i ?? false, underline: r.u ?? false,
                strike: r.s ?? false, heading: r.h ?? false, quote: r.q ?? false,
                code: r.c ?? false, divider: r.d ?? false)))
        }
        decorate(out)
        return out
    }

    static func encode(_ s: NSAttributedString) -> Data? {
        try? JSONEncoder().encode(runs(from: s))
    }

    static func decode(_ data: Data?) -> NSAttributedString {
        guard let data, let runs = try? JSONDecoder().decode([RichRun].self, from: data) else {
            return NSAttributedString(string: "", attributes: Typography.typing)
        }
        return attributed(from: runs)
    }

    /// Colours check boxes and greys out ticked lines. Purely visual.
    static func decorate(_ s: NSMutableAttributedString) {
        let ns = s.string as NSString
        guard ns.length > 0 else { return }
        s.beginEditing()
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: [.byParagraphs, .substringNotRequired]) { _, range, _, _ in
            guard range.length > 0 else { return }
            let first = ns.substring(with: NSRange(location: range.location, length: 1))
            if first == checked || first == unchecked {
                let isChecked = first == checked
                s.addAttribute(.foregroundColor, value: Theme.uiAccent, range: NSRange(location: range.location, length: 1))
                if range.length > 1 {
                    let rest = NSRange(location: range.location + 1, length: range.length - 1)
                    s.addAttribute(.foregroundColor, value: isChecked ? Theme.uiInkSecondary : Theme.uiInk, range: rest)
                    if isChecked {
                        s.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: rest)
                    } else {
                        s.removeAttribute(.strikethroughStyle, range: rest)
                    }
                }
            } else if first == bullet {
                s.addAttribute(.foregroundColor, value: Theme.uiAccent, range: NSRange(location: range.location, length: 1))
            }
        }
        s.endEditing()
    }

    static func markdown(from runs: [RichRun]) -> String {
        // Rebuild line by line so headings/quotes get their prefixes once per paragraph.
        var lines: [(String, Bool, Bool)] = [("", false, false)]
        var codeLines: Set<Int> = []
        var dividerLines: Set<Int> = []
        for r in runs {
            if r.c == true || r.d == true {
                let parts = r.text.components(separatedBy: "\n")
                for (idx, part) in parts.enumerated() {
                    if idx > 0 { lines.append(("", false, false)) }
                    lines[lines.count - 1].0 += part
                    if !part.isEmpty || idx == 0 {
                        if r.c == true { codeLines.insert(lines.count - 1) } else { dividerLines.insert(lines.count - 1) }
                    }
                }
                continue
            }
            var text = r.text
            if r.b == true { text = wrap(text, "**") }
            if r.i == true { text = wrap(text, "_") }
            if r.s == true { text = wrap(text, "~~") }
            let parts = text.components(separatedBy: "\n")
            for (idx, part) in parts.enumerated() {
                if idx > 0 { lines.append(("", false, false)) }
                lines[lines.count - 1].0 += part
                if r.h == true { lines[lines.count - 1].1 = true }
                if r.q == true { lines[lines.count - 1].2 = true }
            }
        }
        var out: [String] = []
        var inCode = false
        for (i, line) in lines.enumerated() {
            let isCode = codeLines.contains(i) && !line.0.isEmpty
            if isCode && !inCode { out.append("```"); inCode = true }
            if !isCode && inCode { out.append("```"); inCode = false }
            if isCode { out.append(line.0); continue }
            if dividerLines.contains(i) && !line.0.isEmpty { out.append("---"); continue }
            out.append(mdLine(line))
        }
        if inCode { out.append("```") }
        return out.joined(separator: "\n")
    }

    private static func mdLine(_ t: (String, Bool, Bool)) -> String {
        let (line, heading, quote) = t
        do {
            var l = line
            if l.hasPrefix(unchecked + " ") { l = "- [ ] " + l.dropFirst(2) }
            else if l.hasPrefix(checked + " ") { l = "- [x] " + l.dropFirst(2) }
            else if l.hasPrefix(bullet + " ") { l = "- " + l.dropFirst(2) }
            if heading && !l.isEmpty { l = "## " + l }
            if quote && !l.isEmpty { l = "> " + l }
            return l
        }
    }

    private static func wrap(_ text: String, _ marker: String) -> String {
        // Keep surrounding whitespace/newlines outside the markers.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let range = text.range(of: trimmed) else { return text }
        return text.replacingCharacters(in: range, with: marker + trimmed + marker)
    }
}
