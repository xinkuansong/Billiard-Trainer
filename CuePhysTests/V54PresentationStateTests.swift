import XCTest
@testable import QiuJi

final class V54PresentationStateTests: XCTestCase {
    func test_planDetailPrimaryActions_coverFourStates() {
        XCTAssertEqual(
            PlanDetailPrimaryAction.resolve(
                recordStatus: nil, isCurrentPlanActive: false, hasAnotherActivePlan: false
            ),
            .start
        )
        XCTAssertEqual(
            PlanDetailPrimaryAction.resolve(
                recordStatus: "paused", isCurrentPlanActive: false, hasAnotherActivePlan: true
            ),
            .switchPlan
        )
        XCTAssertEqual(
            PlanDetailPrimaryAction.resolve(
                recordStatus: "active", isCurrentPlanActive: true, hasAnotherActivePlan: false
            ),
            .arrangeToday
        )
        XCTAssertEqual(
            PlanDetailPrimaryAction.resolve(
                recordStatus: "completed", isCurrentPlanActive: false, hasAnotherActivePlan: true
            ),
            .review
        )
    }

    func test_planLessonStates_coverCurrentCompletedPreviewAndNotStarted() {
        let completed: Set<String> = ["lesson-1", "lesson-4"]
        XCTAssertEqual(state("lesson-3", ordinal: 2, completed: completed), .current)
        XCTAssertEqual(state("lesson-1", ordinal: 0, completed: completed), .completed)
        XCTAssertEqual(state("lesson-4", ordinal: 3, completed: completed), .previewed)
        XCTAssertEqual(state("lesson-2", ordinal: 1, completed: completed), .notStarted)
    }

    func test_sourceBreadcrumb_usesFrozenCopyAndDeletionOnlyChangesNavigation() throws {
        let existing = try XCTUnwrap(TrainingSourceBreadcrumbModel.make(
            sourceKind: TodayScheduleSourceKind.officialLesson,
            title: "中袋定杆",
            subtitle: "准度基础 · 第 2 课",
            sourceExists: true
        ))
        let deleted = try XCTUnwrap(TrainingSourceBreadcrumbModel.make(
            sourceKind: TodayScheduleSourceKind.officialLesson,
            title: "中袋定杆",
            subtitle: "准度基础 · 第 2 课",
            sourceExists: false
        ))

        XCTAssertEqual(existing.text, "官方计划 › 准度基础 · 第 2 课 › 中袋定杆")
        XCTAssertEqual(existing.text, deleted.text)
        XCTAssertTrue(existing.isNavigable)
        XCTAssertFalse(deleted.isNavigable)
    }

    func test_sourceBreadcrumb_supportsTemplateAndLibrary() {
        XCTAssertEqual(
            TrainingSourceBreadcrumbModel.make(
                sourceKind: TodayScheduleSourceKind.template,
                title: "赛前热身",
                subtitle: nil,
                sourceExists: true
            )?.text,
            "我的模版 › 赛前热身"
        )
        XCTAssertEqual(
            TrainingSourceBreadcrumbModel.make(
                sourceKind: TodayScheduleSourceKind.libraryDrill,
                title: "直线球",
                subtitle: nil,
                sourceExists: true
            )?.text,
            "动作库 › 直线球"
        )
    }

    private func state(
        _ id: String,
        ordinal: Int,
        completed: Set<String>
    ) -> PlanLessonDisplayState {
        PlanLessonDisplayState.resolve(
            lessonID: id,
            lessonOrdinal: ordinal,
            currentLessonID: "lesson-3",
            currentOrdinal: 2,
            planRecordStatus: "active",
            completedLessonIDs: completed
        )
    }
}
