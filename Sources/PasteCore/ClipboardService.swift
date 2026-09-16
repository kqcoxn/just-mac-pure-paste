import AppKit

@MainActor
package final class ClipboardService {
    private let pasteboard: NSPasteboard
    package init(pasteboard: NSPasteboard = .general) { self.pasteboard = pasteboard }
    package var version: Int { pasteboard.changeCount }

    package func readText() -> Result<String, PasteResultError> {
        // A Finder file copy can include a text filename; do not turn it into a text paste.
        let items = pasteboard.pasteboardItems ?? []
        if !items.isEmpty && items.allSatisfy({ $0.types.contains(.fileURL) }) {
            return .failure(PasteResultError(.noText))
        }
        if let text = pasteboard.string(forType: .string) {
            return text.isEmpty ? .failure(PasteResultError(.noText)) : .success(text)
        }
        // Some apps provide RTF without an explicit plain-text representation.
        if let data = pasteboard.data(forType: .rtf),
           let richText = NSAttributedString(rtf: data, documentAttributes: nil),
           !richText.string.isEmpty {
            return .success(richText.string)
        }
        if #available(macOS 15.4, *), pasteboard.accessBehavior == .alwaysDeny {
            return .failure(PasteResultError(.clipboardUnavailable))
        }
        return .failure(PasteResultError(.noText))
    }

    package func writeText(_ text: String) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}
