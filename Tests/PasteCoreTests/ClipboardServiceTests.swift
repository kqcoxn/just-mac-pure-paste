import AppKit
import Testing
@testable import PasteCore

@Suite @MainActor
struct ClipboardServiceTests {
    private func withClipboard(_ body: (NSPasteboard, ClipboardService) throws -> Void) rethrows {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        try body(board, ClipboardService(pasteboard: board))
    }

    @Test func stripsFormattingAndPreservesUnicodeWhitespace() throws {
        try withClipboard { board, service in
            let text = "  中文 👨‍👩‍👧‍👦 e\u{301}\n\t第二行\r\n "
            board.setString(text, forType: .string)
            board.setString("<b>unrelated markup</b>", forType: .html)
            let value = try service.readText().get()
            #expect(value == text)
            #expect(service.writeText(value))
            #expect(board.types?.contains(.string) == true)
            // AppKit adds the legacy NSStringPboardType alias on some system versions.
            #expect(board.types?.allSatisfy { $0 == .string || $0.rawValue == "NSStringPboardType" } == true)
            #expect(board.string(forType: .string) == text)
        }
    }

    @Test func convertsRTFOnly() throws {
        try withClipboard { board, service in
            let value = NSAttributedString(string: "富文本\nHello", attributes: [.foregroundColor: NSColor.red])
            let data = try value.data(from: NSRange(location: 0, length: value.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
            board.setData(data, forType: .rtf)
            let text = try service.readText().get()
            #expect(text == "富文本\nHello")
        }
    }

    @Test(arguments: ["empty", "image", "file", "emptyString"])
    func ignoresNonTextWithoutMutation(_ kind: String) {
        withClipboard { board, service in
            switch kind {
            case "image": board.setData(Data([1, 2, 3]), forType: .png)
            case "file":
                board.setString("file:///tmp/example.txt", forType: .fileURL)
                board.setString("example.txt", forType: .string)
            case "emptyString": board.setString("", forType: .string)
            default: break
            }
            let version = board.changeCount
            let types = board.types
            switch service.readText() {
            case .failure(let error): #expect(error.result == .noText)
            case .success: Issue.record("Non-text clipboard should not yield text")
            }
            #expect(board.changeCount == version)
            #expect(board.types == types)
        }
    }

    @Test func mixedImageAndTextUsesText() throws {
        try withClipboard { board, service in
            board.setData(Data([1, 2, 3]), forType: .png)
            board.setString("caption", forType: .string)
            let text = try service.readText().get()
            #expect(text == "caption")
        }
    }
}
