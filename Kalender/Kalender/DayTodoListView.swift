import SwiftUI
import SwiftData

struct DayTodoListView: View {
    let day: Date

    @Environment(\.modelContext) private var modelContext
    @Query private var items: [TodoItem]
    @State private var editingItem: TodoItem?

    init(day: Date) {
        let calendar = Calendar.app
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        self.day = start
        _items = Query(
            filter: #Predicate<TodoItem> { $0.dueDate >= start && $0.dueDate < end },
            sort: \TodoItem.createdAt
        )
    }

    /// Ej klara först, sedan efter klockslag och prioritet.
    private var sortedItems: [TodoItem] {
        items.sorted { a, b in
            if a.isDone != b.isDone { return !a.isDone }
            if a.hasTime != b.hasTime { return a.hasTime }
            if a.hasTime && a.dueDate != b.dueDate { return a.dueDate < b.dueDate }
            if a.priorityRaw != b.priorityRaw { return a.priorityRaw > b.priorityRaw }
            return a.createdAt < b.createdAt
        }
    }

    private var doneCount: Int { items.filter(\.isDone).count }

    var body: some View {
        List {
            Section {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Inga uppgifter",
                        systemImage: "checklist",
                        description: Text("Tryck på + för att lägga till en uppgift den här dagen.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(sortedItems) { item in
                        TodoRow(item: item, onToggle: { toggle(item) })
                            .contentShape(Rectangle())
                            .onTapGesture { editingItem = item }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(item)
                                } label: {
                                    Label("Radera", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    toggle(item)
                                } label: {
                                    Label(
                                        item.isDone ? "Ångra" : "Klar",
                                        systemImage: item.isDone ? "arrow.uturn.backward" : "checkmark"
                                    )
                                }
                                .tint(.green)
                            }
                    }
                }
            } header: {
                HStack {
                    Text(day.svString("EEEE d MMMM").capitalizedFirst)
                    Spacer()
                    if !items.isEmpty {
                        Text("\(doneCount) av \(items.count) klara")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $editingItem) { item in
            TodoEditorView(item: item, initialDate: day)
        }
    }

    private func toggle(_ item: TodoItem) {
        withAnimation {
            item.isDone.toggle()
        }
        ReminderScheduler.update(for: item)
    }

    private func delete(_ item: TodoItem) {
        ReminderScheduler.cancel(for: item)
        withAnimation {
            modelContext.delete(item)
        }
    }
}

private struct TodoRow: View {
    let item: TodoItem
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isDone ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isDone ? "Markera som ej klar" : "Markera som klar")

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? Color.secondary : Color.primary)

                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if item.hasTime {
                    HStack(spacing: 4) {
                        Image(systemName: item.hasReminder ? "bell.fill" : "clock")
                        Text(item.dueDate.timeString)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if item.priority == .high {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                    .accessibilityLabel("Hög prioritet")
            } else if item.priority == .low {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Låg prioritet")
            }
        }
        .padding(.vertical, 2)
        .opacity(item.isDone ? 0.7 : 1)
    }
}
