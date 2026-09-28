import AppKit
import WebKit
import UniformTypeIdentifiers

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var webView: WKWebView!
    private var titleLabel: NSTextField!
    private var landingView: NSStackView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let frame = NSRect(x: 0, y: 0, width: 780, height: 700)
        window = NSWindow(contentRect: frame, styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "EPUB Quick Look"
        window.center()
        window.minSize = NSSize(width: 560, height: 480)

        let content = NSView(frame: frame)
        window.contentView = content
        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(header)

        titleLabel = NSTextField(labelWithString: "EPUB Quick Look")
        titleLabel.font = .boldSystemFont(ofSize: 15)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)

        let openButton = NSButton(title: "Mở EPUB…", target: self, action: #selector(openFile))
        openButton.bezelStyle = .rounded
        openButton.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(openButton)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(separator)

        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.isHidden = true
        content.addSubview(webView)

        let icon = NSImageView(image: NSImage(systemSymbolName: "book.pages", accessibilityDescription: "Sách")
            ?? NSImage())
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 50, weight: .regular)
        let heading = NSTextField(labelWithString: "Xem nhanh sách EPUB")
        heading.font = .boldSystemFont(ofSize: 23)
        let instruction = NSTextField(wrappingLabelWithString:
            "Trong Finder, chọn một tệp .epub rồi nhấn phím Space.\nBạn cũng có thể mở sách tại đây.")
        instruction.alignment = .center
        instruction.textColor = .secondaryLabelColor
        let chooseButton = NSButton(title: "Chọn tệp EPUB", target: self, action: #selector(openFile))
        chooseButton.bezelStyle = .rounded
        chooseButton.keyEquivalent = "\r"
        landingView = NSStackView(views: [icon, heading, instruction, chooseButton])
        landingView.orientation = .vertical
        landingView.alignment = .centerX
        landingView.spacing = 17
        landingView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(landingView)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: content.topAnchor),
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 54),
            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 18),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            openButton.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12),
            openButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -18),
            openButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            separator.topAnchor.constraint(equalTo: header.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            webView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            landingView.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            landingView.centerYAnchor.constraint(equalTo: content.centerYAnchor, constant: 20),
            instruction.widthAnchor.constraint(lessThanOrEqualToConstant: 440)
        ])
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if let url = urls.first { showBook(at: url) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    @objc private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.epub]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url { showBook(at: url) }
    }

    private func showBook(at url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let preview = try EPUBRenderer.render(url: url)
            titleLabel.stringValue = preview.title
            window.title = "\(preview.title) — EPUB Quick Look"
            webView.loadHTMLString(preview.htmlWithEmbeddedImages(), baseURL: nil)
            webView.isHidden = false
            landingView.isHidden = true
            window.makeKeyAndOrderFront(nil)
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Không mở được EPUB"
            alert.runModal()
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
