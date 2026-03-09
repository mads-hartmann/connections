import Foundation

/// A single feed entry extracted from an OPML file.
struct OpmlFeedEntry {
    let url: String
    let title: String?
    let tags: [String]
}

/// Result of parsing an OPML file.
struct OpmlParseResult {
    let feeds: [OpmlFeedEntry]
}

struct OpmlParseError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Parses OPML files to extract feed URLs, titles, and folder-based tags.
final class OpmlSAXParser: NSObject, XMLParserDelegate {
    private var feeds: [OpmlFeedEntry] = []
    private var tagStack: [String] = []
    private var inBody = false
    // Tracks whether each open <outline> is a folder (true) or feed (false)
    private var outlineIsFolder: [Bool] = []

    static func parse(_ content: String) -> Result<OpmlParseResult, OpmlParseError> {
        guard let data = content.data(using: .utf8) else {
            return .failure(OpmlParseError(message: "Failed to encode OPML content"))
        }

        let xmlParser = XMLParser(data: data)
        let delegate = OpmlSAXParser()
        xmlParser.delegate = delegate

        if xmlParser.parse() {
            if delegate.feeds.isEmpty {
                return .failure(OpmlParseError(message: "No feeds found in OPML file"))
            }
            return .success(OpmlParseResult(feeds: delegate.feeds))
        } else if let error = xmlParser.parserError {
            return .failure(OpmlParseError(message: "XML parse error: \(error.localizedDescription)"))
        } else {
            return .failure(OpmlParseError(message: "Unknown parse error"))
        }
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String]
    ) {
        if elementName.lowercased() == "body" {
            inBody = true
            return
        }

        guard inBody, elementName.lowercased() == "outline" else { return }

        let xmlUrl = attributes["xmlUrl"]
        let title = attributes["title"] ?? attributes["text"]

        if let xmlUrl {
            feeds.append(OpmlFeedEntry(url: xmlUrl, title: title, tags: tagStack))
            outlineIsFolder.append(false)
        } else {
            let folderName = title ?? "Unknown"
            tagStack.append(folderName)
            outlineIsFolder.append(true)
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        if elementName.lowercased() == "body" {
            inBody = false
            return
        }

        guard inBody, elementName.lowercased() == "outline" else { return }

        if let isFolder = outlineIsFolder.popLast(), isFolder {
            _ = tagStack.popLast()
        }
    }
}
