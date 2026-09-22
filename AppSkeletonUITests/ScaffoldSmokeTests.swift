import XCTest

/// Drives the real app on the simulator, so the four modules and the self-check screen
/// are verified the way a user hits them.
@MainActor
final class ScaffoldSmokeTests: XCTestCase {
    // setUp runs on the test runner thread, which is not the main actor.
    nonisolated(unsafe) private var app: XCUIApplication!

    private let checkNames = [
        "Configuration", "Request building", "Decoding", "Persistence", "Routing", "Logging",
    ]

    nonisolated override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        resetData()
    }

    func testAllScaffoldChecksPass() throws {
        let selfCheck = app.buttons["架构自检"]
        XCTAssertTrue(selfCheck.waitForExistence(timeout: 10), "Mine tab did not render")
        selfCheck.tap()

        XCTAssertTrue(app.navigationBars["Scaffold"].waitForExistence(timeout: 5), "Push navigation failed")

        for name in checkNames {
            let row = app.staticTexts["scaffold.check.\(name)"]
            XCTAssertTrue(row.waitForExistence(timeout: 5), "Missing check row: \(name)")
            XCTAssertEqual(row.value as? String, "passed", "Check failed: \(name)")
        }
    }

    func testTodoCreateToggleAndDelete() throws {
        app.tabBars.buttons["待办"].waitAndTap()
        app.buttons["新建待办"].waitAndTap()

        let titleField = app.textFields["标题"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Editor sheet did not present")
        titleField.tap()
        titleField.typeText("买牛奶")
        app.buttons["保存"].tap()

        let row = app.staticTexts["todo.row.买牛奶"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Todo row did not appear")
        XCTAssertEqual(row.value as? String, "进行中")

        app.buttons["todo.toggle.买牛奶"].firstMatch.tap()
        let done = expectation(for: NSPredicate(format: "value == '已完成'"), evaluatedWith: row)
        wait(for: [done], timeout: 5)

        let cell = app.cells.containing(.staticText, identifier: "todo.row.买牛奶").firstMatch
        cell.swipeLeft()
        app.buttons["删除"].firstMatch.tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: row)
        wait(for: [gone], timeout: 5)
    }

    func testLedgerEntryCreateUpdatesSummary() throws {
        app.tabBars.buttons["记账"].waitAndTap()
        app.buttons["新建记账"].waitAndTap()

        let amountField = app.textFields["金额"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5), "Editor sheet did not present")
        amountField.tap()
        amountField.typeText("12.5")
        app.buttons["保存"].tap()

        XCTAssertTrue(app.staticTexts["-¥12.50"].waitForExistence(timeout: 5), "Ledger row did not appear")
        let expense = app.staticTexts["ledger.summary.expense"]
        XCTAssertTrue(expense.waitForExistence(timeout: 5), "Summary card did not render")
        XCTAssertEqual(expense.label, "¥12.50")
    }

    func testNoteCreateAndSearch() throws {
        app.tabBars.buttons["记录"].waitAndTap()
        app.buttons["新建记录"].waitAndTap()

        let titleField = app.textFields["标题"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Editor sheet did not present")
        titleField.tap()
        titleField.typeText("会议记录")

        let bodyEditor = app.textViews["正文"]
        XCTAssertTrue(bodyEditor.waitForExistence(timeout: 5), "Body editor missing")
        bodyEditor.tap()
        bodyEditor.typeText("下发布任务")
        app.buttons["保存"].tap()

        let row = app.staticTexts["会议记录"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Note row did not appear")

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search field missing")
        searchField.tap()
        searchField.typeText("会议")
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Search lost the matching note")
    }

    func testSheetPresentsAndDismisses() throws {
        app.tabBars.buttons["待办"].waitAndTap()
        app.buttons["新建待办"].waitAndTap()

        let titleField = app.textFields["标题"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Quick entry sheet did not present")

        // Empty title + send cancels: with the keyboard up the sheet sits
        // above it, so a downward swipe just re-docks instead of dismissing.
        app.buttons["保存"].tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["保存"])
        wait(for: [gone], timeout: 5)
    }

    /// Wipes SwiftData through the app's own 设置 → 清空全部数据 flow so tests stay repeatable.
    nonisolated private func resetData() {
        app.tabBars.buttons["设置"].waitAndTap(timeout: 15)
        let row = app.buttons["清空全部数据"].firstMatch
        guard row.waitForExistence(timeout: 5) else { return }
        row.tap()
        let confirm = app.buttons["确认清空"]
        if confirm.waitForExistence(timeout: 3) {
            confirm.tap()
        }
    }
}

private extension XCUIElement {
    func waitAndTap(timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(waitForExistence(timeout: timeout), "Element never appeared: \(self)", file: file, line: line)
        tap()
    }
}
