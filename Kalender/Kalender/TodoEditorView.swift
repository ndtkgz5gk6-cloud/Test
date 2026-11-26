import SwiftUI
import SwiftData

struct TodoEditorView: View {
    let item: TodoItem?
    /// Dagen uppgiften öppnades från (används när ett enskilt tillfälle raderas).
    let occurrenceDay: Date

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var notes: String
    @State private var date: Date
    @State private var hasTime: Bool
    @State private var time: Date
    @State private var hasReminder: Bool
    @State private var priority: Priority
    @State private var recurrence: Recurrence
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var showingDeleteConfirmation = false
    @State private var notificationsDenied = false

    @FocusState private var titleFocused: Bool

    init(item: TodoItem?, initialDate: Date) {
        self.item = item
        self.occurrenceDay = initialDate
        let calendar = Calendar.app
        let startDate = item?.dueDate ?? initialDate
        _title = State(initialValue: item?.title ?? "")
        _notes = State(initialValue: item?.notes ?? "")
        _date = State(initialValue: startDate)
        _hasTime = State(initialValue: item?.hasTime ?? false)
        _hasReminder = State(initialValue: item?.hasReminder ?? false)
        _priority = State(initialValue: item?.priority ?? .normal)
        _recurrence = State(initialValue: item?.recurrence ?? .none)
        _hasEndDate = State(initialValue: item?.recurrenceEnd != nil)
        _endDate = State(
            initialValue: item?.recurrenceEnd
                ?? calendar.date(byAdding: .month, value: 1, to: startDate)
                ?? startDate
        )

        if let item, item.hasTime {
            _time = State(initialValue: item.dueDate)
        } else {
            // Förval: nästa hela timme
            let nextHour = calendar.date(byAdding: .hour, value: 1, to: .now) ?? .now
            let rounded = calendar.date(bySetting: .minute, value: 0, of: nextHour) ?? nextHour
            _time = State(initialValue: rounded)
        }
    }

    private var isNew: Bool { item == nil }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Vad behöver göras?", text: $title)
                        .focused($titleFocused)
                        .submitLabel(.done)
                    TextField("Anteckningar", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    DatePicker(
                        recurrence == .none ? "Datum" : "Startdatum",
                        selection: $date,
                        displayedComponents: .date
                    )

                    Toggle("Klockslag", isOn: $hasTime.animation())

                    if hasTime {
                        DatePicker("Tid", selection: $time, displayedComponents: .hourAndMinute)

                        Toggle("Påminnelse", isOn: $hasReminder)
                            .onChange(of: hasReminder) { _, newValue in
                                guard newValue else { return }
                                Task {
                                    let granted = await ReminderScheduler.requestAuthorization()
                                    if !granted {
                                        hasReminder = false
                                        notificationsDenied = true
                                    }
                                }
                            }
                    }
                } footer: {
                    if notificationsDenied {
                        Text("Notiser är avstängda. Slå på dem för Kalender i Inställningar för att få påminnelser.")
                    }
                }

                Section {
                    Picker("Upprepa", selection: $recurrence.animation()) {
                        ForEach(Recurrence.allCases) { recurrence in
                            Text(recurrence.title).tag(recurrence)
                        }
                    }

                    if recurrence != .none {
                        Toggle("Slutdatum", isOn: $hasEndDate.animation())

                        if hasEndDate {
                            DatePicker(
                                "Sista dag",
                                selection: $endDate,
                                in: Calendar.app.startOfDay(for: date)...,
                                displayedComponents: .date
                            )
                        }
                    }
                } footer: {
                    if recurrence != .none && !isNew {
                        Text("Ändringar gäller alla tillfällen i serien.")
                    }
                }

                Section("Prioritet") {
                    Picker("Prioritet", selection: $priority) {
                        ForEach(Priority.allCases) { priority in
                            Text(priority.title).tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                if let item {
                    Section {
                        Button(item.isRecurring ? "Radera…" : "Radera uppgift", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
            .environment(\.locale, Locale(identifier: "sv_SE"))
            .environment(\.calendar, .app)
            .navigationTitle(isNew ? "Ny uppgift" : "Redigera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") { save() }
                        .disabled(trimmedTitle.isEmpty)
                }
            }
            .confirmationDialog(
                item?.isRecurring == true ? "Det här är en återkommande uppgift" : "Vill du radera uppgiften?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                if let item, item.isRecurring {
                    if item.occurs(on: occurrenceDay) {
                        Button("Radera endast \(occurrenceDay.svString("d MMMM"))", role: .destructive) {
                            deleteItem(scope: .thisDay)
                        }
                        Button("Radera denna och kommande", role: .destructive) {
                            deleteItem(scope: .thisAndFuture)
                        }
                    }
                    Button("Radera hela serien", role: .destructive) {
                        deleteItem(scope: .all)
                    }
                } else {
                    Button("Radera", role: .destructive) {
                        deleteItem(scope: .all)
                    }
                }
            }
            .onAppear {
                if isNew { titleFocused = true }
            }
        }
    }

    private func save() {
        let calendar = Calendar.app
        let dueDate = hasTime
            ? calendar.combine(day: date, time: time)
            : calendar.startOfDay(for: date)
        let reminder = hasTime && hasReminder
        let end: Date? = (recurrence != .none && hasEndDate)
            ? max(calendar.startOfDay(for: endDate), calendar.startOfDay(for: date))
            : nil

        let target: TodoItem
        if let item {
            item.title = trimmedTitle
            item.notes = notes
            item.dueDate = dueDate
            item.hasTime = hasTime
            item.hasReminder = reminder
            item.priority = priority
            item.recurrence = recurrence
            item.recurrenceEnd = end
            target = item
        } else {
            target = TodoItem(
                title: trimmedTitle,
                notes: notes,
                dueDate: dueDate,
                hasTime: hasTime,
                hasReminder: reminder,
                priority: priority,
                recurrence: recurrence,
                recurrenceEnd: end
            )
            modelContext.insert(target)
        }

        ReminderScheduler.update(for: target)
        dismiss()
    }

    private func deleteItem(scope: TodoItem.DeleteScope) {
        guard let item else { return }
        if item.removeOccurrences(scope, day: occurrenceDay) {
            ReminderScheduler.cancel(for: item)
            modelContext.delete(item)
        } else {
            ReminderScheduler.update(for: item)
        }
        dismiss()
    }
}
