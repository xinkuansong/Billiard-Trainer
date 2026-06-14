import Foundation

#if targetEnvironment(simulator)
/// 录制序列直写仓库内容库（ADR-P11-10）：模拟器进程以宿主用户身份运行、可直接写 Mac
/// 文件系统，录制结束后把序列 JSON 写入 `content/position_play/sequences/`（真相源，进 git），
/// 省去 share sheet → AirDrop → 手动归档的搬运。仅模拟器构建编译，真机/发布版不含此代码。
enum PositionPlaySequenceArchive {

    /// 仓库内容库目录（与 `PositionPlaySequenceExportRunnerTests` 同一硬编码仓库路径约定）。
    static let directory = "/Users/song/projects/13.billiard_trainer/content/position_play/sequences"

    /// 写入序列 JSON，返回落盘 URL。文件名 `seq_<id8>-<名称>-<N>杆.json`；
    /// `seq_<id8>` 为稳定资产键（与 `PositionPlayDrillExporter` 的 `drill_pp_<id8>` 对齐），
    /// 后续 mp4/gif/png 产物沿用同名前缀。编码策略与离线 runner 的解码（iso8601）对齐。
    /// 同一序列（同 `seq_<id8>`）重复归档（如录制结束后重命名）会先清掉旧文件名的版本。
    static func archive(_ sequence: PositionPlaySequence) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(sequence)

        let fm = FileManager.default
        try fm.createDirectory(atPath: directory, withIntermediateDirectories: true)

        let id8 = sequence.id.uuidString.prefix(8).lowercased()
        let prefix = "seq_\(id8)-"
        // 同一序列的旧文件（旧名字/旧杆数）先移除，保证一条序列只留一份。
        for file in (try? fm.contentsOfDirectory(atPath: directory)) ?? []
        where file.hasPrefix(prefix) {
            try? fm.removeItem(atPath: "\(directory)/\(file)")
        }

        let safeName = sequence.name.replacingOccurrences(of: "/", with: "-")
        let url = URL(fileURLWithPath: directory)
            .appendingPathComponent("\(prefix)\(safeName)-\(sequence.steps.count)杆.json")
        try data.write(to: url)
        return url
    }
}
#endif
