import XCTest

final class ControlLayoutPlacementUITests: XCTestCase {
    func testFormationRelocatedNudgeStillOperatesBall() throws {
        launchFormationLayout("formationPractice"); setCoreMode("2D")
        ready("freeplay.moreMenu").tap()
        let arrange = ready("formation.arrange")
        for _ in 0..<5 where !arrange.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
        arrange.tap()
        func balls() throws -> [[String: Any]] {
            let data = try XCTUnwrap((ready("table.scene").value as? String)?.data(using: .utf8))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            return try XCTUnwrap(json["balls"] as? [[String: Any]])
        }
        let target = try XCTUnwrap(try balls().first { $0["key"] as? String != "cueBall" })
        let key = try XCTUnwrap(target["key"] as? String), point = try XCTUnwrap(target["screen"] as? [Double])
        ready("table.scene").coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: point[0], dy: point[1])).tap()
        XCTAssertTrue(ready("formation.nudge.right").isEnabled)
        // TableBallPulse animates 0.18s up + 0.24s down on selection.
        // Compare the settled presentation against its actual pre-selection scale.
        let restingScale = try XCTUnwrap(target["scale"] as? [Double])
        for _ in 0..<30 {
            if try balls().first(where: { $0["key"] as? String == key })?["scale"] as? [Double] == restingScale { break }
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTAssertEqual(try balls().first(where: { $0["key"] as? String == key })?["scale"] as? [Double], restingScale)
        let state = try businessSnapshot(includeCamera: false)
        openFreeEditor(); ready("freeLayout.collapse").tap()
        let button = ready("freeLayout.select.formation.nudge.right"), original = button.frame
        let start = button.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(.init(dx: 150, dy: 0)))
        XCTAssertGreaterThan(button.frame.midX, original.midX + 130)
        ready("freeLayout.collapse").tap(); saveFreeLayout("移动微调键")
        XCTAssertEqual(try businessSnapshot(includeCamera: false), state)
        let moved = ready("formation.nudge.right")
        XCTAssertGreaterThan(moved.frame.midX, original.midX + 130)
        let before = try XCTUnwrap(try balls().first { $0["key"] as? String == key }?["world"] as? [Double])
        moved.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        let after = try XCTUnwrap(try balls().first { $0["key"] as? String == key }?["world"] as? [Double])
        XCTAssertGreaterThan(hypot(after[0] - before[0], after[2] - before[2]), 0.0001)
        try capture("formation-relocated-nudge")
    }

    func testRetiredGlobalEntryAndEmptyMode() throws {
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-hasCompletedOnboarding", "YES",
            "-forcePremium", "-v50.inMemoryStore", "-deeplink.settings"]
        app.launch()
        let grid = ready("settings.grid")
        for _ in 0..<5 where !grid.isHittable { app.swipeUp() }
        XCTAssertTrue(grid.isHittable)
        XCTAssertFalse(element("settings.controlLayout").exists)
        XCTAssertTrue(ready("settings.closeup").exists)
        try capture("general-settings-native-switches")
        launchTeaching("angleDynamic"); teachingMode("angleDynamic", "2D")
        ready("angleDynamic.more").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        XCTAssertFalse(element("controlLayout.open").exists)
        ready("angleDynamic.dismissMenu").coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.5)).tap()
        teachingMode("angleDynamic", "3D"); openFreeEditor()
        XCTAssertTrue(ready("freeLayout.floatingToolbar").exists)
        XCTAssertTrue(ready("freeLayout.select.camera.thirdPerson").exists)
        ready("freeLayout.cancel").tap()
    }

    /// Rollout contract: real page controls, local templates and unchanged business state.
    func testPageLocalFloatingLayout() throws {
        let env = ProcessInfo.processInfo.environment
        let pages = (env["LAYOUT_PAGES"] ?? "freePlay,silu").split(separator: ",").map(String.init)
        for page in pages {
            launchMatrixPage(page)
            let modes = (page.hasSuffix("2d") || page == "formationEditor") ? ["2D"] : (page.hasSuffix("3d") || page == "angleDynamic" ? ["3D"] : ["2D", "3D"])
            for mode in modes {
                if !page.hasSuffix("2d") && !page.hasSuffix("3d") && page != "formationEditor" { rolloutMode(page, mode) }
                if env["LAYOUT_PORTRAIT"] == "1" { XCUIDevice.shared.orientation = .portrait; Thread.sleep(forTimeInterval: 1) }
                let tag = page + "-" + mode
                try capture(tag + "-before")
                let state = try businessSnapshot(includeCamera: false)
                openFreeEditor()
                if env["LAYOUT_BEFORE_ONLY"] == "1" {
                    try capture(tag + "-old-editor")
                    ready("freeLayout.cancel").tap()
                    continue
                }
                XCTAssertTrue(ready("freeLayout.floatingToolbar").exists)
                XCTAssertFalse(element("freeLayout.customize").exists)
                try capture(tag + "-editor")
                let keys = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "freeLayout.select."))
                XCTAssertGreaterThanOrEqual(keys.count, 2)
                let preferred = ["shot.undo", "planning.constraintTool", "shot.aim", "aimPoint.hint", "angle.assist", "shot.power", "camera.thirdPerson", "formation.tool.line"]
                let id = try XCTUnwrap(preferred.map { "freeLayout.select." + $0 }.first { element($0).exists })
                let key = ready(id), original = key.frame
                let otherID = try XCTUnwrap(keys.allElementsBoundByIndex.map(\.identifier).first { $0 != id })
                let other = ready(otherID).frame
                key.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
                ready("freeLayout.larger").tap()
                XCTAssertGreaterThan(key.frame.width, original.width)
                XCTAssertEqual(ready(otherID).frame, other)
                ready("freeLayout.collapse").tap()
                let origin = key.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
                origin.press(forDuration: 0.1, thenDragTo: origin.withOffset(.init(dx: 28, dy: -18)))
                XCTAssertGreaterThan(key.frame.midX, original.midX + 15)
                try capture(tag + "-moved")
                ready("freeLayout.collapse").tap()
                ready("freeLayout.cancel").tap()
                XCTAssertEqual(try businessSnapshot(includeCamera: false), state)
                openFreeEditor()
                XCTAssertEqual(ready(id).frame.width, original.width, accuracy: 1)
                XCTAssertEqual(ready(id).frame.midX, original.midX, accuracy: 1)
                ready(id).coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
                ready("freeLayout.larger").tap()
                let saved = ready(id).frame
                let name = "本页验证 " + page + " " + mode
                saveFreeLayout(name)
                XCTAssertEqual(try businessSnapshot(includeCamera: false), state)
                openFreeEditor()
                XCTAssertEqual(ready(id).frame.width, saved.width, accuracy: 1)
                ready("freeLayout.templates").tap()
                let dots = ready("freeLayout.defaultActions")
                XCTAssertFalse(dots.isEnabled)
                dots.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
                XCTAssertTrue(element("freeLayout.dropdown").exists)
                XCTAssertEqual(ready(id).frame, saved)
                let actions = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "freeLayout.templateActions.", name)).firstMatch
                XCTAssertTrue(actions.waitForExistence(timeout: 5))
                let count = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "freeLayout.templateActions.")).count
                try capture(tag + "-templates")
                actions.tap(); ready("freeLayout.pinTemplate").tap()
                actions.tap(); try capture(tag + "-actions")
                ready("freeLayout.editTemplate").tap()
                ready(id).coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
                ready("freeLayout.larger").tap()
                saveFreeLayout(name)
                openFreeEditor(); ready("freeLayout.templates").tap()
                XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "freeLayout.templateActions.")).count, count)
                actions.tap(); ready("freeLayout.useTemplate").tap()
                XCTAssertFalse(element("freeLayout.editor").exists)
                openFreeEditor(); let applied = ready(id).frame
                ready("freeLayout.templates").tap(); actions.tap()
                ready("freeLayout.deleteTemplate").tap(); ready("freeLayout.confirmDelete").tap()
                XCTAssertFalse(actions.exists)
                ready("freeLayout.closeTemplates").tap(); ready("freeLayout.cancel").tap()
                openFreeEditor(); XCTAssertEqual(ready(id).frame, applied)
                ready("freeLayout.cancel").tap()
                XCTAssertEqual(try businessSnapshot(includeCamera: false), state)
                try capture(tag + "-applied")
            }
        }
    }

    private func rolloutMode(_ page: String, _ mode: String) {
        if ["angleDynamic", "separation", "cushion"].contains(page) { teachingMode(page, mode); return }
        if ["dailyClearance", "freePlay", "shotSimulation", "snakePractice", "composer", "drillTryout", "formationPractice"].contains(page) { setCoreMode(mode); return }
        let prefix = ["silu": "silu", "planThree": "planthree", "snooker": "snooker", "bank": "bankshot", "diamond": "reflection"][page]!
        ready(prefix + ".more").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        if ready(prefix + ".cameraMode").value as? String != mode { ready(prefix + ".cameraMode").tap() }
        ready(prefix + ".dismissMenu").coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.5)).tap()
    }

    func testSettingsAffordanceAndDisabledDefaultActions() throws {
        launchMatrixPage("dailyClearance")
        for mode in ["2D", "3D"] {
            setCoreMode(mode)
            func menu() { ready("freeplay.moreMenu").tap() }
            menu()
            if ready("menu.tableGrid").value as? String == "已选" { ready("menu.tableGrid").tap(); menu() }
            XCTAssertEqual(ready("menu.tableGrid").value as? String, "未选")
            try capture(mode + "-menu-off")
            ready("menu.tableGrid").tap(); menu()
            XCTAssertEqual(ready("menu.tableGrid").value as? String, "已选")
            try capture(mode + "-menu-on")
            ready("dailyClearance.aimModeMenu").tap()
            XCTAssertTrue(ready("dailyClearance.aim.free").isEnabled)
            try capture(mode + "-aim-options")
            ready("dailyClearance.aim.free").tap(); menu()
            XCTAssertTrue(ready("dailyClearance.aimModeMenu").label.contains("自由"))
            ready("dailyClearance.aimModeMenu").tap(); ready("dailyClearance.aim.pocket").tap()
            openFreeEditor()
            let key = ready("freeLayout.select.shot.undo")
            key.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            ready("freeLayout.larger").tap()
            let editedFrame = key.frame
            ready("freeLayout.templates").tap()
            let dots = ready("freeLayout.defaultActions")
            XCTAssertFalse(dots.isEnabled)
            XCTAssertTrue(ready("freeLayout.default").isEnabled)
            try capture(mode + "-default-template")
            dots.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(element("freeLayout.dropdown").exists)
            XCTAssertFalse(element("freeLayout.templateSubmenu").exists)
            XCTAssertEqual(key.frame, editedFrame, "Disabled dots must not trigger the default row")
            ready("freeLayout.closeTemplates").tap(); ready("freeLayout.cancel").tap()
        }
    }

    func testSettingsAffordanceAcrossTableFamilies() throws {
        let pages = (ProcessInfo.processInfo.environment["AFFORDANCE_PAGES"] ?? "freePlay,bank,separation,aimpoint3d")
            .split(separator: ",").map(String.init)
        for page in pages {
            if page.hasPrefix("aimpoint") || page.hasPrefix("anglequiz") {
                app?.terminate()
                XCUIDevice.shared.orientation = .landscapeLeft
                app = XCUIApplication()
                app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-hasCompletedOnboarding", "YES",
                    "-forcePremium", "-v50.inMemoryStore", "-v51.followSystemAppearance", "-appearanceMode", "system",
                    "-dailyInteraction.sharedPage=" + page]
                app.launch()
                let start = ready(page.hasPrefix("aimpoint") ? "aimPointTraining.start" : "angleTraining.start")
                try capture(page + "-training-options")
                start.tap()
                _ = ready(page.hasPrefix("aimpoint") ? "aimPointTraining.settings" : "angleTraining.settings")
            } else { launchMatrixPage(page) }
            let more = ["freeplay.moreMenu", "bankshot.more", "reflection.more", "silu.more", "planthree.more", "snooker.more",
                        "separationAngleAtlas.more", "cushionEnglishAtlas.more", "angleDynamic.more", "aimPointTraining.settings", "angleTraining.settings"]
                .first { element($0).exists }!
            ready(more).coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(["已选", "未选"].contains(ready("menu.tableGrid").value as? String ?? ""))
            try capture(page + "-settings")
        }
    }

    func testDailyToolbarInitialPlacement() throws {
        launchMatrixPage("dailyClearance")
        for mode in ["2D", "3D"] {
            setCoreMode(mode); openFreeEditor()
            let toolbar = ready("freeLayout.floatingToolbar")
            XCTAssertEqual(toolbar.frame.minY, ready("dailyClearance.singleRowPalette").frame.maxY, accuracy: 1)
            XCTAssertLessThanOrEqual(toolbar.frame.width, 481)
            XCTAssertTrue(ready("freeLayout.save").isHittable)
            try capture(mode + "-01-open")
            ready("freeLayout.cancel").tap()
        }
    }

    /// Daily-only Figma pilot: exercise real gestures, cancel isolation, save and mode separation.
    func testDailyCompactLayoutToolbar() throws {
        launchMatrixPage("dailyClearance")
        for mode in ["2D", "3D"] {
            setCoreMode(mode)
            let original = ready("dailyClearance.undo").frame
            let state = try businessSnapshot()
            openFreeEditor()
            XCTAssertFalse(element("freeLayout.customize").exists)
            let toolbar = ready("freeLayout.floatingToolbar")
            XCTAssertLessThanOrEqual(toolbar.frame.width, 481)
            XCTAssertLessThanOrEqual(toolbar.frame.height, 105)
            XCTAssertEqual(toolbar.frame.minY, ready("dailyClearance.singleRowPalette").frame.maxY, accuracy: 1,
                           "Toolbar touches the visible palette edge, not its larger hit target")
            try capture(mode + "-01-open")
            XCTAssertFalse(element("freeLayout.controls").exists)
            let key = ready("freeLayout.select.shot.undo")
            key.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            let before = key.frame
            ready("freeLayout.larger").tap()
            XCTAssertGreaterThan(key.frame.width, before.width)
            let slider = app.sliders["freeLayout.scale"]
            slider.adjust(toNormalizedSliderPosition: 0.7)
            XCTAssertGreaterThan(key.frame.width, before.width * 1.15)
            let actualScale = try XCTUnwrap(Double(slider.value as? String ?? ""))
            XCTAssertEqual(key.frame.width, before.width * actualScale, accuracy: 2,
                           "Rendered control size follows the native slider value")
            let editedScale = actualScale
            let replay = ready("freeLayout.select.shot.replay")
            let replayBefore = replay.frame
            replay.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            XCTAssertEqual(try XCTUnwrap(Double(app.sliders["freeLayout.scale"].value as? String ?? "")), 1, accuracy: 0.01)
            ready("freeLayout.larger").tap()
            XCTAssertGreaterThan(replay.frame.width, replayBefore.width)
            XCTAssertEqual(key.frame.width, before.width * editedScale, accuracy: 2)
            key.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            XCTAssertEqual(try XCTUnwrap(Double(app.sliders["freeLayout.scale"].value as? String ?? "")), editedScale, accuracy: 0.01)
            let start = key.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(.init(dx: 55, dy: -25)))
            XCTAssertGreaterThan(key.frame.midX, before.midX + 35)
            let edited = key.frame
            let handle = ready("freeLayout.toolbarHandle")
            let oldHandle = handle.frame
            let grip = handle.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
            grip.press(forDuration: 0.1, thenDragTo: grip.withOffset(.init(dx: -100, dy: 65)))
            XCTAssertGreaterThan(handle.frame.midY, oldHandle.midY + 40)
            XCTAssertEqual(key.frame.midX, edited.midX, accuracy: 1)
            XCTAssertEqual(key.frame.width, edited.width, accuracy: 1)
            try capture(mode + "-02-selected-moved")
            ready("freeLayout.collapse").tap()
            XCTAssertLessThan(ready("freeLayout.floatingToolbar").frame.width, 210)
            try capture(mode + "-03-collapsed")
            let collapsedGrip = ready("freeLayout.toolbarHandle").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
            collapsedGrip.press(forDuration: 0.1, thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: .init(dx: 0.96, dy: 0.85)))
            ready("freeLayout.collapse").tap()
            XCTAssertTrue(ready("freeLayout.save").isHittable)
            let resetAnchor = ready("freeLayout.resetMenu").frame
            ready("freeLayout.resetMenu").tap()
            let resetMenu = ready("freeLayout.dropdown").frame
            XCTAssertEqual(resetMenu.maxY, resetAnchor.minY - 6, accuracy: 1,
                           "At the bottom edge the menu attaches above its own reset button")
            XCTAssertTrue(resetMenu.minX <= resetAnchor.midX && resetMenu.maxX >= resetAnchor.midX)
            try capture(mode + "-03b-reset-anchor")
            ready("freeLayout.closeTemplates").tap()
            ready("freeLayout.cancel").tap()
            XCTAssertEqual(ready("dailyClearance.undo").frame.midX, original.midX, accuracy: 1)
            XCTAssertEqual(ready("dailyClearance.undo").frame.width, original.width, accuracy: 1)
            XCTAssertEqual(try businessSnapshot(), state)
            openFreeEditor()
            ready("freeLayout.select.shot.undo").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            ready("freeLayout.larger").tap()
            saveFreeLayout("每日浮动工具条 " + mode)
            XCTAssertGreaterThan(ready("dailyClearance.undo").frame.width, original.width)
            openFreeEditor(); ready("freeLayout.templates").tap()
            let templateAnchor = ready("freeLayout.templates").frame
            let libraryFrame = ready("freeLayout.dropdown").frame
            XCTAssertEqual(libraryFrame.minY, templateAnchor.maxY + 6, accuracy: 1)
            XCTAssertEqual(libraryFrame.minX, templateAnchor.minX, accuracy: 1,
                           "Library attaches to the template trigger, not the toolbar's outer edge")
            try capture(mode + "-04-template-library")
            let actions = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "freeLayout.templateActions.", "每日浮动工具条 " + mode)).firstMatch
            XCTAssertTrue(actions.waitForExistence(timeout: 5))
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "freeLayout.templateActions.")).count, 1,
                           "The other mode's templates stay out of this list")
            actions.tap()
            XCTAssertTrue(ready("freeLayout.useTemplate").isHittable)
            XCTAssertTrue(ready("freeLayout.editTemplate").isHittable)
            XCTAssertTrue(ready("freeLayout.deleteTemplate").isHittable)
            ready("freeLayout.pinTemplate").tap()
            actions.tap()
            XCTAssertTrue(app.buttons["取消置顶"].exists)
            let submenu = ready("freeLayout.templateSubmenu").frame
            XCTAssertEqual(min(abs(submenu.minX - libraryFrame.maxX), abs(libraryFrame.minX - submenu.maxX)), 6, accuracy: 1,
                           "Child menu stays beside the parent menu")
            XCTAssertTrue(submenu.minY <= actions.frame.midY && submenu.maxY >= actions.frame.midY,
                          "Child menu remains aligned with the originating template row")
            try capture(mode + "-05-template-actions")
            ready("freeLayout.editTemplate").tap()
            XCTAssertFalse(element("freeLayout.dropdown").exists)
            ready("freeLayout.select.shot.undo").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            ready("freeLayout.larger").tap()
            saveFreeLayout("每日浮动工具条 " + mode)
            openFreeEditor(); ready("freeLayout.templates").tap()
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "freeLayout.templateActions.")).count, 1,
                           "Modify updates the template without making a second copy")
            actions.tap(); ready("freeLayout.useTemplate").tap()
            XCTAssertFalse(element("freeLayout.editor").exists)
            let applied = ready("dailyClearance.undo").frame
            openFreeEditor(); ready("freeLayout.templates").tap()
            actions.tap(); ready("freeLayout.deleteTemplate").tap()
            ready("freeLayout.confirmDelete").tap()
            XCTAssertFalse(actions.exists)
            ready("freeLayout.closeTemplates").tap()
            ready("freeLayout.cancel").tap()
            XCTAssertEqual(ready("dailyClearance.undo").frame, applied,
                           "Deleting the template preserves the applied layout snapshot")
        }
        // Every page now uses the same editor, with a separate local template list.
        launchCore("freePlay"); openFreeEditor()
        XCTAssertFalse(element("freeLayout.customize").exists)
        XCTAssertTrue(ready("freeLayout.floatingToolbar").exists)
        ready("freeLayout.cancel").tap()
    }

    func testFreeLayoutDoesNotExposeLockedProDestination() {
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-hasCompletedOnboarding", "YES",
            "-forceNonPremium", "-v50.inMemoryStore", "-pro.route=snooker"]
        app.launch()
        XCTAssertTrue(element("pro.locked").waitForExistence(timeout: 15))
        XCTAssertFalse(element("pro.authorized").exists)
        XCTAssertFalse(element("controlLayout.open").exists)
        XCTAssertFalse(element("snooker.more").exists)
    }

    func testFreeAdditionalCorePages() throws {
        let pages = (ProcessInfo.processInfo.environment["LAYOUT_PAGES"] ?? "shotSimulation,snakePractice,composer,drillTryout")
            .split(separator: ",").map(String.init)
        for page in pages {
            launchCore(page)
            var savedTwoD: CGRect?
            for mode in ["2D", "3D"] {
                setCoreMode(mode); openFreeEditor(); ready("freeLayout.default").tap()
                let state = try businessSnapshot(), original = ready("dailyClearance.undo").frame
                let neighbor = ready("dailyClearance.playback").frame
                let semantic = page == "drillTryout" ? "tryout.previous" : "shot.undo"
                try capture(page + "-" + mode + "-default", probing: ["dailyClearance.undo", "dailyClearance.playback", "dailyLayout.controlsProbe"])
                openFreeEditor(); ready("freeLayout.customize").tap()
                for id in ["shot.aim", "shot.spin", "shot.power", semantic,
                           page == "drillTryout" ? "tryout.next" : "shot.replay",
                           page == "drillTryout" ? "sequence.play" : "shot.strike"] {
                    chooseFreeControl(id)
                }
                if page == "snakePractice" { chooseFreeControl("snake.restart") }
                if page == "composer" { chooseFreeControl("break.entry") }
                if page == "drillTryout" {
                    chooseFreeControl("tryout.rearrange")
                    XCTAssertFalse(element("freeLayout.select.shot.undo").exists)
                    XCTAssertFalse(element("freeLayout.select.shot.replay").exists)
                }
                chooseFreeControl(semantic); app.buttons["右移"].tap(); app.buttons["放大"].tap()
                let preview = ready("freeLayout.select." + semantic).frame
                XCTAssertEqual(preview.midX, original.midX + 5, accuracy: 2)
                XCTAssertEqual(preview.width, original.width * 1.05, accuracy: 2)
                ready("freeLayout.collapse").tap()
                try capture(page + "-" + mode + "-preview", probing: ["freeLayout.select." + semantic, "freeLayout.collapse"])
                ready("freeLayout.collapse").tap(); saveFreeLayout("R05 " + page)
                XCTAssertEqual(try businessSnapshot(), state)
                XCTAssertEqual(ready("dailyClearance.undo").frame.midX, preview.midX, accuracy: 2)
                XCTAssertEqual(ready("dailyClearance.undo").frame.width, preview.width, accuracy: 2)
                XCTAssertEqual(ready("dailyClearance.playback").frame, neighbor)
                if mode == "2D" { savedTwoD = ready("dailyClearance.undo").frame }
                openFreeEditor(); ready("freeLayout.current").tap(); chooseFreeControl(semantic)
                app.buttons["下移"].tap(); ready("freeLayout.cancel").tap()
                XCTAssertEqual(try businessSnapshot(), state)
                XCTAssertEqual(ready("dailyClearance.undo").frame.midY, preview.midY, accuracy: 2)
                try capture(page + "-" + mode + "-saved", probing: ["dailyClearance.undo", "dailyLayout.controlsProbe"])
            }
            setCoreMode("2D")
            XCTAssertEqual(ready("dailyClearance.undo").frame.width, try XCTUnwrap(savedTwoD).width, accuracy: 2)
            if page == "drillTryout" {
                ready("dailyClearance.playback").tap()
                waitUntil("next authored step", timeout: 60) {
                    (self.element("dailyLayout.controlsProbe").value as? String ?? "").contains("sequenceStep=1 ") && self.element("dailyClearance.undo").isEnabled
                }
                ready("dailyClearance.undo").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
                waitUntil("previous authored step", timeout: 60) {
                    (self.element("dailyLayout.controlsProbe").value as? String ?? "").contains("sequenceStep=0 ") && self.element("dailyClearance.playback").isEnabled
                }
                let paused = try businessSnapshot()
                openFreeEditor(); ready("freeLayout.current").tap(); ready("freeLayout.cancel").tap()
                XCTAssertEqual(try businessSnapshot(), paused)
            } else if page == "snakePractice" {
                ready("snake.restart").tap(); ready("snake.restart.cancel").tap()
                let power = ready("shotStage.powerBar")
                power.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.1)).press(forDuration: 0.05,
                    thenDragTo: power.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.95)), withVelocity: .fast, thenHoldForDuration: 0.05)
                waitUntil("low power ready", timeout: 45) { self.element("dailyClearance.strike").isEnabled }
                ready("dailyClearance.strike").tap()
                XCTAssertTrue(element("snake.failure.retry").waitForExistence(timeout: 60))
                ready("snake.failure.retry").tap()
                waitUntil("retry ready", timeout: 45) { self.element("dailyClearance.strike").isEnabled }
                let retried = try businessSnapshot()
                openFreeEditor(); ready("freeLayout.current").tap(); ready("freeLayout.cancel").tap()
                XCTAssertEqual(try businessSnapshot(), retried)
            } else {
                ready("dailyClearance.strike").tap()
                waitUntil("shot settled", timeout: 60) { self.element("dailyClearance.undo").isEnabled }
                ready("dailyClearance.undo").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            }
            try capture(page + "-real-actions", probing: ["dailyClearance.undo", "dailyClearance.playback", "dailyLayout.controlsProbe"])
        }
        XCTAssertEqual(rows.count, pages.count * 7)
    }

    private func saveFreeLayout(_ name: String) {
        ready("freeLayout.save").tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap()
        if let current = field.value as? String, !current.isEmpty, current != "模板名称" {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(name); app.alerts.buttons["保存"].tap()
        waitUntil("personal layout saved") { !self.element("freeLayout.editor").exists }
    }

    func testFreeTemplateCrossPageLibrary() throws {
        func templates() -> XCUIElementQuery {
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "freeLayout.template."))
        }
        func findTemplate(_ name: String) -> XCUIElement {
            let button = templates().matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            let list = app.scrollViews["freeLayout.templateList"]
            for _ in 0..<6 {
                if button.isHittable && list.frame.contains(CGPoint(x: button.frame.midX, y: button.frame.midY)) { break }
                list.swipeUp()
            }
            return button
        }
        func save(_ name: String) {
            ready("freeLayout.save").tap()
            let field = app.alerts.textFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap()
            if let current = field.value as? String, current != "模板名称", !current.isEmpty {
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
            }
            field.typeText(name); app.alerts.buttons["保存"].tap()
            waitUntil("template saved") { !self.element("freeLayout.editor").exists }
        }
        // Run in a newly isolated bundle: no fabricated personal templates at first entry.
        for page in ["dailyClearance", "freePlay", "silu"] {
            launchMatrixPage(page); openFreeEditor()
            XCTAssertEqual(templates().count, 0)
            XCTAssertEqual(app.buttons.matching(identifier: "freeLayout.default").count, 1)
            if page == "dailyClearance" { try capture("01-empty-library", probing: ["freeLayout.default"]) }
            ready("freeLayout.cancel").tap()
        }
        // Target-only tool has an existing personal value that applying A must preserve.
        openFreeEditor(); ready("freeLayout.customize").tap()
        chooseFreeControl("planning.constraintTool"); app.buttons["右移"].tap()
        save("R03目标")
        let targetTool = ready("silu.tool").frame

        launchMatrixPage("dailyClearance"); openFreeEditor(); ready("freeLayout.customize").tap()
        chooseFreeControl("shot.undo"); app.buttons["右移"].tap(); app.buttons["放大"].tap()
        chooseFreeControl("shot.power"); app.buttons["左移"].tap(); app.buttons["放大"].tap()
        save("R03共享 · 2D")
        let sourceUndo = ready("dailyClearance.undo").frame, sourcePower = ready("shotStage.powerBar").frame
        try capture("02-source-saved", probing: ["dailyClearance.undo", "shotStage.powerBar"])

        launchMatrixPage("freePlay"); setCoreMode("3D")
        openFreeEditor(); ready("freeLayout.customize").tap(); save("R03三维")
        setCoreMode("2D"); openFreeEditor()
        XCTAssertTrue(findTemplate("R03共享 · 2D").isEnabled)
        XCTAssertFalse(findTemplate("R03三维 · 3D").isEnabled)
        XCTAssertTrue(app.staticTexts["请在 3D 模式下使用"].exists)
        try capture("03-other-mode-visible", probing: ["freeLayout.templateList"])
        ready("freeLayout.cancel").tap()

        launchMatrixPage("silu"); openFreeEditor()
        let originalRow = findTemplate("R03共享 · 2D"), originalID = originalRow.identifier
        XCTAssertFalse(originalRow.label.contains("2D · 2D")); originalRow.tap()
        XCTAssertTrue(element("freeLayout.useTemplate").exists)
        XCTAssertTrue(element("freeLayout.deriveTemplate").exists)
        try capture("04-two-actions", probing: ["freeLayout.useTemplate", "freeLayout.deriveTemplate"])
        ready("freeLayout.deriveTemplate").tap()
        chooseFreeControl("planning.constraintTool"); app.buttons["下移"].tap()
        ready("freeLayout.cancel").tap()
        XCTAssertEqual(ready("silu.tool").frame, targetTool)
        openFreeEditor(); findTemplate("R03共享 · 2D").tap(); ready("freeLayout.useTemplate").tap()
        waitUntil("template applied") { !self.element("freeLayout.editor").exists }
        XCTAssertEqual(ready("silu.tool").frame, targetTool)
        XCTAssertEqual(ready("silu.undo").frame.midX, sourceUndo.midX, accuracy: 2)
        XCTAssertEqual(ready("silu.undo").frame.midY, sourceUndo.midY, accuracy: 2)
        XCTAssertEqual(ready("shotStage.powerBar").frame.midX, sourcePower.midX, accuracy: 2)
        XCTAssertFalse(element("break.entry").exists)
        try capture("05-intersection-applied", probing: ["silu.undo", "silu.tool", "shotStage.powerBar"])
        openFreeEditor(); findTemplate("R03共享 · 2D").tap(); ready("freeLayout.deriveTemplate").tap()
        chooseFreeControl("planning.constraintTool"); app.buttons["右移"].tap()
        ready("freeLayout.collapse").tap()
        try capture("06-derived-preview", probing: ["freeLayout.collapse"])
        ready("freeLayout.collapse").tap(); save("R03共享")
        let derivedTool = ready("silu.tool").frame
        XCTAssertEqual(derivedTool.midX, targetTool.midX + 5, accuracy: 2)
        try capture("07-derived-saved", probing: ["silu.tool", "silu.undo"])
        openFreeEditor()
        XCTAssertEqual(templates().count, 4)
        XCTAssertTrue(element(originalID).exists)
        XCTAssertEqual(templates().matching(NSPredicate(format: "label CONTAINS %@", "R03共享 · 2D")).count, 2)
        let derivedID = findTemplate("R03共享 · 2D").identifier
        XCTAssertNotEqual(derivedID, originalID)
        ready("freeLayout.cancel").tap()

        launchMatrixPage("dailyClearance")
        XCTAssertEqual(ready("dailyClearance.undo").frame.midY, sourceUndo.midY, accuracy: 2)
        openFreeEditor(); ready(derivedID).tap(); ready("freeLayout.useTemplate").tap()
        waitUntil("derived applied back") { !self.element("freeLayout.editor").exists }
        XCTAssertFalse(element("silu.tool").exists)
        XCTAssertEqual(ready("dailyClearance.undo").frame.midY, sourceUndo.midY, accuracy: 2)
        try capture("08-derived-back-to-source", probing: ["dailyClearance.undo", "break.entry"])
    }

    func testFreePadActualWindowResize() throws {
        launchMatrixPage("dailyClearance")
        openFreeEditor(); ready("freeLayout.default").tap()
        let state = try businessSnapshot(includeCamera: false)
        openFreeEditor(); ready("freeLayout.customize").tap(); chooseFreeControl("shot.undo")
        // Keep the action centers clear of iPadOS window-resize handles. Edge
        // clipping is captured separately; system chrome cannot be a hit target.
        let window = app.windows.firstMatch
        ready("freeLayout.select.shot.undo").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: window.coordinate(withNormalizedOffset: .init(dx: 0.15, dy: 0.7)))
        app.buttons["右移"].tap(); app.buttons["放大"].tap()
        chooseFreeControl("shot.strike")
        ready("freeLayout.select.shot.strike").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: window.coordinate(withNormalizedOffset: .init(dx: 0.8, dy: 0.8)))
        let strikePreview = ready("freeLayout.select.shot.strike").frame
        let strikeX = (strikePreview.midX - window.frame.minX) / window.frame.width
        let strikeY = (strikePreview.midY - window.frame.minY) / window.frame.height
        ready("freeLayout.save").tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText("R04窗口")
        app.alerts.buttons["保存"].tap()
        waitUntil("saved") { !self.element("freeLayout.editor").exists }
        let original = app.windows.firstMatch.frame, control = ready("dailyClearance.undo").frame
        // iPadOS can report a partially off-window SwiftUI button's AX parent
        // in window coordinates while its visible label remains screen-relative.
        // Measure the rendered label independently, and prove the physical hit
        // below; keep the unmodified parent AX tree in every capture.
        let label = ready("dailyClearance.undo").staticTexts["重打"].frame
        let labelOffset = CGPoint(x: label.midX - control.midX, y: label.midY - control.midY)
        func visibleUndoFrame() -> CGRect {
            let label = ready("dailyClearance.undo").staticTexts["重打"].frame
            return CGRect(x: label.midX - labelOffset.x - control.width / 2,
                          y: label.midY - labelOffset.y - control.height / 2,
                          width: control.width, height: control.height)
        }
        let x = (control.midX - original.minX) / original.width, y = (control.midY - original.minY) / original.height
        func zoomWindow() {
            let window = app.windows.firstMatch, before = window.frame
            window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 52, dy: 32)).tap()
            Thread.sleep(forTimeInterval: 0.5)
            if abs(window.frame.width - before.width) < 1 {
                window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 104, dy: 32)).tap()
            }
        }
        defer { if app.windows.firstMatch.exists, abs(app.windows.firstMatch.frame.width - original.width) > 1 { zoomWindow() } }
        try capture("01-window-saved", probing: ["dailyClearance.undo", "table.scene"])
        let origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(.init(dx: original.width - 7, dy: original.height - 7)).press(forDuration: 0.5,
            thenDragTo: origin.withOffset(.init(dx: original.width * 0.7, dy: original.height * 0.78)))
        waitUntil("real smaller window") {
            let f = self.app.windows.firstMatch.frame
            return f.width < original.width - 80 || f.height < original.height - 80
        }
        XCTAssertFalse(element("dailyLayout.limited").exists, "Personal layouts must not trigger the default capacity blocker")
        XCTAssertTrue(ready("paletteBall__1").exists, "The real palette remains visible")
        let smaller = app.windows.firstMatch.frame, moved = visibleUndoFrame()
        XCTAssertEqual(ready("dailyClearance.undo").frame.midX, moved.midX, accuracy: 2)
        XCTAssertEqual(ready("dailyClearance.undo").frame.midY, moved.midY, accuracy: 2)
        XCTAssertEqual((moved.midX - smaller.minX) / smaller.width, x, accuracy: 0.005)
        XCTAssertEqual((moved.midY - smaller.minY) / smaller.height, y, accuracy: 0.005)
        XCTAssertEqual(try businessSnapshot(includeCamera: false), state)
        try capture("02-real-window-smaller", probing: ["dailyClearance.undo", "table.scene"])
        app.windows.firstMatch.coordinate(withNormalizedOffset: .init(dx: strikeX, dy: strikeY)).tap()
        waitUntil("window shot settled", timeout: 90) { self.element("dailyClearance.undo").isEnabled }
        XCTAssertTrue((ready("dailyLayout.controlsProbe").value as? String ?? "").contains("dailyShotCount=1"))
        app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            .withOffset(.init(dx: moved.midX - smaller.minX, dy: moved.midY - smaller.minY)).tap()
        waitUntil("relocated undo receives physical touch in floating window") {
            (self.element("dailyLayout.controlsProbe").value as? String ?? "").contains("dailyShotCount=0")
        }
        // Undo legitimately creates a new sequence draft identity. Layout edits
        // and subsequent window changes must preserve this post-action state.
        let afterUndo = try businessSnapshot(includeCamera: false)
        openFreeEditor(); ready("freeLayout.current").tap(); chooseFreeControl("shot.undo")
        let preview = ready("freeLayout.select.shot.undo").frame
        XCTAssertEqual(preview.midX, moved.midX, accuracy: 2)
        XCTAssertEqual(preview.midY, moved.midY, accuracy: 2)
        app.buttons["右移"].tap()
        XCTAssertEqual(ready("freeLayout.select.shot.undo").frame.midX, preview.midX + 5, accuracy: 2)
        ready("freeLayout.cancel").tap()
        XCTAssertEqual(visibleUndoFrame(), moved)
        zoomWindow()
        waitUntil("original window size restored") { abs(self.app.windows.firstMatch.frame.width - original.width) < 1 }
        let restored = app.windows.firstMatch.frame, returned = ready("dailyClearance.undo").frame
        XCTAssertEqual((returned.midX - restored.minX) / restored.width, x, accuracy: 0.005)
        XCTAssertEqual((returned.midY - restored.minY) / restored.height, y, accuracy: 0.005)
        XCTAssertEqual(try businessSnapshot(includeCamera: false), afterUndo)
        try capture("03-window-restored", probing: ["dailyClearance.undo", "table.scene"])
    }

    func testFreeLegacyNativeConversion() throws {
        launchMatrixPage("dailyClearance")
        let applied = ready("dailyClearance.undo").frame
        openFreeEditor()
        let migrated = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "freeLayout.template.", "旧版")).firstMatch
        XCTAssertTrue(migrated.waitForExistence(timeout: 10), "A measured compatible v1 template must become usable")
        let count = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "freeLayout.template.")).count
        try capture("01-migrated-library")
        let manage = ready("freeLayout.manage")
        for _ in 0..<5 where !manage.isHittable { app.scrollViews["freeLayout.templateList"].swipeUp() }
        manage.tap()
        let oldName = app.staticTexts["原模板：旧版"]
        for _ in 0..<6 where !oldName.exists || !oldName.isHittable { app.collectionViews["freeLibrary"].swipeUp() }
        XCTAssertTrue(oldName.waitForExistence(timeout: 5))
        try capture("02-legacy-provenance")
        ready("freeLibrary.close").tap(); ready("freeLayout.cancel").tap()
        launchMatrixPage("dailyClearance")
        XCTAssertEqual(ready("dailyClearance.undo").frame, applied)
        openFreeEditor()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "freeLayout.template.")).count, count)
        ready("freeLayout.cancel").tap()
        try capture("03-migrated-relaunch", probing: ["dailyClearance.undo", "dailyClearance.playback"])
    }

    func testFreeManagementPrecisionAndRotation() throws {
        launchMatrixPage("dailyClearance")
        let baseline = ready("dailyClearance.undo").frame
        setCoreMode("3D"); let threeD = ready("dailyClearance.undo").frame
        setCoreMode("2D"); openFreeEditor(); ready("freeLayout.customize").tap()
        chooseFreeControl("shot.undo"); app.buttons["数值"].tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (field.value as? String ?? "").count))
        field.typeText("137.5"); app.alerts.buttons["确定"].tap()
        app.buttons["右移"].tap()
        let preview = ready("freeLayout.select.shot.undo").frame
        XCTAssertEqual(preview.width, baseline.width * 1.375, accuracy: 2)
        ready("freeLayout.collapse").tap(); try capture("01-precise-preview")
        ready("freeLayout.collapse").tap(); ready("freeLayout.save").tap()
        let name = app.alerts.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("R04精确")
        app.alerts.buttons["保存"].tap()
        waitUntil("saved") { !self.element("freeLayout.editor").exists }
        let saved = ready("dailyClearance.undo").frame
        XCTAssertEqual(saved.midX, preview.midX, accuracy: 2); XCTAssertEqual(saved.width, preview.width, accuracy: 2)
        try capture("02-precise-saved", probing: ["dailyClearance.undo"])
        openFreeEditor()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "freeLayout.template.", "R04精确")).firstMatch
        let templateID = row.identifier.replacingOccurrences(of: "freeLayout.template.", with: "")
        let manage = ready("freeLayout.manage")
        if !manage.isHittable { app.scrollViews["freeLayout.templateList"].swipeUp() }
        manage.tap(); ready("freeLibrary.actions." + templateID).tap(); app.buttons["改名"].tap()
        let rename = app.alerts.textFields.firstMatch
        XCTAssertTrue(rename.waitForExistence(timeout: 5)); rename.tap()
        rename.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (rename.value as? String ?? "").count))
        rename.typeText("R04改名 · 3D"); app.alerts.buttons["保存"].tap()
        XCTAssertTrue(app.staticTexts["R04改名 · 2D"].waitForExistence(timeout: 5))
        try capture("03-renamed-library")
        ready("freeLibrary.actions." + templateID).tap(); app.buttons["删除"].tap(); app.buttons["删除模板"].tap()
        waitUntil("library deleted") { !self.element("freeLibrary.actions." + templateID).exists }
        ready("freeLibrary.close").tap(); ready("freeLayout.cancel").tap()
        XCTAssertEqual(ready("dailyClearance.undo").frame, saved)
        setCoreMode("3D"); XCTAssertEqual(ready("dailyClearance.undo").frame, threeD); setCoreMode("2D")
        launchMatrixPage("dailyClearance")
        XCTAssertEqual(ready("dailyClearance.undo").frame, saved)
        try capture("04-deleted-source-relaunch", probing: ["dailyClearance.undo"])
        if UIDevice.current.userInterfaceIdiom == .pad {
            let beforeWindow = app.windows.firstMatch.frame
            XCUIDevice.shared.orientation = .portrait
            waitUntil("portrait") { self.app.windows.firstMatch.frame.height > self.app.windows.firstMatch.frame.width }
            let afterWindow = app.windows.firstMatch.frame, rotated = ready("dailyClearance.undo").frame
            XCTAssertEqual(rotated.midX / afterWindow.width, saved.midX / beforeWindow.width, accuracy: 0.005)
            XCTAssertEqual(rotated.midY / afterWindow.height, saved.midY / beforeWindow.height, accuracy: 0.005)
            try capture("05-rotated-retained", probing: ["dailyClearance.undo"])
            XCUIDevice.shared.orientation = .landscapeLeft
            waitUntil("landscape") { self.app.windows.firstMatch.frame.width > self.app.windows.firstMatch.frame.height }
            XCTAssertEqual(ready("dailyClearance.undo").frame, saved)
        } else { try capture("05-mode-retained", probing: ["dailyClearance.undo"]) }
        openFreeEditor(); ready("freeLayout.default").tap()
        waitUntil("restored") { !self.element("freeLayout.editor").exists }
        XCTAssertEqual(ready("dailyClearance.undo").frame, baseline)
        try capture("06-page-default", probing: ["dailyClearance.undo"])
    }

    /// R01: actual controls on the complete live page, not the legacy group editor.
    func testFreeControlVerticalSlice() throws {
        launchCore("dailyClearance", fixture: "selection")
        setCoreMode("2D")
        openFreeEditor()
        ready("freeLayout.default").tap()
        waitUntil("default returned") { !self.element("freeLayout.editor").exists }
        let original = ready("dailyClearance.undo").frame
        let neighbor = ready("dailyClearance.playback").frame
        try capture("01-before", probing: ["dailyClearance.undo", "dailyClearance.playback", "freeplay.moreMenu", "paletteBall__1", "table.scene"])
        openFreeEditor()
        ready("freeLayout.customize").tap()
        let control = ready("freeLayout.select.shot.undo")
        let target = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 35, dy: app.windows.firstMatch.frame.height * 0.22))
        control.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).press(forDuration: 0.2, thenDragTo: target)
        let moved = ready("freeLayout.select.shot.undo").frame
        XCTAssertEqual(moved.midX, 35, accuracy: 3)
        XCTAssertLessThan(moved.midY, original.midY - 20)
        let untouched = ready("freeLayout.select.shot.replay").frame
        XCTAssertEqual(untouched.midX, neighbor.midX, accuracy: 1)
        XCTAssertEqual(untouched.midY, neighbor.midY, accuracy: 1)
        app.sliders["freeLayout.scale"].adjust(toNormalizedSliderPosition: 0.6)
        let resized = ready("freeLayout.select.shot.undo").frame
        XCTAssertGreaterThan(resized.width, original.width * 1.3)
        XCTAssertEqual(resized.midX, moved.midX, accuracy: 1)
        try capture("02-edit-selected", probing: ["freeLayout.select.shot.undo", "freeLayout.select.shot.replay"])
        ready("freeLayout.collapse").tap()
        try capture("03-edit-collapsed", probing: ["freeLayout.collapse"])
        ready("freeLayout.collapse").tap()
        ready("freeLayout.save").tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText("R01")
        app.alerts.buttons["保存"].tap()
        waitUntil("save returned") { !self.element("freeLayout.editor").exists }
        let saved = ready("dailyClearance.undo").frame
        XCTAssertEqual(saved.midX, resized.midX, accuracy: 2)
        XCTAssertEqual(saved.midY, resized.midY, accuracy: 2)
        XCTAssertEqual(saved.width, resized.width, accuracy: 2)
        XCTAssertEqual(ready("dailyClearance.playback").frame, neighbor)
        try capture("04-saved", probing: ["dailyClearance.undo", "dailyClearance.playback", "freeplay.moreMenu", "paletteBall__1", "table.scene"])
        openFreeEditor(); ready("freeLayout.current").tap()
        ready("freeLayout.select.shot.undo").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        app.buttons["右移"].tap(); ready("freeLayout.cancel").tap()
        XCTAssertEqual(ready("dailyClearance.undo").frame, saved)
        launchCore("dailyClearance", fixture: "selection")
        XCTAssertEqual(ready("dailyClearance.undo").frame.midX, saved.midX, accuracy: 2)
        XCTAssertEqual(ready("dailyClearance.undo").frame.width, saved.width, accuracy: 2)
        try capture("05-restarted", probing: ["dailyClearance.undo", "dailyClearance.playback"])
        setCoreMode("3D")
        XCTAssertEqual(ready("dailyClearance.undo").frame.width, original.width, accuracy: 2)
        setCoreMode("2D")
        XCTAssertEqual(ready("dailyClearance.undo").frame.midX, saved.midX, accuracy: 2)
        try capture("06-mode-return", probing: ["dailyClearance.undo", "dailyClearance.playback"])
        ready("dailyClearance.strike").tap()
        waitUntil("real shot settled", timeout: 90) { self.element("dailyClearance.undo").isEnabled }
        XCTAssertTrue((ready("dailyLayout.controlsProbe").value as? String ?? "").contains("dailyShotCount=1"))
        let relocatedUndo = ready("dailyClearance.undo")
        XCTAssertTrue(relocatedUndo.isHittable, "Scaled control outside safe area must receive touches")
        relocatedUndo.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        waitUntil("relocated original action executed", timeout: 30) {
            (self.element("dailyLayout.controlsProbe").value as? String ?? "").contains("dailyShotCount=0")
        }
        try capture("07-real-hit", probing: ["dailyClearance.undo", "dailyClearance.playback", "dailyLayout.controlsProbe"])
    }

    private func openFreeEditor() {
        let more = ["freeplay.moreMenu", "silu.more", "planthree.more", "snooker.more", "bankshot.more", "reflection.more", "angleDynamic.more", "separationAngleAtlas.more", "cushionEnglishAtlas.more", "angleTraining.settings", "aimPointTraining.settings"]
            .first { element($0).exists } ?? "freeplay.moreMenu"
        ready(more).coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        let entry = ready("controlLayout.open")
        for _ in 0..<4 where !entry.isHittable {
            // fullScreenCover's AX ScrollView can report an empty visible frame
            // despite a visible menu. Send the real gesture inside its measured
            // viewport; entry visibility and the complete editor flow still assert.
            let window = app.windows.firstMatch
            let viewport = ready("dailyClearance.menuPanel").frame.intersection(window.frame)
            XCTAssertFalse(viewport.isEmpty)
            let origin = window.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(.init(dx: viewport.midX - window.frame.minX,
                                    dy: viewport.minY + viewport.height * 0.8 - window.frame.minY))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(.init(
                    dx: viewport.midX - window.frame.minX,
                    dy: viewport.minY + viewport.height * 0.25 - window.frame.minY)))
        }
        waitUntil("free layout entry enabled", timeout: 90) { entry.isEnabled }
        entry.tap(); _ = ready("freeLayout.editor")
    }

    private func chooseFreeControl(_ id: String) {
        ready("freeLayout.controls").tap()
        let option = ready("freeLayout.choose." + id)
        let list = app.scrollViews["freeLayout.controlList"]
        for _ in 0..<5 {
            if option.isHittable && list.frame.contains(CGPoint(x: option.frame.midX, y: option.frame.midY)) { break }
            list.swipeUp()
        }
        XCTAssertTrue(option.isHittable); option.tap()
    }

    func testFreeControlThreePageIntegration() throws {
        for page in (ProcessInfo.processInfo.environment["LAYOUT_PAGES"] ?? "dailyClearance,freePlay,silu").split(separator: ",").map(String.init) {
            launchMatrixPage(page)
            if page == "silu" {
                ready("silu.tool").tap(); app.buttons["落区"].tap()
                let table = ready("table.scene")
                table.coordinate(withNormalizedOffset: .init(dx: 0.37, dy: 0.48)).press(forDuration: 0.1,
                    thenDragTo: table.coordinate(withNormalizedOffset: .init(dx: 0.58, dy: 0.76)))
                waitUntil("constraint ready") { self.element("solver.solve").isEnabled }
                ready("solver.solve").tap()
                waitUntil("solution ready", timeout: 90) { self.element("silu.strike").isEnabled }
            }
            for mode in ["2D", "3D"] {
                if page == "silu" {
                    ready("silu.more").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
                    let camera = ready("silu.cameraMode")
                    if camera.value as? String != mode { camera.tap() }
                    ready("silu.dismissMenu").coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.5)).tap()
                } else { setCoreMode(mode) }
                openFreeEditor(); ready("freeLayout.default").tap()
                let state = try businessSnapshot()
                let stage = ready("table.scene").frame
                let probes = ["table.scene", "break.entry", "shotStage.spinEntry", "shotStage.powerBar", "shotCamera.thirdPerson", "dailyClearance.observeTable", "shotCamera.temporaryTopDown", "silu.tool", "solver.solve", "dailyClearance.undo", "dailyClearance.playback"]
                try capture(page + "-" + mode + "-before", probing: probes)
                openFreeEditor(); ready("freeLayout.customize").tap()
                let query = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "freeLayout.select."))
                let controlIDs = query.allElementsBoundByIndex.map(\.identifier).sorted()
                XCTAssertEqual(Set(controlIDs).count, controlIDs.count)
                XCTAssertGreaterThanOrEqual(controlIDs.count, page == "silu" ? 9 : 7)
                XCTAssertTrue(controlIDs.contains("freeLayout.select.shot.power"))
                XCTAssertTrue(controlIDs.contains("freeLayout.select.shot.spin"))
                if mode == "3D" { XCTAssertTrue(controlIDs.contains("freeLayout.select.camera.thirdPerson")) }
                if page == "silu" {
                    let tool = ready("freeLayout.select.planning.constraintTool"), original = tool.frame
                    let target = app.windows.firstMatch.coordinate(withNormalizedOffset: .init(dx: 0.3, dy: 0.2))
                    tool.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).press(forDuration: 0.2, thenDragTo: target)
                    let moved = tool.frame
                    XCTAssertGreaterThan(abs(moved.midX - original.midX), 50)
                    app.buttons["撤销"].tap()
                    XCTAssertEqual(tool.frame.midX, original.midX, accuracy: 1)
                    app.buttons["重做"].tap()
                    XCTAssertEqual(tool.frame.midX, moved.midX, accuracy: 1)
                }
                for controlID in controlIDs {
                    let before = Dictionary(uniqueKeysWithValues: controlIDs.map { ($0, ready($0).frame) })
                    chooseFreeControl(controlID.replacingOccurrences(of: "freeLayout.select.", with: ""))
                    app.buttons["右移"].tap(); app.buttons["上移"].tap(); app.buttons["放大"].tap()
                    let after = ready(controlID).frame
                    XCTAssertEqual(after.midX, before[controlID]!.midX + 5, accuracy: 1)
                    XCTAssertEqual(after.midY, before[controlID]!.midY - 5, accuracy: 1)
                    XCTAssertGreaterThan(after.width, before[controlID]!.width)
                    for other in controlIDs where other != controlID {
                        let r = ready(other).frame
                        XCTAssertEqual(r.midX, before[other]!.midX, accuracy: 1, "Neighbor moved: " + other)
                        XCTAssertEqual(r.midY, before[other]!.midY, accuracy: 1, "Neighbor moved: " + other)
                        XCTAssertEqual(r.width, before[other]!.width, accuracy: 1)
                    }
                }
                ready("freeLayout.collapse").tap()
                try capture(page + "-" + mode + "-preview", probing: probes)
                XCUIDevice.shared.press(.home); app.activate()
                XCTAssertTrue(ready("freeLayout.editor").exists)
                ready("freeLayout.collapse").tap(); ready("freeLayout.save").tap()
                let name = app.alerts.textFields.firstMatch
                XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("R02 " + page)
                app.alerts.buttons["保存"].tap()
                waitUntil("saved") { !self.element("freeLayout.editor").exists }
                XCTAssertEqual(ready("table.scene").frame, stage)
                XCTAssertEqual(try businessSnapshot(), state, "Layout must preserve balls/camera/parameters")
                try capture(page + "-" + mode + "-saved", probing: probes)
                let savedPower = ready("shotStage.powerBar").frame
                openFreeEditor(); ready("freeLayout.current").tap(); chooseFreeControl("shot.power")
                app.buttons["左移"].tap(); ready("freeLayout.cancel").tap()
                XCTAssertEqual(ready("shotStage.powerBar").frame, savedPower)
                XCTAssertEqual(try businessSnapshot(), state)
                let power = ready("shotStage.powerBar"), speed = power.value as? String
                power.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.65)).press(forDuration: 0.1,
                    thenDragTo: power.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.4)))
                XCTAssertNotEqual(power.value as? String, speed, "Relocated real ruler must adjust power")
                if page == "silu" {
                    ready("silu.tool").tap(); app.cells.buttons["摆球"].tap()
                    XCTAssertTrue((ready("silu.layoutState").value as? String ?? "").contains("tool=none"))
                }
                if mode == "3D" {
                    for (semantic, actual) in [("overview", "dailyClearance.observeTable"), ("thirdPerson", "shotCamera.thirdPerson"), ("firstPerson", "shotCamera.firstPerson")] where controlIDs.contains("freeLayout.select.camera." + semantic) {
                        ready(actual).tap()
                        waitUntil("relocated camera action " + semantic) { self.element(actual).value as? String == "已选中" }
                    }
                }
            }
        }
    }
    func testFreeControlBreakStages() throws {
        for page in ["freePlay", "silu"] {
            launchMatrixPage(page)
            let more = page == "silu" ? "silu.more" : "freeplay.moreMenu"
            if page == "silu" {
                ready(more).coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
                if ready("silu.cameraMode").value as? String != "3D" { ready("silu.cameraMode").tap() }
                dismissFreeMenu(page)
            } else { setCoreMode("3D") }
            openFreeEditor(); ready("freeLayout.default").tap()
            // Temporary top-down is still the 3D page; changing its layout is blocked.
            ready("shotCamera.temporaryTopDown").tap()
            if page == "freePlay" {
                XCTAssertFalse(ready(more).isEnabled)
            } else {
                ready(more).coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
                XCTAssertFalse(ready("controlLayout.open").isEnabled)
                dismissFreeMenu(page)
            }
            XCTAssertFalse(element("freeLayout.editor").exists)
            try capture(page + "-temporary-top-down")
            ready("shotCamera.temporaryTopDown").tap()
            if page == "silu" { ready(more).coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap() }
            ready("break.entry").tap(); ready("break.game.9").tap()
            let strike = page == "silu" ? "silu.strike" : "break.strike"
            waitUntil("strike ready", timeout: 90) { self.element(strike).isEnabled }
            let original = ready(strike).frame
            openFreeEditor(); ready("freeLayout.customize").tap()
            for id in ["break.rerack", "shot.aim", "shot.spin", "shot.power", "break.strike"] {
                _ = ready("freeLayout.select." + id)
            }
            XCTAssertFalse(element("freeLayout.select.shot.strike").exists)
            chooseFreeControl("break.strike")
            app.buttons["左移"].tap(); app.buttons["放大"].tap()
            let edited = ready("freeLayout.select.break.strike").frame
            XCTAssertEqual(edited.midX, original.midX - 5, accuracy: 1)
            ready("freeLayout.collapse").tap()
            try capture(page + "-break-preview")
            ready("freeLayout.collapse").tap(); ready("freeLayout.save").tap()
            let name = app.alerts.textFields.firstMatch
            XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("R02 break")
            app.alerts.buttons["保存"].tap()
            waitUntil("saved break") { !self.element("freeLayout.editor").exists }
            XCTAssertEqual(ready(strike).frame.midX, edited.midX, accuracy: 1)
            let movedStrike = ready(strike)
            movedStrike.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            waitUntil("real relocated break started", timeout: 5) {
                !self.element(strike).exists || !self.element(strike).isEnabled || self.element(strike).label != "开球"
            }
            if page == "silu" {
                waitUntil("break settled", timeout: 90) { self.element(strike).isEnabled && self.element(strike).label == "完成" }
            } else { waitUntil("confirm ready", timeout: 90) { self.element("break.confirm").exists && self.element("break.confirm").isEnabled } }
            ready(more).coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); XCTAssertFalse(ready("controlLayout.open").isEnabled); dismissFreeMenu(page)
            ready(page == "silu" ? "silu.strike" : "break.confirm").tap()
            openFreeEditor(); ready("freeLayout.current").tap()
            XCTAssertFalse(element("freeLayout.select.break.strike").exists)
            _ = ready("freeLayout.select.shot.strike")
            ready("freeLayout.cancel").tap()
            try capture(page + "-normal-after-break")
        }
    }

    func testFreeControlOverlapRecovery() throws {
        launchCore("dailyClearance", fixture: "selection"); setCoreMode("2D")
        openFreeEditor(); ready("freeLayout.default").tap()
        let original = ready("dailyClearance.undo").frame
        openFreeEditor(); ready("freeLayout.customize").tap()
        let undo = ready("freeLayout.select.shot.undo"), replay = ready("freeLayout.select.shot.replay")
        undo.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).press(forDuration: 0.2,
            thenDragTo: replay.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)))
        XCTAssertEqual(undo.frame.midX, replay.frame.midX, accuracy: 2)
        XCTAssertEqual(undo.frame.midY, replay.frame.midY, accuracy: 2)
        try capture("overlap-selected")
        chooseFreeControl("shot.replay")
        app.buttons["右移"].tap()
        XCTAssertEqual(replay.frame.midX, undo.frame.midX + 5, accuracy: 1)
        chooseFreeControl("shot.undo"); ready("freeLayout.resetSelected").tap()
        XCTAssertEqual(undo.frame.midX, original.midX, accuracy: 1)
        XCTAssertEqual(undo.frame.midY, original.midY, accuracy: 1)
        try capture("overlap-recovered")
        ready("freeLayout.cancel").tap()
        XCTAssertEqual(ready("dailyClearance.undo").frame, original)
        try capture("overlap-cancelled")
    }

    private func dismissFreeMenu(_ page: String) {
        if page == "silu" { ready("silu.dismissMenu").coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.5)).tap() }
        else { app.coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.5)).tap() }
    }

    private var app: XCUIApplication!
    private var output: URL!
    private var rows = [[String: String]]()
    private let ids = ["controlLayout.revision", "controlLayout.geometry", "table.scene", "freeplay.stage", "dailyClearance.landscape",
        "dailyLayout.headerProbe", "dailyLayout.spaceProbe", "dailyLayout.controlsProbe", "silu.template",
        "dailyClearance.back", "freeplay.moreMenu", "silu.back", "silu.more",
        "shotStage.aimWheel", "shotStage.powerBar", "shotStage.instrument", "shotStage.powerShell",
        "shotStage.spinEntry", "dailyClearance.strike", "dailyClearance.undo", "dailyClearance.playback",
        "shotCamera.thirdPerson", "shotCamera.temporaryTopDown", "dailyClearance.observeTable",
        "silu.tool", "silu.clearConstraint", "solver.solve", "silu.undo", "silu.replay", "silu.strike",
        "teaching.informationViewport", "silu.layoutState", "spinPad.disc", "dailyClearance.menuPanel", "paletteBall__1", "paletteBall__15"]
    override func setUpWithError() throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        output = env["LAYOUT_BASELINE_DIR"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("control-layout-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        defer { app?.terminate() }
        if let app, let output {
            let shot = XCUIScreen.main.screenshot(), ax = app.debugDescription
            try shot.pngRepresentation.write(to: output.appendingPathComponent("final-diagnostic.png"))
            try ax.write(to: output.appendingPathComponent("final-diagnostic.ax.txt"), atomically: true, encoding: .utf8)
            let image = XCTAttachment(screenshot: shot); image.name = "final-diagnostic"
            image.lifetime = .keepAlways; add(image)
            let tree = XCTAttachment(string: ax); tree.name = "final-diagnostic.ax.txt"
            tree.lifetime = .keepAlways; add(tree)
        }
    }
    private func element(_ id: String) -> XCUIElement {
        let named = app.descendants(matching: .any).matching(identifier: id).firstMatch
        // ProAccessGate's identifier can propagate onto root diagnostic elements.
        // Keep real navigation and read the same probe by its semantic content.
        if id == "table.scene", !named.exists {
            return app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "球桌")).firstMatch
        }
        if id == "dailyLayout.controlsProbe", !named.exists {
            return app.descendants(matching: .any).matching(NSPredicate(format: "value BEGINSWITH %@", "stageHeight=")).firstMatch
        }
        if id == "controlLayout.geometry", !named.exists {
            return app.descendants(matching: .any).matching(NSPredicate(format: "value BEGINSWITH %@", "status=")).firstMatch
        }
        if id == "silu.layoutState", !named.exists {
            return app.descendants(matching: .any).matching(NSPredicate(format: "value BEGINSWITH %@", "target=")).firstMatch
        }
        return named
    }
    private func ready(_ id: String) -> XCUIElement {
        let node = element(id)
        XCTAssertTrue(node.exists || node.waitForExistence(timeout: 20), id)
        return node
    }
    private func rect(_ r: CGRect) -> [String: Any] {
        ["x": r.minX, "y": r.minY, "width": r.width, "height": r.height].mapValues { value -> Any in
            value.isFinite ? value : "nonfinite"
        }
    }
    private func capture(_ name: String, probing: [String]? = nil) throws {
        if !name.hasSuffix("-busy") { Thread.sleep(forTimeInterval: 0.7) }
        let shot = XCUIScreen.main.screenshot()
        try shot.pngRepresentation.write(to: output.appendingPathComponent(name + ".png"))
        let ax = app.debugDescription
        try ax.write(to: output.appendingPathComponent(name + ".ax.txt"), atomically: true, encoding: .utf8)
        var controls = [[String: Any]]()
        for id in (probing ?? (name.hasSuffix("-base") ? ids : ["dailyClearance.menuPanel", "dailyClearance.spinTransparencyPanel", "spinPad.disc", "dailyClearance.strike", "silu.strike"])) {
            let e = element(id)
            if e.exists {
                controls.append(["id": id, "actualIdentifier": e.identifier, "frame": rect(e.frame), "enabled": e.isEnabled,
                    "hittable": "not queried; see action and image evidence", "label": e.label, "value": e.value.map { String(describing: $0) } ?? ""])
            }
        }
        let payload: [String: Any] = ["name": name, "window": rect(app.windows.firstMatch.frame),
            "controls": controls, "launchArguments": app.launchArguments,
            "entry": "real page UI; launch and navigation route recorded in launchArguments", "capturedAt": Date().timeIntervalSince1970]
        try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent(name + ".json"))
        rows.append(["name": name, "image": name + ".png", "measurements": name + ".json"])
        try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("manifest.json"))
        let attachment = XCTAttachment(screenshot: shot); attachment.name = name
        attachment.lifetime = .keepAlways; add(attachment)
        let tree = XCTAttachment(string: ax); tree.name = name + ".ax.txt"
        tree.lifetime = .keepAlways; add(tree)
        let geometry = XCTAttachment(data: try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        geometry.name = name + ".json"; geometry.lifetime = .keepAlways; add(geometry)
    }
    private func waitUntil(_ description: String, timeout: TimeInterval = 15, _ condition: @escaping () -> Bool) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)], timeout: timeout), .completed, description)
    }
    private func saveLayoutPage() {
        ready("layoutEditor.save").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        ready("layoutEditor.savePage").tap()
        waitUntil("editor dismissed") { !self.element("layoutEditor").exists }
    }
    private func resetLayoutPage() {
        openLayoutEditor()
        let restore = app.buttons["恢复本页"].firstMatch
        for _ in 0..<6 where !restore.isHittable { app.scrollViews["layoutEditor.properties"].swipeUp() }
        restore.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        app.buttons["本页使用球迹默认"].tap(); saveLayoutPage()
    }
    private func setCoreMode(_ mode: String) {
        ready("freeplay.moreMenu").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        let selector = ready("freeplay.cameraMode")
        if selector.value as? String != mode { selector.tap() }
        XCTAssertEqual(selector.value as? String, mode)
        app.buttons["关闭菜单"].firstMatch.coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.5)).tap()
        waitUntil("camera and solver settled", timeout: 45) { self.element("dailyClearance.strike").isEnabled }
    }
    private func launchCore(_ page: String, fixture: String? = nil) {
        app?.terminate()
        let portrait = ProcessInfo.processInfo.environment["LAYOUT_ORIENTATION"] == "portrait"
        XCUIDevice.shared.orientation = portrait ? .portrait : .landscapeLeft
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES",
            "-forcePremium", "-v50.inMemoryStore", "-appearanceMode", "dark", "-dailyLayout.probe", "-3dDrag.probe",
            "-drillTryout.hasSeenGestureHint", "YES", "-snakePractice.count", "5", "-snakePractice.mode", "沿线清台"]
        switch page {
        case "shotSimulation": app.launchArguments.append("-dailyInteraction.sharedPage=shot")
        case "composer": app.launchArguments.append("-dailyInteraction.sharedPage=composer")
        case "drillTryout": app.launchArguments.append("-deeplink.drillDetail=" + (ProcessInfo.processInfo.environment["LAYOUT_DRILL"] ?? "drill_c029"))
        default: app.launchArguments.append("-deeplink." + page)
        }
        if let fixture { app.launchArguments.append("-dailyClearance.fixture=" + fixture) }
        app.launch()
        if page == "snakePractice" { ready("snake.start").tap() }
        if page == "drillTryout" {
            ready("bottomTryoutButton").tap()
            if element("tryoutFormation_0").waitForExistence(timeout: 2) { ready("tryoutFormation_0").tap() }
        }
        _ = ready("freeplay.moreMenu")
        // Full-screen tryout presentation can reset the device orientation after launch.
        XCUIDevice.shared.orientation = portrait ? .portrait : .landscapeLeft
        waitUntil("requested orientation") {
            let frame = self.app.windows.firstMatch.frame
            return portrait ? frame.height > frame.width : frame.width > frame.height
        }
        waitUntil("ready to operate", timeout: 45) { self.element("dailyClearance.strike").isEnabled }
        if page == "drillTryout" {
            XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "pro.authorized").count, 1,
                           "Authorization belongs to its container, not every descendant control")
            let entry = ready("dailyLayout.controlsProbe").value as? String ?? ""
            XCTAssertTrue(entry.contains("sequenceMode=true"), "Tryout must load its authored sequence before layout actions: " + entry)
        }
    }

    func testPlanningNoSolutionCanStillEdit() throws {
        app = XCUIApplication(); XCUIDevice.shared.orientation = .landscapeLeft
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES",
            "-forcePremium", "-v50.inMemoryStore", "-dailyLayout.probe", "-3dDrag.probe", "-deeplink.snooker", "-snooker.none"]
        app.launch(); _ = ready("snooker.more")
        openFreeEditor(); ready("freeLayout.cancel").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        waitUntil("no solution editor return") { !self.element("freeLayout.editor").exists }
        XCTAssertFalse(ready("snooker.strike").isEnabled)
        XCTAssertTrue((ready("snooker.layoutState").value as? String ?? "").contains("solutions=0"))
        let before = try businessSnapshot()
        try capture("snooker-no-solution", probing: ["snooker.layoutState", "snooker.strike"])
        openFreeEditor(); ready("freeLayout.customize").tap(); chooseFreeControl("shot.strike"); app.buttons["下移"].tap(); saveFreeLayout("R06 无解")
        XCTAssertEqual(try businessSnapshot(), before)
        XCTAssertFalse(ready("snooker.strike").isEnabled)
        try capture("snooker-no-solution-saved", probing: ["snooker.layoutState", "snooker.strike", "controlLayout.geometry"])
        XCTAssertEqual(rows.count, 2)
    }

    private func launchQuiz(_ page: String, premium: Bool = true) {
        app?.terminate()
        XCUIDevice.shared.orientation = ProcessInfo.processInfo.environment["LAYOUT_ORIENTATION"] == "portrait" ? .portrait : .landscapeLeft
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES",
            "-forcePremium", "-v50.inMemoryStore", "-v51.followSystemAppearance", "-appearanceMode", "system", "-dailyLayout.probe", "-3dDrag.probe",
            "-dailyInteraction.sharedPage=" + page]
        if !premium { app.launchArguments += ["-forceNonPremium", "-w7.forceDailyLimitNear"] }
        app.launch()
        XCTAssertFalse(element("controlLayout.open").exists)
        ready(page.hasPrefix("aimpoint") ? "aimPointTraining.start" : "angleTraining.start").tap()
        _ = ready(page.hasPrefix("aimpoint") ? "aimPointTraining.settings" : "angleTraining.settings")
        let portrait = ProcessInfo.processInfo.environment["LAYOUT_ORIENTATION"] == "portrait"
        XCUIDevice.shared.orientation = portrait ? .portrait : .landscapeLeft
        waitUntil("quiz orientation") {
            let frame = self.app.windows.firstMatch.frame
            return portrait ? frame.height > frame.width : frame.width > frame.height
        }
        openFreeEditor(); ready("freeLayout.cancel").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        waitUntil("quiz editor settled") { !self.element("freeLayout.editor").exists }
    }
    func testAngleQuizLayoutsAndAnswer() throws {
        func tap(_ id: String) { ready(id).coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap() }
        func input(_ value: String) {
            XCTAssertTrue((ready("angleTraining.layoutState").value as? String ?? "").contains("input=\(value);"))
        }
        for page in (ProcessInfo.processInfo.environment["LAYOUT_PAGES"] ?? "anglequiz2d,anglequiz3d").split(separator: ",").map(String.init).filter({ $0.hasPrefix("anglequiz") }) {
            launchQuiz(page)
            let initial = try businessSnapshot(includeCamera: false)
            tap("angleTraining.primaryAction"); tap("angleKeypad.digit.3"); tap("angleKeypad.digit.0"); input("30")
            let inputState = try businessSnapshot(includeCamera: false), digit = ready("angleKeypad.digit.3").frame
            let neighbor = ready("angleKeypad.digit.1").frame
            openFreeEditor()
            for id in (0...9).map({ "angle.digit." + String($0) }) + ["angle.erase", "angle.submit", "angle.cancel"] {
                XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "freeLayout.select." + id).count, 1)
            }
            tap("freeLayout.select.angle.digit.3"); tap("freeLayout.larger"); tap("freeLayout.collapse")
            let key = ready("freeLayout.select.angle.digit.3")
            let origin = key.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
            origin.press(forDuration: 0.1, thenDragTo: origin.withOffset(.init(dx: -70, dy: -15)))
            XCTAssertLessThan(key.frame.midX, digit.midX - 50)
            try capture(page + "-keyboard-preview")
            tap("freeLayout.collapse"); tap("freeLayout.cancel")
            XCTAssertEqual(try businessSnapshot(includeCamera: false), inputState)
            XCTAssertEqual(ready("angleKeypad.digit.3").frame, digit)
            openFreeEditor(); tap("freeLayout.select.angle.digit.3"); tap("freeLayout.larger")
            let saved = ready("freeLayout.select.angle.digit.3").frame
            saveFreeLayout("本页数字 " + page)
            XCTAssertEqual(try businessSnapshot(includeCamera: false), inputState)
            XCTAssertEqual(ready("angleKeypad.digit.3").frame.width, saved.width, accuracy: 1)
            XCTAssertEqual(ready("angleKeypad.digit.1").frame, neighbor)
            tap("angleKeypad.erase"); input("3"); tap("angleKeypad.erase"); input("")
            for number in 0...9 { tap("angleKeypad.digit." + String(number)); input(String(number)); tap("angleKeypad.erase"); input("") }
            tap("angleKeypad.cancel")
            XCTAssertTrue((ready("angleTraining.layoutState").value as? String ?? "").contains("answers=0"))
            tap("angleTraining.primaryAction"); tap("angleKeypad.digit.3"); tap("angleKeypad.digit.0"); input("30")
            tap("angleKeypad.submit")
            waitUntil("single answer recorded") { (self.element("angleTraining.layoutState").value as? String ?? "").contains("answers=1") }
            let result = try businessSnapshot(includeCamera: false)
            openFreeEditor(); tap("freeLayout.select.angle.next"); tap("freeLayout.larger"); tap("freeLayout.cancel")
            XCTAssertEqual(try businessSnapshot(includeCamera: false), result)
            try capture(page + "-result")
            tap("angleTraining.primaryAction")
            waitUntil("next question") { (self.element("angleTraining.layoutState").value as? String ?? "").contains("index=1") }
            XCTAssertNotEqual(try businessSnapshot(includeCamera: false), initial)
            tap("angleTraining.settings"); tap("angleTraining.finish"); _ = ready("training.summary")
            try capture(page + "-summary")
        }
    }

    func testAimPointQuizLayoutsAndAnswer() throws {
        func tap(_ id: String) { ready(id).coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap() }
        for page in (ProcessInfo.processInfo.environment["LAYOUT_PAGES"] ?? "aimpoint2d,aimpoint3d").split(separator: ",").map(String.init).filter({ $0.hasPrefix("aimpoint") }) {
            launchQuiz(page)
            let initial = try businessSnapshot(includeCamera: false), original = ready("aimPointTraining.submit").frame
            openFreeEditor(); tap("freeLayout.select.aimPoint.submit"); tap("freeLayout.larger")
            let saved = ready("freeLayout.select.aimPoint.submit").frame
            saveFreeLayout("本页提交 " + page)
            XCTAssertEqual(try businessSnapshot(includeCamera: false), initial)
            XCTAssertGreaterThan(saved.width, original.width)
            XCTAssertEqual(ready("aimPointTraining.submit").frame.width, saved.width, accuracy: 1)
            let wheel = ready("aimPointTraining.aimWheel")
            wheel.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.65)).press(forDuration: 0.2,
                thenDragTo: wheel.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.35)), withVelocity: XCUIGestureVelocity(rawValue: 90), thenHoldForDuration: 0.1)
            XCTAssertNotEqual(try businessSnapshot(includeCamera: false), initial)
            tap("aimPointTraining.angleHint")
            let assisted = try businessSnapshot(includeCamera: false)
            openFreeEditor(); tap("freeLayout.select.aimPoint.hint"); tap("freeLayout.larger"); tap("freeLayout.cancel")
            XCTAssertEqual(try businessSnapshot(includeCamera: false), assisted)
            try capture(page + "-aimed-cancelled")
            tap("aimPointTraining.submit")
            waitUntil("aim answer recorded once") { (self.element("aimPointTraining.layoutState").value as? String ?? "").contains("answers=1") }
            XCTAssertFalse(element("aimPointTraining.submit").exists)
            let result = try businessSnapshot(includeCamera: false)
            openFreeEditor(); tap("freeLayout.select.aimPoint.next"); tap("freeLayout.larger"); tap("freeLayout.cancel")
            XCTAssertEqual(try businessSnapshot(includeCamera: false), result)
            try capture(page + "-result")
            tap("aimPointTraining.next")
            waitUntil("next aim question") { (self.element("aimPointTraining.layoutState").value as? String ?? "").contains("phase=aiming") }
            XCTAssertNotEqual(try businessSnapshot(includeCamera: false), result)
            tap("aimPointTraining.settings"); tap("aimPointTraining.finish"); _ = ready("training.summary")
            try capture(page + "-summary")
        }
    }

    private func launchFormationLayout(_ page: String) {
        app?.terminate(); XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-hasCompletedOnboarding", "YES", "-forcePremium",
            "-v50.inMemoryStore", "-v51.followSystemAppearance", "-appearanceMode", "system", "-dailyLayout.probe", "-3dDrag.probe",
            "-deeplink.customFormation", "-customFormation.owner=layout-" + UUID().uuidString]
        app.launch()
        let new = ready("formation.new")
        for _ in 0..<5 where !new.isHittable { app.swipeUp() }
        new.tap(); _ = ready("paletteBall__1")
        XCUIDevice.shared.orientation = .landscapeLeft
        ready("paletteBall__1").tap()
        if page == "formationPractice" {
            ready("formation.edit.save").tap()
            let alert = app.alerts["保存模板"], field = alert.textFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 10)); field.tap()
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (field.value as? String ?? "").count) + "布局验证球形")
            alert.buttons.matching(identifier: "formation.save.confirm").firstMatch.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            ready("formation.start").tap(); _ = ready("freeplay.moreMenu")
        }
    }

    private func launchMatrixPage(_ page: String) {
        if page == "formationEditor" || page == "formationPractice" { launchFormationLayout(page); return }
        if page.hasPrefix("anglequiz") || page.hasPrefix("aimpoint") { launchQuiz(page); return }
        if ["angleDynamic", "separation", "cushion"].contains(page) { launchTeaching(page); teachingMode(page, "2D"); return }
        if ["shotSimulation", "snakePractice", "composer", "drillTryout", "freePlay"].contains(page) { launchCore(page); setCoreMode("2D"); return }
        app?.terminate()
        let portrait = ProcessInfo.processInfo.environment["LAYOUT_ORIENTATION"] == "portrait"
        XCUIDevice.shared.orientation = portrait ? .portrait : .landscapeLeft
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES",
            "-forcePremium", "-v50.inMemoryStore", "-v51.followSystemAppearance", "-appearanceMode", "system", "-dailyLayout.probe", "-3dDrag.probe"]
        let prefix: String
        switch page {
        case "dailyClearance":
            prefix = "freeplay"
            app.launchArguments += ["-deeplink.dailyClearance", "-dailyClearance.resetState", "-dailyClearance.resetHomeState",
                "-dailyClearance.fixture=selection", "-dailyClearance.fixtureSettled"]
        case "silu": prefix = "silu"; app.launchArguments += ["-deeplink.silu"]
        case "planThree": prefix = "planthree"; app.launchArguments += ["-deeplink.planThree", "-planThree.twoBall"]
        case "snooker": prefix = "snooker"; app.launchArguments += ["-deeplink.snooker", "-snooker.full"]
        case "bank": prefix = "bankshot"; app.launchArguments += ["-dailyInteraction.sharedPage=bank"]
        default: prefix = "reflection"; app.launchArguments += ["-dailyInteraction.sharedPage=diamond"]
        }
        app.launch()
        let more = prefix == "freeplay" ? "freeplay.moreMenu" : prefix + ".more"
        _ = ready(more)
        XCUIDevice.shared.orientation = portrait ? .portrait : .landscapeLeft
        waitUntil("matrix orientation") { let f = self.app.windows.firstMatch.frame; return portrait ? f.height > f.width : f.width > f.height }
        ready(more).coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        let camera = ready(prefix + ".cameraMode")
        if camera.value as? String != "2D" { camera.tap() }
        if prefix == "freeplay" { app.buttons["关闭菜单"].firstMatch.coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.5)).tap() }
        else { ready(prefix + ".dismissMenu").coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.5)).tap() }
    }

    func testAllEntryLayoutSmoke() throws {
        let pages = (ProcessInfo.processInfo.environment["LAYOUT_PAGES"] ?? "dailyClearance,freePlay,shotSimulation,snakePractice,composer,drillTryout,silu,planThree,snooker,bank,diamond,angleDynamic,separation,cushion,anglequiz2d,anglequiz3d,aimpoint2d,aimpoint3d").split(separator: ",").map(String.init)
        for page in pages {
            launchMatrixPage(page); resetLayoutPage()
            let teaching = ["angleDynamic", "separation", "cushion"].contains(page)
            let group = teaching ? "information" : "primary"
            let moveUp = teaching || page.hasPrefix("anglequiz") || page.hasPrefix("aimpoint")
            let probes = ["controlLayout.geometry", "controlLayout.revision", "dailyLayout.controlsProbe", "angleTraining.layoutState", "aimPointTraining.layoutState"]
            let state = try businessSnapshot(), y = groupY(group)
            try capture(page + "-default", probing: probes)
            openLayoutEditor()
            if teaching { ready("layoutEditor.group.information").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap() }
            revealEditor(moveUp ? "layoutEditor.up" : "layoutEditor.down").tap(); saveLayoutPage()
            XCTAssertEqual(try businessSnapshot(), state)
            XCTAssertEqual(groupY(group), y + (moveUp ? -8 : 8), accuracy: 0.6)
            XCTAssertTrue((ready("controlLayout.geometry").value as? String ?? "").contains("status=customized"))
            try capture(page + "-personal", probing: probes)
            resetLayoutPage()
            XCTAssertEqual(try businessSnapshot(), state)
            XCTAssertEqual(groupY(group), y, accuracy: 0.6)
            try capture(page + "-restored", probing: probes)
        }
        XCTAssertEqual(rows.count, pages.count * 3)
    }

    func testQuizCameraSlotAndTemporaryView() throws {
        launchQuiz("aimpoint3d"); resetLayoutPage()
        let state = try businessSnapshot()
        let camera = ready("shotCamera.thirdPerson"), original = camera.frame
        openLayoutEditor(); ready("layoutEditor.group.camera").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        revealEditor("layoutEditor.mirrorCamera").tap(); saveLayoutPage()
        XCTAssertEqual(try businessSnapshot(), state)
        XCTAssertLessThan(ready("shotCamera.thirdPerson").frame.midX, original.midX - 100)
        try capture("camera-mirrored", probing: ["controlLayout.geometry", "shotCamera.thirdPerson", "aimPointTraining.layoutState"])
        let revision = ready("controlLayout.revision").value as? String
        ready("shotCamera.temporaryTopDown").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        ready("aimPointTraining.settings").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        XCTAssertFalse(ready("controlLayout.open").isEnabled)
        ready("aimPointTraining.dismissMenu").coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.5)).tap()
        try capture("camera-temporary-busy", probing: ["controlLayout.geometry", "aimPointTraining.layoutState"])
        ready("shotCamera.temporaryTopDown").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        XCTAssertEqual(ready("controlLayout.revision").value as? String, revision)
        XCTAssertTrue((ready("aimPointTraining.layoutState").value as? String ?? "").contains("answers=0"))
        resetLayoutPage()
        XCTAssertEqual(ready("shotCamera.thirdPerson").frame.midX, original.midX, accuracy: 0.6)
        try capture("camera-restored", probing: ["controlLayout.geometry", "shotCamera.thirdPerson", "aimPointTraining.layoutState"])
    }

    func testFixedQuizRotationAndActualResize() throws {
        for page in (ProcessInfo.processInfo.environment["LAYOUT_PAGES"] ?? "anglequiz2d,aimpoint2d").split(separator: ",").map(String.init) {
            launchQuiz(page); resetLayoutPage()
            let prefix = page.hasPrefix("aimpoint") ? "aimPointTraining" : "angleTraining"
            openLayoutEditor(); revealEditor("layoutEditor.up").tap(); saveLayoutPage()
            let state = try businessSnapshot(includeCamera: false), revision = ready("controlLayout.revision").value as? String
            let original = app.windows.firstMatch.frame
            func sameState() throws {
                XCTAssertEqual(try businessSnapshot(includeCamera: false), state)
                XCTAssertEqual(ready("controlLayout.revision").value as? String, revision)
            }
            try capture(page + "-landscape-saved", probing: ["controlLayout.geometry", prefix + ".layoutState"])
            XCUIDevice.shared.orientation = .portrait
            waitUntil("actual portrait") { let f = self.app.windows.firstMatch.frame; return f.height > f.width }
            try sameState()
            XCTAssertTrue((ready("controlLayout.geometry").value as? String ?? "").contains("primaryTranslation=0.0,0.0"))
            try capture(page + "-portrait-default", probing: ["controlLayout.geometry", prefix + ".layoutState"])
            XCUIDevice.shared.orientation = .landscapeLeft
            waitUntil("actual landscape restored") { abs(self.app.windows.firstMatch.frame.width - original.width) < 1 }
            try sameState()
            XCTAssertTrue((ready("controlLayout.geometry").value as? String ?? "").contains("primaryTranslation=0.0,-8.0"))
            try capture(page + "-landscape-restored", probing: ["controlLayout.geometry", prefix + ".layoutState"])
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(.init(dx: original.width - 7, dy: original.height - 7)).press(forDuration: 0.5,
                thenDragTo: origin.withOffset(.init(dx: original.width * 0.7, dy: original.height * 0.78)))
            waitUntil("real resized quiz window") { let f = self.app.windows.firstMatch.frame; return f.width < original.width - 80 || f.height < original.height - 80 }
            try sameState()
            try capture(page + "-window-resized", probing: ["controlLayout.geometry", prefix + ".layoutState"])
            let window = app.windows.firstMatch, small = window.frame
            window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 52, dy: 32)).tap()
            Thread.sleep(forTimeInterval: 0.5)
            if abs(window.frame.width - small.width) < 1 { window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 104, dy: 32)).tap() }
            waitUntil("quiz window restored") { abs(self.app.windows.firstMatch.frame.width - original.width) < 1 }
            try sameState()
            XCTAssertTrue((ready("controlLayout.geometry").value as? String ?? "").contains("primaryTranslation=0.0,-8.0"))
            XCTAssertTrue(app.windows.firstMatch.frame.contains(ready(prefix + (page.hasPrefix("aimpoint") ? ".submit" : ".primaryAction")).frame))
            try capture(page + "-window-restored", probing: ["controlLayout.geometry", prefix + ".layoutState"])
        }
    }

    func testAimPointMovedDirectionAndCloseup() throws {
        for page in (ProcessInfo.processInfo.environment["LAYOUT_PAGES"] ?? "aimpoint2d,aimpoint3d").split(separator: ",").map(String.init).filter({ $0.hasPrefix("aimpoint") }) {
            launchQuiz(page); resetLayoutPage()
            ready("aimPointTraining.settings").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            if ready("menu.aimCloseup").value as? String != "已选" { ready("menu.aimCloseup").tap() }
            else { ready("aimPointTraining.dismissMenu").coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.5)).tap() }
            let state = try businessSnapshot(), y = ready("aimPointTraining.aimWheel").frame.minY
            openLayoutEditor(); ready("layoutEditor.group.direction").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            revealEditor("layoutEditor.down").tap()
            XCTAssertTrue(ready("layoutEditor.feedback").label.contains("已调整"))
            saveLayoutPage()
            XCTAssertEqual(try businessSnapshot(), state)
            XCTAssertEqual(ready("aimPointTraining.aimWheel").frame.minY, y + 8, accuracy: 0.6)
            try capture(page + "-direction-moved", probing: ["controlLayout.geometry", "aimPointTraining.aimWheel", "aimPointTraining.layoutState"])
            let wheel = ready("aimPointTraining.aimWheel"), start = ready("aimPointTraining.aimWheel").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.3, thenDragTo: start.withOffset(.init(dx: 0, dy: -3)),
                withVelocity: XCUIGestureVelocity(rawValue: 5), thenHoldForDuration: 3)
            XCTAssertNotEqual(try businessSnapshot(), state)
            XCTAssertTrue((ready("aimPointTraining.layoutState").value as? String ?? "").contains("answers=0"))
            XCTAssertTrue(wheel.isEnabled)
            waitUntil("closeup dismissed after release") { !self.element("aimCloseup.hud").exists }
            try capture(page + "-direction-released", probing: ["controlLayout.geometry", "aimPointTraining.aimWheel", "aimPointTraining.layoutState"])
        }
    }

    func testEmbeddedPreviewDoesNotConsumeLayout() throws {
        launchCore("freePlay"); setCoreMode("2D"); resetLayoutPage()
        openLayoutEditor(); revealEditor("layoutEditor.down").tap(); saveLayoutPage()
        let savedRevision = ready("controlLayout.revision").value as? String
        app.terminate(); XCUIDevice.shared.orientation = .portrait
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES",
            "-forcePremium", "-v50.inMemoryStore", "-v51.followSystemAppearance", "-appearanceMode", "system", "-dailyLayout.probe", "-3dDrag.probe", "-deeplink.drillDetail=drill_c001"]
        app.launch(); _ = ready("drillScene.cameraMode")
        XCTAssertFalse(element("controlLayout.geometry").exists)
        XCTAssertFalse(element("controlLayout.open").exists)
        try capture("embedded-detail-original", probing: ["drillScene.cameraMode", "drillScene.renderViewport", "drillPlayButton"])
        let before = ready("drillScene.cameraMode").value as? String
        ready("drillScene.cameraMode").tap()
        XCTAssertNotEqual(ready("drillScene.cameraMode").value as? String, before)
        XCTAssertFalse(element("controlLayout.geometry").exists)
        if element("drillPlayButton").exists { ready("drillPlayButton").tap() }
        try capture("embedded-detail-camera-playback", probing: ["drillScene.cameraMode", "drillScene.renderViewport", "drillPlayButton"])
        launchCore("freePlay"); setCoreMode("2D")
        XCTAssertEqual(ready("controlLayout.revision").value as? String, savedRevision)
        XCTAssertTrue((ready("controlLayout.geometry").value as? String ?? "").contains("primaryTranslation=0.0,8.0"))
        try capture("embedded-return-personal-preserved", probing: ["controlLayout.geometry", "controlLayout.revision"])
        resetLayoutPage()
    }

    func testFixedQuizQuotaAfterLayout() throws {
        for page in (ProcessInfo.processInfo.environment["LAYOUT_PAGES"] ?? "anglequiz2d,anglequiz3d").split(separator: ",").map(String.init).filter({ $0.hasPrefix("anglequiz") }) {
            let prefix = page.hasPrefix("aimpoint") ? "aimPointTraining" : "angleTraining"
            launchQuiz(page, premium: false); resetLayoutPage()
            let before = try businessSnapshot()
            openLayoutEditor(); revealEditor("layoutEditor.up").tap(); saveLayoutPage()
            XCTAssertEqual(try businessSnapshot(), before)
            if page.hasPrefix("aimpoint") { ready(prefix + ".submit").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap() }
            else {
                ready(prefix + ".primaryAction").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
                ready("3").tap(); ready("0").tap(); app.buttons["提交"].tap()
            }
            waitUntil("quota answer recorded once") { (self.element(prefix + ".layoutState").value as? String ?? "").contains("answers=1") }
            ready(prefix + ".settings").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            XCTAssertFalse(ready("controlLayout.open").isEnabled)
            ready(prefix + ".dismissMenu").coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.5)).tap()
            let action = ready(prefix + (page.hasPrefix("aimpoint") ? ".next" : ".primaryAction"))
            XCTAssertEqual(action.label, "总结")
            try capture(page + "-quota-result", probing: [prefix + ".layoutState", action.identifier])
            action.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); _ = ready("training.summary")
            try capture(page + "-quota-summary", probing: ["training.summary", "training.summaryClose"])
        }
    }

    func testFixedQuizTemplateSharing() throws {
        let family = ProcessInfo.processInfo.environment["LAYOUT_PAGES"] ?? "anglequiz"
        let twoD = family + "2d", threeD = family + "3d"
        let prefix = family == "anglequiz" ? "angleTraining" : "aimPointTraining"
        let name = "答题" + UUID().uuidString.prefix(6)
        let probes = ["controlLayout.geometry", prefix + ".layoutState"]
        func apply() {
            openLayoutEditor(); revealEditor("layoutEditor.templates").tap(); app.buttons[name].firstMatch.tap(); saveLayoutPage()
        }
        launchQuiz(threeD); resetLayoutPage(); let threeY = groupY("primary")
        launchQuiz(twoD); resetLayoutPage(); let twoY = groupY("primary")
        openLayoutEditor(); revealEditor("layoutEditor.up").tap(); saveLayoutPage()
        XCTAssertEqual(groupY("primary"), twoY - 8, accuracy: 0.6)
        try capture("fixed-two-local", probing: probes)
        launchQuiz(threeD); XCTAssertEqual(groupY("primary"), threeY, accuracy: 0.6)
        try capture("fixed-three-independent", probing: probes)
        launchQuiz(twoD); XCTAssertEqual(groupY("primary"), twoY - 8, accuracy: 0.6)
        openLayoutEditor(); ready("layoutEditor.save").tap(); ready("layoutEditor.saveAs").tap()
        let field = app.alerts.textFields.firstMatch; XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap(); field.typeText(name); app.alerts.buttons["保存并应用"].tap()
        waitUntil("quiz template saved") { !self.element("layoutEditor").exists }
        launchQuiz(threeD); apply(); XCTAssertEqual(groupY("primary"), threeY - 8, accuracy: 0.6)
        try capture("fixed-three-shared", probing: probes)
        launchQuiz(twoD); openLayoutEditor(); revealEditor("layoutEditor.up").tap()
        ready("layoutEditor.save").tap(); ready("layoutEditor.promote").tap()
        let confirm = ready("layoutPromotion.confirm")
        for _ in 0..<8 where !confirm.isHittable { app.swipeUp() }; confirm.tap()
        waitUntil("quiz template updated") { !self.element("layoutEditor").exists }
        launchQuiz(threeD); XCTAssertEqual(groupY("primary"), threeY - 16, accuracy: 0.6)
        try capture("fixed-three-followed-update", probing: probes)
        openLayoutEditor(); revealEditor("layoutEditor.layer").tap(); app.buttons["仅3D"].tap()
        revealEditor("layoutEditor.down").tap(); saveLayoutPage()
        XCTAssertEqual(groupY("primary"), threeY - 8, accuracy: 0.6)
        try capture("fixed-three-mode-override", probing: probes)
        launchQuiz(twoD); XCTAssertEqual(groupY("primary"), twoY - 16, accuracy: 0.6)
        try capture("fixed-two-unaffected", probing: probes)
        launchQuiz(threeD); XCTAssertEqual(groupY("primary"), threeY - 8, accuracy: 0.6)
        openLayoutEditor(); revealEditor("layoutEditor.layer").tap(); app.buttons["仅3D"].tap()
        revealEditor("layoutEditor.restoreGroup").tap(); saveLayoutPage()
        XCTAssertEqual(groupY("primary"), threeY - 16, accuracy: 0.6)
        try capture("fixed-three-restored-layer", probing: probes)
        resetLayoutPage(); XCTAssertEqual(groupY("primary"), threeY, accuracy: 0.6)
        try capture("fixed-three-default", probing: probes)
    }

    private func launchTeaching(_ page: String) {
        app?.terminate()
        XCUIDevice.shared.orientation = ProcessInfo.processInfo.environment["LAYOUT_ORIENTATION"] == "portrait" ? .portrait : .landscapeLeft
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES",
            "-forcePremium", "-v50.inMemoryStore", "-v51.followSystemAppearance", "-appearanceMode", "system", "-dailyLayout.probe", "-3dDrag.probe",
            "-dailyInteraction.sharedPage=" + page]
        app.launch(); _ = ready(teachingPrefix(page) + ".more")
    }
    private func teachingPrefix(_ page: String) -> String {
        ["angleDynamic": "angleDynamic", "separation": "separationAngleAtlas", "cushion": "cushionEnglishAtlas"][page]!
    }
    private func teachingMode(_ page: String, _ value: String) {
        let prefix = teachingPrefix(page)
        ready(prefix + ".more").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        if ready(prefix + ".cameraMode").value as? String != value { ready(prefix + ".cameraMode").tap() }
        ready(prefix + ".dismissMenu").coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.5)).tap()
    }
    private func groupY(_ group: String) -> Double {
        let raw = ready("controlLayout.geometry").value as? String ?? ""
        let token = raw.split(separator: ";").first { $0.hasPrefix(group + "=") }!
        return Double(token.split(separator: "=")[1].split(separator: ",")[1])!
    }
    private func dragTeachingCueAndChoosePocket() throws {
        func sceneData() throws -> [String: Any] {
            let raw = try XCTUnwrap(ready("table.scene").value as? String)
            return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        }
        let payload = try sceneData()
        let balls = try XCTUnwrap(payload["balls"] as? [[String: Any]])
        let cue = try XCTUnwrap(balls.first { $0["key"] as? String == "cueBall" })
        let before = try XCTUnwrap(cue["world"] as? [Double])
        let point = try XCTUnwrap(cue["screen"] as? [Double])
        let table = ready("table.scene")
        let start = table.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: point[0], dy: point[1]))
        // Cross the existing finger-clearance dead zone before expecting world movement.
        start.press(forDuration: 0.15, thenDragTo: start.withOffset(.init(dx: -90, dy: 70)),
            withVelocity: XCUIGestureVelocity(rawValue: 100), thenHoldForDuration: 0.2)
        let pockets = try XCTUnwrap(payload["pockets"] as? [[String: Any]])
        let pocket = try XCTUnwrap(pockets.first { ($0["index"] as? Int) == 3 })
        let pocketPoint = try XCTUnwrap(pocket["screen"] as? [Double])
        table.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: pocketPoint[0], dy: pocketPoint[1])).tap()
        openFreeEditor(); ready("freeLayout.cancel").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        waitUntil("scene interaction settled") { !self.element("freeLayout.editor").exists }
        let afterData = try sceneData()
        let traceName = ["angleDynamic", "separationAngleAtlas", "cushionEnglishAtlas"].first { element($0 + ".layoutState").exists }!
        try JSONSerialization.data(withJSONObject: afterData, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent(traceName + "-drag-raw.json"))
        let afterBalls = try XCTUnwrap(afterData["balls"] as? [[String: Any]])
        let after = try XCTUnwrap(afterBalls.first { $0["key"] as? String == "cueBall" }?["world"] as? [Double])
        XCTAssertGreaterThan(hypot(after[0] - before[0], after[2] - before[2]), 0.005)
        let prefix = ["angleDynamic", "separationAngleAtlas", "cushionEnglishAtlas"].first { element($0 + ".layoutState").exists }!
        XCTAssertTrue((ready(prefix + ".layoutState").value as? String ?? "").contains("pocket=3"))
    }
    func testTeachingCameraPreviewIsIndependent() throws {
        launchTeaching("angleDynamic"); teachingMode("angleDynamic", "2D"); resetLayoutPage()
        let before = try businessSnapshot()
        openLayoutEditor()
        XCTAssertFalse(element("layoutEditor.group.camera").exists)
        try capture("teaching-editor-2D", probing: ["layoutEditor.group.information", "layoutEditor.group.camera"])
        revealEditor("layoutEditor.mode")
        app.segmentedControls["layoutEditor.mode"].buttons["3D"].tap()
        XCTAssertTrue(ready("layoutEditor.group.camera").exists)
        XCTAssertFalse(element("layoutEditor.group.instrument").exists)
        try capture("teaching-editor-3D", probing: ["layoutEditor.group.information", "layoutEditor.group.camera"])
        ready("layoutEditor.cancel").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        waitUntil("camera preview closed") { !self.element("layoutEditor").exists }
        XCTAssertEqual(try businessSnapshot(), before)
        XCTAssertEqual(rows.count, 2)
    }

    private func adjustTeachingSpin() {
        ready("shotStage.spinEntry").tap()
        let disc = ready("spinPad.disc")
        disc.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).press(forDuration: 0.15,
            thenDragTo: disc.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.02)),
            withVelocity: XCUIGestureVelocity(rawValue: 100), thenHoldForDuration: 0.2)
        let raw = ready("cushionEnglishAtlas.layoutState").value as? String ?? ""
        let value = raw.split(separator: " ").first { $0.hasPrefix("spinY=") }.flatMap { Double($0.dropFirst(6)) }
        XCTAssertGreaterThan(abs(value ?? 0), 0.001, raw)
    }
    func testTeachingSceneDragAndPocket() throws {
        for page in ["angleDynamic", "separation", "cushion"] {
            launchTeaching(page); teachingMode(page, "2D"); resetLayoutPage()
            let prefix = teachingPrefix(page)
            if page == "cushion" {
                adjustTeachingSpin()
                try capture("cushion-spin-panel", probing: ["spinPad.disc", prefix + ".layoutState"])
                ready("关闭打点").coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.5)).tap()
                openLayoutEditor(); ready("layoutEditor.cancel").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
                waitUntil("spin settled") { !self.element("layoutEditor").exists }
            }
            try capture(page + "-drag-before", probing: ["table.scene", prefix + ".layoutState"])
            try dragTeachingCueAndChoosePocket()
            let state = try businessSnapshot()
            openLayoutEditor(); revealEditor("layoutEditor.up").tap(); saveLayoutPage()
            XCTAssertEqual(try businessSnapshot(), state)
            try capture(page + "-drag-preserved", probing: ["controlLayout.geometry", "table.scene", prefix + ".layoutState"])
        }
        XCTAssertEqual(rows.count, 7)
    }

    func testTeachingTemplateSharingAndSceneInteraction() throws {
        let name = "教学" + UUID().uuidString.prefix(6)
        let probes = ["controlLayout.geometry", "table.scene", "angleDynamic.layoutState", "separationAngleAtlas.layoutState", "cushionEnglishAtlas.layoutState"]
        func launch(_ page: String) { launchTeaching(page); teachingMode(page, "2D") }
        func apply() {
            openLayoutEditor(); revealEditor("layoutEditor.templates").tap(); app.buttons[name].firstMatch.tap(); saveLayoutPage()
        }
        launch("angleDynamic"); resetLayoutPage()
        openLayoutEditor(); revealEditor("layoutEditor.up").tap()
        ready("layoutEditor.save").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); ready("layoutEditor.saveAs").tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3)); field.tap(); field.typeText(name)
        app.alerts.buttons["保存并应用"].tap()
        waitUntil("created teaching template") { !self.element("layoutEditor").exists }
        try capture("teaching-template-created", probing: probes)
        launch("separation"); resetLayoutPage(); let separationY = groupY("information")
        apply(); XCTAssertEqual(groupY("information"), separationY - 8, accuracy: 0.5)
        openLayoutEditor(); revealEditor("layoutEditor.down").tap(); saveLayoutPage()
        XCTAssertEqual(groupY("information"), separationY, accuracy: 0.5)
        try capture("teaching-local-override", probing: probes)
        launch("cushion"); resetLayoutPage(); let cushionY = groupY("information")
        apply(); XCTAssertEqual(groupY("information"), cushionY - 8, accuracy: 0.5)
        try capture("teaching-shared-applied", probing: probes)
        try dragTeachingCueAndChoosePocket()
        let state = try businessSnapshot()
        openLayoutEditor(); ready("layoutEditor.cancel").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        waitUntil("scene editor preserved") { !self.element("layoutEditor").exists }
        XCTAssertEqual(try businessSnapshot(), state)
        try capture("teaching-drag-pocket-preserved", probing: probes)
        launch("angleDynamic")
        openLayoutEditor(); revealEditor("layoutEditor.up").tap()
        ready("layoutEditor.save").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); ready("layoutEditor.promote").tap()
        let confirm = ready("layoutPromotion.confirm")
        for _ in 0..<8 where !confirm.isHittable { app.swipeUp() }; confirm.tap()
        waitUntil("teaching promoted") { !self.element("layoutEditor").exists }
        try capture("teaching-template-updated", probing: probes)
        launch("cushion"); XCTAssertEqual(groupY("information"), cushionY - 16, accuracy: 0.5)
        try capture("teaching-shared-relaunched", probing: probes)
        launch("separation"); XCTAssertEqual(groupY("information"), separationY, accuracy: 0.5)
        openLayoutEditor(); revealEditor("layoutEditor.restoreGroup").tap(); saveLayoutPage()
        XCTAssertEqual(groupY("information"), separationY - 16, accuracy: 0.5)
        try capture("teaching-restored-following", probing: probes)
        resetLayoutPage(); XCTAssertEqual(groupY("information"), separationY, accuracy: 0.5)
        try capture("teaching-restored-default", probing: probes)
        XCTAssertEqual(rows.count, 8)
    }

    func testTeachingPageLayouts() throws {
        let pages = ProcessInfo.processInfo.environment["LAYOUT_PAGES"]?.split(separator: ",").map(String.init)
            ?? ["angleDynamic", "separation", "cushion"]
        for page in pages {
            let prefix = teachingPrefix(page)
            launchTeaching(page)
            let probes = ["table.scene", prefix + ".layoutState", prefix + ".metrics", prefix + ".trackCount",
                          "shotStage.spinEntry", "shotStage.powerBar", "dailyClearance.observeTable", prefix + ".spinLegend.0"]
            for mode in ["2D", "3D"] {
                teachingMode(page, mode); openFreeEditor(); ready("freeLayout.default").tap()
                let before = try businessSnapshot(), stage = ready("table.scene").frame
                try capture(page + "-" + mode + "-default", probing: probes)
                if page == "angleDynamic" && mode == "2D" {
                    openFreeEditor()
                    XCTAssertTrue(ready("freeLayout.noControls").exists)
                    XCTAssertFalse(ready("freeLayout.customize").isEnabled)
                    try capture(page + "-2D-no-controls", probing: ["freeLayout.noControls", "freeLayout.customize"])
                    ready("freeLayout.cancel").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
                    waitUntil("empty teaching editor closed") { !self.element("freeLayout.editor").exists }
                    XCTAssertEqual(try businessSnapshot(), before)
                    try capture(page + "-2D-unchanged", probing: probes)
                    continue
                }
                let control = page == "angleDynamic" ? "camera.overview" : page + ".legend.0"
                let targetID = page == "angleDynamic" ? "dailyClearance.observeTable" : prefix + ".spinLegend.0"
                let neighborID = page == "angleDynamic" ? "shotCamera.thirdPerson" : prefix + ".spinLegend.1"
                let original = ready(targetID).frame, neighbor = ready(neighborID).frame
                openFreeEditor(); ready("freeLayout.customize").tap()
                XCTAssertFalse(element("layoutEditor.mode").exists)
                let ids = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "freeLayout.select."))
                    .allElementsBoundByIndex.map(\.identifier)
                XCTAssertEqual(ids.count, Set(ids).count)
                XCTAssertEqual(ids.count, (page == "angleDynamic" ? 0 : 10) + (mode == "3D" ? 4 : 0))
                if page != "angleDynamic" {
                    for index in 0..<8 { XCTAssertTrue(ids.contains("freeLayout.select." + page + ".legend." + String(index))) }
                }
                chooseFreeControl(control); app.buttons["右移"].tap(); app.buttons["放大"].tap()
                let preview = ready("freeLayout.select." + control).frame
                XCTAssertEqual(preview.midX, original.midX + 5, accuracy: 2)
                XCTAssertEqual(preview.width, original.width * 1.05, accuracy: 2)
                ready("freeLayout.collapse").tap()
                try capture(page + "-" + mode + "-preview", probing: ["freeLayout.collapse"])
                ready("freeLayout.collapse").tap(); saveFreeLayout("R07 " + page)
                XCTAssertEqual(try businessSnapshot(), before)
                XCTAssertEqual(ready("table.scene").frame, stage)
                XCTAssertEqual(ready(targetID).frame.midX, preview.midX, accuracy: 2)
                XCTAssertEqual(ready(targetID).frame.width, preview.width, accuracy: 2)
                XCTAssertEqual(ready(neighborID).frame, neighbor)
                openFreeEditor(); ready("freeLayout.current").tap(); chooseFreeControl(control); app.buttons["下移"].tap()
                XCUIDevice.shared.press(.home); app.activate()
                ready("freeLayout.cancel").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
                waitUntil("teaching draft cancelled") { !self.element("freeLayout.editor").exists }
                XCTAssertEqual(try businessSnapshot(), before)
                XCTAssertEqual(ready(targetID).frame.midY, preview.midY, accuracy: 2)
                try capture(page + "-" + mode + "-saved", probing: probes)
            }
            teachingMode(page, "2D")
            if page == "angleDynamic" {
                ready(prefix + ".more").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
                ready(prefix + ".aimLine").tap()
            } else {
                ready(prefix + ".spinLegend.0").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
                XCTAssertEqual(ready(prefix + ".trackCount").label, "7/8")
                let power = ready("shotStage.powerBar")
                power.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.6)).press(forDuration: 0.1,
                    thenDragTo: power.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.45)))
                if page == "separation" { XCTAssertFalse(ready("shotStage.spinEntry").isEnabled) }
                if page == "cushion" {
                    adjustTeachingSpin()
                    ready("关闭打点").coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.5)).tap()
                }
            }
            try dragTeachingCueAndChoosePocket()
            let parameters = try businessSnapshot()
            try capture(page + "-parameters-and-drag", probing: probes)
            openFreeEditor(); ready("freeLayout.default").tap()
            XCTAssertEqual(try businessSnapshot(), parameters)
            try capture(page + "-restored", probing: probes)
        }
        XCTAssertEqual(rows.count, pages.count * 8)
    }

    func testPlanningPageLayouts() throws {
        let pages = ProcessInfo.processInfo.environment["LAYOUT_PAGES"]?.split(separator: ",").map(String.init)
            ?? ["planThree", "snooker", "bank", "diamond"]
        let portrait = ProcessInfo.processInfo.environment["LAYOUT_ORIENTATION"] == "portrait"
        for page in pages {
            let prefix = ["planThree": "planthree", "snooker": "snooker", "bank": "bankshot", "diamond": "reflection"][page]!
            app?.terminate(); XCUIDevice.shared.orientation = portrait ? .portrait : .landscapeLeft
            app = XCUIApplication()
            app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES",
                "-forcePremium", "-v50.inMemoryStore", "-appearanceMode", "dark", "-dailyLayout.probe", "-3dDrag.probe"]
            if page == "planThree" { app.launchArguments += ["-deeplink.planThree", "-planThree.twoBall"] }
            else if page == "snooker" { app.launchArguments += ["-deeplink.snooker", "-snooker.full"] }
            else { app.launchArguments += ["-dailyInteraction.sharedPage=" + page] }
            app.launch(); _ = ready(prefix + ".more")
            waitUntil("planning orientation") { let f = self.app.windows.firstMatch.frame; return portrait ? f.height > f.width : f.width > f.height }
            func mode(_ value: String) {
                ready(prefix + ".more").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
                let camera = ready(prefix + ".cameraMode")
                if camera.value as? String != value { camera.tap() }
                ready(prefix + ".dismissMenu").coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.5)).tap()
            }
            let undoID = (page == "bank" || page == "diamond") ? "solver.undo" : prefix + ".undo"
            let replayID = (page == "bank" || page == "diamond") ? "solver.replay" : prefix + ".replay"
            let probes = ["table.scene", prefix + ".layoutState", undoID, replayID, prefix + ".strike", "solver.nextSolution", "shotStage.powerBar"]
            for viewMode in ["2D", "3D"] {
                mode(viewMode); openFreeEditor(); ready("freeLayout.default").tap()
                let before = try businessSnapshot(), original = ready(undoID).frame, neighbor = ready(replayID).frame
                try capture(page + "-" + viewMode + "-default", probing: probes)
                openFreeEditor(); ready("freeLayout.customize").tap()
                var controls = ["shot.undo", "shot.replay", "shot.power", "shot.strike", "planning.nextSolution"]
                if element("freeLayout.select.shot.spin").exists { controls.append("shot.spin") }
                if page == "bank" || page == "diamond" { controls += ["solver.mode", "solver.cushions"] }
                else if page == "snooker" { controls += ["defense.targetTool", "defense.clearSelection", "planning.solve"] }
                else { controls += ["planning.roles", "planning.constraintTool", "planning.clearConstraint", "planning.solve"] }
                for id in controls { chooseFreeControl(id) }
                chooseFreeControl("shot.undo"); app.buttons["右移"].tap(); app.buttons["放大"].tap()
                let preview = ready("freeLayout.select.shot.undo").frame
                XCTAssertEqual(preview.midX, original.midX + 5, accuracy: 2)
                XCTAssertEqual(preview.width, original.width * 1.05, accuracy: 2)
                ready("freeLayout.collapse").tap()
                try capture(page + "-" + viewMode + "-preview", probing: ["freeLayout.collapse"])
                ready("freeLayout.collapse").tap(); saveFreeLayout("R06 " + page)
                XCTAssertEqual(try businessSnapshot(), before)
                XCTAssertEqual(ready(undoID).frame.midX, preview.midX, accuracy: 2)
                XCTAssertEqual(ready(undoID).frame.width, preview.width, accuracy: 2)
                XCTAssertEqual(ready(replayID).frame, neighbor)
                openFreeEditor(); ready("freeLayout.current").tap(); chooseFreeControl("shot.undo")
                app.buttons["下移"].tap(); XCUIDevice.shared.press(.home); app.activate()
                ready("freeLayout.cancel").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
                waitUntil("planning editor cancelled after foreground") { !self.element("freeLayout.editor").exists }
                XCTAssertEqual(try businessSnapshot(), before)
                XCTAssertEqual(ready(undoID).frame.midY, preview.midY, accuracy: 2)
                try capture(page + "-" + viewMode + "-saved", probing: probes)
            }
            mode("2D")
            if page == "bank" || page == "diamond" {
                ready("solver.cushions").tap(); app.buttons["1库"].firstMatch.tap()
                XCTAssertTrue(ready("solver.cushions").label.contains("1库"))
                openFreeEditor(); ready("freeLayout.cancel").tap()
                XCTAssertTrue(ready("solver.cushions").label.contains("1库"))
                ready("solver.cushions").tap(); app.buttons["自动"].firstMatch.tap()
                waitUntil("automatic solution settled", timeout: 90) { self.element(prefix + ".strike").isEnabled }
                let power = ready("shotStage.powerBar")
                power.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.65)).press(forDuration: 0.1,
                    thenDragTo: power.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.4)))
                waitUntil("solver microadjustment settled", timeout: 90) { self.element(prefix + ".strike").isEnabled }
                let adjusted = try businessSnapshot()
                openFreeEditor()
                ready("freeLayout.cancel").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
                waitUntil("solver draft returned") { !self.element("freeLayout.editor").exists }
                XCTAssertEqual(try businessSnapshot(), adjusted)
                ready("solver.mode").tap()
                let free = try businessSnapshot()
                openFreeEditor(); ready("freeLayout.cancel").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
                waitUntil("free editor returned") { !self.element("freeLayout.editor").exists }
                XCTAssertEqual(try businessSnapshot(), free)
                XCTAssertTrue(ready("shotStage.aimWheel").exists)
            } else {
                func tapScene(_ array: String, key: String, value: String) throws {
                    let table = ready("table.scene")
                    let raw = try XCTUnwrap(table.value as? String)
                    let data = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
                    let candidates = try XCTUnwrap(data[array] as? [[String: Any]])
                    let item = try XCTUnwrap(candidates.first { String(describing: $0[key]!) == value })
                    let point = try XCTUnwrap(item["screen"] as? [Double])
                    table.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: point[0], dy: point[1])).tap()
                }
                if page == "planThree" {
                    ready("planthree.roles").tap(); ready("planthree.role.0").tap()
                    try tapScene("balls", key: "key", value: "_1")
                    ready("planthree.roles").tap(); ready("planthree.role.1").tap()
                    try tapScene("pockets", key: "index", value: "1")
                    ready("planthree.tool").tap(); app.buttons["落区"].tap()
                    let table = ready("table.scene")
                    table.coordinate(withNormalizedOffset: .init(dx: 0.35, dy: 0.45)).press(forDuration: 0.1,
                        thenDragTo: table.coordinate(withNormalizedOffset: .init(dx: 0.56, dy: 0.72)))
                    openFreeEditor(); ready("freeLayout.cancel").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
                    ready("planthree.clearConstraint").tap()
                    ready("planthree.tool").tap(); app.buttons["摆球"].tap()
                } else {
                    ready("snooker.tool").tap(); app.buttons["目标球"].tap()
                    try tapScene("balls", key: "key", value: "_1")
                }
                let solve = ready("solver.solve")
                waitUntil("solve enabled", timeout: 90) { solve.isEnabled }; solve.tap()
                waitUntil("solution completed", timeout: 120) { self.element(prefix + ".strike").exists && self.element(prefix + ".strike").isEnabled }
                let power = ready("shotStage.powerBar")
                power.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.65)).press(forDuration: 0.1,
                    thenDragTo: power.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.4)))
                let adjusted = try businessSnapshot()
                openFreeEditor(); ready("freeLayout.cancel").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
                waitUntil("adjusted editor returned") { !self.element("freeLayout.editor").exists }
                XCTAssertEqual(try businessSnapshot(), adjusted)
            }
            if element("solver.nextSolution").exists && element("solver.nextSolution").isEnabled {
                let old = ready("solver.nextSolution").label
                ready("solver.nextSolution").tap()
                waitUntil("next solution selected", timeout: 90) { self.element("solver.nextSolution").label != old }
            }
            waitUntil("shot prediction ready", timeout: 90) { self.element(prefix + ".strike").isEnabled }
            ready(prefix + ".strike").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            waitUntil("real shot settled", timeout: 90) { self.element(undoID).exists && self.element(undoID).isEnabled }
            XCTAssertTrue(ready(replayID).isEnabled)
            ready(replayID).tap()
            waitUntil("real replay settled", timeout: 90) { self.element(undoID).isEnabled }
            ready(undoID).coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            try capture(page + "-real-actions", probing: probes)
        }
        XCTAssertEqual(rows.count, pages.count * 7)
    }

    func testTryoutEntryState() throws {
        launchCore("drillTryout")
        try capture("tryout-entry", probing: ["dailyLayout.controlsProbe"])
        setCoreMode("2D")
        try capture("tryout-mode", probing: ["dailyLayout.controlsProbe"])
        resetLayoutPage()
        try capture("tryout-reset", probing: ["dailyLayout.controlsProbe"])
    }

    func testRemainingCorePageLayouts() throws {
        let pages = ProcessInfo.processInfo.environment["LAYOUT_PAGES"]?.split(separator: ",").map(String.init)
            ?? ["shotSimulation", "snakePractice", "composer", "drillTryout"]
        let probes = ["controlLayout.geometry", "dailyLayout.controlsProbe", "table.scene", "dailyClearance.strike", "dailyClearance.undo", "dailyClearance.playback"]
        for page in pages {
            launchCore(page); setCoreMode("2D"); resetLayoutPage()
            for mode in ["2D", "3D"] {
                setCoreMode(mode)
                let before = try businessSnapshot()
                let initialY = ready("dailyClearance.strike").frame.minY
                try capture(page + "-" + mode + "-default", probing: probes)
                openLayoutEditor()
                if mode == "3D" {
                    // Keep the 2D personal setting while writing the explicit 3D layer.
                    let scope = revealEditor("layoutEditor.layer")
                    scope.tap(); app.buttons["仅3D"].firstMatch.tap()
                }
                revealEditor("layoutEditor.down").tap()
                XCTAssertTrue(ready("layoutEditor.feedback").label.contains("已调整"))
                setEditorPreview(true)
                ready("layoutEditor.previewStrike").tap()
                setEditorPreview(false)
                saveLayoutPage()
                waitUntil("saved primary offset") { abs(self.element("dailyClearance.strike").frame.minY - initialY - 8) < 0.5 }
                XCTAssertEqual(try businessSnapshot(), before)
                try capture(page + "-" + mode + "-personal", probing: probes)
                openLayoutEditor()
                if mode == "3D" { revealEditor("layoutEditor.layer").tap(); app.buttons["仅3D"].firstMatch.tap() }
                revealEditor("layoutEditor.up").tap()
                XCTAssertTrue(ready("layoutEditor.feedback").label.contains("已调整"))
                XCUIDevice.shared.press(.home); app.activate(); _ = ready("layoutEditor")
                ready("layoutEditor.cancel").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
                ready("放弃修改").tap()
                waitUntil("cancel returns to same host") { !self.element("layoutEditor").exists }
                XCTAssertEqual(try businessSnapshot(), before)
            }
            // Real page-specific actions after editing, using the relocated original controls.
            if page == "snakePractice" {
                XCTAssertTrue((ready("dailyLayout.controlsProbe").value as? String ?? "").contains("snakeCanStrike=true"))
                ready("snake.restart").tap(); ready("snake.restart.cancel").tap()
                ready("dailyClearance.strike").tap()
                waitUntil("snake shot finished", timeout: 60) { self.element("snake.failure.retry").exists || self.element("dailyClearance.strike").isEnabled }
            } else if page == "drillTryout" {
                XCTAssertEqual(ready("dailyClearance.playback").label, "下一杆")
                ready("dailyClearance.playback").tap()
                waitUntil("next sequence step", timeout: 45) { (self.element("dailyLayout.controlsProbe").value as? String ?? "").contains("sequenceStep=1 ") }
                waitUntil("next authored shot settled", timeout: 60) {
                    self.element("dailyClearance.strike").label == "继续" && self.element("dailyClearance.undo").isEnabled
                }
                ready("dailyClearance.undo").tap()
                waitUntil("previous sequence step", timeout: 45) { (self.element("dailyLayout.controlsProbe").value as? String ?? "").contains("sequenceStep=0 ") }
                waitUntil("previous authored shot settled", timeout: 60) {
                    self.element("dailyClearance.strike").label == "继续" && self.element("dailyClearance.playback").isEnabled
                }
                ready("dailyClearance.strike").tap()
                waitUntil("sequence playback") { self.element("dailyClearance.strike").label == "暂停" }
                ready("dailyClearance.strike").tap()
                waitUntil("sequence paused", timeout: 45) { self.element("dailyClearance.strike").label == "继续" }
                let paused = try businessSnapshot()
                openLayoutEditor(); ready("layoutEditor.cancel").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
                waitUntil("paused editor exit") { !self.element("layoutEditor").exists }
                XCTAssertEqual(try businessSnapshot(), paused)
            } else {
                let power = ready("shotStage.powerBar")
                power.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.6)).press(forDuration: 0.1, thenDragTo: power.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.45)))
                waitUntil("power solve", timeout: 45) { self.element("dailyClearance.strike").isEnabled }
                ready("dailyClearance.strike").tap()
                waitUntil("shot settled with undo available", timeout: 60) { self.element("dailyClearance.undo").isEnabled }
                XCTAssertTrue(ready("dailyClearance.undo").isEnabled)
                ready("dailyClearance.undo").tap()
            }
            try capture(page + "-real-actions", probing: probes)
        }
        XCTAssertEqual(rows.count, pages.count * 5)
    }

    func testCoreSpecialStatesPreserveAttemptsAndBlockTerminalEditing() throws {
        launchCore("snakePractice"); setCoreMode("2D")
        let before = try businessSnapshot()
        openLayoutEditor(); revealEditor("layoutEditor.down").tap(); saveLayoutPage()
        XCTAssertEqual(try businessSnapshot(), before)
        let power = ready("shotStage.powerBar")
        power.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.1)).press(forDuration: 0.05,
            thenDragTo: power.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.95)), withVelocity: .fast, thenHoldForDuration: 0.05)
        waitUntil("snake low power ready", timeout: 45) { self.element("dailyClearance.strike").isEnabled }
        ready("dailyClearance.strike").tap()
        XCTAssertTrue(element("snake.failure.retry").waitForExistence(timeout: 60))
        try capture("snake-failure-after-layout", probing: ["dailyLayout.controlsProbe", "snake.failure.retry"])
        ready("snake.failure.retry").tap()
        waitUntil("snake retry", timeout: 45) { self.element("dailyClearance.strike").isEnabled }
        let retried = try businessSnapshot()
        openLayoutEditor(); ready("layoutEditor.cancel").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        waitUntil("retry editor exit") { !self.element("layoutEditor").exists }
        XCTAssertEqual(try businessSnapshot(), retried)
        ready("freeplay.moreMenu").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); ready("snake.settings").tap()
        XCTAssertTrue(app.staticTexts["暂无训练记录"].waitForExistence(timeout: 5))
        try capture("snake-retry-no-completion", probing: ["snake.settingsCancel"])
        ready("snake.settingsCancel").tap()

        launchCore("freePlay"); setCoreMode("2D")
        openLayoutEditor(); revealEditor("layoutEditor.down").tap(); saveLayoutPage()
        ready("break.entry").tap(); ready("break.game.9").tap()
        waitUntil("break ready", timeout: 45) { self.element("break.strike").isEnabled }
        ready("break.strike").tap()
        waitUntil("break confirmation", timeout: 60) { self.element("break.confirm").exists && self.element("break.confirm").isEnabled }
        ready("freeplay.moreMenu").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); XCTAssertFalse(ready("controlLayout.open").isEnabled)
        app.buttons["关闭菜单"].firstMatch.coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.5)).tap()
        try capture("free-break-confirm-blocked", probing: ["break.confirm", "controlLayout.geometry"])
        ready("break.confirm").tap()
        waitUntil("free break confirmed", timeout: 45) { self.element("dailyClearance.strike").isEnabled }
        let free = try businessSnapshot()
        openLayoutEditor(); ready("layoutEditor.cancel").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        waitUntil("free editor exit") { !self.element("layoutEditor").exists }
        XCTAssertEqual(try businessSnapshot(), free)
        try capture("free-break-returned", probing: ["dailyLayout.controlsProbe", "dailyClearance.strike"])

        app.terminate(); app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES",
            "-forcePremium", "-v50.inMemoryStore", "-dailyLayout.probe", "-3dDrag.probe", "-deeplink.dailyClearance",
            "-dailyClearance.resetState", "-dailyClearance.resetHomeState", "-dailyClearance.fixture=completed", "-dailyClearance.fixtureSettled"]
        app.launch(); _ = ready("dailyClearance.replay")
        let terminal = try businessSnapshot()
        ready("freeplay.moreMenu").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap(); XCTAssertFalse(ready("controlLayout.open").isEnabled)
        try capture("daily-terminal-edit-blocked", probing: ["controlLayout.open", "dailyLayout.controlsProbe"])
        app.buttons["关闭菜单"].firstMatch.coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.5)).tap()
        XCTAssertEqual(try businessSnapshot(), terminal)
        XCTAssertTrue(ready("dailyClearance.replay").isEnabled)
        XCTAssertEqual(rows.count, 5)
    }

    func testThreePageBaseline() throws {
        let portrait = ProcessInfo.processInfo.environment["LAYOUT_ORIENTATION"] == "portrait"
        let requested = ProcessInfo.processInfo.environment["LAYOUT_PAGES"]?.split(separator: ",").map(String.init) ?? ["dailyClearance", "freePlay", "silu"]
        for page in requested {
            app?.terminate()
            XCUIDevice.shared.orientation = portrait ? .portrait : .landscapeLeft
            app = XCUIApplication()
            app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                "-hasCompletedOnboarding", "YES", "-forcePremium", "-v50.inMemoryStore",
                "-v51.followSystemAppearance", "-appearanceMode", "system", "-dailyLayout.probe", "-3dDrag.probe",
                "-deeplink." + page, "-dailyClearance.resetState", "-dailyClearance.resetHomeState",
                "-dailyClearance.preferredGame.v1", "chineseEightBall",
                "-dailyClearance.fixture=selection", "-dailyClearance.fixtureSettled"]
            app.launchEnvironment["CONTROL_LAYOUT_PROBE"] = ProcessInfo.processInfo.environment["CONTROL_LAYOUT_PROBE"] ?? "default"
            app.launch()
            let more = page == "silu" ? "silu.more" : "freeplay.moreMenu"
            let camera = page == "silu" ? "silu.cameraMode" : "freeplay.cameraMode"
            _ = ready(more)
            let orientation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let r = self.app.windows.firstMatch.frame
                return portrait ? r.height > r.width : r.width > r.height
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [orientation], timeout: 10), .completed)
            for mode in ["2D", "3D"] {
                ready(more).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                let toggle = ready(camera)
                if toggle.value as? String != mode { toggle.tap() }
                XCTAssertEqual(ready(camera).value as? String, mode)
                if page == "silu" { ready("silu.dismissMenu").tap() }
                else { app.buttons["关闭菜单"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).tap() }
                try capture(page + "-" + mode + "-base")
                ready(more).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                try capture(page + "-" + mode + "-menu")
                ready(page == "silu" ? "silu.transparency" : "dailyClearance.spinTransparencyMenu").tap()
                _ = ready("dailyClearance.spinTransparencyPanel")
                try capture(page + "-" + mode + "-transparency")
                if page == "silu" {
                    ready("dailyClearance.spinTransparencyDone").tap()
                } else {
                    app.terminate(); app.launch(); _ = ready(more)
                    ready("shotStage.spinEntry").tap()
                }
                _ = ready("spinPad.disc")
                try capture(page + "-" + mode + "-spin")
                app.terminate(); app.launch(); _ = ready(more)
                if mode == "3D" {
                    ready("shotCamera.temporaryTopDown").tap()
                    try capture(page + "-" + mode + "-temporary2D")
                    ready("shotCamera.temporaryTopDown").tap()
                }
            }
        }
        XCTAssertEqual(rows.count, requested.count * 9)
    }
    func testBusySamples() throws {
        for page in ["dailyClearance", "freePlay", "silu"] {
            app?.terminate(); XCUIDevice.shared.orientation = .landscapeLeft
            app = XCUIApplication()
            app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                "-hasCompletedOnboarding", "YES", "-forcePremium", "-v50.inMemoryStore",
                "-appearanceMode", "dark", "-dailyLayout.probe", "-3dDrag.probe",
                "-deeplink." + page, "-dailyClearance.resetState", "-dailyClearance.resetHomeState",
                "-dailyClearance.fixture=selection", "-dailyClearance.fixtureSettled"]
            app.launchEnvironment["CONTROL_LAYOUT_PROBE"] = ProcessInfo.processInfo.environment["CONTROL_LAYOUT_PROBE"] ?? "default"
            app.launch()
            let more = page == "silu" ? "silu.more" : "freeplay.moreMenu"
            _ = ready(more)
            if page == "silu" {
                ready(more).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                let entry = ready("break.entry")
                for _ in 0..<4 where !entry.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
                entry.tap(); ready("break.game.15").tap()
            }
            let strike = ready(page == "silu" ? "silu.strike" : "dailyClearance.strike")
            XCTAssertTrue(strike.isEnabled)
            strike.tap()
            let disabledImmediately = !strike.isEnabled
            try capture(page + "-shot-busy")
            XCTAssertTrue(disabledImmediately, "Must observe actual shot busy state, not label a settled frame busy")
            let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in strike.isEnabled }, object: nil)
            _ = XCTWaiter.wait(for: [settled], timeout: 20)
        }
        XCTAssertEqual(rows.count, 3)
    }

    func testDailyLayoutEditor() throws {
        let portrait = ProcessInfo.processInfo.environment["LAYOUT_ORIENTATION"] == "portrait"
        XCUIDevice.shared.orientation = portrait ? .portrait : .landscapeLeft
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
            "-hasCompletedOnboarding", "YES", "-forcePremium", "-v50.inMemoryStore",
            "-appearanceMode", "dark", "-dailyLayout.probe", "-3dDrag.probe",
            "-deeplink.dailyClearance", "-dailyClearance.resetState", "-dailyClearance.resetHomeState",
            "-dailyClearance.fixture=selection", "-dailyClearance.fixtureSettled"]
        app.launch()
        _ = ready("freeplay.moreMenu")
        let landscape = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let r = self.app.windows.firstMatch.frame
            return portrait ? r.height > r.width : r.width > r.height
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 10), .completed)
        // Restore through the production UI so repeated runs never depend on a previous template.
        openLayoutEditor()
        let restore = app.buttons["恢复本页"].firstMatch
        for _ in 0..<5 where !restore.isHittable { app.scrollViews["layoutEditor.properties"].swipeUp() }
        restore.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["本页使用球迹默认"].tap()
        ready("layoutEditor.save").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        ready("layoutEditor.savePage").tap()
        let resetClosed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !self.element("layoutEditor").exists }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [resetClosed], timeout: 5), .completed)
        let before = try businessSnapshot()
        try capture("daily-before-base")
        openLayoutEditor()
        try capture("daily-editor-base")
        setEditorPreview(true)
        ready("layoutEditor.previewStrike").tap()
        XCTAssertTrue(ready("layoutEditor.feedback").label.contains("已触达击球"))
        let previewPower = ready("layoutEditor").descendants(matching: .any).matching(identifier: "shotStage.powerBar").firstMatch
        XCTAssertTrue(previewPower.exists)
        let previewSpeed = previewPower.value as? String
        previewPower.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            .press(forDuration: 0.1, thenDragTo: previewPower.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)))
        XCTAssertNotEqual(previewPower.value as? String, previewSpeed)
        ready("layoutEditor").descendants(matching: .button).matching(identifier: "shotStage.spinEntry").firstMatch.tap()
        try capture("daily-preview-spin")
        app.buttons["收起打点盘"].tap()
        XCUIDevice.shared.press(.home)
        app.activate()
        _ = ready("layoutEditor")
        setEditorPreview(false)
        revealEditor("layoutEditor.down").tap()
        try capture("daily-draft-base")
        ready("layoutEditor.cancel").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        if app.buttons["放弃修改"].waitForExistence(timeout: 2) { app.buttons["放弃修改"].tap() }
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !self.element("layoutEditor").exists }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
        if element("layoutEditor").exists { try capture("daily-cancel-failed") }
        XCTAssertFalse(element("layoutEditor").exists, "Cancel/discard must restore the original page: \(String(describing: element("layoutEditor.state").value))")
        XCTAssertEqual(try businessSnapshot(), before)
        openLayoutEditor()
        revealEditor("layoutEditor.swap").tap()
        XCTAssertTrue(ready("layoutEditor.feedback").label.contains("已调整"), ready("layoutEditor.feedback").label)
        ready("layoutEditor.save").tap(); ready("layoutEditor.savePage").tap()
        XCTAssertFalse(element("layoutEditor").exists)
        XCTAssertEqual(try businessSnapshot(), before)
        try capture("daily-saved-base")
        let savedX = ready("dailyClearance.strike").frame.midX
        XCTAssertLessThan(savedX, app.windows.firstMatch.frame.midX)
        app.terminate(); app.launch()
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            abs(self.element("dailyClearance.strike").frame.midX - savedX) <= 0.5
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 10), .completed)
        XCTAssertEqual(ready("dailyClearance.strike").frame.midX, savedX, accuracy: 0.5)
        try capture("daily-relaunch-base")
        openLayoutEditor()
        ready("layoutEditor.save").tap(); ready("layoutEditor.saveAs").tap()
        let name = app.alerts.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 3)); name.tap(); name.typeText("我的布局")
        app.alerts.buttons["保存并应用"].tap()
        XCTAssertFalse(element("layoutEditor").exists)
        try capture("daily-template-base")
        let strike = ready("dailyClearance.strike")
        XCTAssertTrue(strike.isEnabled); strike.tap(); XCTAssertFalse(strike.isEnabled)
        try capture("daily-normal-shot-busy")
        XCTAssertEqual(rows.count, 8)
    }

    func testDailyLayoutNavigationAndModes() throws {
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
            "-hasCompletedOnboarding", "YES", "-forcePremium", "-v50.inMemoryStore",
            "-appearanceMode", "dark", "-dailyLayout.probe", "-3dDrag.probe",
            "-v53.authenticatedProfileFixture", "-dailyClearance.resetState", "-dailyClearance.resetHomeState",
            "-dailyClearance.fixture=selection", "-dailyClearance.fixtureSettled"]
        app.launch()
        app.switchTab(.training)
        let home = app.buttons["trainingHome.dailyClearance"]
        XCTAssertTrue(home.waitForExistence(timeout: 10)); home.tap()
        let entered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            self.app.windows.firstMatch.frame.width > self.app.windows.firstMatch.frame.height
                && self.element("dailyClearance.strike").exists
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [entered], timeout: 15), .completed)
        let originalX = ready("dailyClearance.strike").frame.midX
        openLayoutEditor()
        ready("layoutEditor.swap").tap()
        XCTAssertTrue(ready("layoutEditor.feedback").label.contains("已调整"))
        ready("layoutEditor.save").tap(); ready("layoutEditor.savePage").tap()
        let savedX = ready("dailyClearance.strike").frame.midX
        XCTAssertNotEqual(savedX, originalX)
        for mode in ["2D", "3D"] {
            ready("freeplay.moreMenu").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let toggle = ready("freeplay.cameraMode")
            if toggle.value as? String != mode { toggle.tap() }
            XCTAssertEqual(toggle.value as? String, mode)
            app.buttons["关闭菜单"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).tap()
            XCTAssertEqual(ready("dailyClearance.strike").frame.midX, savedX, accuracy: 0.5)
            try capture("daily-saved-" + mode + "-base")
        }
        ready("dailyClearance.back").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.switchTab(.training)
        XCTAssertTrue(home.waitForExistence(timeout: 10)); home.tap()
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = self.element("dailyClearance.strike").frame
            return frame.width > 0 && abs(frame.midX - savedX) <= 0.5
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 15), .completed)
        try capture("daily-navigation-reentry-base")
        XCTAssertEqual(rows.count, 3)
    }

    func testThreePageSharedEditor() throws {
        let portrait = ProcessInfo.processInfo.environment["LAYOUT_ORIENTATION"] == "portrait"
        let templateName = "共享" + UUID().uuidString.prefix(6)
        func launch(_ page: String) {
            app?.terminate(); XCUIDevice.shared.orientation = portrait ? .portrait : .landscapeLeft
            app = XCUIApplication()
            app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                "-hasCompletedOnboarding", "YES", "-forcePremium", "-v50.inMemoryStore",
                "-appearanceMode", "dark", "-dailyLayout.probe", "-3dDrag.probe", "-deeplink." + page,
                "-dailyClearance.resetState", "-dailyClearance.resetHomeState",
                "-dailyClearance.fixture=selection", "-dailyClearance.fixtureSettled"]
            app.launch(); _ = ready(page == "silu" ? "silu.more" : "freeplay.moreMenu")
            let orientation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let r = self.app.windows.firstMatch.frame
                return portrait ? r.height > r.width : r.width > r.height
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [orientation], timeout: 10), .completed)
        }
        func savePage() {
            ready("layoutEditor.save").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            ready("layoutEditor.savePage").tap()
            let closed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !self.element("layoutEditor").exists }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
        }
        func resetPage() {
            openLayoutEditor()
            let restore = app.buttons["恢复本页"].firstMatch
            for _ in 0..<6 where !restore.isHittable { app.scrollViews["layoutEditor.properties"].swipeUp() }
            restore.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            app.buttons["本页使用球迹默认"].tap(); savePage()
        }
        launch("dailyClearance"); resetPage()
        try capture("shared-daily-before-base")
        openLayoutEditor(); revealEditor("layoutEditor.down").tap()
        XCTAssertTrue(ready("layoutEditor.feedback").label.contains("已调整"))
        ready("layoutEditor.save").tap(); ready("layoutEditor.saveAs").tap()
        let name = app.alerts.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 3)); name.tap(); name.typeText(templateName)
        app.alerts.buttons["保存并应用"].tap()
        try capture("shared-daily-template-base")
        for page in ["freePlay", "silu"] {
            launch(page); resetPage()
            let primaryID = page == "silu" ? "silu.strike" : "dailyClearance.strike"
            let before = try businessSnapshot()
            let defaultY = ready(primaryID).frame.minY
            try capture("shared-" + page + "-before-base")
            openLayoutEditor()
            revealEditor("layoutEditor.templates").tap(); app.buttons[templateName].firstMatch.tap()
            savePage()
            XCTAssertEqual(try businessSnapshot(), before)
            XCTAssertEqual(ready(primaryID).frame.minY, defaultY + 8, accuracy: 0.5)
            try capture("shared-" + page + "-applied-base")
            openLayoutEditor(); revealEditor("layoutEditor.up").tap(); savePage()
            XCTAssertEqual(ready(primaryID).frame.minY, defaultY, accuracy: 0.5)
            XCTAssertEqual(try businessSnapshot(), before)
            try capture("shared-" + page + "-local-base")
            openLayoutEditor(); revealEditor("layoutEditor.down").tap()
            XCUIDevice.shared.press(.home); app.activate(); _ = ready("layoutEditor")
            ready("layoutEditor.cancel").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(app.buttons["放弃修改"].waitForExistence(timeout: 3)); app.buttons["放弃修改"].tap()
            let closed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !self.element("layoutEditor").exists }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
            XCTAssertEqual(try businessSnapshot(), before)
            app.terminate(); app.launch(); _ = ready(primaryID)
            XCTAssertEqual(ready(primaryID).frame.minY, defaultY, accuracy: 0.5)
            try capture("shared-" + page + "-relaunch-base")
        }
        XCTAssertEqual(rows.count, 10)
    }

    func testPadActualWindowResizePreservesLayoutAndTraining() throws {
        func zoomWindow() {
            let window = app.windows.firstMatch
            let before = window.frame
            window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 52, dy: 32)).tap()
            Thread.sleep(forTimeInterval: 0.5)
            if abs(window.frame.width - before.width) < 1 {
                // The first tap expands iPadOS's compact traffic-light control.
                // The native expanded green button is 104pt from the window's left edge.
                window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 104, dy: 32)).tap()
            }
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES",
            "-forcePremium", "-v50.inMemoryStore", "-v51.followSystemAppearance", "-appearanceMode", "system",
            "-dailyLayout.probe", "-3dDrag.probe", "-deeplink.dailyClearance", "-dailyClearance.resetState",
            "-dailyClearance.resetHomeState", "-dailyClearance.fixture=selection", "-dailyClearance.fixtureSettled"]
        app.launch(); _ = ready("freeplay.moreMenu")
        let entryFrame = app.windows.firstMatch.frame
        if entryFrame.minX > 1 || entryFrame.minY > 40 {
            // iPadOS window zoom control observed in the native window evidence.
            zoomWindow()
            let full = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.app.windows.firstMatch.frame.minX < 1 }, object: nil)
            let reached = XCTWaiter.wait(for: [full], timeout: 5)
            if reached != .completed {
                try XCUIApplication(bundleIdentifier: "com.apple.springboard").debugDescription.write(to: output.appendingPathComponent("window-system-entry.ax.txt"), atomically: true, encoding: .utf8)
            }
            XCTAssertEqual(reached, .completed)
        }
        ready("freeplay.moreMenu").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        if ready("freeplay.cameraMode").value as? String != "2D" { ready("freeplay.cameraMode").tap() }
        app.coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.5)).tap()
        openLayoutEditor()
        let restore = app.buttons["恢复本页"].firstMatch
        for _ in 0..<8 where !restore.isHittable { app.scrollViews["layoutEditor.properties"].swipeUp() }
        restore.tap(); app.buttons["本页使用球迹默认"].tap()
        ready("layoutEditor.save").tap(); ready("layoutEditor.savePage").tap()
        openLayoutEditor(); revealEditor("layoutEditor.down").tap()
        ready("layoutEditor.save").tap(); ready("layoutEditor.savePage").tap()
        let revision = ready("controlLayout.revision").value as? String
        let original = app.windows.firstMatch.frame
        defer {
            if app.windows.firstMatch.exists, abs(app.windows.firstMatch.frame.width - original.width) > 1 {
                zoomWindow()
            }
        }
        let state = try businessSnapshot(includeCamera: false)
        XCTAssertTrue((ready("controlLayout.geometry").value as? String ?? "").contains("primaryTranslation=0.0,8.0"))
        try capture("window-original-base")
        let origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(.init(dx: original.width - 7, dy: original.height - 7))
            .press(forDuration: 0.5, thenDragTo: origin.withOffset(.init(dx: original.width * 0.7, dy: original.height * 0.78)))
        let resized = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let current = self.app.windows.firstMatch.frame
            return current.width < original.width - 80 || current.height < original.height - 80
        }, object: nil)
        let changed = XCTWaiter.wait(for: [resized], timeout: 8)
        try capture("window-resized-base")
        XCTAssertEqual(changed, .completed, "Must change real iPad app window, not a test layout proposal")
        XCTAssertEqual(try businessSnapshot(includeCamera: false), state)
        XCTAssertEqual(ready("controlLayout.revision").value as? String, revision)
        zoomWindow()
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            abs(self.app.windows.firstMatch.frame.width - original.width) < 1 && abs(self.app.windows.firstMatch.frame.height - original.height) < 1
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 8), .completed)
        XCTAssertEqual(try businessSnapshot(includeCamera: false), state)
        XCTAssertEqual(ready("controlLayout.revision").value as? String, revision)
        try capture("window-restored-base")
        // iPadOS may change the titlebar/home-indicator safe area after zooming.
        // Verify the saved displacement against the new native default, not screen Y.
        XCTAssertTrue((ready("controlLayout.geometry").value as? String ?? "").contains("primaryTranslation=0.0,8.0"))
        XCTAssertTrue(app.windows.firstMatch.frame.contains(ready("dailyClearance.strike").frame))
        XCTAssertEqual(rows.count, 3)
    }

    func testSettingsTemplateManagementAndDisplayIsolation() throws {
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES",
            "-forcePremium", "-v50.inMemoryStore", "-v53.authenticatedProfileFixture", "-v51.followSystemAppearance",
            "-appearanceMode", "system", "-deeplink.settings"]
        app.launch()
        let layout = ready("settings.controlLayout")
        for _ in 0..<6 where !layout.isHittable { app.swipeUp() }
        var original = [String: String]()
        for id in ["settings.grid", "settings.closeup", "settings.trajectory3D", "settings.transparency"] {
            let item = element(id)
            if item.exists { original[id] = String(describing: item.value) }
        }
        layout.tap(); _ = ready("layoutLibrary")
        try capture("settings-layout-library")
        app.buttons["球迹默认"].firstMatch.tap()
        app.buttons["复制为新模板"].tap()
        let name = "设置" + UUID().uuidString.prefix(6)
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.coordinate(withNormalizedOffset: .init(dx: 0.95, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (field.value as? String ?? "").count) + name)
        app.alerts.buttons["保存"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        for _ in 0..<8 where !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.exists); row.tap()
        app.buttons["重命名"].tap()
        let renameField = app.alerts.textFields.firstMatch
        XCTAssertTrue(renameField.waitForExistence(timeout: 3)); renameField.coordinate(withNormalizedOffset: .init(dx: 0.95, dy: 0.5)).tap()
        renameField.typeText("调整")
        app.alerts.buttons["保存"].tap()
        ready("layoutLibrary.apply").tap()
        XCTAssertTrue(ready("layoutApply.shotSimulation").isEnabled)
        XCTAssertFalse(element("layoutApply.customFormationPractice").exists)
        let free = ready("layoutApply.freePlay")
        free.coordinate(withNormalizedOffset: .init(dx: 0.93, dy: 0.5)).tap()
        try capture("settings-layout-apply-review")
        let apply = ready("layoutApply.confirm")
        for _ in 0..<12 where !apply.isHittable { app.swipeUp() }; apply.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let family = app.buttons["击球"].firstMatch
        for _ in 0..<10 where !family.isHittable { app.swipeUp() }; family.tap()
        app.buttons["更换默认模板"].firstMatch.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        let choice = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 3)); choice.tap(); ready("layoutReview.confirm").tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let renamedRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        for _ in 0..<10 where !renamedRow.isHittable { app.swipeDown() }; renamedRow.tap()
        let deletion = app.buttons["删除模板"].firstMatch
        for _ in 0..<10 where !deletion.isHittable { app.swipeUp() }; deletion.tap()
        app.buttons["引用页面改用球迹默认"].tap()
        try capture("settings-layout-delete-review")
        ready("layoutReview.confirm").tap()
        _ = ready("layoutLibrary")
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch.exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        _ = ready("settings.controlLayout")
        for (id, value) in original { XCTAssertEqual(String(describing: element(id).value), value, id) }
        try capture("settings-display-preserved")
        XCTAssertEqual(rows.count, 4)
    }

    func testTemplateManagementContinuousChain() throws {
        let portrait = ProcessInfo.processInfo.environment["LAYOUT_ORIENTATION"] == "portrait"
        let templateName = "管理" + UUID().uuidString.prefix(6)
        func launch(_ page: String) {
            app?.terminate(); XCUIDevice.shared.orientation = portrait ? .portrait : .landscapeLeft
            app = XCUIApplication()
            app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES",
                "-forcePremium", "-v50.inMemoryStore", "-v51.followSystemAppearance", "-appearanceMode", "system",
                "-dailyLayout.probe", "-3dDrag.probe", "-deeplink." + page, "-dailyClearance.resetState",
                "-dailyClearance.resetHomeState", "-dailyClearance.fixture=selection", "-dailyClearance.fixtureSettled"]
            app.launch(); _ = ready(page == "silu" ? "silu.more" : "freeplay.moreMenu")
            let more = page == "silu" ? "silu.more" : "freeplay.moreMenu"
            let mode = page == "silu" ? "silu.cameraMode" : "freeplay.cameraMode"
            ready(more).coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            if ready(mode).value as? String != "2D" { ready(mode).tap() }
            if page == "silu" { ready("silu.dismissMenu").tap() }
            else { app.coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.5)).tap() }
        }
        func savePage() {
            ready("layoutEditor.save").tap(); ready("layoutEditor.savePage").tap()
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                !self.element("layoutEditor").exists
            }, object: nil)], timeout: 5), .completed)
        }
        func reset() {
            openLayoutEditor()
            let restore = app.buttons["恢复本页"].firstMatch
            for _ in 0..<8 where !restore.isHittable { app.scrollViews["layoutEditor.properties"].swipeUp() }
            restore.tap(); app.buttons["本页使用球迹默认"].tap(); savePage()
        }
        func apply() {
            openLayoutEditor(); revealEditor("layoutEditor.templates").tap(); app.buttons[templateName].firstMatch.tap(); savePage()
        }
        launch("dailyClearance"); reset()
        let dailyY = ready("dailyClearance.strike").frame.minY
        openLayoutEditor(); revealEditor("layoutEditor.down").tap()
        ready("layoutEditor.save").tap(); ready("layoutEditor.saveAs").tap()
        let name = app.alerts.textFields.firstMatch; XCTAssertTrue(name.waitForExistence(timeout: 3)); name.tap(); name.typeText(templateName)
        app.alerts.buttons["保存并应用"].tap()
        try capture("manager-created-base")
        launch("freePlay"); reset(); let freeY = ready("dailyClearance.strike").frame.minY
        apply(); openLayoutEditor(); revealEditor("layoutEditor.up").tap(); savePage()
        XCTAssertEqual(ready("dailyClearance.strike").frame.minY, freeY, accuracy: 0.5)
        try capture("manager-free-local-base")
        launch("silu"); reset(); let siluY = ready("silu.strike").frame.minY
        apply(); XCTAssertEqual(ready("silu.strike").frame.minY, siluY + 8, accuracy: 0.5)
        try capture("manager-silu-follow-base")
        launch("dailyClearance"); let before = try businessSnapshot()
        openLayoutEditor(); revealEditor("layoutEditor.down").tap()
        ready("layoutEditor.save").tap(); ready("layoutEditor.promote").tap()
        try capture("manager-promotion-review")
        let confirm = ready("layoutPromotion.confirm")
        for _ in 0..<8 where !confirm.isHittable { app.swipeUp() }
        confirm.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !self.element("layoutEditor").exists && abs(self.element("dailyClearance.strike").frame.minY - dailyY - 16) <= 0.5
        }, object: nil)], timeout: 10), .completed)
        _ = ready("dailyClearance.strike")
        XCTAssertEqual(try businessSnapshot(), before)
        XCTAssertEqual(ready("dailyClearance.strike").frame.minY, dailyY + 16, accuracy: 0.5)
        try capture("manager-promoted-base")
        launch("silu"); XCTAssertEqual(ready("silu.strike").frame.minY, siluY + 16, accuracy: 0.5)
        try capture("manager-silu-updated-base")
        launch("freePlay"); XCTAssertEqual(ready("dailyClearance.strike").frame.minY, freeY, accuracy: 0.5)
        openLayoutEditor(); revealEditor("layoutEditor.restoreGroup").tap(); savePage()
        XCTAssertEqual(ready("dailyClearance.strike").frame.minY, freeY + 16, accuracy: 0.5)
        try capture("manager-free-restored-base")
        try verifyNestedTemplateUpdate(templateName: templateName, freeY: freeY)
        XCTAssertEqual(rows.count, 12)
    }

    private func verifyNestedTemplateUpdate(templateName: String, freeY: CGFloat) throws {
        let freeBefore = try businessSnapshot()
        openLayoutEditor(); revealEditor("layoutEditor.library").tap()
        _ = ready("layoutLibrary"); try capture("manager-library")
        let template = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", templateName)).firstMatch
        let library = ready("layoutLibrary")
        for _ in 0..<14 {
            if template.exists && template.isHittable { break }
            library.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.8)).press(forDuration: 0.1,
                thenDragTo: library.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.35)))
        }
        if !template.exists { try capture("manager-library-search-failure") }
        XCTAssertTrue(template.exists); template.tap()
        ready("layoutLibrary.edit").tap(); ready("layoutLibrary.beginEdit").tap()
        revealEditor("layoutEditor.up").tap()
        try capture("manager-independent-preview")
        ready("layoutEditor.save").tap(); app.buttons["更新此模板"].tap()
        let update = ready("layoutPromotion.confirm")
        for _ in 0..<8 where !update.isHittable { app.swipeUp() }; update.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            self.element("layoutLibrary.beginEdit").exists && self.element("layoutLibrary.beginEdit").isHittable
        }, object: nil)], timeout: 10), .completed)
        app.buttons["完成"].firstMatch.tap()
        if !app.buttons["返回编辑"].firstMatch.exists { app.navigationBars.buttons.element(boundBy: 0).tap() }
        XCTAssertTrue(app.buttons["返回编辑"].firstMatch.waitForExistence(timeout: 3))
        app.buttons["返回编辑"].firstMatch.tap()
        _ = ready("layoutEditor")
        try capture("manager-stale-editor")
        ready("layoutEditor.save").tap(); ready("layoutEditor.savePage").tap()
        XCTAssertTrue(app.alerts["布局未保存"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.alerts.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "另一处更新")).firstMatch.exists)
        app.alerts.buttons["重新载入"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !self.app.alerts.firstMatch.exists && self.element("layoutEditor.cancel").isHittable
        }, object: nil)], timeout: 5), .completed)
        ready("layoutEditor.cancel").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !self.element("layoutEditor").exists && abs(self.element("dailyClearance.strike").frame.minY - freeY - 8) <= 0.5
        }, object: nil)], timeout: 5), .completed, element("layoutEditor.state").exists ? String(describing: element("layoutEditor.state").value) : "editor closed")
        XCTAssertEqual(try businessSnapshot(), freeBefore)
        XCTAssertEqual(ready("dailyClearance.strike").frame.minY, freeY + 8, accuracy: 0.5)
        try capture("manager-reloaded-base")
        app.terminate(); app.launch(); _ = ready("dailyClearance.strike")
        XCTAssertEqual(ready("dailyClearance.strike").frame.minY, freeY + 8, accuracy: 0.5)
        try capture("manager-relaunch-base")
    }

    func testManagerConflictReloadReturnsToTraining() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES",
            "-forcePremium", "-v50.inMemoryStore", "-v51.followSystemAppearance", "-appearanceMode", "system",
            "-dailyLayout.probe", "-3dDrag.probe", "-deeplink.freePlay"]
        app.launch(); _ = ready("freeplay.moreMenu")
        ready("freeplay.moreMenu").coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        if ready("freeplay.cameraMode").value as? String != "2D" { ready("freeplay.cameraMode").tap() }
        app.coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.5)).tap()
        openLayoutEditor()
        let restore = app.buttons["恢复本页"].firstMatch
        for _ in 0..<8 where !restore.isHittable { app.scrollViews["layoutEditor.properties"].swipeUp() }
        restore.tap(); app.buttons["本页使用球迹默认"].tap()
        ready("layoutEditor.save").tap(); ready("layoutEditor.savePage").tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !self.element("layoutEditor").exists
        }, object: nil)], timeout: 5), .completed)
        let freeY = ready("dailyClearance.strike").frame.minY
        let name = "冲突" + UUID().uuidString.prefix(6)
        openLayoutEditor(); revealEditor("layoutEditor.down").tap(); revealEditor("layoutEditor.down").tap()
        ready("layoutEditor.save").tap(); ready("layoutEditor.saveAs").tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3)); field.tap(); field.typeText(name)
        app.alerts.buttons["保存并应用"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !self.element("layoutEditor").exists
        }, object: nil)], timeout: 5), .completed)
        try verifyNestedTemplateUpdate(templateName: name, freeY: freeY)
        XCTAssertEqual(rows.count, 5)
    }

    func testSharedPagesBusinessAndNavigation() throws {
        let portrait = ProcessInfo.processInfo.environment["LAYOUT_ORIENTATION"] == "portrait"
        func waitEnabled(_ id: String, timeout: TimeInterval = 75) {
            let e = element(id)
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == true AND enabled == true"), object: e)], timeout: timeout), .completed, id)
        }
        func dismissMenu(_ page: String) {
            if page == "silu" { ready("silu.dismissMenu").tap() }
            else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).tap() }
        }
        for page in ["freePlay", "silu"] {
            app?.terminate(); XCUIDevice.shared.orientation = .portrait
            app = XCUIApplication()
            app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                "-hasCompletedOnboarding", "YES", "-forcePremium", "-v50.inMemoryStore",
                "-appearanceMode", "dark", "-dailyLayout.probe", "-3dDrag.probe",
                "-v53.authenticatedProfileFixture"]
            app.launch(); app.switchTab(.angle)
            let title = page == "silu" ? "思路训练" : "自由击球"
            let tab = page == "silu" ? "解" : "打"
            ready("angleHomeTab_" + tab).tap(); app.buttons[title].firstMatch.tap()
            let more = page == "silu" ? "silu.more" : "freeplay.moreMenu"
            let camera = page == "silu" ? "silu.cameraMode" : "freeplay.cameraMode"
            let primary = page == "silu" ? "silu.strike" : "dailyClearance.strike"
            _ = ready(more)
            XCUIDevice.shared.orientation = portrait ? .portrait : .landscapeLeft
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let r = self.app.windows.firstMatch.frame
                return portrait ? r.height > r.width : r.width > r.height
            }, object: nil)], timeout: 10), .completed)
            for mode in ["3D", "2D"] {
                ready(more).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                if ready(camera).value as? String != mode { ready(camera).tap() }
                XCTAssertEqual(ready(camera).value as? String, mode); dismissMenu(page)
                let before = try businessSnapshot()
                openLayoutEditor()
                ready("layoutEditor.cancel").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                XCTAssertEqual(try businessSnapshot(), before)
                try capture(page + "-business-" + mode + "-base")
            }
            if page == "silu" {
                ready("silu.tool").tap(); app.buttons["落区"].tap()
                let table = ready("table.scene")
                table.coordinate(withNormalizedOffset: CGVector(dx: 0.37, dy: 0.48)).press(forDuration: 0.1,
                    thenDragTo: table.coordinate(withNormalizedOffset: CGVector(dx: 0.58, dy: 0.76)))
                waitEnabled("solver.solve"); ready("solver.solve").tap()
                waitEnabled("silu.strike", timeout: 90)
                XCTAssertTrue(ready("solver.nextSolution").label.hasPrefix("解"))
                let solved = try businessSnapshot()
                openLayoutEditor(); revealEditor("layoutEditor.up").tap()
                ready("layoutEditor.save").tap(); ready("layoutEditor.savePage").tap()
                XCTAssertEqual(try businessSnapshot(), solved)
                try capture("silu-solved-preserved-base")
                // The real parameter binding still modifies the existing solution after editing.
                let power = ready("shotStage.powerBar")
                let speed = power.value as? String
                power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)).press(forDuration: 0.1,
                    thenDragTo: power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
                XCTAssertNotEqual(power.value as? String, speed)
                XCTAssertTrue((ready("silu.layoutState").value as? String ?? "").contains("adjusted=true"))
                let adjusted = try businessSnapshot()
                openLayoutEditor(); XCUIDevice.shared.press(.home); app.activate()
                ready("layoutEditor.cancel").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                XCTAssertEqual(try businessSnapshot(), adjusted)
                try capture("silu-adjusted-preserved-base")
            } else {
                openLayoutEditor(); revealEditor("layoutEditor.up").tap()
                ready("layoutEditor.save").tap(); ready("layoutEditor.savePage").tap()
                ready("break.entry").tap(); ready("break.game.9").tap()
                waitEnabled("break.strike"); ready("break.strike").tap(); waitEnabled("break.confirm")
                ready(more).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                XCTAssertFalse(ready("controlLayout.open").isEnabled)
                dismissMenu(page)
                try capture("freePlay-break-confirm-base")
                ready("break.confirm").tap(); waitEnabled("dailyClearance.strike")
                XCTAssertFalse(element("break.confirm").exists)
                let confirmed = try businessSnapshot()
                openLayoutEditor()
                ready("layoutEditor.cancel").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                XCTAssertEqual(try businessSnapshot(), confirmed)
                try capture("freePlay-break-restored-base")
            }
            let y = ready(primary).frame.minY
            ready(page == "silu" ? "silu.back" : "dailyClearance.back")
                .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(app.buttons[title].firstMatch.waitForExistence(timeout: 10))
            app.buttons[title].firstMatch.tap(); _ = ready(primary)
            let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let frame = self.element(primary).frame
                return frame.width > 0 && abs(frame.minY - y) <= 0.5
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 10), .completed)
            try capture(page + "-navigation-reentry-base")
        }
        XCTAssertEqual(rows.count, 10)
    }

    private func setEditorPreview(_ enabled: Bool) {
        let toggle = revealEditor("layoutEditor.preview")
        let expected = enabled ? "1" : "0"
        if toggle.value as? String != expected {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
        XCTAssertEqual(toggle.value as? String, expected)
    }

    private func revealEditor(_ id: String) -> XCUIElement {
        let node = ready(id)
        let scroll = app.scrollViews["layoutEditor.properties"]
        for _ in 0..<10 {
            let viewport = scroll.frame.insetBy(dx: 0, dy: 4)
            let frame = node.frame
            if node.isHittable && viewport.contains(CGPoint(x: frame.midX, y: frame.midY)) { break }
            let downward = !frame.isEmpty && frame.midY < viewport.minY
            // A long press that begins on the segmented picker is consumed by UIKit.
            // Use an actual slow scroll swipe, not a press on an embedded control.
            if downward { scroll.swipeDown(velocity: XCUIGestureVelocity(rawValue: 100)) }
            else { scroll.swipeUp(velocity: XCUIGestureVelocity(rawValue: 100)) }
        }
        XCTAssertTrue(node.isHittable && scroll.frame.contains(CGPoint(x: node.frame.midX, y: node.frame.midY)), "\(id) frame=\(node.frame) viewport=\(scroll.frame)")
        return node
    }

    private func openLayoutEditor() {
        let more = ["silu.more", "planthree.more", "snooker.more", "bankshot.more", "reflection.more", "angleDynamic.more", "separationAngleAtlas.more", "cushionEnglishAtlas.more", "angleTraining.settings", "aimPointTraining.settings", "freeplay.moreMenu"].first { element($0).exists } ?? "freeplay.moreMenu"
        ready(more).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let entry = ready("controlLayout.open")
        for _ in 0..<4 where !entry.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
        waitUntil("layout entry settled", timeout: 90) { entry.isEnabled }; entry.tap(); _ = ready("layoutEditor")
    }
    private func businessSnapshot(includeCamera: Bool = true) throws -> String {
        let probe = ready("table.scene")
        let data = try XCTUnwrap((probe.value as? String)?.data(using: .utf8))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var kept = json.filter { (includeCamera ? ["rendererID", "balls", "camera"] : ["rendererID", "balls"]).contains($0.key) }
        if !includeCamera, let balls = json["balls"] as? [[String: Any]] {
            // A real resize changes projection and pixel diameter, not physical balls.
            kept["balls"] = balls.map { $0.filter { ["key", "world", "scale", "draggable"].contains($0.key) } }
        }
        let controlProbe = element("dailyLayout.controlsProbe")
        let tokens = (controlProbe.exists ? (controlProbe.value as? String ?? "") : "").split(separator: " ")
        kept["parameters"] = tokens.filter { token in
            ["velocity=", "spinX=", "spinY=", "phase=", "dailyShotCount=", "sequenceMode=", "recording=", "sequenceID=", "sequenceCount=", "sequencePhase=", "sequenceStep=", "snakeCanStrike=", "snakeRecords=", "snakeActive="].contains { token.hasPrefix($0) }
        }.map(String.init)
        for prefix in ["planthree", "snooker", "bankshot", "reflection", "silu", "angleDynamic", "separationAngleAtlas", "cushionEnglishAtlas", "angleTraining", "aimPointTraining"] {
            let state = element(prefix + ".layoutState")
            if state.exists { kept[prefix] = state.value as? String }
        }
        return String(data: try JSONSerialization.data(withJSONObject: kept, options: .sortedKeys), encoding: .utf8)!
    }

    func testRelocatedControls() throws {
        let portrait = ProcessInfo.processInfo.environment["LAYOUT_ORIENTATION"] == "portrait"
        for page in ["freePlay", "silu"] {
            app?.terminate()
            XCUIDevice.shared.orientation = portrait ? .portrait : .landscapeLeft
            app = XCUIApplication()
            app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                "-hasCompletedOnboarding", "YES", "-forcePremium", "-v50.inMemoryStore",
                "-appearanceMode", "dark", "-dailyLayout.probe", "-3dDrag.probe",
                "-deeplink." + page, "-dailyClearance.resetState", "-dailyClearance.resetHomeState",
                "-dailyClearance.fixture=selection", "-dailyClearance.fixtureSettled"]
            app.launchEnvironment["CONTROL_LAYOUT_PROBE"] = ProcessInfo.processInfo.environment["CONTROL_LAYOUT_PROBE"] ?? "swap"
            app.launch()
            let more = page == "silu" ? "silu.more" : "freeplay.moreMenu"
            let camera = page == "silu" ? "silu.cameraMode" : "freeplay.cameraMode"
            _ = ready(more)
            if page == "silu" {
                ready(more).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                let entry = ready("break.entry")
                for _ in 0..<4 where !entry.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
                entry.tap(); ready("break.game.15").tap()
            }
            for mode in ["2D", "3D"] {
                ready(more).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                if ready(camera).value as? String != mode { ready(camera).tap() }
                XCTAssertEqual(ready(camera).value as? String, mode)
                if page == "silu" { ready("silu.dismissMenu").tap() }
                else { app.buttons["关闭菜单"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).tap() }
                let geometry = ready("controlLayout.geometry")
                let placed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    (geometry.value as? String)?.contains("status=customized") == true
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [placed], timeout: 5), .completed, String(describing: geometry.value))
                let primary = ready(page == "silu" ? "silu.strike" : "dailyClearance.strike")
                XCTAssertLessThan(primary.frame.midX, app.windows.firstMatch.frame.midX)
                let power = ready("shotStage.powerBar")
                XCTAssertLessThan(power.frame.midX, app.windows.firstMatch.frame.midX)
                let speedBefore = power.value as? String
                power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
                    .press(forDuration: 0.1, thenDragTo: power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
                XCTAssertNotEqual(power.value as? String, speedBefore, "Relocated power gesture must update its existing binding")
                try capture(page + "-" + mode + "-base")
                ready("shotStage.spinEntry").tap(); _ = ready("spinPad.disc")
                try capture(page + "-" + mode + "-spin")
                let close = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "关闭")).firstMatch
                XCTAssertTrue(close.exists); close.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.05)).tap()
                if mode == "3D" {
                    XCTAssertTrue(primary.isEnabled)
                    primary.tap()
                    XCTAssertFalse(primary.isEnabled, "Actual relocated strike must start the existing shot")
                }
            }
        }
        XCTAssertEqual(rows.count, 8)
    }

    func testBoundedLayoutDrag() throws {
        let portrait = ProcessInfo.processInfo.environment["LAYOUT_ORIENTATION"] == "portrait"
        for page in ["freePlay", "silu"] {
            app?.terminate(); XCUIDevice.shared.orientation = portrait ? .portrait : .landscapeLeft
            app = XCUIApplication()
            app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                "-hasCompletedOnboarding", "YES", "-forcePremium", "-v50.inMemoryStore",
                "-appearanceMode", "dark", "-dailyLayout.probe", "-3dDrag.probe",
                "-deeplink." + page, "-dailyClearance.resetState", "-dailyClearance.resetHomeState",
                "-dailyClearance.fixture=selection", "-dailyClearance.fixtureSettled"]
            app.launchEnvironment["CONTROL_LAYOUT_PROBE"] = "drag"
            app.launch()
            let more = page == "silu" ? "silu.more" : "freeplay.moreMenu"
            let camera = page == "silu" ? "silu.cameraMode" : "freeplay.cameraMode"
            ready(more).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            if ready(camera).value as? String != "2D" { ready(camera).tap() }
            XCTAssertEqual(ready(camera).value as? String, "2D")
            if page == "silu" { ready("silu.dismissMenu").tap() }
            else { app.buttons["关闭菜单"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).tap() }
            let primary = ready(page == "silu" ? "silu.strike" : "dailyClearance.strike")
            let original = primary.frame
            let wasEnabled = primary.isEnabled
            let speed = ready("shotStage.powerBar").value as? String
            let stage = ready(page == "silu" ? "table.scene" : "freeplay.stage").frame
            let drag = ready("controlLayout.drag.primary")
            let start = drag.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 20)))
            XCTAssertGreaterThan(primary.frame.minY, original.minY + 0.5)
            XCTAssertEqual(primary.frame.minX, original.minX, accuracy: 0.5)
            XCTAssertLessThanOrEqual(primary.frame.maxY, app.windows.firstMatch.frame.maxY)
            let otherID = page == "silu" ? "silu.tool" : "shotStage.aimWheel"
            let other = ready(otherID); let otherY = other.frame.minY
            let group = ready(page == "silu" ? "controlLayout.drag.planning" : "controlLayout.drag.direction")
            let otherStart = group.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            otherStart.press(forDuration: 0.1, thenDragTo: otherStart.withOffset(CGVector(dx: 0, dy: -20)))
            XCTAssertLessThan(other.frame.minY, otherY - 0.5)
            try capture(page + "-drag-base")
            let accepted = primary.frame
            let invalid = drag.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            invalid.press(forDuration: 0.1, thenDragTo: invalid.withOffset(CGVector(dx: 0, dy: -200)))
            XCTAssertEqual(primary.frame, accepted)
            XCTAssertTrue((ready("controlLayout.geometry").value as? String)?.contains("dropRejected=true") == true)
            XCTAssertEqual(primary.isEnabled, wasEnabled)
            XCTAssertEqual(ready("shotStage.powerBar").value as? String, speed)
            XCTAssertEqual(ready(page == "silu" ? "table.scene" : "freeplay.stage").frame, stage)
            try capture(page + "-rejected-base")
        }
        XCTAssertEqual(rows.count, 4)
    }

}
