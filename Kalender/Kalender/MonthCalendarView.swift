import SwiftUI

struct MonthCalendarView: View {
    @Binding var selectedDate: Date
    @Binding var displayedMonth: Date
    let counts: [Date: DayCount]

    private var calendar: Calendar { .app }

    /// Veckodagar med början på måndag: M T O T F L S
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift]).map { $0.uppercased() }
    }

    var body: some View {
        VStack(spacing: 8) {
            header

            HStack(spacing: 0) {
                Text("v.")
                    .frame(width: 28)
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            ForEach(Array(calendar.weeksInMonth(displayedMonth).enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    Text(weekNumber(for: week))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 28)

                    ForEach(0..<7, id: \.self) { index in
                        if let day = week[index] {
                            DayCell(
                                date: day,
                                isSelected: calendar.isDate(day, inSameDayAs: selectedDate),
                                isToday: calendar.isDateInToday(day),
                                count: counts[calendar.startOfDay(for: day)]
                            )
                            .onTapGesture {
                                selectedDate = calendar.startOfDay(for: day)
                            }
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width < -50 {
                        changeMonth(by: 1)
                    } else if value.translation.width > 50 {
                        changeMonth(by: -1)
                    }
                }
        )
    }

    private var header: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .padding(8)
            }
            .accessibilityLabel("Föregående månad")

            Spacer()

            Text(displayedMonth.svString("MMMM yyyy").capitalizedFirst)
                .font(.title3.bold())

            Spacer()

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .padding(8)
            }
            .accessibilityLabel("Nästa månad")
        }
        .padding(.top, 4)
    }

    private func weekNumber(for week: [Date?]) -> String {
        guard let day = week.compactMap({ $0 }).first else { return "" }
        return "\(calendar.component(.weekOfYear, from: day))"
    }

    private func changeMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = newMonth
        }
    }
}

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let count: DayCount?

    var body: some View {
        VStack(spacing: 3) {
            Text("\(Calendar.app.component(.day, from: date))")
                .font(.body.weight(isToday || isSelected ? .bold : .regular))
                .foregroundStyle(foreground)
                .frame(width: 34, height: 34)
                .background {
                    if isSelected {
                        Circle().fill(Color.accentColor)
                    } else if isToday {
                        Circle().stroke(Color.accentColor, lineWidth: 1.5)
                    }
                }

            indicator
                .frame(height: 6)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var foreground: Color {
        if isSelected { return .white }
        if isToday { return .accentColor }
        return .primary
    }

    @ViewBuilder
    private var indicator: some View {
        if let count, count.total > 0 {
            Circle()
                .fill(count.open > 0 ? Color.accentColor : Color.green)
                .frame(width: 6, height: 6)
        } else {
            Color.clear.frame(width: 6, height: 6)
        }
    }

    private var accessibilityText: String {
        var text = date.svString("EEEE d MMMM")
        if let count, count.total > 0 {
            text += ", \(count.open) av \(count.total) uppgifter kvar"
        }
        return text
    }
}
