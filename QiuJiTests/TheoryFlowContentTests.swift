import XCTest
@testable import QiuJi

/// v30 W4 两篇（清台 5 步决策流程 / 清台速查手册）的内容不变量。
///
/// 守两件事：
/// 1. **数值纪律**（转写模板 §2.4）：流程页硬编码的时间预算，必须与仓内 vendored
///    `Theory/contracts/run-out-flow.json` 的 `duration_target_s` / `time_budget_seconds`
///    逐项相等。D-v30-1 裁定运行时不读 JSON，所以这层比对是唯一能防数值漂移的护栏。
/// 2. **速查表深链**：每条速记都必须指向一个**已上线**的球理页，且标题取自
///    `TheoryCatalog`（页名三处逐字一致）；11 篇一条不漏、一条不重。
final class TheoryFlowContentTests: XCTestCase {

    // MARK: - vendored contract

    private func runOutFlowJSON() throws -> [String: Any] {
        let url = try XCTUnwrap(
            Bundle.main.url(
                forResource: "run-out-flow",
                withExtension: "json",
                subdirectory: "Theory/contracts"
            ),
            "Theory/contracts/run-out-flow.json 未进 App Bundle"
        )
        let object = try JSONSerialization.jsonObject(with: try Data(contentsOf: url))
        return try XCTUnwrap(object as? [String: Any], "run-out-flow.json 不是 JSON 对象")
    }

    func testFlowStepDurationsMatchVendoredContract() throws {
        let root = try runOutFlowJSON()
        let states = try XCTUnwrap(root["states"] as? [[String: Any]])
        XCTAssertEqual(states.count, 5, "流程状态数变了")
        XCTAssertEqual(TheoryFlowTimeBudget.steps.count, states.count, "硬编码步骤数与 contracts 不一致")

        for (index, state) in states.enumerated() {
            let step = TheoryFlowTimeBudget.steps[index]
            XCTAssertEqual(state["id"] as? String, step.stateId, "第 \(index + 1) 步顺序 / id 漂移")

            let durations = try XCTUnwrap(state["duration_target_s"] as? [String: Any])
            XCTAssertEqual(durations["novice"] as? Int, step.novice, "\(step.stateId) 新手用时漂移")
            XCTAssertEqual(durations["intermediate"] as? Int, step.intermediate, "\(step.stateId) 进阶用时漂移")
            XCTAssertEqual(durations["expert"] as? Int, step.expert, "\(step.stateId) 高手用时漂移")
        }
    }

    func testFlowTotalsMatchVendoredContract() throws {
        let root = try runOutFlowJSON()
        let budget = try XCTUnwrap(root["time_budget_seconds"] as? [String: Any])
        XCTAssertEqual(budget["novice"] as? Int, TheoryFlowTimeBudget.noviceTotal)
        XCTAssertEqual(budget["intermediate"] as? Int, TheoryFlowTimeBudget.intermediateTotal)
        XCTAssertEqual(budget["expert"] as? Int, TheoryFlowTimeBudget.expertTotal)
        // 上屏的三个总数（80 / 43 / 28）来自这三项求和，钉死防止改错某一步后总数悄悄变。
        XCTAssertEqual(TheoryFlowTimeBudget.noviceTotal, 80)
        XCTAssertEqual(TheoryFlowTimeBudget.intermediateTotal, 43)
        XCTAssertEqual(TheoryFlowTimeBudget.expertTotal, 28)
    }

    /// 步骤名不得把 contracts 的工程字段名 / 英文名带上屏（红线 3）。
    func testFlowStepNamesAreChineseOnly() {
        for step in TheoryFlowTimeBudget.steps {
            let latin = step.name.unicodeScalars.filter {
                (0x41...0x5A).contains($0.value) || (0x61...0x7A).contains($0.value)
            }
            XCTAssertTrue(latin.isEmpty, "步骤名「\(step.name)」含英文字母")
            XCTAssertFalse(step.name.contains("_"), "步骤名不得带 contracts 字段风格的下划线")
        }
    }

    // MARK: - 速查表深链

    func testQuickRefLinksCoverEveryOtherPageExactlyOnce() {
        let linked = TheoryQuickRefView.allRows.map(\.page)
        let expected = TheoryPageID.allCases.filter { $0 != .quickRef }
        XCTAssertEqual(
            Set(linked), Set(expected),
            "速查表深链必须恰好覆盖除本页外的 11 篇"
        )
        XCTAssertEqual(linked.count, Set(linked).count, "速查表深链有重复条目")
    }

    func testQuickRefLinksPointToPublishedPages() throws {
        for row in TheoryQuickRefView.allRows {
            let entry = try XCTUnwrap(
                TheoryCatalog.entry(for: row.page),
                "\(row.page.rawValue) 不在索引目录里"
            )
            XCTAssertTrue(
                entry.isPublished,
                "速查表不得链到未上线的「\(entry.title)」（会落死链）"
            )
            XCTAssertFalse(row.line.isEmpty, "\(row.page.rawValue) 的速记为空")
        }
    }

    /// 速记行同样受红线 3 约束：不得出现定理 / 模块编号。
    func testQuickRefLinesDoNotExposeTheoremNumbers() throws {
        let pattern = try NSRegularExpression(pattern: "\\b[TM]\\d{2}\\b")
        for row in TheoryQuickRefView.allRows {
            let range = NSRange(row.line.startIndex..<row.line.endIndex, in: row.line)
            XCTAssertEqual(
                pattern.numberOfMatches(in: row.line, range: range), 0,
                "速查表条目出现定理编号：\(row.line)"
            )
        }
    }
}
