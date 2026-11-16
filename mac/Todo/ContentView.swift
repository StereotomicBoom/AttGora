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

enum TextScale {
    static let key = "textScale"
    static func step(_ value: Double, by delta: Double) -> Double {
        min(2.0, max(0.7, ((value + delta) * 10).rounded() / 10))
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
    @AppStorage(TextScale.key) private var textScale = 1.0
    @FocusState private var newTaskFocused: Bool
    @State private var draggingID: UUID?
    @State private var dragSteps = 0
    @State private var dragOffset: CGFloat = 0
    @State private var rowHeight: CGFloat = 30

    private var dragIndices: (from: Int, to: Int)? {
        guard let id = draggingID, let from = visibleIDs.firstIndex(of: id) else { return nil }
        return (from, min(max(from + dragSteps, 0), visibleIDs.count - 1))
    }

    private func shift(at index: Int) -> CGFloat {
        guard let d = dragIndices else { return 0 }
        if index == d.from { return dragOffset }
        if d.from < index && index <= d.to { return -rowHeight }
        if d.to <= index && index < d.from { return rowHeight }
        return 0
    }

    private func finishDrag() {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            if let d = dragIndices, d.to != d.from {
                store.move(visible: visibleIDs, from: IndexSet(integer: d.from),
                           to: d.to > d.from ? d.to + 1 : d.to)
            }
            draggingID = nil
            dragSteps = 0
            dragOffset = 0
        }
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
                    .font(.system(size: 26 * textScale))
                    .padding(.horizontal, 12)
                    .frame(height: 57 * textScale)
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

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(visibleIDs.enumerated()), id: \.element) { index, id in
                        let isDragging = draggingID == id
                        VStack(spacing: 0) {
                            TodoRow(
                                item: binding(id),
                                number: index + 1,
                                onDrag: { dy in
                                    draggingID = id
                                    dragOffset = dy
                                    dragSteps = Int((dy / rowHeight).rounded())
                                },
                                onDrop: finishDrag
                            )
                            .padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 8))
                            Rule().padding(.leading, 4)
                        }
                        .background(Color.paper)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowHeight = $0 }
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
                        .shadow(color: .black.opacity(isDragging ? 0.25 : 0), radius: 6, y: 2)
                        .offset(y: shift(at: index))
                        .animation(isDragging ? nil : .easeInOut(duration: 0.15), value: shift(at: index))
                        .zIndex(isDragging ? 1 : 0)
                    }
                }
                .padding(.horizontal, 4)
            }
            .background(Color.paper)
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
                Button { textScale = TextScale.step(textScale, by: -0.1) } label: {
                    Image(systemName: "minus").frame(width: 14, height: 14)
                }
                .disabled(textScale <= 0.7)
                .help("Mindre text (⌘−)")
                Button { textScale = TextScale.step(textScale, by: 0.1) } label: {
                    Image(systemName: "plus").frame(width: 14, height: 14)
                }
                .disabled(textScale >= 2.0)
                .help("Större text (⌘+)")
                Spacer()
                Button("Rensa klara", action: store.clearCompleted)
                    .disabled(store.items.allSatisfy { !$0.done })
            }
            .padding()
        }
        .font(.system(size: 17 * textScale))
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
    let onDrag: (CGFloat) -> Void
    let onDrop: () -> Void
    @State private var editing = false
    @State private var longPressed = false
    @AppStorage(TextScale.key) private var textScale = 1.0
    @FocusState private var titleFocused: Bool

    var body: some View {
        HStack {
            Text("\(number).")
                .monospacedDigit()
                .foregroundStyle(Color.muted)
                .frame(minWidth: 18 * textScale, alignment: .trailing)
                .contentShape(Rectangle())
                .gesture(tapGesture)
            Button {
                item.done.toggle()
            } label: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(item.done ? Color.accentColor : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(item.done ? .clear : Color(white: 0.45), lineWidth: 1.5)
                    )
                    .overlay {
                        if item.done {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11 * textScale, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 18 * textScale, height: 18 * textScale)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Klar")
            .accessibilityValue(item.done ? "Ja" : "Nej")
            Button {
                item.priority = item.priority == 0 ? Priority.medium.rawValue : Priority.none.rawValue
            } label: {
                Image(systemName: item.priority == 0 ? "star" : "star.fill")
                    .font(.system(size: 17 * textScale))
                    .foregroundStyle(priorityColor)
                    .frame(width: 20 * textScale, height: 18 * textScale)
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
                    .contentShape(Rectangle())
                    .gesture(tapGesture)
                    .help(item.done ? "" : "Klicka: pågår av/på · Håll in och dra: flytta · Dubbelklicka: ändra text")
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .simultaneousGesture(dragGesture, including: editing ? .subviews : .all)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(item.inProgress ? Color.inProgress : .clear)
                .padding(.horizontal, -4)
                .padding(.vertical, -2)
        )
    }

    private var dragGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
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
        case .none: Color(white: 0.55)
        case .medium: Color(red: 1.0, green: 0.69, blue: 0.30)
        }
    }
}
