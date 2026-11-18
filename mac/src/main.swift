import Cocoa
import WebKit

let dataDir: URL = {
    let dir = ProcessInfo.processInfo.environment["TODO_DATA_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Todo", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}()
let todosFile = dataDir.appendingPathComponent("todos.json")
let webRoot = Bundle.main.resourceURL!.appendingPathComponent("web", isDirectory: true)

final class SchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else { return }
        let rel = url.path == "/" ? "index.html" : String(url.path.dropFirst())
        let file = webRoot.appendingPathComponent(rel).standardizedFileURL
        let types = ["html": "text/html; charset=utf-8", "js": "text/javascript; charset=utf-8", "css": "text/css; charset=utf-8", "svg": "image/svg+xml"]
        let found = file.path.hasPrefix(webRoot.standardizedFileURL.path) ? try? Data(contentsOf: file) : nil
        let headers = ["Content-Type": found == nil ? "text/plain" : types[file.pathExtension] ?? "application/octet-stream", "Cache-Control": "no-store"]
        task.didReceive(HTTPURLResponse(url: url, statusCode: found == nil ? 404 : 200, httpVersion: "HTTP/1.1", headerFields: headers)!)
        task.didReceive(found ?? Data("not found".utf8))
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

final class MenuPicker: NSObject {
    var picked: String?
    @objc func pick(_ sender: NSMenuItem) { picked = sender.representedObject as? String }

    func build(_ items: [[String: Any]], into menu: NSMenu) {
        for item in items {
            if item["separator"] as? Bool == true { menu.addItem(.separator()); continue }
            let entry = NSMenuItem(title: item["title"] as? String ?? "", action: #selector(pick(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = item["id"] as? String
            entry.state = item["checked"] as? Bool == true ? .on : .off
            if let sub = item["submenu"] as? [[String: Any]] {
                let submenu = NSMenu()
                build(sub, into: submenu)
                entry.submenu = submenu
                entry.action = nil
            }
            menu.addItem(entry)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandlerWithReply {
    var window: NSWindow!
    var webView: WKWebView!
    var items: [[String: Any]] = []
    var alarmShowing = false

    var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        items = (try? Data(contentsOf: todosFile)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [[String: Any]] } ?? []

        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(SchemeHandler(), forURLScheme: "app")
        config.userContentController.addScriptMessageHandler(self, contentWorld: .page, name: "native")
        webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        if #available(macOS 13.3, *) { webView.isInspectable = true }

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 560),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Att göra"
        window.minSize = NSSize(width: 380, height: 420)
        window.backgroundColor = .white
        window.appearance = NSAppearance(named: .aqua)
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = webView
        window.center()
        window.setFrameAutosaveName("TodoMain")
        window.makeKeyAndOrderFront(nil)
        webView.load(URLRequest(url: URL(string: "app://local/index.html")!))
        NSApp.activate(ignoringOtherApps: true)

        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.checkAlarms() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window.makeKeyAndOrderFront(nil)
        return true
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        guard let body = message.body as? [String: Any], let cmd = body["cmd"] as? String else { return replyHandler(nil, "bad message") }
        switch cmd {
        case "load":
            replyHandler((try? String(contentsOf: todosFile, encoding: .utf8)) ?? "[]", nil)
        case "save":
            guard let json = body["json"] as? String,
                  let parsed = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]]
            else { return replyHandler(nil, "bad json") }
            items = parsed
            try? Data(json.utf8).write(to: todosFile, options: .atomic)
            replyHandler(true, nil)
        case "getScale":
            replyHandler(UserDefaults.standard.object(forKey: "textScale") as? Double ?? 1.0, nil)
        case "setScale":
            UserDefaults.standard.set(body["value"] as? Double ?? 1.0, forKey: "textScale")
            replyHandler(true, nil)
        case "version":
            replyHandler(version, nil)
        case "open":
            if let s = body["url"] as? String, let url = URL(string: s), url.scheme == "https" { NSWorkspace.shared.open(url) }
            replyHandler(true, nil)
        case "dialog":
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = body["title"] as? String ?? ""
            alert.informativeText = body["text"] as? String ?? ""
            for b in body["buttons"] as? [String] ?? ["OK"] { alert.addButton(withTitle: b) }
            replyHandler(alert.runModal().rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue, nil)
        case "menu":
            let picker = MenuPicker()
            let menu = NSMenu()
            picker.build(body["items"] as? [[String: Any]] ?? [], into: menu)
            menu.popUp(positioning: nil, at: webView.convert(window.mouseLocationOutsideOfEventStream, from: nil), in: webView)
            replyHandler(picker.picked, nil)
        default:
            replyHandler(nil, "unknown command")
        }
    }

    private func checkAlarms() {
        let now = Date().timeIntervalSinceReferenceDate
        guard !alarmShowing,
              let index = items.firstIndex(where: { $0["done"] as? Bool != true && ($0["alarm"] as? Double ?? .infinity) <= now }),
              let id = items[index]["id"] as? String
        else { return }
        alarmShowing = true
        NSSound(named: "Glass")?.play()
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Alarm"
        alert.informativeText = items[index]["title"] as? String ?? ""
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Snooza 5 min")
        let snooze = alert.runModal() == .alertSecondButtonReturn
        let next: Double? = snooze ? Date().addingTimeInterval(5 * 60).timeIntervalSinceReferenceDate : nil
        if let i = items.firstIndex(where: { $0["id"] as? String == id }) { items[i]["alarm"] = next ?? .infinity }
        webView.evaluateJavaScript("todo.setAlarm(\(jsString(id)), \(next.map { String($0) } ?? "null"))")
        alarmShowing = false
    }

    private func jsString(_ s: String) -> String {
        String(data: try! JSONSerialization.data(withJSONObject: [s]), encoding: .utf8)!.dropFirst().dropLast().description
    }

    private func js(_ code: String) {
        window.makeKeyAndOrderFront(nil)
        webView.evaluateJavaScript(code)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let u = navigationAction.request.url, u.scheme != "app" {
            if u.scheme == "https" { NSWorkspace.shared.open(u) }
            return decisionHandler(.cancel)
        }
        decisionHandler(.allow)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { webView.reload() }

    @objc func newTask(_ sender: Any?) { js("todo.focusNew()") }
    @objc func biggerText(_ sender: Any?) { js("todo.scaleBy(0.1)") }
    @objc func smallerText(_ sender: Any?) { js("todo.scaleBy(-0.1)") }
    @objc func normalText(_ sender: Any?) { js("todo.resetScale()") }
    @objc func checkUpdates(_ sender: Any?) { js("todo.checkForUpdates(true)") }
    @objc func showWindow(_ sender: Any?) { window.makeKeyAndOrderFront(nil) }

    private func buildMenu() {
        let main = NSMenu()
        func add(_ title: String, _ build: (NSMenu) -> Void) -> NSMenu {
            let item = NSMenuItem(); main.addItem(item)
            let menu = NSMenu(title: title); build(menu); item.submenu = menu
            return menu
        }
        _ = add("Todo") { m in
            m.addItem(withTitle: "Om Todo", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
            m.addItem(withTitle: "Sök efter uppdateringar…", action: #selector(checkUpdates(_:)), keyEquivalent: "")
            m.addItem(.separator())
            m.addItem(withTitle: "Göm Todo", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
            m.addItem(.separator())
            m.addItem(withTitle: "Avsluta Todo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        }
        _ = add("Arkiv") { m in
            m.addItem(withTitle: "Ny uppgift", action: #selector(newTask(_:)), keyEquivalent: "n")
            m.addItem(withTitle: "Stäng", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        }
        _ = add("Redigera") { m in
            m.addItem(withTitle: "Ångra", action: Selector(("undo:")), keyEquivalent: "z")
            m.addItem(withTitle: "Gör om", action: Selector(("redo:")), keyEquivalent: "Z")
            m.addItem(.separator())
            m.addItem(withTitle: "Klipp ut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
            m.addItem(withTitle: "Kopiera", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
            m.addItem(withTitle: "Klistra in", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
            m.addItem(withTitle: "Markera allt", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        }
        _ = add("Visa") { m in
            m.addItem(withTitle: "Större text", action: #selector(biggerText(_:)), keyEquivalent: "+")
            m.addItem(withTitle: "Mindre text", action: #selector(smallerText(_:)), keyEquivalent: "-")
            m.addItem(withTitle: "Normal textstorlek", action: #selector(normalText(_:)), keyEquivalent: "0")
        }
        let win = add("Fönster") { m in
            m.addItem(withTitle: "Minimera", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
            m.addItem(withTitle: "Att göra", action: #selector(showWindow(_:)), keyEquivalent: "")
        }
        NSApp.windowsMenu = win
        NSApp.mainMenu = main
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
