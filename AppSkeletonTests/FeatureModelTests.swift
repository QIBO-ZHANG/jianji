import XCTest
import SwiftData
@testable import AppSkeleton

final class FeatureModelTests: XCTestCase {
    func testTodoSetDoneTracksCompletedAt() {
        let item = TodoItem(title: "买牛奶")
        XCTAssertNil(item.completedAt)

        item.setDone(true)
        XCTAssertTrue(item.isDone)
        XCTAssertNotNil(item.completedAt)

        item.setDone(false)
        XCTAssertFalse(item.isDone)
        XCTAssertNil(item.completedAt)
    }

    func testTodoFlagReminderAndDueDay() {
        let calendar = Calendar.current
        let due = Date.now

        let flagged = TodoItem(title: "交房租", dueDate: due, remindAt: due, isFlagged: true)
        XCTAssertTrue(flagged.isFlagged)
        XCTAssertNotNil(flagged.remindAt)
        XCTAssertEqual(flagged.dueDay, calendar.startOfDay(for: due))

        let plain = TodoItem(title: "无日期")
        XCTAssertFalse(plain.isFlagged)
        XCTAssertNil(plain.remindAt)
        XCTAssertNil(plain.dueDay)
    }

    func testLedgerCategoriesSplitByKind() {
        XCTAssertEqual(LedgerCategory.cases(for: .income).map(\.rawValue), ["salary", "bonus", "investment"])
        XCTAssertTrue(LedgerCategory.cases(for: .expense).contains(.dining))
        XCTAssertEqual(LedgerCategory.dining.kind, .expense)
        XCTAssertEqual(LedgerCategory.salary.kind, .income)
    }

    func testLedgerSummaryAggregatesCurrentMonthOnly() {
        let calendar = Calendar.current
        let thisMonth = Date.now
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: thisMonth)!

        let entries = [
            LedgerEntry(amount: Decimal(string: "12.50")!, kind: .expense, category: .dining, date: thisMonth),
            LedgerEntry(amount: Decimal(string: "30")!, kind: .expense, category: .transport, date: thisMonth),
            LedgerEntry(amount: Decimal(string: "12.50")!, kind: .expense, category: .dining, date: thisMonth),
            LedgerEntry(amount: Decimal(string: "100")!, kind: .income, category: .salary, date: thisMonth),
            LedgerEntry(amount: Decimal(string: "999")!, kind: .expense, category: .shopping, date: lastMonth),
        ]

        let summary = LedgerSummary.of(entries, in: thisMonth, calendar: calendar)
        XCTAssertEqual(summary.expense, Decimal(string: "55")!)
        XCTAssertEqual(summary.income, Decimal(string: "100")!)
        XCTAssertEqual(summary.byCategory, [.dining: Decimal(string: "25")!, .transport: Decimal(string: "30")!])
    }

    func testSignedAmountAndText() {
        let expense = LedgerEntry(amount: Decimal(string: "12.5")!, kind: .expense, category: .dining)
        let income = LedgerEntry(amount: Decimal(string: "100")!, kind: .income, category: .salary)
        XCTAssertEqual(expense.signedAmount, Decimal(string: "-12.5")!)
        XCTAssertTrue(expense.amountText.hasPrefix("-"))
        XCTAssertTrue(income.amountText.hasPrefix("+"))
    }

    @MainActor
    func testRouterKeepsOneStackPerTab() {
        let router = AppRouter()
        router.push(.scaffoldCheck)
        XCTAssertEqual(router.selectedTab, .todo)

        router.selectedTab = .note
        XCTAssertTrue(router.path.isEmpty)
        router.push(.scaffoldCheck)

        router.selectedTab = .todo
        XCTAssertEqual(router.path, [.scaffoldCheck])
    }

    @MainActor
    func testDeepLinkSelectsTabAndRoute() {
        let router = AppRouter()

        XCTAssertTrue(router.open(URL(string: "appskeleton://scaffold")!))
        XCTAssertEqual(router.selectedTab, .mine)
        XCTAssertEqual(router.path, [.scaffoldCheck])

        XCTAssertTrue(router.open(URL(string: "appskeleton://ledger")!))
        XCTAssertEqual(router.selectedTab, .ledger)
        XCTAssertTrue(router.path.isEmpty)

        XCTAssertFalse(router.open(URL(string: "appskeleton://nope")!))
    }

    @MainActor
    func testInMemoryContainerRoundTripsTodo() throws {
        let container = ModelStore.makeInMemory()
        let context = ModelContext(container)

        context.insert(TodoItem(title: "写周报"))
        try context.save()

        var descriptor = FetchDescriptor<TodoItem>()
        XCTAssertEqual(try context.fetchCount(descriptor), 1)

        let fetched = try context.fetch(descriptor).first
        XCTAssertNotNil(fetched)

        if let fetched { context.delete(fetched) }
        try context.save()
        descriptor = FetchDescriptor<TodoItem>()
        XCTAssertEqual(try context.fetchCount(descriptor), 0)
    }
}
