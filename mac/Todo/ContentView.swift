import SwiftUI

extension Color {
    static let paper = Color(red: 0.965, green: 0.945, blue: 0.906)
    static let paperLight = Color(red: 0.988, green: 0.978, blue: 0.957)
    static let paperEdge = Color(red: 0.84, green: 0.80, blue: 0.73)
}

enum Filter: String, CaseIterable, Identifiable {
    case all = "Alla", active = "Kvar", done = "Klara"
    var id: Self { self }
}

struct ContentView: View {
    @ObservedObject var store: TodoStore
    @State private var newTitle = ""
    @State private var filter: Filter = .all
    @State private var selection = Set<UUID>()
    @FocusState private var newTaskFocused: Bool

    private var visibleIDs: [UUID] {
        store.items.filter { item in
            switch filter {
            case .all: true
            case .active: !item.done
            case .done: item.done
            }
        }.map(\.id)
    }

    private func binding(_ id: UUID) -> Binding<TodoItem> {
        Binding(
            get: { store.item(id) ?? TodoItem(id: id, title: "") },
            set: { store.update($0) }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Ny uppgift", text: $newTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.paperLight)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(newTaskFocused ? Color.accentColor : Color.paperEdge,
                                    lineWidth: newTaskFocused ? 2 : 1)
                    )
                    .focused($newTaskFocused)
                    .onSubmit(add)
                Button("Lägg till", action: add)
                    .controlSize(.large)
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()

            Picker("Filter", selection: $filter) {
                ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.bottom, 8)

            List(selection: $selection) {
                ForEach(visibleIDs, id: \.self) { id in
                    TodoRow(item: binding(id))
                        .tag(id)
                        .contextMenu {
                            Menu("Prioritet") {
                                ForEach(Priority.allCases) { p in
                                    Button(p.name) {
                                        if var item = store.item(id) {
                                            item.priority = p.rawValue
                                            store.update(item)
                                        }
                                    }
                                }
                            }
                            Button("Ta bort", role: .destructive) {
                                store.delete([id])
                            }
                        }
                }
                .onMove { source, destination in
                    store.move(visible: visibleIDs, from: source, to: destination)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.paper)
            .onDeleteCommand { store.delete(selection); selection.removeAll() }
            .overlay {
                if visibleIDs.isEmpty {
                    Text(store.items.isEmpty ? "Inget att göra 🎉" : "Inga uppgifter här")
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("\(store.remaining) kvar")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Rensa klara", action: store.clearCompleted)
                    .disabled(store.items.allSatisfy { !$0.done })
            }
            .padding()
        }
        .background(Color.paper)
        .toolbarBackground(Color.paper, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .preferredColorScheme(.light)
        .onAppear { newTaskFocused = true }
        .onReceive(NotificationCenter.default.publisher(for: .focusNewTask)) { _ in
            newTaskFocused = true
        }
    }

    private func add() {
        store.add(newTitle)
        newTitle = ""
    }
}

struct TodoRow: View {
    @Binding var item: TodoItem

    var body: some View {
        HStack {
            Toggle("", isOn: $item.done)
                .toggleStyle(.checkbox)
                .labelsHidden()
            Button {
                item.priority = (item.priority + 1) % Priority.allCases.count
            } label: {
                RoundedRectangle(cornerRadius: 3)
                    .fill(priorityColor)
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Prioritet: \(Priority(rawValue: item.priority)?.name ?? "Ingen") (klicka för att ändra)")
            TextField("Uppgift", text: $item.title)
                .textFieldStyle(.plain)
                .strikethrough(item.done)
                .foregroundStyle(item.done ? .secondary : .primary)
        }
        .padding(.vertical, 2)
    }

    private var priorityColor: Color {
        switch Priority(rawValue: item.priority) ?? .none {
        case .none: .gray.opacity(0.35)
        case .low: .green
        case .medium: .orange
        case .high: .red
        }
    }
}
