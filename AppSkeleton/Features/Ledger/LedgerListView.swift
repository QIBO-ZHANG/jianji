import SwiftUI
import SwiftData
import Charts

struct LedgerListView: View {
    @Query(sort: \LedgerEntry.date, order: .reverse) private var entries: [LedgerEntry]
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context

    private var summary: LedgerSummary { LedgerSummary.of(entries, in: .now) }

    private var days: [(day: Date, entries: [LedgerEntry])] {
        Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.date) }
            .sorted { $0.key > $1.key }
            .map { (day: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
    }

    var body: some View {
        List {
            Section {
                LedgerSummaryCard(summary: summary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            if days.isEmpty {
                Section {
                    ContentUnavailableView(
                        "暂无账目",
                        systemImage: "yensign.circle",
                        description: Text("点右上角 + 记第一笔账")
                    )
                    .listRowBackground(Color.clear)
                }
            } else {
                ForEach(days, id: \.day) { group in
                    Section(group.day.formatted(.dateTime.month().day().weekday())) {
                        ForEach(group.entries) { entry in
                            LedgerRow(entry: entry)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        context.delete(entry)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle(AppTab.ledger.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.present(.ledgerEditor(nil))
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("新建记账")
            }
        }
    }
}

private struct LedgerSummaryCard: View {
    let summary: LedgerSummary

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium.rawValue) {
            Text(Date.now.formatted(.dateTime.year().month(.wide)))
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.secondaryLabel)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("支出").font(Theme.Typography.caption).foregroundStyle(Theme.Palette.secondaryLabel)
                    Text(summary.expense.currencyText)
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Palette.label)
                        .accessibilityIdentifier("ledger.summary.expense")
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("收入").font(Theme.Typography.caption).foregroundStyle(Theme.Palette.secondaryLabel)
                    Text(summary.income.currencyText)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Palette.positive)
                        .accessibilityIdentifier("ledger.summary.income")
                }
            }

            if summary.byCategory.isEmpty {
                Text("本月还没有支出记录")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
            } else {
                Chart(summary.byCategory.sorted { $0.value > $1.value }, id: \.key) { element in
                    SectorMark(
                        angle: .value("金额", element.value),
                        innerRadius: .ratio(0.62),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("分类", element.key.label))
                    .cornerRadius(3)
                }
                .chartForegroundStyleScale { (label: String) in
                    LedgerCategory.allCases.first { $0.label == label }?.tint ?? Color.gray
                }
                .chartLegend(position: .bottom, alignment: .center, spacing: 8)
                .frame(height: 170)
            }
        }
        .card()
    }
}

private struct LedgerRow: View {
    let entry: LedgerEntry
    @Environment(AppRouter.self) private var router

    var body: some View {
        HStack(spacing: Theme.Spacing.medium.rawValue) {
            Image(systemName: entry.category.systemImage)
                .font(.body)
                .foregroundStyle(entry.category.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.category.label)
                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                }
            }

            Spacer(minLength: 0)

            Text(entry.amountText)
                .font(.body.monospacedDigit())
                .foregroundStyle(entry.kind == .expense ? Theme.Palette.label : Theme.Palette.positive)
                .accessibilityIdentifier("ledger.row.\(entry.id.uuidString)")
        }
        .contentShape(Rectangle())
        .onTapGesture { router.present(.ledgerEditor(entry.id)) }
    }
}
