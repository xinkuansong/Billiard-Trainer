//
//  DrillTryoutBoardStore.swift
//  QiuJi
//
//  动作库试打球形加载器（方案 20260709-动作库试打模式 D4：与视频示范同源）。
//
//  数据源：App Bundle `DrillBoards/`——由 `make tryout-sync` 从
//  `content/position_play/sequences/`（批量出片台产出、视频示范渲染源）同步而来，
//  文件即 `PositionPlaySequence` JSON 原样。序列更新后重跑同步命令即可刷新。
//
//  文件名两种式样（与 `BatchSequenceArchive` 归档约定一致）：
//  - 多球形：`drill_cNNN__<token>-<名称>-<N>杆.json`（token 不含「-」）
//  - 旧式单序列：`drill_cNNN-<名称>-<N>杆.json`
//
//  坐标契约：序列 `initial.onTable` 与 `BoardSnapshot` 同为归一化 2D 系
//  （x∈[0,1] 左→右、y∈[0,0.5] 上→下），恒等直传，零轴向变换。
//

import Foundation

/// 一个可试打的球形（= 一条出片序列的初始布局 + 首杆参考意图）。
struct DrillTryoutFormation: Identifiable {
    /// 球形去重 token（旧式单序列为空串）。
    let token: String
    /// 序列名（选择列表显示，例「初级蛇彩走位 · 球形2」）。
    let title: String
    /// Bundle 内文件名（稳定排序与 id 用）。
    let fileName: String
    /// 初始布局（试打摆球 + 「重摆球形」回退目标）。
    let initial: BoardSnapshot
    /// 序列杆数（说明卡「共 N 杆」与选择列表副标题）。
    let stepCount: Int
    /// 首杆意图（说明卡「局面目标/参考打法」；空序列为 nil）。
    let firstShot: PlannedShot?

    var id: String { fileName }
}

/// 从 Bundle `DrillBoards/` 加载 drill 的试打球形集合。
enum DrillTryoutBoardStore {

    static let bundleSubdirectory = "DrillBoards"

    /// 某 drill 的全部球形，按文件名稳定排序；无序列文件返回空数组
    /// （调用侧回退 `DrillBoardBuilder` 的 shotIntent 路径）。
    static func formations(for drillId: String, bundle: Bundle = .main) -> [DrillTryoutFormation] {
        let urls = bundle.urls(
            forResourcesWithExtension: "json", subdirectory: bundleSubdirectory
        ) ?? []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return urls
            .filter { belongs($0.lastPathComponent, to: drillId) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let sequence = try? decoder.decode(PositionPlaySequence.self, from: data),
                      !sequence.initial.onTable.isEmpty
                else { return nil }
                return DrillTryoutFormation(
                    token: token(fromFileName: url.lastPathComponent, drillId: drillId),
                    title: sequence.name,
                    fileName: url.lastPathComponent,
                    initial: sequence.initial,
                    stepCount: sequence.steps.count,
                    firstShot: sequence.steps.first?.shot
                )
            }
    }

    // MARK: - 文件名解析

    /// 文件是否属于该 drill：`drill_cNNN__…` 或 `drill_cNNN-…`（前缀后必须紧跟
    /// 分隔符，避免 `drill_c04` 误匹配 `drill_c042`）。
    static func belongs(_ fileName: String, to drillId: String) -> Bool {
        fileName.hasPrefix("\(drillId)__") || fileName.hasPrefix("\(drillId)-")
    }

    /// 提取球形 token：多球形式样取 `__` 与下一个「-」之间的段；旧式单序列返回空串。
    static func token(fromFileName fileName: String, drillId: String) -> String {
        let multiPrefix = "\(drillId)__"
        guard fileName.hasPrefix(multiPrefix) else { return "" }
        let rest = fileName.dropFirst(multiPrefix.count)
        return String(rest.prefix(while: { $0 != "-" }))
    }
}
