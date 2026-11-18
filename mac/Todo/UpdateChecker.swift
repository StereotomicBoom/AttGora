import AppKit

enum UpdateChecker {
    static let repo = "StereotomicBoom/Todo"

    private struct Release: Decodable {
        let tag_name: String
        let html_url: URL
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static func check(manual: Bool = false) {
        Task {
            let release = await latestRelease()
            await MainActor.run { show(release, manual: manual) }
        }
    }

    private static func latestRelease() async -> Release? {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return try? JSONDecoder().decode(Release.self, from: data)
    }

    @MainActor
    private static func show(_ release: Release?, manual: Bool) {
        guard let release else {
            if manual { inform("Kunde inte söka efter uppdateringar", "Kontrollera internetanslutningen och försök igen.") }
            return
        }
        let latest = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        guard isNewer(latest, than: currentVersion) else {
            if manual { inform("Todo är uppdaterad", "Du har den senaste versionen (\(currentVersion)).") }
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Ny version av Todo"
        alert.informativeText = "Version \(latest) finns. Du har \(currentVersion)."
        alert.addButton(withTitle: "Ladda ner")
        alert.addButton(withTitle: "Senare")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(release.html_url)
        }
    }

    @MainActor
    private static func inform(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.runModal()
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }
        let y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}
