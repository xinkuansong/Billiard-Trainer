import XCTest
@testable import QiuJi

/// 球理索引目录 + vendored contracts 的不变量（问题集合 v30 W0，W1 按 X-v30-2 更新）。
///
/// 这里守三件事：
/// 1. vendored `Theory/contracts/*.json` 确实进了 App Bundle（`Bundle.main` 能解析出子目录）；
/// 2. 索引页副标题的取材纪律——**X-v30-2 裁定后**由「必须是原文连续子串」放宽为
///    「语义等价的限定改写」。放宽不等于放开，本文件用四道仍有约束力的断言替代原来的子串断言：
///    - `testSubtitleNumbersAndUnitsComeFromContracts`：副标题里出现的每个数值 + 单位
///      必须在来源串里逐字出现（改写不得改数、不得换单位、不得凭空造数）；
///    - `testSubtitlesKeepSemanticAnchors`：每条钉死若干**语义锚词**（适用条件 / 关键限定词 /
///      被改写术语的规范中文名），改写不得把断言的核心条件写丢或写偏；
///    - `testSubtitlesUseNoLatinLetters`：不得再出现英文术语（X-v30-2 要解决的问题本身）；
///    - `testRewriteInventoryMatchesDocumentedDecision`：「哪几条是逐字、哪几条是改写」
///      必须与文档记录的清单**完全一致**——逐字条目被偷偷改写、或改写条目被悄悄回退，都会失败。
///    取舍记录（原文 → 改写 → 依据）：`docs/research/20260807-v30理论转写模板.md` §六。
/// 3. 上线状态与详情页注册的成对维护（`testPublishedEntriesMatchRegisteredDestinations`）。
final class TheoryCatalogTests: XCTestCase {

    // MARK: - 文档化的取材决策清单（改副标题时必须同步改这里 + 转写模板 §六）

    /// 副标题**逐字**取自来源串（连续子串）的条目。
    private static let verbatimSubtitleIDs: Set<TheoryPageID> = [.t05, .t07]

    /// 副标题为**语义等价改写**的条目（X-v30-2 裁定允许）。
    private static let rewrittenSubtitleIDs: Set<TheoryPageID> = [
        .t01, .t02, .t03, .t04, .t06, .t08, .t09, .t10, .flow,
    ]

    /// 速查表的来源是 16 `quick-reference.md`（未 vendor，不进 Bundle），
    /// 无法在测试里比对来源串，故不参与取材类断言（取舍记录仍在转写模板 §六）。
    private static let subtitleSourceUnavailableIDs: Set<TheoryPageID> = [.quickRef]

    /// 已在 `MainTabView.theoryDestination` 注册详情页的条目（v30 W1 试点两篇）。
    ///
    /// `theoryDestination` 是 `MainTabView` 的 private 方法，测试无法直接读那个 switch；
    /// 这里用文档化清单守住**成对维护**纪律：新上线一页时，必须同时改
    /// switch、`isPublished` 与本清单，漏一处就红。
    private static let registeredPageIDs: Set<TheoryPageID> = [
        .t01, .t02, .t03, .t04, .t08, .t09,
    ]

    /// 每条副标题必须保住的语义锚词（适用条件 / 关键限定词 / 规范中文术语）。
    private static let semanticAnchors: [TheoryPageID: [String]] = [
        .t01: ["自然滚动", "厚度", "切角", "30°"],
        .t02: ["滑动", "分离角", "90°"],
        .t03: ["碰撞瞬间", "切线", "垂直", "连心线", "旋转"],
        .t04: ["9 档", "出杆长度"],
        .t05: ["最后一颗球", "倒推"],
        .t06: ["关键球"],
        .t07: ["球团", "尽早"],
        .t08: ["三问", "进球把握", "走位把握", "代价"],
        .t09: ["加塞", "挤偏", "弧线", "投掷"],
        .t10: ["3 个独立维度", "距离", "库位", "障碍球"],
        .flow: ["上台", "顺序"],
        .quickRef: ["5 分钟"],
    ]

    // MARK: - Bundle packaging

    private func contractURL(_ name: String) throws -> URL {
        let url = Bundle.main.url(
            forResource: name,
            withExtension: "json",
            subdirectory: "Theory/contracts"
        )
        return try XCTUnwrap(url, "Theory/contracts/\(name).json 未进 App Bundle")
    }

    func testVendoredContractsArePackagedAndDecodable() throws {
        for name in ["theorem-tags", "module-tags", "run-out-flow"] {
            let url = try contractURL(name)
            let object = try JSONSerialization.jsonObject(
                with: try Data(contentsOf: url)
            ) as? [String: Any]
            let json = try XCTUnwrap(object, "\(name).json 不是 JSON 对象")
            XCTAssertEqual(json["schema_version"] as? String, "1.1.0", "\(name) schema 版本漂移")
            XCTAssertEqual(json["theory_version"] as? String, "v1.0-rc3", "\(name) 理论版本漂移")
        }
    }

    // MARK: - Catalog invariants

    func testCatalogCoversEveryPageIdExactlyOnce() {
        XCTAssertEqual(TheoryCatalog.entries.count, TheoryPageID.allCases.count)
        XCTAssertEqual(TheoryCatalog.entries.count, 12)
        XCTAssertEqual(Set(TheoryCatalog.entries.map(\.id)).count, TheoryCatalog.entries.count)
        for id in TheoryPageID.allCases {
            XCTAssertNotNil(TheoryCatalog.entry(for: id), "\(id.rawValue) 未登记进索引目录")
        }
    }

    func testCatalogTitlesAndSubtitlesAreNonEmpty() {
        for entry in TheoryCatalog.entries {
            XCTAssertFalse(entry.title.isEmpty, "\(entry.id.rawValue) 标题为空")
            XCTAssertFalse(entry.subtitle.isEmpty, "\(entry.id.rawValue) 副标题为空")
        }
    }

    func testGroupedEntriesPreserveAllEntries() {
        let grouped = TheoryCatalog.groupedEntries.flatMap(\.entries)
        XCTAssertEqual(Set(grouped.map(\.id)), Set(TheoryCatalog.entries.map(\.id)))
    }

    /// 上线状态与详情页注册**成对维护**（组件规范 §一「注册点 A / B」）。
    func testPublishedEntriesMatchRegisteredDestinations() {
        let published = Set(TheoryCatalog.entries.filter(\.isPublished).map(\.id))
        XCTAssertEqual(
            published,
            Self.registeredPageIDs,
            "isPublished 与已注册详情页清单不一致——注册 destination / 改 isPublished / 更新本测试清单必须三处同步"
        )
    }

    // MARK: - 副标题来源

    /// 每条副标题的来源串（定理取 `statement_one_liner`，流程取 `run-out-flow.description`）。
    private func subtitleSources() throws -> [TheoryPageID: String] {
        var sources: [TheoryPageID: String] = [:]

        let theoremData = try Data(contentsOf: try contractURL("theorem-tags"))
        let theoremRoot = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: theoremData) as? [String: Any]
        )
        let theorems = try XCTUnwrap(theoremRoot["theorems"] as? [[String: Any]])
        var oneLiners: [String: String] = [:]
        for theorem in theorems {
            if let id = theorem["id"] as? String,
               let line = theorem["statement_one_liner"] as? String {
                oneLiners[id] = line
            }
        }
        XCTAssertEqual(oneLiners.count, 10, "vendored contracts 定理条目数变了")

        for id in TheoryPageID.allCases {
            guard let theoremId = id.theoremId else { continue }
            sources[id] = try XCTUnwrap(oneLiners[theoremId], "\(theoremId) 不在 vendored contracts 中")
        }

        let flowData = try Data(contentsOf: try contractURL("run-out-flow"))
        let flowRoot = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: flowData) as? [String: Any]
        )
        sources[.flow] = try XCTUnwrap(flowRoot["description"] as? String)

        return sources
    }

    /// 逐字条目必须仍然是来源串的连续子串（原纪律对这几条不放宽）。
    func testVerbatimSubtitlesRemainVerbatimSubstrings() throws {
        let sources = try subtitleSources()
        for id in Self.verbatimSubtitleIDs {
            let entry = try XCTUnwrap(TheoryCatalog.entry(for: id))
            let source = try XCTUnwrap(sources[id], "\(id.rawValue) 没有可比对的来源串")
            XCTAssertTrue(
                source.contains(entry.subtitle),
                "\(id.rawValue) 登记为逐字取材，但已不是来源串的连续子串：\n  副标题=\(entry.subtitle)\n  原文=\(source)"
            )
        }
    }

    /// 「逐字 / 改写」清单必须与文档记录一致：任一条目悄悄换阵营都会失败。
    func testRewriteInventoryMatchesDocumentedDecision() throws {
        let sources = try subtitleSources()
        var actualVerbatim: Set<TheoryPageID> = []
        var actualRewritten: Set<TheoryPageID> = []

        for entry in TheoryCatalog.entries {
            if Self.subtitleSourceUnavailableIDs.contains(entry.id) { continue }
            let source = try XCTUnwrap(sources[entry.id], "\(entry.id.rawValue) 没有可比对的来源串")
            if source.contains(entry.subtitle) {
                actualVerbatim.insert(entry.id)
            } else {
                actualRewritten.insert(entry.id)
            }
        }

        XCTAssertEqual(
            actualVerbatim,
            Self.verbatimSubtitleIDs,
            "逐字取材条目集合变了——改副标题取材方式必须同步更新本清单与转写模板 §六 取舍记录"
        )
        XCTAssertEqual(
            actualRewritten,
            Self.rewrittenSubtitleIDs,
            "改写条目集合变了——改副标题取材方式必须同步更新本清单与转写模板 §六 取舍记录"
        )
    }

    /// 改写不得动数：副标题里的每个「数值 + 单位」必须在来源串里逐字出现。
    ///
    /// 这是 X-v30-2 放宽后替代「连续子串」的核心量化约束——允许换措辞，
    /// 不允许改 `14°–49°`、`~30°`、`9 档` 这类数值与单位，也不允许凭空造出新数字。
    func testSubtitleNumbersAndUnitsComeFromContracts() throws {
        let sources = try subtitleSources()
        let pattern = try NSRegularExpression(pattern: "\\d+(?:\\.\\d+)?[°%]?")

        for entry in TheoryCatalog.entries {
            if Self.subtitleSourceUnavailableIDs.contains(entry.id) { continue }
            let source = try XCTUnwrap(sources[entry.id])
            let subtitle = entry.subtitle
            let range = NSRange(subtitle.startIndex..<subtitle.endIndex, in: subtitle)
            for match in pattern.matches(in: subtitle, range: range) {
                guard let tokenRange = Range(match.range, in: subtitle) else { continue }
                let token = String(subtitle[tokenRange])
                XCTAssertTrue(
                    source.contains(token),
                    "\(entry.id.rawValue) 副标题出现来源串里没有的数值「\(token)」：\n  副标题=\(subtitle)\n  原文=\(source)"
                )
            }
        }
    }

    /// 改写不得把断言的核心条件写丢：逐条钉死语义锚词。
    func testSubtitlesKeepSemanticAnchors() throws {
        for entry in TheoryCatalog.entries {
            let anchors = try XCTUnwrap(
                Self.semanticAnchors[entry.id],
                "\(entry.id.rawValue) 缺语义锚词登记"
            )
            XCTAssertFalse(anchors.isEmpty, "\(entry.id.rawValue) 语义锚词为空")
            for anchor in anchors {
                XCTAssertTrue(
                    entry.subtitle.contains(anchor),
                    "\(entry.id.rawValue) 副标题丢了语义锚词「\(anchor)」：\(entry.subtitle)"
                )
            }
        }
    }

    /// X-v30-2 的目标本身：用户可见副标题不再出现英文术语。
    func testSubtitlesUseNoLatinLetters() {
        for entry in TheoryCatalog.entries {
            let latin = entry.subtitle.unicodeScalars.filter {
                (0x41...0x5A).contains($0.value) || (0x61...0x7A).contains($0.value)
            }
            XCTAssertTrue(
                latin.isEmpty,
                "\(entry.id.rawValue) 副标题仍含英文字母 \(latin.map(String.init).joined())：\(entry.subtitle)"
            )
        }
    }

    // MARK: - 用户可见文案纪律（红线 3：编号不进正文措辞）

    func testUserFacingCopyDoesNotExposeTheoremNumbers() {
        let pattern = try? NSRegularExpression(pattern: "\\b[TM]\\d{2}\\b")
        for entry in TheoryCatalog.entries {
            for text in [entry.title, entry.subtitle] {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                let hits = pattern?.numberOfMatches(in: text, range: range) ?? 0
                XCTAssertEqual(hits, 0, "\(entry.id.rawValue) 的用户可见文案出现定理编号：\(text)")
            }
        }
    }
}
