import SwiftUI
import SwiftData

/// Ett tillfälle av en uppgift en viss dag.
struct Occurrence: Identifiable {
    let item: TodoItem
    let day: Date

    var id: PersistentIdentifier { item.persistentModelID }
    var isDone: Bool { item.isDone(on: day) }
    var date: Date { item.occurrenceDate(on: day) }
}

struct DayTodoListView: View {
    let day: Date

    @Environment(\.modelContext) private var modelContext
    @Query private var items: [TodoItem]
    @State private var editingItem: TodoItem?
    @State private var pendingDelete: Occurrence?

    init(day: Date) {
        let calendar = Calendar.app
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        self.day = start
        // Vanliga uppgifter den här dagen + alla serier som har startat
        _items = Query(
            filter: #Predicate<TodoItem> {
                ($0.recurrenceRaw == 0 && $0.dueDate >= start && $0.dueDate < end)
                    || ($0.recurrenceRaw != 0 && $0.dueDate < end)
            },
            sort: \TodoItem.createdAt
        )
    }

    /// Ej klara först, sedan efter klockslag och prioritet.
    private var occurrences: [Occurrence] {
        items
            .filter { $0.occurs(on: day) }
            .map { Occurrence(item: $0, day: day) }
            .sorted { a, b in
                if a.isDone != b.isDone { return !a.isDone }
                if a.item.hasTime != b.item.hasTime { return a.item.hasTime }
                if a.item.hasTime && a.date != b.date { return a.date < b.date }
                if a.item.priorityRaw != b.item.priorityRaw { return a.item.priorityRaw > b.item.priorityRaw }
                return a.item.createdAt < b.item.createdAt
            }
    }

    var body: some View {
        let occurrences = occurrences
        let doneCount = occurrences.filter(\.isDone).count

        List {
            Section {
                if occurrences.isEmpty {
                    ContentUnavailableView(
                        "Inga uppgifter",
                        systemImage: "checklist",
                        description: Text("Tryck på + för att lägga till en uppgift den här dagen.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(occurrences) { occurrence in
                        TodoRow(occurrence: occurrence, onToggle: { toggle(occurrence) })
                            .contentShape(Rectangle())
                            .onTapGesture { editingItem = occurrence.item }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    if occurrence.item.isRecurring {
                                        pendingDelete = occurrence
                                    } else {
                                        delete(occurrence, scope: .all)
                                    }
                                } label: {
                                    Label("Radera", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    toggle(occurrence)
                                } label: {
                                    Label(
                                        occurrence.isDone ? "Ångra" : "Klar",
                                        systemImage: occurrence.isDone ? "arrow.uturn.backward" : "checkmark"
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
                    if !occurrences.isEmpty {
                        Text("\(doneCount) av \(occurrences.count) klara")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $editingItem) { item in
            TodoEditorView(item: item, initialDate: day)
        }
        .confirmationDialog(
            "Det här är en återkommande uppgift",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { occurrence in
            Button("Radera endast denna dag", role: .destructive) {
                delete(occurrence, scope: .thisDay)
            }
            Button("Radera denna och kommande", role: .destructive) {
                delete(occurrence, scope: .thisAndFuture)
            }
            Button("Radera hela serien", role: .destructive) {
                delete(occurrence, scope: .all)
            }
        }
    }

    private func toggle(_ occurrence: Occurrence) {
        withAnimation {
            occurrence.item.toggleDone(on: occurrence.day)
        }
        ReminderScheduler.update(for: occurrence.item)
    }

    private func delete(_ occurrence: Occurrence, scope: TodoItem.DeleteScope) {
        let item = occurrence.item
        withAnimation {
            if item.removeOccurrences(scope, day: occurrence.day) {
                ReminderScheduler.cancel(for: item)
                modelContext.delete(item)
            } else {
                ReminderScheduler.update(for: item)
            }
        }
        pendingDelete = nil
    }
}

private struct TodoRow: View {
    let occurrence: Occurrence
    let onToggle: () -> Void

    private var item: TodoItem { occurrence.item }

    var body: some View {
        let isDone = occurrence.isDone

        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isDone ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDone ? "Markera som ej klar" : "Markera som klar")

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .strikethrough(isDone)
                    .foregroundStyle(isDone ? Color.secondary : Color.primary)

                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if item.hasTime || item.isRecurring {
                    HStack(spacing: 10) {
                        if item.hasTime {
                            Label(occurrence.date.timeString, systemImage: item.hasReminder ? "bell.fill" : "clock")
                        }
                        if item.isRecurring {
                            Label(item.recurrence.shortTitle, systemImage: "repeat")
                        }
                    }
                    .labelStyle(CompactLabelStyle())
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
        .opacity(isDone ? 0.7 : 1)
    }
}

private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}
