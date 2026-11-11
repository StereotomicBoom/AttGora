import SwiftUI

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

    private var visibleIndices: [Int] {
        store.items.indices.filter { i in
            switch filter {
            case .all: true
            case .active: !store.items[i].done
            case .done: store.items[i].done
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Ny uppgift", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
                    .focused($newTaskFocused)
                    .onSubmit(add)
                Button("Lägg till", action: add)
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
                ForEach(visibleIndices, id: \.self) { i in
                    TodoRow(item: $store.items[i])
                        .tag(store.items[i].id)
                        .contextMenu {
                            Button("Ta bort", role: .destructive) {
                                store.delete([store.items[i].id])
                            }
                        }
                }
            }
            .onDeleteCommand { store.delete(selection); selection.removeAll() }
            .overlay {
                if visibleIndices.isEmpty {
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
            TextField("Uppgift", text: $item.title)
                .textFieldStyle(.plain)
                .strikethrough(item.done)
                .foregroundStyle(item.done ? .secondary : .primary)
        }
        .padding(.vertical, 2)
    }
}
