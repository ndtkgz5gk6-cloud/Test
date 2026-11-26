import SwiftUI
import SwiftData

struct DayCount {
    var total = 0
    var open = 0
}

struct ContentView: View {
    @Query private var allItems: [TodoItem]
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedDate = Calendar.app.startOfDay(for: .now)
    @State private var displayedMonth = Calendar.app.startOfMonth(for: .now)
    @State private var showingNewTodo = false

    private var calendar: Calendar { .app }

    /// Antal uppgifter per dag i den visade månaden (inklusive återkommande tillfällen).
    private var counts: [Date: DayCount] {
        var result: [Date: DayCount] = [:]
        let days = calendar.weeksInMonth(displayedMonth).flatMap { $0 }.compactMap { $0 }
        for day in days {
            var count = DayCount()
            for item in allItems where item.occurs(on: day) {
                count.total += 1
                if !item.isDone(on: day) { count.open += 1 }
            }
            if count.total > 0 {
                result[calendar.startOfDay(for: day)] = count
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MonthCalendarView(
                    selectedDate: $selectedDate,
                    displayedMonth: $displayedMonth,
                    counts: counts
                )
                .padding(.horizontal)
                .padding(.bottom, 8)

                Divider()

                DayTodoListView(day: selectedDate)
                    .id(selectedDate)
            }
            .navigationTitle("Kalender")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Idag") {
                        withAnimation {
                            selectedDate = calendar.startOfDay(for: .now)
                            displayedMonth = calendar.startOfMonth(for: .now)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewTodo = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Ny uppgift")
                }
            }
            .sheet(isPresented: $showingNewTodo) {
                TodoEditorView(item: nil, initialDate: selectedDate)
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                // Fyll på påminnelser för återkommande uppgifter
                if phase == .active {
                    ReminderScheduler.refreshAll(allItems)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TodoItem.self, inMemory: true)
}
