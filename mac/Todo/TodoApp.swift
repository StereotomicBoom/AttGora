import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct TodoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = TodoStore()
    @AppStorage(TextScale.key) private var textScale = 1.0

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
            CommandGroup(before: .toolbar) {
                Button("Större text") { textScale = TextScale.step(textScale, by: 0.1) }
                    .keyboardShortcut("+")
                    .disabled(textScale >= 2.0)
                Button("Mindre text") { textScale = TextScale.step(textScale, by: -0.1) }
                    .keyboardShortcut("-")
                    .disabled(textScale <= 0.7)
                Button("Normal textstorlek") { textScale = 1.0 }
                    .keyboardShortcut("0")
                Divider()
            }
        }
    }
}

extension Notification.Name {
    static let focusNewTask = Notification.Name("focusNewTask")
}
