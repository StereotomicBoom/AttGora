import SwiftUI

extension Color {
    static let paper = Color.white
    static let paperLight = Color.white
    static let paperEdge = Color(white: 0.55)
    static let rule = Color(white: 0.72)
    static let muted = Color(white: 0.36)
    static let doneText = Color(white: 0.55)
}

struct Rule: View {
    var body: some View {
        Rectangle().fill(Color.rule).frame(height: 1)
    }
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
                    .font(.system(size: 26))
                    .padding(.horizontal, 12)
                    .frame(height: 57)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.paperLight)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(newTaskFocused ? Color.accentColor : Color.paperEdge,
                                    lineWidth: newTaskFocused ? 2 : 1.5)
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
            .controlSize(.large)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.bottom, 8)

            Rule()

            List(selection: $selection) {
                ForEach(visibleIDs, id: \.self) { id in
                    TodoRow(item: binding(id))
                        .tag(id)
                        .listRowSeparator(.visible)
                        .listRowSeparatorTint(Color.rule)
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
                        .foregroundStyle(Color.muted)
                }
            }

            Rule()

            HStack {
                Text("\(store.remaining) kvar")
                    .foregroundStyle(Color.muted)
                Spacer()
                Button("Rensa klara", action: store.clearCompleted)
                    .disabled(store.items.allSatisfy { !$0.done })
            }
            .padding()
        }
        .font(.system(size: 17))
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
                .controlSize(.large)
                .labelsHidden()
            Button {
                item.priority = (item.priority + 1) % Priority.allCases.count
            } label: {
                RoundedRectangle(cornerRadius: 3)
                    .fill(priorityColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(item.priority == 0 ? Color(white: 0.45) : .clear, lineWidth: 1.5)
                    )
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(item.done ? 0.4 : 1)
            .help("Prioritet: \(Priority(rawValue: item.priority)?.name ?? "Ingen") (klicka för att ändra)")
            TextField("Uppgift", text: $item.title)
                .textFieldStyle(.plain)
                .strikethrough(item.done)
                .italic(item.done)
                .foregroundStyle(item.done ? Color.doneText : Color.primary)
        }
        .padding(.vertical, 2)
    }

    private var priorityColor: Color {
        switch Priority(rawValue: item.priority) ?? .none {
        case .none: .clear
        case .low: Color(red: 0.13, green: 0.58, blue: 0.24)
        case .medium: Color(red: 0.90, green: 0.45, blue: 0.0)
        case .high: Color(red: 0.82, green: 0.11, blue: 0.11)
        }
    }
}
