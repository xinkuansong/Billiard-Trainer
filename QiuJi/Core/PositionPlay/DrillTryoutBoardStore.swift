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
//  坐标契约：开局盘面与 `BoardSnapshot` 同为归一化 2D 系
//  （x∈[0,1] 左→右、y∈[0,0.5] 上→下），恒等直传，零轴向变换。
//
//  开局盘面真源：`steps.first?.before ?? initial`（与 `DrillStaticPreview` /
//  `SequenceVideoExporter` 同源）。批量出片台录制常见 `initial` 仅含母球，
//  真实摆球在首杆 `before`；试打若直读 `initial` 会丢目标球（多球形尤其明显）。
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
    /// 完整逐杆序列（Q19.2④ 序列模式逐杆播放；空 = 无多杆数据，序列模式降级）。
    let steps: [SequenceStep]

    var id: String { fileName }

    /// 选球形副标题球数（Q19.2①）：初始在桌目标球数，**不含母球**。
    var objectBallCount: Int {
        initial.onTable.keys.filter { !PositionPlayBall.isCue($0) }.count
    }

    /// 是否具备可逐杆播放的序列（≥1 杆）。
    var hasSequence: Bool { !steps.isEmpty }
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
                      // 0 杆仅占位/摆球样例：试打走 shotIntent 回退（与出片 runner 跳过同口径）。
                      !sequence.steps.isEmpty
                else { return nil }
                // 开局盘面：首杆 before 优先（录制残留 initial 常只有母球）。
                let opening = sequence.steps.first?.before ?? sequence.initial
                guard !opening.onTable.isEmpty else { return nil }
                return DrillTryoutFormation(
                    token: token(fromFileName: url.lastPathComponent, drillId: drillId),
                    title: sequence.name,
                    fileName: url.lastPathComponent,
                    initial: opening,
                    stepCount: sequence.steps.count,
                    firstShot: sequence.steps.first?.shot,
                    steps: sequence.steps
                )
            }
    }

    /// 列表/缩略图门面球形：`preferredToken`（profile.representative）→ `A1` →
    /// 旧式无 token 单文件 → 最低编号 `A*` → 否则才落到 `manual*` / 其它。
    /// 禁止在存在 `A*` / legacy 时误选 Snipaste/manual 扫目录首项。
    static func representative(
        from formations: [DrillTryoutFormation],
        preferredToken: String? = nil
    ) -> DrillTryoutFormation? {
        guard !formations.isEmpty else { return nil }
        if let preferredToken, !preferredToken.isEmpty,
           let hit = formations.first(where: { $0.token == preferredToken }) {
            return hit
        }
        if let a1 = formations.first(where: { $0.token == "A1" }) { return a1 }
        if let legacy = formations.first(where: { $0.token.isEmpty }) { return legacy }
        let aRanked = formations
            .compactMap { f -> (DrillTryoutFormation, Int)? in
                guard f.token.count >= 2, f.token.first == "A",
                      let n = Int(f.token.dropFirst()) else { return nil }
                return (f, n)
            }
            .sorted { $0.1 < $1.1 }
        if let first = aRanked.first?.0 { return first }
        if let manual = formations.first(where: { $0.token.hasPrefix("manual") }) {
            return manual
        }
        return formations.first
    }

    /// Convenience: load + pick representative for a drill id.
    static func representative(
        for drillId: String,
        preferredToken: String? = nil,
        bundle: Bundle = .main
    ) -> DrillTryoutFormation? {
        representative(from: formations(for: drillId, bundle: bundle),
                       preferredToken: preferredToken)
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
