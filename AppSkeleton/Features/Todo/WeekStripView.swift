import SwiftUI

/// Day strip under the title, per the mockups: collapsed mode shows one week,
/// expanded mode shows the whole month grid with muted adjacent-month days.
/// Each day carries dots — orange when it has flagged todos, blue for plain
/// ones. Horizontal swipe changes week (collapsed) or month (expanded); the
/// handle below toggles between the two. Picking a day in the grid collapses.
struct WeekStripView: View {
    @Binding var selectedDay: Date
    @Binding var isExpanded: Bool
    /// Lookup keyed by start-of-day; missing days have no dots.
    let marks: [Date: DayMark]

    struct DayMark: Equatable {
        var hasPlain = false
        var hasFlagged = false
    }

    private let calendar = Calendar.current
    private static let weekdaySymbols = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                weekdayHeader
                Group {
                    if isExpanded {
                        monthGrid
                            .transition(.move(edge: .top).combined(with: .opacity))
                    } else {
                        weekRow
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                collapseHandle
            }
            .padding(.vertical, Theme.Spacing.medium.rawValue)
            .background(
                Theme.Palette.surface,
                in: RoundedRectangle(cornerRadius: Theme.Radius.sheet.rawValue, style: .continuous)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sheet.rawValue, style: .continuous))
        }
        .padding(.horizontal, Theme.Spacing.large.rawValue)
        .animation(.snappy(duration: 0.25), value: isExpanded)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Self.weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Week mode

    private var weekStart: Date {
        let weekday = calendar.component(.weekday, from: selectedDay) // 1 = Sunday
        return calendar.date(byAdding: .day, value: 1 - weekday, to: calendar.startOfDay(for: selectedDay))!
    }

    private var weekDays: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var weekRow: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { day in
                dayCell(day, inSelectedMonth: true)
            }
        }
        .gesture(swipe)
    }

    // MARK: - Month mode

    private var monthGrid: some View {
        let weeks = gridWeeks
        return VStack(spacing: 6) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(week, id: \.self) { day in
                        dayCell(day, inSelectedMonth: calendar.isDate(day, equalTo: selectedDay, toGranularity: .month))
                    }
                }
            }
        }
        .gesture(swipe)
    }

    /// Full weeks covering the selected month, padded with adjacent-month days.
    private var gridWeeks: [[Date]] {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDay))!
        let leading = calendar.component(.weekday, from: monthStart) - 1
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)!.count
        let gridStart = calendar.date(byAdding: .day, value: -leading, to: monthStart)!
        let cellCount = Int(ceil(Double(leading + daysInMonth) / 7)) * 7
        return stride(from: 0, to: cellCount, by: 7).map { offset in
            (0..<7).compactMap { calendar.date(byAdding: .day, value: offset + $0, to: gridStart) }
        }
    }

    // MARK: - Cells

    private func dayCell(_ day: Date, inSelectedMonth: Bool) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(day)
        let mark = marks[day] ?? DayMark()

        return VStack(spacing: 6) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Theme.Palette.surface)
                        .frame(width: 40, height: 40)
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                } else if isToday {
                    Circle()
                        .strokeBorder(Theme.Palette.primary, lineWidth: 1.5)
                        .frame(width: 40, height: 40)
                }
                Text(day.formatted(.dateTime.day()))
                    .font(isSelected ? .body.weight(.bold) : .body.weight(isToday ? .semibold : .regular))
                    .foregroundStyle(inSelectedMonth ? Theme.Palette.label : Theme.Palette.secondaryLabel.opacity(0.7))
            }
            .frame(height: 40)
            dots(for: mark, muted: !inSelectedMonth)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.snappy(duration: 0.2)) {
                selectedDay = day
                if isExpanded { isExpanded = false }
            }
        }
    }

    private func dots(for mark: DayMark, muted: Bool) -> some View {
        HStack(spacing: 3) {
            if mark.hasFlagged {
                dot(Theme.Palette.flag)
            }
            if mark.hasPlain {
                dot(Theme.Palette.primary)
            }
        }
        .opacity(muted ? 0.5 : 1)
        .frame(height: 5)
    }

    private func dot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 5, height: 5)
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let forward = value.translation.width < 0
                withAnimation(.snappy(duration: 0.2)) {
                    if isExpanded {
                        selectedDay = calendar.date(byAdding: .month, value: forward ? 1 : -1, to: selectedDay)!
                    } else {
                        selectedDay = calendar.date(byAdding: .day, value: forward ? 7 : -7, to: selectedDay)!
                    }
                }
            }
    }

    private var collapseHandle: some View {
        Capsule()
            .fill(Theme.Palette.secondaryLabel.opacity(0.4))
            .frame(width: 36, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onEnded { value in
                        if value.translation.height > 0 && !isExpanded {
                            withAnimation(.snappy(duration: 0.25)) { isExpanded = true }
                        }
                    }
            )
            .onTapGesture { withAnimation(.snappy(duration: 0.25)) { isExpanded.toggle() } }
            .accessibilityLabel(isExpanded ? "收起日历" : "展开日历")
    }
}
