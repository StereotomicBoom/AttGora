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
                                onDrop: finishDrag,
                                onMoveToTop: { store.moveToTop(id) }
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
    let onMoveToTop: () -> Void
    @State private var editing = false
    @State private var longPressed = false
    @State private var showAlarm = false
    @State private var now = Date()
    @State private var clickMonitor: Any?
    @State private var titleWidth: CGFloat = 0
    @AppStorage(TextScale.key) private var textScale = 1.0
    @FocusState private var titleFocused: Bool

    var body: some View {
        HStack {
            Text("\(number).")
                .monospacedDigit()
                .foregroundStyle(Color.muted)
                .fixedSize()
                .frame(minWidth: 28 * textScale, alignment: .trailing)
                .contentShape(Rectangle())
                .gesture(outsideTapGesture)
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
            Button {
                showAlarm = true
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "stopwatch")
                        .font(.system(size: 16 * textScale))
                    if let alarm = activeAlarm {
                        Text(alarmLabel(alarm))
                            .font(.system(size: 12 * textScale))
                            .monospacedDigit()
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
                .foregroundStyle(activeAlarm != nil ? Color.accentColor : Color(white: 0.55))
                .frame(minWidth: 20 * textScale, minHeight: 18 * textScale)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .opacity(item.done ? 0.4 : 1)
            .disabled(item.done)
            .help(activeAlarm.map { "Alarm: \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "Sätt alarm")
            .accessibilityLabel("Alarm")
            .popover(isPresented: $showAlarm, arrowEdge: .bottom) {
                AlarmEditor(item: $item) { showAlarm = false }
            }
            ZStack(alignment: .topLeading) {
                if editing {
                    TextField("Uppgift", text: $item.title, axis: .vertical)
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
                        .contentShape(Rectangle())
                        .gesture(tapGesture)
                        .help(item.done ? "" : "Klicka: pågår av/på · Håll in och dra: flytta · Dubbelklicka: ändra text")
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { titleWidth = $0 }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(outsideTapGesture)
                    .help("Dubbelklicka: flytta överst")
            )
        }
        .padding(.vertical, 2)
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now = $0 }
        .onChange(of: editing) { _, isEditing in
            if isEditing {
                clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
                    endEditingIfOutside(event)
                    return event
                }
            } else if let clickMonitor {
                NSEvent.removeMonitor(clickMonitor)
                self.clickMonitor = nil
            }
        }
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

    private var outsideTapGesture: some Gesture {
        TapGesture(count: 2).onEnded { onMoveToTop() }
            .exclusively(before: TapGesture().onEnded {
                guard !longPressed else { return }
                if !item.done { item.inProgress.toggle() }
            })
    }

    private var tapGesture: some Gesture {
        SpatialTapGesture(count: 2).onEnded { tap in
            if isOnText(tap.location) { editing = true } else { onMoveToTop() }
        }
            .exclusively(before: TapGesture().onEnded {
                guard !longPressed else { return }
                if !item.done { item.inProgress.toggle() }
            })
    }

    private func isOnText(_ point: CGPoint) -> Bool {
        let storage = NSTextStorage(string: item.title, attributes: [.font: NSFont.systemFont(ofSize: 17 * textScale)])
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: titleWidth + 1, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        layout.ensureLayout(for: container)
        var lines: [CGRect] = []
        layout.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: layout.numberOfGlyphs)) { _, used, _, _, _ in
            lines.append(used)
        }
        guard let line = lines.first(where: { point.y < $0.maxY }) ?? lines.last else { return true }
        return point.x <= line.maxX + 4
    }

    private func endEditingIfOutside(_ event: NSEvent) {
        guard let window = event.window,
              let editor = window.firstResponder as? NSTextView,
              let hit = window.contentView?.hitTest(window.contentView!.convert(event.locationInWindow, from: nil)),
              hit === editor || hit.isDescendant(of: editor) == true
        else {
            editing = false
            return
        }
    }

    private var activeAlarm: Date? {
        guard let alarm = item.alarm, alarm > now else { return nil }
        return alarm
    }

    private func alarmLabel(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
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

struct AlarmEditor: View {
    @Binding var item: TodoItem
    let close: () -> Void
    @State private var date: Date

    init(item: Binding<TodoItem>, close: @escaping () -> Void) {
        _item = item
        self.close = close
        let soon = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        _date = State(initialValue: item.wrappedValue.alarm.flatMap { $0 > Date() ? $0 : nil } ?? soon)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Alarm").font(.headline)
            Text(item.title)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: 12) {
                ClockField(date: $date)
                    .fixedSize()
                    .frame(maxHeight: .infinity)
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        if item.alarm != nil {
                            wideButton("Ta bort", role: .destructive) {
                                item.alarm = nil
                                close()
                            }
                        } else {
                            wideButton("Avbryt", action: close)
                                .keyboardShortcut(.cancelAction)
                        }
                        wideButton("Sätt alarm") {
                            item.alarm = nextOccurrence(of: date)
                            close()
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                    GridRow {
                        wideButton("+15 min") { date = Date().addingTimeInterval(15 * 60) }
                        wideButton("+1 h") { date = Date().addingTimeInterval(60 * 60) }
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 13))
        .padding(12)
        .frame(width: 340)
        .background {
            if item.alarm != nil {
                Button("", action: close)
                    .keyboardShortcut(.cancelAction)
                    .opacity(0)
            }
        }
    }

    private func wideButton(_ title: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
    }

    private func nextOccurrence(of time: Date) -> Date {
        let cal = Calendar.current
        let parts = cal.dateComponents([.hour, .minute], from: time)
        let now = Date()
        let today = cal.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: now) ?? time
        return today > now ? today : cal.date(byAdding: .day, value: 1, to: today) ?? today
    }
}

struct ClockField: View {
    @Binding var date: Date
    @FocusState private var focus: Part?
    @State private var typed = ""
    @State private var hovered: Part?
    @State private var overClock = false
    @State private var scrollMonitor: Any?
    @State private var scrollAccum: CGFloat = 0

    enum Part { case hour, minute }

    var body: some View {
        HStack(spacing: 4) {
            HStack(spacing: 0) {
                segment(.hour)
                Text(":").padding(.bottom, 4)
                segment(.minute)
            }
            .font(.system(size: 36, weight: .medium, design: .rounded).monospacedDigit())
            VStack(spacing: 2) {
                chevron("chevron.up", 1)
                chevron("chevron.down", -1)
            }
        }
        .onChange(of: focus) { typed = "" }
        .onHover { overClock = $0 }
        .onAppear {
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                handleScroll(event) ? nil : event
            }
        }
        .onDisappear {
            if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
            scrollMonitor = nil
        }
    }

    private func handleScroll(_ event: NSEvent) -> Bool {
        guard overClock else { return false }
        let part = focus ?? hovered ?? .minute
        var dy = event.scrollingDeltaY
        if event.isDirectionInvertedFromDevice { dy = -dy }
        if event.hasPreciseScrollingDeltas {
            scrollAccum += dy
            let threshold: CGFloat = 12
            while abs(scrollAccum) >= threshold {
                step(part, scrollAccum > 0 ? 1 : -1)
                scrollAccum -= scrollAccum > 0 ? threshold : -threshold
            }
        } else if dy != 0 {
            step(part, dy > 0 ? 1 : -1)
        }
        return true
    }

    private func segment(_ part: Part) -> some View {
        Text(String(format: "%02d", value(part)))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(focus == part ? Color.accentColor.opacity(0.25) : .clear)
            )
            .contentShape(Rectangle())
            .focusable()
            .focused($focus, equals: part)
            .focusEffectDisabled()
            .onTapGesture { focus = part }
            .onHover { inside in
                if inside { hovered = part } else if hovered == part { hovered = nil }
            }
            .onKeyPress(.upArrow) { step(part, 1); return .handled }
            .onKeyPress(.downArrow) { step(part, -1); return .handled }
            .onKeyPress(.leftArrow) { focus = .hour; return .handled }
            .onKeyPress(.rightArrow) { focus = .minute; return .handled }
            .onKeyPress(characters: .decimalDigits) { press in
                type(press.characters, into: part)
                return .handled
            }
    }

    private func chevron(_ symbol: String, _ delta: Int) -> some View {
        Button { step(focus ?? .minute, delta) } label: {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 36, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private func value(_ part: Part) -> Int {
        Calendar.current.component(part == .hour ? .hour : .minute, from: date)
    }

    private func step(_ part: Part, _ delta: Int) {
        let max = part == .hour ? 24 : 60
        set(part, ((value(part) + delta) % max + max) % max)
    }

    private func type(_ digits: String, into part: Part) {
        typed = String((typed + digits).suffix(2))
        if let v = Int(typed), v <= (part == .hour ? 23 : 59) {
            set(part, v)
        }
        if typed.count == 2 {
            typed = ""
            if part == .hour { focus = .minute }
        }
    }

    private func set(_ part: Part, _ v: Int) {
        let cal = Calendar.current
        let hour = part == .hour ? v : value(.hour)
        let minute = part == .minute ? v : value(.minute)
        date = cal.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }
}
