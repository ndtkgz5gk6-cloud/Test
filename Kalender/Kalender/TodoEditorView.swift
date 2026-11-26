import SwiftUI
import SwiftData

struct TodoEditorView: View {
    let item: TodoItem?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var notes: String
    @State private var date: Date
    @State private var hasTime: Bool
    @State private var time: Date
    @State private var hasReminder: Bool
    @State private var priority: Priority
    @State private var showingDeleteConfirmation = false
    @State private var notificationsDenied = false

    @FocusState private var titleFocused: Bool

    init(item: TodoItem?, initialDate: Date) {
        self.item = item
        let calendar = Calendar.app
        _title = State(initialValue: item?.title ?? "")
        _notes = State(initialValue: item?.notes ?? "")
        _date = State(initialValue: item?.dueDate ?? initialDate)
        _hasTime = State(initialValue: item?.hasTime ?? false)
        _hasReminder = State(initialValue: item?.hasReminder ?? false)
        _priority = State(initialValue: item?.priority ?? .normal)

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
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "sv_SE"))
                        .environment(\.calendar, .app)

                    Toggle("Klockslag", isOn: $hasTime.animation())

                    if hasTime {
                        DatePicker("Tid", selection: $time, displayedComponents: .hourAndMinute)
                            .environment(\.locale, Locale(identifier: "sv_SE"))

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

                Section("Prioritet") {
                    Picker("Prioritet", selection: $priority) {
                        ForEach(Priority.allCases) { priority in
                            Text(priority.title).tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                if !isNew {
                    Section {
                        Button("Radera uppgift", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
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
                "Vill du radera uppgiften?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Radera", role: .destructive) { deleteItem() }
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

        let target: TodoItem
        if let item {
            item.title = trimmedTitle
            item.notes = notes
            item.dueDate = dueDate
            item.hasTime = hasTime
            item.hasReminder = reminder
            item.priority = priority
            target = item
        } else {
            target = TodoItem(
                title: trimmedTitle,
                notes: notes,
                dueDate: dueDate,
                hasTime: hasTime,
                hasReminder: reminder,
                priority: priority
            )
            modelContext.insert(target)
        }

        ReminderScheduler.update(for: target)
        dismiss()
    }

    private func deleteItem() {
        guard let item else { return }
        ReminderScheduler.cancel(for: item)
        modelContext.delete(item)
        dismiss()
    }
}
