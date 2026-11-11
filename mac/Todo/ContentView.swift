import SwiftUI

extension Color {
    static let paper = Color.white
    static let paperLight = Color.white
    static let paperEdge = Color(white: 0.55)
    static let rule = Color(white: 0.72)
    static let muted = Color(white: 0.36)
    static let doneText = Color(white: 0.55)
    static let inProgress = Color(red: 0.84, green: 0.91, blue: 1.0)
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
    @State private var draggingID: UUID?
    @State private var dragSteps = 0
    @State private var rowHeight: CGFloat = 30

    private var dragIndices: (from: Int, to: Int)? {
        guard let id = draggingID, let from = visibleIDs.firstIndex(of: id) else { return nil }
        return (from, min(max(from + dragSteps, 0), visibleIDs.count - 1))
    }

    private func dropLine(at index: Int) -> VerticalEdge? {
        guard let d = dragIndices, d.to == index, d.to != d.from else { return nil }
        return d.to < d.from ? .top : .bottom
    }

    private func finishDrag() {
        if let d = dragIndices, d.to != d.from {
            store.move(visible: visibleIDs, from: IndexSet(integer: d.from),
                       to: d.to > d.from ? d.to + 1 : d.to)
        }
        draggingID = nil
        dragSteps = 0
    }

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
                    let index = visibleIDs.firstIndex(of: id) ?? 0
                    TodoRow(
                        item: binding(id),
                        number: index + 1,
                        isDragging: draggingID == id,
                        dropLine: dropLine(at: index),
                        onDrag: { dy in
                            draggingID = id
                            dragSteps = Int((dy / rowHeight).rounded())
                        },
                        onDrop: finishDrag,
                        onHeight: { rowHeight = $0 + 8 }
                    )
                        .tag(id)
                        .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 8))
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
    let number: Int
    let isDragging: Bool
    let dropLine: VerticalEdge?
    let onDrag: (CGFloat) -> Void
    let onDrop: () -> Void
    let onHeight: (CGFloat) -> Void
    @State private var editing = false
    @State private var longPressed = false
    @FocusState private var titleFocused: Bool

    var body: some View {
        HStack {
            Text("\(number).")
                .monospacedDigit()
                .foregroundStyle(Color.muted)
                .frame(minWidth: 18, alignment: .trailing)
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
            if editing {
                TextField("Uppgift", text: $item.title)
                    .textFieldStyle(.plain)
                    .focused($titleFocused)
                    .onSubmit { editing = false }
                    .onChange(of: titleFocused) { _, focused in
                        if !focused { editing = false }
                    }
                    .onAppear { titleFocused = true }
            } else {
                Text(item.title)
                    .strikethrough(item.done)
                    .italic(item.done)
                    .foregroundStyle(titleColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(item.done ? "" : "Klicka: pågår av/på · Håll in och dra: flytta · Dubbelklicka: ändra text")
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .gesture(tapGesture, including: editing ? .subviews : .all)
        .simultaneousGesture(dragGesture, including: editing ? .subviews : .all)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeight($0) }
        .overlay {
            if isDragging {
                RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor, lineWidth: 2)
            }
        }
        .overlay(alignment: dropLine == .bottom ? .bottom : .top) {
            if dropLine != nil {
                Rectangle().fill(Color.accentColor).frame(height: 3)
                    .offset(y: dropLine == .bottom ? 5 : -5)
            }
        }
        .listRowBackground(
            item.inProgress
                ? RoundedRectangle(cornerRadius: 6).fill(Color.inProgress).padding(.horizontal, 4)
                : nil
        )
    }

    private var dragGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                if case .second(true, let drag) = value {
                    longPressed = true
                    onDrag(drag?.translation.height ?? 0)
                }
            }
            .onEnded { _ in
                onDrop()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { longPressed = false }
            }
    }

    private var tapGesture: some Gesture {
        TapGesture(count: 2).onEnded { editing = true }
            .exclusively(before: TapGesture().onEnded {
                guard !longPressed else { return }
                if !item.done { item.inProgress.toggle() }
            })
    }

    private var titleColor: Color {
        item.done ? .doneText : .primary
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
