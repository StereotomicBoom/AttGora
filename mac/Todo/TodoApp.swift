import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct TodoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = TodoStore()

    var body: some Scene {
        WindowGroup("Att göra") {
            ContentView(store: store)
                .frame(minWidth: 380, minHeight: 420)
        }
        .defaultSize(width: 440, height: 560)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Ny uppgift") {
                    NotificationCenter.default.post(name: .focusNewTask, object: nil)
                }
                .keyboardShortcut("n")
            }
        }
    }
}

extension Notification.Name {
    static let focusNewTask = Notification.Name("focusNewTask")
}
