import SwiftUI
import UIKit
import UserNotifications
import WebKit

let dataDir: URL = {
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("AttGora", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}()
let todosFile = dataDir.appendingPathComponent("todos.json")
let syncFile = dataDir.appendingPathComponent("sync.json")
let webRoot = Bundle.main.resourceURL!.appendingPathComponent("web", isDirectory: true)

@main
struct AttGoraApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            WebView().ignoresSafeArea(.container, edges: .all)
        }
    }
}

struct WebView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> WebController { WebController() }
    func updateUIViewController(_ controller: WebController, context: Context) {}
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let snooze = UNNotificationAction(identifier: "snooze", title: "Snooza 5 min")
        center.setNotificationCategories([UNNotificationCategory(identifier: "alarm", actions: [snooze], intentIdentifiers: [])])
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = response.notification.request.identifier
        let next: Double? = response.actionIdentifier == "snooze" ? Date().addingTimeInterval(5 * 60).timeIntervalSinceReferenceDate : nil
        WebController.setAlarm(id, next)
        completionHandler()
    }
}

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

final class WebController: UIViewController, WKScriptMessageHandlerWithReply, WKNavigationDelegate {
    private static weak var current: WebController?
    private static var pendingAlarms: [(String, Double?)] = []

    private var webView: WKWebView!
    private var ready = false

    static func setAlarm(_ id: String, _ at: Double?) {
        if let c = current, c.ready { c.sendAlarm(id, at) } else { pendingAlarms.append((id, at)) }
    }

    private var theme: String { traitCollection.userInterfaceStyle == .dark ? "dark" : "light" }

    override func viewDidLoad() {
        super.viewDidLoad()
        WebController.current = self
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(SchemeHandler(), forURLScheme: "app")
        config.userContentController.addScriptMessageHandler(self, contentWorld: .page, name: "native")
        config.userContentController.addUserScript(WKUserScript(
            source: "document.documentElement.dataset.theme = '\(theme)'", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        #if DEBUG
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        #endif
        view.backgroundColor = .systemBackground
        view.addSubview(webView)
        webView.load(URLRequest(url: URL(string: "app://local/index.html")!))

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: WebController, _) in
            self.webView.evaluateJavaScript("document.documentElement.dataset.theme = '\(self.theme)'")
        }
    }

    private func sendAlarm(_ id: String, _ at: Double?) {
        webView.evaluateJavaScript("todo.setAlarm(\(jsString(id)), \(at.map { String($0) } ?? "null"))")
    }

    private func jsString(_ s: String) -> String {
        String(data: try! JSONSerialization.data(withJSONObject: [s]), encoding: .utf8)!.dropFirst().dropLast().description
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
            try? Data(json.utf8).write(to: todosFile, options: .atomic)
            scheduleAlarms(parsed)
            replyHandler(true, nil)
        case "loadSync":
            replyHandler((try? String(contentsOf: syncFile, encoding: .utf8)) ?? "{}", nil)
        case "saveSync":
            try? Data((body["json"] as? String ?? "{}").utf8).write(to: syncFile, options: .atomic)
            replyHandler(true, nil)
        case "platform":
            replyHandler("ios", nil)
        case "ready":
            ready = true
            let pending = WebController.pendingAlarms
            WebController.pendingAlarms = []
            for (id, at) in pending { sendAlarm(id, at) }
            replyHandler(true, nil)
        case "getScale":
            replyHandler(UserDefaults.standard.object(forKey: "textScale") as? Double ?? 1.0, nil)
        case "setScale":
            UserDefaults.standard.set(body["value"] as? Double ?? 1.0, forKey: "textScale")
            replyHandler(true, nil)
        case "version":
            replyHandler(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "", nil)
        case "open":
            if let s = body["url"] as? String, let url = URL(string: s), url.scheme == "https" { UIApplication.shared.open(url) }
            replyHandler(true, nil)
        case "dialog":
            let alert = UIAlertController(title: body["title"] as? String, message: body["text"] as? String, preferredStyle: .alert)
            for (n, b) in (body["buttons"] as? [String] ?? ["OK"]).enumerated() {
                alert.addAction(UIAlertAction(title: b, style: .default) { _ in replyHandler(n, nil) })
            }
            present(alert, animated: true)
        case "menu":
            let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            for (id, title) in flatten(body["items"] as? [[String: Any]] ?? []) {
                sheet.addAction(UIAlertAction(title: title, style: id == "delete" ? .destructive : .default) { _ in replyHandler(id, nil) })
            }
            sheet.addAction(UIAlertAction(title: "Avbryt", style: .cancel) { _ in replyHandler(nil, nil) })
            sheet.popoverPresentationController?.sourceView = view
            sheet.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            present(sheet, animated: true)
        case "saveFile":
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(body["name"] as? String ?? "Uppgift.txt")
            do {
                try Data((body["text"] as? String ?? "").utf8).write(to: url, options: .atomic)
            } catch {
                return replyHandler(nil, error.localizedDescription)
            }
            let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            share.completionWithItemsHandler = { _, completed, _, _ in replyHandler(completed, nil) }
            share.popoverPresentationController?.sourceView = view
            share.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            present(share, animated: true)
        default:
            replyHandler(nil, "unknown command")
        }
    }

    private func flatten(_ items: [[String: Any]], parent: String = "") -> [(String, String)] {
        items.flatMap { item -> [(String, String)] in
            let title = item["title"] as? String ?? ""
            if let sub = item["submenu"] as? [[String: Any]] { return flatten(sub, parent: title) }
            guard let id = item["id"] as? String else { return [] }
            let full = parent.isEmpty ? title : "\(parent): \(title)"
            return [(id, item["checked"] as? Bool == true ? full + " ✓" : full)]
        }
    }

    private func scheduleAlarms(_ items: [[String: Any]]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let now = Date().timeIntervalSinceReferenceDate
        let upcoming = items.compactMap { item -> (String, String, Double)? in
            guard item["done"] as? Bool != true, let id = item["id"] as? String, let at = item["alarm"] as? Double, at > now else { return nil }
            return (id, item["title"] as? String ?? "", at)
        }.sorted { $0.2 < $1.2 }.prefix(60)
        guard !upcoming.isEmpty else { return }
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            for (id, title, at) in upcoming {
                let content = UNMutableNotificationContent()
                content.title = "Alarm"
                content.body = title
                content.sound = .default
                content.categoryIdentifier = "alarm"
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, at - Date().timeIntervalSinceReferenceDate), repeats: false)
                center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let u = navigationAction.request.url, u.scheme != "app" {
            if u.scheme == "https" { UIApplication.shared.open(u) }
            return decisionHandler(.cancel)
        }
        decisionHandler(.allow)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        ready = false
        webView.reload()
    }
}
