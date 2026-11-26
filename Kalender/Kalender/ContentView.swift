import SwiftUI
import SwiftData

struct DayCount {
    var total = 0
    var open = 0
}

struct ContentView: View {
    @Query private var allItems: [TodoItem]

    @State private var selectedDate = Calendar.app.startOfDay(for: .now)
    @State private var displayedMonth = Calendar.app.startOfMonth(for: .now)
    @State private var showingNewTodo = false

    private var calendar: Calendar { .app }

    private var counts: [Date: DayCount] {
        var result: [Date: DayCount] = [:]
        for item in allItems {
            let day = calendar.startOfDay(for: item.dueDate)
            result[day, default: DayCount()].total += 1
            if !item.isDone {
                result[day, default: DayCount()].open += 1
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
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TodoItem.self, inMemory: true)
}
