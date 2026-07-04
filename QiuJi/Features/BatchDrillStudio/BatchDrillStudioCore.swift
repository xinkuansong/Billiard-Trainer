//
//  BatchDrillStudioCore.swift
//  QiuJi
//
//  批量 Drill 出片工作台（仅模拟器，内容生产工具，ADR-P11-10 同源）。
//
//  目标：把「62 个 drill 文件夹的截图 → 走位序列 JSON → 教学素材」流水线里
//  「逐张手动上传」这一瓶颈自动化——直接从项目 15 的 `shooterpools录制/drill_NNN/`
//  目录加载截图，旋转 90°（横屏截图 → 竖版真台），人工标定建球形，再进
//  「编排 + 求解二合一」工具产出击打序列，最后按 **drill_cNNN** 稳定键直写内容库，
//  供 `make position-export` 出片、并经 `drill_cNNN_*` 资产名进入精讲页面。
//
//  仅模拟器编译：模拟器进程以宿主用户身份运行、可直读/直写 Mac 文件系统。
//

#if targetEnvironment(simulator)
import Foundation
import SwiftUI
import UIKit

// MARK: - Drill 映射目录

/// 一个待出片的 drill：源截图目录 + 映射后的 App 端 drill 标识。
struct BatchDrill: Identifiable, Hashable {
    /// 源文件夹名（项目 15），形如 `drill_042`。
    let folderName: String
    /// App 端稳定标识（`drill_cNNN`，= 文件夹号插入 "c"）。
    let drillId: String
    /// 分类（来自 `index.json`，未登记时 nil）。
    let category: String?
    /// 中文名（来自 catalog/已存在的 drill JSON，可空）。
    let nameZh: String?
    /// 该 drill 文件夹下的截图（png/jpg），按文件名排序。
    let imageURLs: [URL]
    /// 是否已在 `index.json` 登记（未登记 → 出片仍可，但精讲页接不上，给警告）。
    let isRegistered: Bool
    /// 已落库球形 token 集合（每张图 = 一个球形，token = 该图 `formationToken`；
    /// 旧版单序列文件以 "" 占位）。
    var savedStems: Set<String>

    /// 一张图算一个球形：每张图各产一条独立序列；同图重存覆盖、异图并存。
    var id: String { drillId }
    var displayTitle: String { nameZh.map { "\(drillId) · \($0)" } ?? drillId }
    /// 该 drill 是否已存至少一个球形（完成判定：≥1，不要求每张图都存）。
    var hasSavedSequence: Bool { !savedStems.isEmpty }
    /// 已落库球形数（含旧版占位）。
    var savedFormationCount: Int { savedStems.count }
    /// 某张图是否已存球形。
    func isImageSaved(_ url: URL) -> Bool {
        savedStems.contains(BatchDrillCatalog.formationToken(forImage: url))
    }
}

/// 扫描源目录、映射 drill 标识、读取 `index.json` 与内容库状态。
enum BatchDrillCatalog {

    /// 项目 15 截图根目录（与录制 spec 约定一致）。
    static let sourceRoot =
        "/Users/song/projects/15.tutorial_video/shooterpools录制"

    /// App 资源 `index.json`（drill_cNNN → category 真源）。
    static let indexJSONPath =
        "/Users/song/projects/13.billiard_trainer/QiuJi/Resources/Drills/index.json"

    /// 已落库序列目录（与 `BatchSequenceArchive.directory` 同一处）。
    static let sequencesDir =
        "/Users/song/projects/13.billiard_trainer/content/position_play/sequences"

    private static let imageExts: Set<String> = ["png", "jpg", "jpeg", "heic"]

    /// 文件夹名 `drill_042` → App 标识 `drill_c042`（按号插入 "c"，保号宽度）。
    static func mapToDrillId(folderName: String) -> String? {
        let prefix = "drill_"
        guard folderName.hasPrefix(prefix) else { return nil }
        let num = folderName.dropFirst(prefix.count)
        guard !num.isEmpty, num.allSatisfy(\.isNumber) else { return nil }
        return "drill_c\(num)"
    }

    /// 图片 → 球形去重 token（同一张图稳定不变，作 `drill_cNNN__<token>` 文件键）。
    /// 截图名形如 `Snipaste_2026-05-25_22-28-27` 含大量「-」，必须把「-」等分隔符替换掉，
    /// 使 token 不含「-」，文件名 `drill_cNNN__<token>-<名>-<N>杆.json` 才能被可靠回解析。
    static func formationToken(forImageStem stem: String) -> String {
        var t = stem
        for ch in ["-", " ", "/", "\\", ":", "."] {
            t = t.replacingOccurrences(of: ch, with: "_")
        }
        return t.isEmpty ? "main" : t
    }

    static func formationToken(forImage url: URL) -> String {
        formationToken(forImageStem: url.deletingPathExtension().lastPathComponent)
    }

    /// 扫描并构建待出片目录（按 drill 号排序）。
    static func load() -> [BatchDrill] {
        let fm = FileManager.default
        let categoryMap = loadCategoryMap()
        let nameMap = loadDrillNameMap()
        let savedMap = loadSavedFormationMap()

        let folders = (try? fm.contentsOfDirectory(atPath: sourceRoot)) ?? []
        var drills: [BatchDrill] = []
        for folder in folders {
            var isDir: ObjCBool = false
            let full = "\(sourceRoot)/\(folder)"
            guard fm.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue,
                  let drillId = mapToDrillId(folderName: folder) else { continue }

            let images = ((try? fm.contentsOfDirectory(atPath: full)) ?? [])
                .filter { imageExts.contains(($0 as NSString).pathExtension.lowercased()) }
                .sorted()
                .map { URL(fileURLWithPath: "\(full)/\($0)") }
            guard !images.isEmpty else { continue }

            drills.append(BatchDrill(
                folderName: folder,
                drillId: drillId,
                category: categoryMap[drillId],
                nameZh: nameMap[drillId],
                imageURLs: images,
                isRegistered: categoryMap[drillId] != nil,
                savedStems: savedMap[drillId] ?? []
            ))
        }
        return drills.sorted { $0.drillId < $1.drillId }
    }

    /// 重新读取内容库，刷新各 drill 的「已保存球形」集合。
    static func refreshSavedFlags(_ drills: [BatchDrill]) -> [BatchDrill] {
        let saved = loadSavedFormationMap()
        return drills.map { var d = $0; d.savedStems = saved[d.drillId] ?? []; return d }
    }

    // MARK: - index.json / drill JSON 读取

    private struct IndexFile: Decodable {
        struct Cat: Decodable { let category: String; let drills: [String] }
        let categories: [Cat]
    }

    private static func loadCategoryMap() -> [String: String] {
        guard let data = FileManager.default.contents(atPath: indexJSONPath),
              let idx = try? JSONDecoder().decode(IndexFile.self, from: data) else { return [:] }
        var map: [String: String] = [:]
        for cat in idx.categories {
            for id in cat.drills { map[id] = cat.category }
        }
        return map
    }

    private struct DrillNameProbe: Decodable { let id: String; let nameZh: String }

    /// 从已存在的 drill JSON（`Resources/Drills/<category>/<id>.json`）读中文名（best-effort）。
    private static func loadDrillNameMap() -> [String: String] {
        let drillsRoot = "/Users/song/projects/13.billiard_trainer/QiuJi/Resources/Drills"
        let fm = FileManager.default
        var map: [String: String] = [:]
        guard let enumerator = fm.enumerator(atPath: drillsRoot) else { return map }
        for case let rel as String in enumerator where rel.hasSuffix(".json") && !rel.hasSuffix("index.json") {
            let path = "\(drillsRoot)/\(rel)"
            guard let data = fm.contents(atPath: path),
                  let probe = try? JSONDecoder().decode(DrillNameProbe.self, from: data) else { continue }
            map[probe.id] = probe.nameZh
        }
        return map
    }

    /// 扫描内容库，构建 drillId → 已存球形 token 集合。
    /// - 新版文件名：`drill_cNNN__<token>-<名>-<N>杆.json`（token 不含「-」）→ 取 token。
    /// - 旧版文件名：`drill_cNNN-<名>-<N>杆.json`（无 `__`）→ 用 "" 占位（计入完成，但不点亮某张图）。
    private static func loadSavedFormationMap() -> [String: Set<String>] {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: sequencesDir)) ?? []
        var map: [String: Set<String>] = [:]
        for f in files where f.hasPrefix("drill_c") && f.hasSuffix(".json") {
            let name = String(f.dropLast(5))   // 去掉 ".json"
            if let us = name.range(of: "__") {
                let drillId = String(name[..<us.lowerBound])
                let token = String(name[us.upperBound...].prefix { $0 != "-" })
                map[drillId, default: []].insert(token)
            } else if let dash = name.firstIndex(of: "-") {
                // 旧版单序列：取首段作 drillId，"" 占位。
                map[String(name[..<dash]), default: []].insert("")
            }
        }
        return map
    }

    // MARK: - 存档回读（存档 + 在原有基础上修改）

    /// 定位某 drill × 某球形 token 已落库的序列文件（新版 `drill_cNNN__<token>-…`；
    /// token 为 "" 时回退旧版单序列 `drill_cNNN-…`）。
    static func savedSequenceURL(drillId: String, token: String) -> URL? {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: sequencesDir)) ?? []
        if !token.isEmpty {
            let prefix = "\(drillId)__\(token)-"
            if let f = files.first(where: { $0.hasPrefix(prefix) && $0.hasSuffix(".json") }) {
                return URL(fileURLWithPath: "\(sequencesDir)/\(f)")
            }
            return nil
        }
        let legacyPrefix = "\(drillId)-"
        if let f = files.first(where: {
            $0.hasPrefix(legacyPrefix) && !$0.contains("__") && $0.hasSuffix(".json")
        }) {
            return URL(fileURLWithPath: "\(sequencesDir)/\(f)")
        }
        return nil
    }

    /// 读回一条已落库序列（与归档编码策略对齐：iso8601 日期）。
    static func loadSequence(at url: URL) -> PositionPlaySequence? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PositionPlaySequence.self, from: data)
    }

    /// 便捷：直接按 drill + 来源截图取回其已存序列（供「改存档」入口）。
    static func loadSequence(drillId: String, imageURL: URL) -> PositionPlaySequence? {
        let token = formationToken(forImage: imageURL)
        guard let url = savedSequenceURL(drillId: drillId, token: token) else { return nil }
        return loadSequence(at: url)
    }
}

// MARK: - drill 键控序列归档

/// 把序列以 **drill_cNNN × 图片（球形）** 双键直写内容库（区别于编排台的 `seq_<id8>` 随机键）。
/// 一张图 = 一个球形：文件名 `drill_cNNN__<token>-<名称>-<N>杆.json`（token = 该图 `formationToken`）。
/// - 同一张图重复保存 → 覆盖（只删同 `drill_cNNN__<token>-` 旧文件）；
/// - 不同图 → 各自独立并存；
/// - **不触碰**旧版单序列 `drill_cNNN-…`（无 `__`）：它算该 drill 既有的一个球形，
///   保留出片正常；如需淘汰由人工删除，绝不在写新球形时静默删旧（防误删既有成果）。
/// 出片 runner 据文件名定位产物目录，再人工归位为 `drill_cNNN_*` / formations 接入精讲页。
enum BatchSequenceArchive {

    static let directory = BatchDrillCatalog.sequencesDir

    /// - Parameters:
    ///   - imageStem: 来源截图的文件名（不含扩展名），用于派生球形 token。
    ///   - legacy: true = 覆盖旧版单序列存档（`drill_cNNN-…` 无 `__`），保持旧文件名格式；
    ///     这是**作者显式改旧存档**的路径，区别于写新球形时「绝不动旧文件」的默认约定。
    @discardableResult
    static func archive(_ sequence: PositionPlaySequence, drillId: String,
                        imageStem: String, legacy: Bool = false) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(sequence)

        let fm = FileManager.default
        try fm.createDirectory(atPath: directory, withIntermediateDirectories: true)

        let safeName = sequence.name.replacingOccurrences(of: "/", with: "-")

        if legacy {
            // 只覆盖同 drill 的旧版单序列文件（无 `__`），不碰任何新版球形文件。
            for file in (try? fm.contentsOfDirectory(atPath: directory)) ?? []
            where file.hasPrefix("\(drillId)-") && !file.contains("__") && file.hasSuffix(".json") {
                try? fm.removeItem(atPath: "\(directory)/\(file)")
            }
            let url = URL(fileURLWithPath: directory)
                .appendingPathComponent("\(drillId)-\(safeName)-\(sequence.steps.count)杆.json")
            try data.write(to: url)
            return url
        }

        let token = BatchDrillCatalog.formationToken(forImageStem: imageStem)
        let stemPrefix = "\(drillId)__\(token)-"   // 仅同图覆盖；旧版单序列与其它图一律不动
        for file in (try? fm.contentsOfDirectory(atPath: directory)) ?? []
        where file.hasPrefix(stemPrefix) {
            try? fm.removeItem(atPath: "\(directory)/\(file)")
        }

        let url = URL(fileURLWithPath: directory)
            .appendingPathComponent("\(stemPrefix)\(safeName)-\(sequence.steps.count)杆.json")
        try data.write(to: url)
        return url
    }
}

// MARK: - 跨步骤共享上下文

/// 在「目录 → 拍照建球形 → 编排求解」三步之间传递当前 drill 与产出的球形。
@MainActor
final class BatchAuthoringContext: ObservableObject {
    @Published var drills: [BatchDrill] = []
    /// 当前选中的 drill（进入拍照/编排前设置）。
    @Published var current: BatchDrill?
    /// 拍照建球形确认后的归一化球形，交给编排求解工具。
    @Published var confirmedBoard: BoardSnapshot?
    /// 当前选用的源截图（决定球形 token；也用于序列命名）。
    @Published var sourceImageURL: URL?
    /// 待「续接编辑」的已存序列（走「改存档」入口时设置）：编排台据此重放重建、跳过拍照建球形。
    /// nil = 常规新建流程（拍照建球形 → 空录制）。
    @Published var editingSequence: PositionPlaySequence?
    /// 正在编辑的是否旧版单序列存档（`drill_cNNN-…` 无 `__`）：保存时覆盖原旧版文件而非另建新版。
    @Published var editingLegacyArchive = false
    /// 「保存」（留在本 drill 继续做下一张图）信号：拍照建球形页据此重置回选图栅格。
    @Published var pickerResetToken = UUID()

    func reload() {
        drills = BatchDrillCatalog.load()
    }

    func refreshSaved() {
        drills = BatchDrillCatalog.refreshSavedFlags(drills)
        if let cur = current { current = drills.first { $0.drillId == cur.drillId } ?? cur }
    }

    /// 序列默认名：沿用已存在 drill 的中文名，否则用 drillId。
    /// 多图 drill 追加「· 球形K」（K = 该图在排序中的序号），下游 formations 标题可辨。
    func defaultSequenceName(for drill: BatchDrill, imageURL: URL? = nil) -> String {
        let base = drill.nameZh ?? drill.drillId
        guard drill.imageURLs.count > 1, let url = imageURL,
              let idx = drill.imageURLs.firstIndex(of: url) else { return base }
        return "\(base) · 球形\(idx + 1)"
    }

    /// 推进到下一个未保存的 drill（用于「保存并下一个」）。返回是否还有下一个。
    func advanceToNextUnsaved() -> Bool {
        guard let cur = current,
              let idx = drills.firstIndex(where: { $0.drillId == cur.drillId }) else { return false }
        let after = drills[(idx + 1)...].first { !$0.hasSavedSequence }
        if let next = after {
            current = next
            confirmedBoard = nil
            sourceImageURL = nil
            editingSequence = nil
            editingLegacyArchive = false
            return true
        }
        return false
    }
}

// MARK: - 图像旋转

extension UIImage {
    /// 顺时针旋转 90°（横屏截图 → 竖版真台朝向）。重渲像素，保持后续标定坐标一致。
    func rotated90Clockwise() -> UIImage {
        let newSize = CGSize(width: size.height, height: size.width)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { ctx in
            let c = ctx.cgContext
            // UIKit 翻转坐标系下：移到右上角后 +90° 即视觉顺时针。
            c.translateBy(x: newSize.width, y: 0)
            c.rotate(by: .pi / 2)
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - 入口：批量 drill 目录

/// 角度 → 工具 → 「批量出片台」（仅模拟器）。列出待出片 drill，逐个进入拍照建球形。
struct BatchDrillStudioView: View {
    @StateObject private var context = BatchAuthoringContext()
    @State private var goExtract = false

    var body: some View {
        List {
            Section {
                summaryRow
            }
            Section("待出片 Drill（\(context.drills.count)）") {
                ForEach(context.drills) { drill in
                    Button { open(drill) } label: { drillRow(drill) }
                        .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("批量出片台")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { context.reload() } label: { Image(systemName: "arrow.clockwise") }
            }
        }
        .navigationDestination(isPresented: $goExtract) {
            BatchBallExtractionView(context: context)
        }
        .onAppear {
            if context.drills.isEmpty { context.reload() } else { context.refreshSaved() }
        }
    }

    private var summaryRow: some View {
        let savedDrills = context.drills.filter(\.hasSavedSequence).count
        let formations = context.drills.reduce(0) { $0 + $1.savedFormationCount }
        let unregistered = context.drills.filter { !$0.isRegistered }.count
        return VStack(alignment: .leading, spacing: 4) {
            Text("源目录：\(BatchDrillCatalog.sourceRoot)")
                .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            Text("已开工 \(savedDrills)/\(context.drills.count) drill · 共 \(formations) 球形"
                 + (unregistered > 0 ? " · 未登记 \(unregistered)" : ""))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func drillRow(_ drill: BatchDrill) -> some View {
        HStack(spacing: 12) {
            Image(systemName: drill.hasSavedSequence ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(drill.hasSavedSequence ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(drill.displayTitle).font(.system(size: 15, weight: .semibold))
                HStack(spacing: 6) {
                    Text("\(drill.imageURLs.count) 张截图")
                    if drill.savedFormationCount > 0 {
                        Text("· 已存 \(drill.savedFormationCount) 球形").foregroundStyle(.green)
                    }
                    if let c = drill.category { Text("· \(c)") }
                    if !drill.isRegistered {
                        Text("· 未登记").foregroundStyle(.orange)
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private func open(_ drill: BatchDrill) {
        context.current = drill
        context.confirmedBoard = nil
        context.sourceImageURL = nil
        context.editingSequence = nil
        context.editingLegacyArchive = false
        goExtract = true
    }
}
#endif
