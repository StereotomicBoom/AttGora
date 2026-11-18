import SwiftUI
import AppKit

struct TodoItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var done = false
    var created = Date()
    var priority = 0
    var inProgress = false
    var alarm: Date?

    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        done = try c.decodeIfPresent(Bool.self, forKey: .done) ?? false
        created = try c.decodeIfPresent(Date.self, forKey: .created) ?? Date()
        let stored = try c.decodeIfPresent(Int.self, forKey: .priority) ?? 0
        priority = stored == 0 ? Priority.none.rawValue : Priority.medium.rawValue
        inProgress = try c.decodeIfPresent(Bool.self, forKey: .inProgress) ?? false
        alarm = try c.decodeIfPresent(Date.self, forKey: .alarm)
    }
}

enum Priority: Int, CaseIterable, Identifiable {
    case none = 0, medium = 2
    var id: Int { rawValue }

    var name: String {
        switch self {
        case .none: "Ingen"
        case .medium: "Medel"
        }
    }
}

@MainActor
final class TodoStore: ObservableObject {
    @Published var items: [TodoItem] = [] {
        didSet {
            let wasDone = Set(oldValue.filter(\.done).map(\.id))
            let unticked = Set(items.filter { !$0.done && wasDone.contains($0.id) }.map(\.id))
            let open = items.filter { unticked.contains($0.id) } + items.filter { !$0.done && !unticked.contains($0.id) }
            let ordered = (open + items.filter { $0.done }).map { item in
                var item = item
                if item.done {
                    item.inProgress = false
                    item.alarm = nil
                }
                return item
            }
            if ordered != items { items = ordered }
            save()
        }
    }

    private let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Todo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("todos.json")
    }()

    init() {
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) {
            items = decoded.filter { !$0.done } + decoded.filter { $0.done }
        }
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkAlarms() }
        }
        Task { @MainActor in self.checkAlarms() }
    }

    private var alarmShowing = false

    private func checkAlarms() {
        guard !alarmShowing,
              let due = items.first(where: { !$0.done && ($0.alarm ?? .distantFuture) <= Date() })
        else { return }
        alarmShowing = true
        NSSound(named: "Glass")?.play()
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Alarm"
        alert.informativeText = due.title
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Snooza 5 min")
        let response = alert.runModal()
        if var item = item(due.id) {
            item.alarm = response == .alertSecondButtonReturn ? Date().addingTimeInterval(5 * 60) : nil
            update(item)
        }
        alarmShowing = false
    }

    var remaining: Int { items.filter { !$0.done }.count }

    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let lastStarred = items.lastIndex { !$0.done && $0.priority != Priority.none.rawValue }
        items.insert(TodoItem(title: trimmed), at: lastStarred.map { $0 + 1 } ?? 0)
    }

    func item(_ id: UUID) -> TodoItem? {
        items.first { $0.id == id }
    }

    func update(_ item: TodoItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i] = item
    }

    func move(visible: [UUID], from source: IndexSet, to destination: Int) {
        var reordered = visible
        reordered.move(fromOffsets: source, toOffset: destination)
        let visibleSet = Set(visible)
        let byId = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        var next = reordered.makeIterator()
        items = items.map { visibleSet.contains($0.id) ? byId[next.next()!]! : $0 }
    }

    func moveToTop(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        var reordered = items
        reordered.insert(reordered.remove(at: i), at: 0)
        items = reordered
    }

    func delete(_ ids: Set<UUID>) {
        items.removeAll { ids.contains($0.id) }
    }

    func clearCompleted() {
        items.removeAll { $0.done }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

