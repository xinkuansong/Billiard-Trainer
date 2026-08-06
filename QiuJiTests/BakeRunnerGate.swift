//
//  BakeRunnerGate.swift
//  QiuJiTests
//
//  烘焙 / 出片 runner 的统一开关（问题集合 v29 W1）。
//
//  背景：`DrillThumbnailBakeRunnerTests` / `V21W{2,3,4}BakeTests` /
//  `PositionPlaySequenceExportRunnerTests` / `DrillBakeRunnerTests` 都是「内容生产
//  跑测」而非回归测试——它们会长跑全量物理，前几个还会写 git 跟踪的
//  `QiuJi/Resources/DrillThumbnails/*.png` 与 `QiuJi/Resources/Drills/**/*.json`。
//  随常规全量 `QiuJiTests` 跑会污染工作区，故统一加门：**环境变量未设置时 XCTSkip**。
//
//  开门方式（make 目标已代劳，两路并存）：
//    - 标志文件 `build/.run-bake-runners`（仓库根，支持 worktree）——**make 目标实际生效的一路**；
//    - 环境变量 `QIUJI_RUN_BAKE_RUNNERS=1`——从 Xcode 跑（scheme 环境变量）时生效。
//  实测（2026-08-06，Xcode 16 / iOS 26.2 模拟器）：`xcodebuild test ... TEST_RUNNER_XXX=1`
//  **传不进**宿主 App 内的单测进程（本仓 `PositionPlaySequenceExportRunnerTests` 早有同样记录），
//  故标志文件是确定性的那一路，与既有 `.stills-only` / `.resume` 同范式。
//

import Foundation
import XCTest

enum BakeRunnerGate {

    /// 环境变量名（make 目标以 `TEST_RUNNER_` 前缀传入）。
    static let environmentKey = "QIUJI_RUN_BAKE_RUNNERS"

    /// 标志文件（相对仓库根）。
    static let flagFileRelativePath = "build/.run-bake-runners"

    /// 仓库根（由本文件路径推导，天然支持 git worktree）。
    static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // QiuJiTests/
            .deletingLastPathComponent()   // <repo root>
    }

    static var isEnabled: Bool {
        if ProcessInfo.processInfo.environment[environmentKey] == "1" { return true }
        let flag = repositoryRoot.appendingPathComponent(flagFileRelativePath)
        return FileManager.default.fileExists(atPath: flag.path)
    }

    /// 未开门时跳过当前测试。
    static func skipUnlessEnabled(_ runner: String,
                                  file: StaticString = #filePath,
                                  line: UInt = #line) throws {
        try XCTSkipUnless(
            isEnabled,
            """
            \(runner) 是烘焙/出片 runner，不随常规测试跑。\
            开门方式：`cd scripts && make thumbnails`（或其他 runner 的 make 目标），\
            或设置 \(environmentKey)=1 / 放置 \(flagFileRelativePath) 标志文件。
            """,
            file: file, line: line
        )
    }

    /// 缩略图输出目录：优先环境变量注入，否则取本仓 `QiuJi/Resources/DrillThumbnails`。
    static var thumbnailOutputDirectory: URL {
        if let injected = ProcessInfo.processInfo.environment["QIUJI_THUMBNAIL_OUTPUT_DIR"],
           !injected.isEmpty {
            return URL(fileURLWithPath: injected, isDirectory: true)
        }
        return repositoryRoot.appendingPathComponent("QiuJi/Resources/DrillThumbnails",
                                                     isDirectory: true)
    }
}
