import SwiftUI
import SwiftData

struct TodoListView: View {
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var items: [TodoItem]
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context

    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var calendarExpanded = false
    @State private var showingSearch = false
    @State private var showingQuickEntry = false
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var calendar: Calendar { .current }
    private var todayStart: Date { calendar.startOfDay(for: .now) }
    private var isTodaySelected: Bool { calendar.isDate(selectedDay, inSameDayAs: .now) }

    /// 待办·9月 — the month follows the selected week.
    private var pageTitle: String {
        "待办·\(selectedDay.formatted(.dateTime.month(.defaultDigits)))月"
    }

    var body: some View {
        VStack(spacing: 0) {
            if showingSearch {
                searchBar
            } else {
                headerBar
                WeekStripView(selectedDay: $selectedDay, isExpanded: $calendarExpanded, marks: dateMarks)
            }
            cardList
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingQuickEntry) {
            TodoQuickEntryView(defaultDay: selectedDay)
        }
        .task { applyDebugFixture() }
    }

    // MARK: - Header

    /// Title on the left, …🔍 pill and a separate + circle on the right.
    private var headerBar: some View {
        HStack(spacing: Theme.Spacing.small.rawValue) {
            Text(pageTitle)
                .font(.system(size: 28, weight: .bold))
            Spacer(minLength: 0)
            HStack(spacing: Theme.Spacing.medium.rawValue) {
                Menu {
                    Button("回到今天") {
                        withAnimation(.snappy) { selectedDay = todayStart }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Palette.label)
                }
                .tint(Theme.Palette.label)
                Button {
                    withAnimation(.snappy) { showingSearch = true }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Palette.label)
                }
                .accessibilityLabel("搜索待办")
            }
            .padding(.horizontal, Theme.Spacing.large.rawValue)
            .padding(.vertical, 10)
            .frame(height: 44)
            .glassCapsule()

            Button {
                showingQuickEntry = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.Palette.label)
                    .frame(width: 44, height: 44)
            }
            .glassCapsule(Circle())
            .accessibilityLabel("新建待办")
        }
        .padding(.horizontal, Theme.Spacing.large.rawValue)
        .padding(.top, Theme.Spacing.small.rawValue)
        .padding(.bottom, Theme.Spacing.medium.rawValue)
    }

    /// Search replaces the whole header, per the 搜索 mockup.
    private var searchBar: some View {
        HStack(spacing: Theme.Spacing.small.rawValue) {
            HStack(spacing: Theme.Spacing.small.rawValue) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.Palette.secondaryLabel)
                TextField("搜索待办", text: $query)
                    .autocorrectionDisabled()
                    .focused($searchFocused)
                Image(systemName: "mic.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Palette.secondaryLabel.opacity(0.6))
            }
            .padding(.horizontal, Theme.Spacing.large.rawValue)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .glassCapsule()

            Button {
                withAnimation(.snappy) {
                    showingSearch = false
                    query = ""
                    searchFocused = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Palette.label)
                    .frame(width: 40, height: 40)
            }
            .glassCapsule(Circle())
            .accessibilityLabel("取消搜索")
        }
        .padding(.horizontal, Theme.Spacing.large.rawValue)
        .padding(.top, Theme.Spacing.small.rawValue)
        .padding(.bottom, Theme.Spacing.medium.rawValue)
        .onAppear { searchFocused = true }
    }

    // MARK: - Sections

    private var daySections: [(id: String, title: String, rows: [TodoItem])] {
        let incomplete = items.filter { !$0.isDone }

        // Overdue todos fold into today's list; other days show only their own.
        let overdue = isTodaySelected
            ? incomplete.filter { let day = $0.dueDay; return day != nil && day! < todayStart }
            : []
        let ofDay = incomplete.filter { $0.dueDay == selectedDay }
        let dayRows = (overdue + ofDay).sorted { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) }

        let unscheduled = incomplete.filter { $0.dueDate == nil }
        let completed = items.filter { $0.isDone }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }

        var sections: [(id: String, title: String, rows: [TodoItem])] = []
        let dayTitle = isTodaySelected ? "今日待办" : selectedDay.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_CN"))) + " 待办"
        if !dayRows.isEmpty { sections.append(("day", dayTitle, dayRows)) }
        if !unscheduled.isEmpty { sections.append(("unscheduled", "未安排", unscheduled)) }
        if !completed.isEmpty { sections.append(("done", "已完成", completed)) }
        return sections
    }

    private var searchResults: [TodoItem] {
        guard !query.isEmpty else { return [] }
        return items
            .filter { $0.title.localizedStandardContains(query) }
            .sorted {
                if $0.isDone != $1.isDone { return !$0.isDone }
                return ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }
    }

    private var dateMarks: [Date: WeekStripView.DayMark] {
        var map: [Date: WeekStripView.DayMark] = [:]
        for item in items where !item.isDone {
            guard let day = item.dueDay else { continue }
            var mark = map[day] ?? WeekStripView.DayMark()
            if item.isFlagged { mark.hasFlagged = true } else { mark.hasPlain = true }
            map[day] = mark
        }
        return map
    }

    // MARK: - Content

    @ViewBuilder
    private var cardList: some View {
        if showingSearch {
            if query.isEmpty {
                emptySearchPrompt
            } else if searchResults.isEmpty {
                noResultsCard
            } else {
                searchResultList
            }
        } else if daySections.isEmpty {
            emptyDayCard
        } else {
            sectionList
        }
    }

    private var emptySearchPrompt: some View {
        VStack(spacing: Theme.Spacing.small.rawValue) {
            Text("请输入关键词搜索")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.Palette.secondaryLabel)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(Theme.Spacing.large.rawValue)
        .background(
            Theme.Palette.surface,
            in: RoundedRectangle(cornerRadius: Theme.Radius.sheet.rawValue, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sheet.rawValue, style: .continuous))
        .padding(.horizontal, Theme.Spacing.medium.rawValue)
    }

    private var noResultsCard: some View {
        VStack(spacing: Theme.Spacing.small.rawValue) {
            Text("没有匹配的待办")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.Palette.secondaryLabel)
            Text("换个关键词试试")
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.secondaryLabel.opacity(0.7))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(Theme.Spacing.large.rawValue)
        .background(
            Theme.Palette.surface,
            in: RoundedRectangle(cornerRadius: Theme.Radius.sheet.rawValue, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sheet.rawValue, style: .continuous))
        .padding(.horizontal, Theme.Spacing.medium.rawValue)
    }

    private var searchResultList: some View {
        List {
            ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, item in
                TodoRow(item: item, showsDivider: index < searchResults.count - 1)
            }
        }
        .todoCardStyle()
    }

    /// 今日待办 header with a plain hint line, per the 无状态 mockup.
    private var emptyDayCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small.rawValue) {
            Text(isTodaySelected ? "今日待办" : "这一天")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.Palette.secondaryLabel)
            Text(isTodaySelected ? "今日没有待办，请点击右上角添加按钮" : "这一天没有待办，请点击右上角添加按钮")
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.secondaryLabel.opacity(0.7))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(Theme.Spacing.large.rawValue)
        .background(
            Theme.Palette.surface,
            in: RoundedRectangle(cornerRadius: Theme.Radius.sheet.rawValue, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sheet.rawValue, style: .continuous))
        .padding(.horizontal, Theme.Spacing.medium.rawValue)
    }

    private var sectionList: some View {
        List {
            ForEach(daySections, id: \.id) { section in
                Section {
                    ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, item in
                        TodoRow(item: item, showsDivider: index < section.rows.count - 1)
                    }
                } header: {
                    Text(section.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                        .textCase(nil)
                }
            }
        }
        .todoCardStyle()
        .padding(.bottom, 16)
    }

    /// Launch-time screenshot fixture: SKELETON_TODO_STATE=calendar/search/quickentry.
    private func applyDebugFixture() {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment["SKELETON_TODO_STATE"] ?? ""
        let defaults = UserDefaults.standard.string(forKey: "SKELETON_TODO_STATE") ?? ""
        let state = env.isEmpty ? defaults : env
        print("[fixture] env=\(env) defaults=\(defaults) resolved=\(state)")
        switch state {
        case "calendar": calendarExpanded = true
        case "search": showingSearch = true
        case "quickentry":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showingQuickEntry = true }
        default: break
        }
        #endif
    }
}

/// Flat card of matching rows shown in search mode; empty query lists all todos.
private struct SearchResultList: View {
    let results: [TodoItem]

    var body: some View {
        if results.isEmpty {
            VStack(spacing: Theme.Spacing.small.rawValue) {
                Text("没有匹配的待办")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.Palette.secondaryLabel)
                Text("换个关键词试试")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.secondaryLabel.opacity(0.7))
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(Theme.Spacing.large.rawValue)
            .background(
                Theme.Palette.surface,
                in: RoundedRectangle(cornerRadius: Theme.Radius.sheet.rawValue, style: .continuous)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sheet.rawValue, style: .continuous))
            .padding(.horizontal, Theme.Spacing.medium.rawValue)
        } else {
            List {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                    TodoRow(item: item, showsDivider: index < results.count - 1)
                }
            }
            .todoCardStyle()
        }
    }
}

private extension View {
    func todoCardStyle() -> some View {
        self
            .listStyle(.plain)
            .listRowSeparator(.hidden)
            .scrollContentBackground(.hidden)
            .background(
                Theme.Palette.surface,
                in: RoundedRectangle(cornerRadius: Theme.Radius.sheet.rawValue, style: .continuous)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sheet.rawValue, style: .continuous))
            .padding(.horizontal, Theme.Spacing.medium.rawValue)
    }
}

private struct TodoRow: View {
    let item: TodoItem
    let showsDivider: Bool

    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: Theme.Spacing.large.rawValue) {
                toggleButton
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .foregroundStyle(item.isDone ? Theme.Palette.secondaryLabel : Theme.Palette.label)
                        .accessibilityIdentifier("todo.row.\(item.title)")
                        .accessibilityValue(item.isDone ? "已完成" : "进行中")
                    metadata
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, Theme.Spacing.medium.rawValue)
            .contentShape(Rectangle())
            .onTapGesture { router.present(.todoEditor(item.id)) }
            if showsDivider {
                DashedSeparator()
            }
        }
        .listRowInsets(EdgeInsets(top: 0, leading: Theme.Spacing.large.rawValue, bottom: 0, trailing: Theme.Spacing.large.rawValue))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .leading) {
            Button {
                item.isFlagged.toggle()
            } label: {
                Label(item.isFlagged ? "取消标旗" : "标旗", systemImage: item.isFlagged ? "flag.slash" : "flag.fill")
            }
            .tint(Theme.Palette.flag)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                ReminderScheduler.cancel(for: item)
                context.delete(item)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var toggleButton: some View {
        Button {
            withAnimation(.snappy) { item.setDone(!item.isDone) }
            ReminderScheduler.sync(item)
        } label: {
            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(item.isDone ? Theme.Palette.primary : Theme.Palette.secondaryLabel)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.isDone ? "标记为未完成" : "标记为已完成")
        .accessibilityIdentifier("todo.toggle.\(item.title)")
    }

    @ViewBuilder
    private var metadata: some View {
        let muted = item.isDone
        HStack(spacing: Theme.Spacing.small.rawValue) {
            if item.isFlagged {
                Image(systemName: "flag.fill")
                    .font(.footnote)
                    .foregroundStyle(muted ? Theme.Palette.secondaryLabel : Theme.Palette.flag)
            }
            if let remindAt = item.remindAt {
                Label(
                    remindAt.formatted(.dateTime.month().day().hour().minute().locale(Locale(identifier: "zh_CN"))),
                    systemImage: "bell.fill"
                )
                .font(.footnote)
                .foregroundStyle(muted ? Theme.Palette.secondaryLabel : Theme.Palette.primary)
            } else if item.dueDate != nil {
                Label(
                    (item.dueDate ?? .now).formatted(.dateTime.month().day().locale(Locale(identifier: "zh_CN"))),
                    systemImage: "bell.slash.fill"
                )
                .font(.footnote)
                .foregroundStyle(Theme.Palette.secondaryLabel)
            }
        }
    }
}
