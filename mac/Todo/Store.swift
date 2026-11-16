import SwiftUI
import UserNotifications

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
            let ordered = (items.filter { !$0.done } + items.filter { $0.done }).map { item in
                var item = item
                if item.done {
                    item.inProgress = false
                    item.alarm = nil
                }
                return item
            }
            if ordered != items { items = ordered }
            save()
            Alarms.sync(items)
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
        Alarms.sync(items)
    }

    var remaining: Int { items.filter { !$0.done }.count }

    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.insert(TodoItem(title: trimmed), at: 0)
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

enum Alarms {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func sync(_ items: [TodoItem]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for item in items {
            guard let date = item.alarm, date > Date(), !item.done else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Att göra"
            content.body = item.title
            content.sound = .default
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            center.add(UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: trigger))
        }
    }
}
