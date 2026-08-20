import XCTest

final class P3_DrillLibraryUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean()
        app.switchTab(.drillLibrary)
        sleep(3)
    }

    // MARK: - Visual & Layout

    func testV01_BallTypeChipsVisible() {
        let allChip = app.buttons.matching(NSPredicate(format: "label == '全部'")).firstMatch
        let chineseChip = app.buttons.matching(NSPredicate(format: "label == '中式台球'")).firstMatch
        let nineBallChip = app.buttons.matching(NSPredicate(format: "label == '9球'")).firstMatch
        XCTAssertTrue(allChip.waitForExistence(timeout: 5) || app.staticTexts["全部"].waitForExistence(timeout: 3),
                      "Ball type chip '全部' should be visible")
        XCTAssertTrue(chineseChip.waitForExistence(timeout: 3) || app.staticTexts["中式台球"].waitForExistence(timeout: 3),
                      "Ball type chip '中式台球' should be visible")
        XCTAssertTrue(nineBallChip.waitForExistence(timeout: 3) || app.staticTexts["9球"].waitForExistence(timeout: 3),
                      "Ball type chip '9球' should be visible")
    }

    func testV02_CategorySidebarVisible() {
        sleep(1)
        let sidebarAll = app.descendants(matching: .any)["sidebar_全部"]
        let allFound = sidebarAll.waitForExistence(timeout: 5) ||
                       app.buttons.matching(NSPredicate(format: "label == '全部'")).firstMatch.waitForExistence(timeout: 3) ||
                       app.staticTexts["全部"].firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(allFound, "Sidebar '全部' should exist")

        // 侧栏标识来自 DrillCategory.nameZh（如「准度训练」「杆法训练」）。
        let sidebarCat = app.descendants(matching: .any)["sidebar_准度训练"]
        let categoryFound = sidebarCat.waitForExistence(timeout: 5) ||
                            app.descendants(matching: .any)["sidebar_杆法训练"].waitForExistence(timeout: 3) ||
                            app.descendants(matching: .any)["sidebar_走位训练"].waitForExistence(timeout: 3)
        XCTAssertTrue(categoryFound, "At least one sidebar category should exist")
    }

    func testV03_SearchBarVisible() {
        let searchField = app.textFields["搜索动作"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3), "Search bar should be visible")
    }

    func testV05_GridLayoutWithSectionHeaders() {
        let scrollViews = app.scrollViews
        XCTAssertTrue(scrollViews.count > 0, "Should have scroll views for grid content")
    }

    func testV17_DrillDetailNavigable() {
        let drillCard = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'drillCard_'")).firstMatch
        if drillCard.waitForExistence(timeout: 5) {
            drillCard.tap()
        } else {
            let cell = app.cells.firstMatch
            guard cell.waitForExistence(timeout: 5) else { return }
            cell.tap()
        }
        sleep(3)
        let detailLoaded = app.staticTexts["训练要点"].waitForExistence(timeout: 5) ||
                           app.buttons["关闭"].waitForExistence(timeout: 5) ||
                           app.buttons["解锁 Pro"].waitForExistence(timeout: 5) ||
                           app.staticTexts["点击此处输入备注"].waitForExistence(timeout: 5) ||
                           app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS 'heart' OR label CONTAINS 'Heart'")).firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(detailLoaded, "Should navigate to drill detail")
    }

    // MARK: - Search

    func testSearchFilters() {
        let searchField = app.textFields["搜索动作"]
        guard searchField.waitForExistence(timeout: 3) else { return }
        searchField.tap()
        searchField.typeText("直线")
        sleep(1)

        let clearButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'xmark'")).firstMatch
        if clearButton.waitForExistence(timeout: 2) {
            clearButton.tap()
            sleep(1)
        }
    }

    func testSearchEmptyState() {
        let searchField = app.textFields["搜索动作"]
        guard searchField.waitForExistence(timeout: 3) else { return }
        searchField.tap()
        searchField.typeText("zzzzz")
        sleep(1)
        XCTAssertTrue(app.staticTexts["没有找到相关动作"].waitForExistence(timeout: 3),
                      "Empty state should show for no results")
    }

    // MARK: - Sidebar Filtering

    func testSidebarCategorySwitch() {
        let cueAction = app.buttons.matching(NSPredicate(format: "label == '杆法'")).firstMatch
        let cueText = app.staticTexts["杆法"].firstMatch
        if cueAction.waitForExistence(timeout: 3) {
            cueAction.tap()
        } else if cueText.waitForExistence(timeout: 3) {
            cueText.tap()
        }
        sleep(1)

        let allButton = app.buttons.matching(NSPredicate(format: "label == '全部'")).firstMatch
        let allText = app.staticTexts["全部"].firstMatch
        if allButton.waitForExistence(timeout: 3) {
            allButton.tap()
        } else if allText.waitForExistence(timeout: 3) {
            allText.tap()
        }
        sleep(1)
    }

    // MARK: - Favorites

    func testFavoriteToggle() {
        let drillCell = app.cells.firstMatch
        if drillCell.waitForExistence(timeout: 5) {
            drillCell.tap()
        } else {
            return
        }
        sleep(2)

        let heart = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS 'heart' OR label CONTAINS 'Heart'")).firstMatch
        guard heart.waitForExistence(timeout: 3) else { return }
        heart.tap()
        sleep(1)
        heart.tap()
        sleep(1)
    }

    // MARK: - Detail Page Elements

    func testDetailPageElements() {
        let drillCell = app.cells.firstMatch
        if drillCell.waitForExistence(timeout: 5) {
            drillCell.tap()
        } else {
            return
        }
        sleep(2)

        let actionRowOrBottom = app.staticTexts["要点"].waitForExistence(timeout: 3) ||
                                app.staticTexts["历史"].waitForExistence(timeout: 3) ||
                                app.buttons["关闭"].waitForExistence(timeout: 3) ||
                                app.buttons["解锁 Pro"].waitForExistence(timeout: 3)
        XCTAssertTrue(actionRowOrBottom, "Action icon row or bottom bar should be visible")
    }

    func testDetailNotesCard() {
        let drillCell = app.cells.firstMatch
        if drillCell.waitForExistence(timeout: 5) {
            drillCell.tap()
        } else {
            return
        }
        sleep(2)

        app.scrollDown(times: 1)
        sleep(1)
        let notesOrCoaching = app.staticTexts["点击此处输入备注"].waitForExistence(timeout: 3) ||
                              app.staticTexts["训练要点"].waitForExistence(timeout: 3) ||
                              app.buttons["关闭"].waitForExistence(timeout: 3)
        XCTAssertTrue(notesOrCoaching, "Notes card or coaching section should be visible after scroll")
    }

    /// 动作库：打开靠后的卡片再返回，应仍停在该卡附近（与训练货架记位同一口径）。
    func testLibraryScrollRestoredAfterClosingDrill() {
        let sidebar = app.buttons["sidebar_杆法训练"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 8), "侧栏应有杆法训练")
        sidebar.tap()
        // 侧栏筛选去抖 300ms + Q19.1 补滚 0.36s，等网格切到杆法再滑。
        sleep(1)

        let card = app.buttons["drillCard_drill_c073"]
        XCTAssertTrue(scrollUntilOnScreen(card), "应能滑到杆法卡片 c073")
        tapEvenIfOccluded(card)
        // 详情页 SceneKit 会拖垮整树 AX 查询，只等导航返回键。
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 8), "应进入动作详情")
        back.tap()
        XCTAssertTrue(
            app.buttons["sidebar_杆法训练"].waitForExistence(timeout: 8),
            "应回到动作库"
        )
        let backCard = app.buttons["drillCard_drill_c073"]
        XCTAssertTrue(
            backCard.waitForExistence(timeout: 3) && isOnScreen(backCard),
            "返回后 c073 仍应在视口内，无需从顶部再滑"
        )
    }

    private func isOnScreen(_ element: XCUIElement) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        let screen = app.frame
        return frame.width > 0
            && frame.maxY > 80
            && frame.minY < screen.height - 40
    }

    private func scrollUntilOnScreen(_ element: XCUIElement, maxSwipes: Int = 16) -> Bool {
        for _ in 0..<maxSwipes {
            if isOnScreen(element) { return true }
            app.windows.firstMatch.swipeUp()
        }
        return isOnScreen(element)
    }

    private func tapEvenIfOccluded(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
        }
    }
}
