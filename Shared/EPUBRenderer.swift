import Foundation
import UniformTypeIdentifiers

struct EPUBImage {
    let id: String
    let data: Data
    let type: UTType
}

struct EPUBPreview {
    let title: String
    let author: String?
    let html: String
    let images: [EPUBImage]

    func htmlWithEmbeddedImages() -> String {
        var result = html
        for image in images {
            result = result.replacingOccurrences(
                of: "cid:\(image.id)",
                with: "data:\(image.type.preferredMIMEType ?? "image/png");base64,\(image.data.base64EncodedString())"
            )
        }
        return result
    }
}

enum EPUBRenderer {
    static func render(url: URL) throws -> EPUBPreview {
        let archive = try ZIPArchive(url: url)
        guard let containerData = try archive.data(at: "META-INF/container.xml", limit: 100_000) else {
            throw EPUBError.invalidBook("thiếu META-INF/container.xml")
        }
        let container = try XMLItems(data: containerData)
        guard let rootFile = container.elements.first(where: { $0.name == "rootfile" })?.attributes["full-path"] else {
            throw EPUBError.invalidBook("không tìm thấy tệp OPF")
        }
        let opfPath = normalizedPath(rootFile)
        guard let opfData = try archive.data(at: opfPath, limit: 2_000_000) else {
            throw EPUBError.invalidBook("thiếu tệp OPF")
        }
        let opf = try XMLItems(data: opfData)
        let title = opf.elements.first(where: { $0.name == "title" })?.text
            .nilIfEmpty ?? url.deletingPathExtension().lastPathComponent
        let author = opf.elements.first(where: { $0.name == "creator" })?.text.nilIfEmpty
        var manifest: [String: String] = [:]
        var mediaTypes: [String: String] = [:]
        for item in opf.elements where item.name == "item" {
            if let id = item.attributes["id"], let href = item.attributes["href"] {
                manifest[id] = relativePath(href, from: opfPath)
                mediaTypes[id] = item.attributes["media-type"] ?? ""
            }
        }
        let spine = opf.elements.filter { $0.name == "itemref" }
            .filter { $0.attributes["linear"] != "no" }
            .compactMap { $0.attributes["idref"] }
        guard !spine.isEmpty else { throw EPUBError.invalidBook("sách không có chương") }

        var images: [EPUBImage] = []
        var imageIDs: [String: String] = [:]
        var imageBytes = 0
        var chapters: [String] = []
        var totalMarkup = 0
        let maxChapters = 30
        let maxMarkup = 2_000_000

        for id in spine.prefix(maxChapters) {
            guard let path = manifest[id],
                  ["application/xhtml+xml", "text/html"].contains(mediaTypes[id]),
                  let chapterData = try archive.data(at: path, limit: 4_000_000) else { continue }
            let chapter = SafeXHTML(data: chapterData) { source in
                let imagePath = relativePath(source, from: path)
                if let existing = imageIDs[imagePath] { return existing }
                guard images.count < 80,
                      let type = imageType(for: imagePath),
                      let data = try? archive.data(at: imagePath, limit: 5_000_000),
                      imageBytes + data.count <= 25_000_000 else { return nil }
                let imageID = "epub-image-\(images.count)"
                images.append(EPUBImage(id: imageID, data: data, type: type))
                imageIDs[imagePath] = imageID
                imageBytes += data.count
                return imageID
            }
            let body = chapter.render()
            if !body.isEmpty {
                chapters.append("<section class=\"chapter\">\(body)</section>")
                totalMarkup += body.utf8.count
                if totalMarkup >= maxMarkup { break }
            }
        }
        guard !chapters.isEmpty else { throw EPUBError.invalidBook("không có nội dung có thể hiển thị") }
        let truncated = spine.count > chapters.count
        let subtitle = author.map { "<p class=\"author\">\(escapeHTML($0))</p>" } ?? ""
        let ending = truncated
            ? "<p class=\"ending\">Bản xem nhanh hiển thị các chương đầu. Mở sách bằng ứng dụng đọc EPUB để xem toàn bộ.</p>"
            : ""
        let html = """
        <!doctype html><html lang="vi"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src cid: data:; style-src 'unsafe-inline'">
        <style>
        :root { color-scheme: light dark; font-family: -apple-system, BlinkMacSystemFont, Georgia, serif; }
        body { max-width: 760px; margin: 0 auto; padding: 28px 36px 70px; color: #20232a; background: #fffdfa; line-height: 1.68; font-size: 17px; }
        header { border-bottom: 1px solid #ddd9d2; padding-bottom: 22px; margin-bottom: 34px; }
        h1 { font-size: 2em; line-height: 1.2; margin: 0; } .author { color: #6b6d73; margin: 9px 0 0; }
        h2,h3,h4,h5,h6 { line-height: 1.3; margin-top: 1.6em; } p { margin: .85em 0; }
        .chapter { margin-bottom: 44px; } .chapter + .chapter { border-top: 1px solid #e7e4de; padding-top: 22px; }
        img { display: block; max-width: 100%; height: auto; margin: 1.4em auto; }
        blockquote { border-left: 3px solid #c0beb8; padding-left: 1.1em; margin-left: .4em; color: #555; }
        table { border-collapse: collapse; max-width: 100%; } td,th { border: 1px solid #bbb; padding: 5px 9px; }
        pre,code { white-space: pre-wrap; overflow-wrap: anywhere; } .ending { color: #73757c; font-size: .88em; text-align: center; }
        @media (prefers-color-scheme: dark) { body { background: #1b1c1f; color: #e9e9ed; } header,.chapter + .chapter { border-color: #444; } .author,.ending { color: #aaa; } blockquote { color: #bbb; } td,th { border-color: #666; } }
        </style></head><body><header><h1>\(escapeHTML(title))</h1>\(subtitle)</header>
        \(chapters.joined())\(ending)</body></html>
        """
        return EPUBPreview(title: title, author: author, html: html, images: images)
    }

    private static func imageType(for path: String) -> UTType? {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch ext {
        case "png": return .png
        case "jpg", "jpeg": return .jpeg
        case "gif": return .gif
        case "webp": return UTType(filenameExtension: "webp")
        default: return nil
        }
    }
}

private func normalizedPath(_ path: String) -> String {
    let raw = path.removingPercentEncoding ?? path
    var parts: [Substring] = []
    for part in raw.split(separator: "/") {
        if part == ".." { if !parts.isEmpty { parts.removeLast() } }
        else if part != "." { parts.append(part) }
    }
    return parts.joined(separator: "/")
}

private func relativePath(_ href: String, from document: String) -> String {
    let withoutFragment = String(href.split(separator: "#", maxSplits: 1).first ?? "")
    let folder = (document as NSString).deletingLastPathComponent
    return normalizedPath(folder + "/" + withoutFragment)
}

private func escapeHTML(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private final class XMLItems: NSObject, XMLParserDelegate {
    struct Element {
        let name: String
        let attributes: [String: String]
        var text: String
    }
    var elements: [Element] = []
    private var active: [Int] = []

    init(data: Data) throws {
        super.init()
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else { throw EPUBError.invalidBook("XML không hợp lệ") }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String]) {
        let name = elementName.split(separator: ":").last.map(String.init) ?? elementName
        elements.append(Element(name: name, attributes: attributeDict, text: ""))
        active.append(elements.count - 1)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if let index = active.last { elements[index].text += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if let index = active.popLast() {
            elements[index].text = elements[index].text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

private final class SafeXHTML: NSObject, XMLParserDelegate {
    private static let allowed: Set<String> = [
        "p", "div", "span", "h1", "h2", "h3", "h4", "h5", "h6", "br", "hr",
        "strong", "b", "em", "i", "u", "s", "small", "sup", "sub", "blockquote",
        "ul", "ol", "li", "dl", "dt", "dd", "pre", "code", "figure", "figcaption",
        "table", "thead", "tbody", "tr", "th", "td", "caption", "a", "img"
    ]
    private let data: Data
    private let imageID: (String) -> String?
    private var output = ""
    private var insideBody = false
    private var blockedDepth = 0
    private var openTags: [String?] = []

    init(data: Data, imageID: @escaping (String) -> String?) {
        self.data = data
        self.imageID = imageID
    }

    func render() -> String {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldResolveExternalEntities = false
        if parser.parse() { return output }
        let raw = String(data: data, encoding: .utf8) ?? ""
        let withoutActiveContent = raw.replacingOccurrences(
            of: "(?is)<(script|style|iframe|object|embed|form|svg|math)\\b[^>]*>.*?</\\1\\s*>",
            with: " ", options: .regularExpression)
        let plain = withoutActiveContent.replacingOccurrences(of: "<[^>]*>", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return plain.isEmpty ? "" : "<p>\(escapeHTML(String(plain.prefix(50_000))))</p>"
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String]) {
        let name = elementName.lowercased().split(separator: ":").last.map(String.init) ?? elementName
        if name == "body" { insideBody = true; return }
        guard insideBody else { return }
        if blockedDepth > 0 || ["script", "style", "iframe", "object", "embed", "form", "svg", "math"].contains(name) {
            blockedDepth += 1
            openTags.append(nil)
            return
        }
        guard Self.allowed.contains(name) else { openTags.append(nil); return }
        if name == "img" {
            if let source = attributeDict["src"], let id = imageID(source) {
                let alt = escapeHTML(attributeDict["alt"] ?? "")
                output += "<img src=\"cid:\(id)\" alt=\"\(alt)\">"
            }
            openTags.append(nil)
            return
        }
        if name == "br" || name == "hr" { output += "<\(name)>"; openTags.append(nil); return }
        let tag = name == "a" ? "span" : name
        let direction = ["ltr", "rtl", "auto"].contains(attributeDict["dir"] ?? "")
            ? " dir=\"\(attributeDict["dir"]!)\"" : ""
        output += "<\(tag)\(direction)>"
        openTags.append(tag)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideBody && blockedDepth == 0 { output += escapeHTML(string) }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.lowercased().split(separator: ":").last.map(String.init) ?? elementName
        if name == "body" { insideBody = false; return }
        guard insideBody else { return }
        if let tag = openTags.popLast() {
            if let tag { output += "</\(tag)>" }
            else if blockedDepth > 0 { blockedDepth -= 1 }
        }
    }
}
