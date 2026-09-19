import Foundation
import SwiftData
import SwiftUI

enum LedgerKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case expense
    case income

    var id: String { rawValue }

    var label: String {
        switch self {
        case .expense: "支出"
        case .income: "收入"
        }
    }
}

enum LedgerCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case dining, transport, shopping, housing, entertainment, health, education
    case salary, bonus, investment
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dining: "餐饮"
        case .transport: "交通"
        case .shopping: "购物"
        case .housing: "居住"
        case .entertainment: "娱乐"
        case .health: "医疗"
        case .education: "学习"
        case .salary: "工资"
        case .bonus: "奖金"
        case .investment: "理财"
        case .other: "其他"
        }
    }

    var systemImage: String {
        switch self {
        case .dining: "fork.knife"
        case .transport: "bus.fill"
        case .shopping: "bag.fill"
        case .housing: "house.fill"
        case .entertainment: "gamecontroller.fill"
        case .health: "cross.case.fill"
        case .education: "book.fill"
        case .salary: "banknote.fill"
        case .bonus: "gift.fill"
        case .investment: "chart.line.up.trend.xyaxis"
        case .other: "ellipsis.circle.fill"
        }
    }

    var kind: LedgerKind {
        switch self {
        case .salary, .bonus, .investment: .income
        default: .expense
        }
    }

    var tint: Color {
        switch self {
        case .dining: .orange
        case .transport: .blue
        case .shopping: .pink
        case .housing: .brown
        case .entertainment: .purple
        case .health: .red
        case .education: .indigo
        case .salary, .bonus, .investment: .green
        case .other: .gray
        }
    }

    static func cases(for kind: LedgerKind) -> [LedgerCategory] {
        allCases.filter { $0.kind == kind }
    }
}

@Model
final class LedgerEntry {
    @Attribute(.unique) var id: UUID
    var amount: Decimal
    var kind: LedgerKind
    var category: LedgerCategory
    var date: Date
    var note: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        amount: Decimal,
        kind: LedgerKind,
        category: LedgerCategory,
        date: Date = .now,
        note: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.amount = amount
        self.kind = kind
        self.category = category
        self.date = date
        self.note = note
        self.createdAt = createdAt
    }

    var signedAmount: Decimal {
        kind == .expense ? -amount : amount
    }

    var amountText: String {
        let text = amount.formatted(.currency(code: "CNY"))
        return kind == .expense ? "-\(text)" : "+\(text)"
    }
}

/// Pure month aggregation so the summary card and the tests share one implementation.
struct LedgerSummary: Equatable, Sendable {
    var expense: Decimal = 0
    var income: Decimal = 0
    var byCategory: [LedgerCategory: Decimal] = [:]

    static func of(_ entries: [LedgerEntry], in month: Date, calendar: Calendar = .current) -> LedgerSummary {
        var summary = LedgerSummary()
        for entry in entries where calendar.isDate(entry.date, equalTo: month, toGranularity: .month) {
            switch entry.kind {
            case .expense:
                summary.expense += entry.amount
                summary.byCategory[entry.category, default: 0] += entry.amount
            case .income:
                summary.income += entry.amount
            }
        }
        return summary
    }
}

extension Decimal {
    var currencyText: String {
        formatted(.currency(code: "CNY"))
    }
}
