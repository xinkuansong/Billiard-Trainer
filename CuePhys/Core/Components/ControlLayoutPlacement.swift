import Foundation
import CoreGraphics

/// One native layout pass supplies all three measurements. No screenshot-derived or guessed frames.
struct FreeControlLegacyMeasurements: Equatable {
    struct Control: Equatable {
        var frame: CGRect
        var group: ControlLayoutGroup?
    }
    var groups: [ControlLayoutGroup: CGRect] = [:]
    var controls: [String: Control] = [:]
    var obstacles: [CGRect] = []
}

enum FreeControlLegacyConverter {
    struct Conversion {
        var values: FreeControlValues
        var pending: String?
    }
    static func convert(_ archive: ControlLayoutArchive, page: TablePreferencePage, mode: FreeControlLayoutMode,
                        domain: ControlLayoutDomain, input: ControlLayoutPlacement.Input,
                        controls: [String: FreeControlLegacyMeasurements.Control], window: FreeControlWindow) -> Conversion {
        let intent = ControlLayoutResolver.resolve(archive, page: page, domain: domain,
            mode: mode == .twoD ? .twoD : .threeD, capabilities: Set(ControlLayoutGroup.allCases))
        guard !intent.values.isEmpty else { return .init(values: [:], pending: nil) }
        guard window.width > 0, window.height > 0, window.width.isFinite, window.height.isFinite else {
            return .init(values: [:], pending: "尚未取得有效窗口尺寸")
        }
        let portrait = window.height > window.width
        guard (domain == .padPortrait) == portrait,
              abs(input.page.width - window.width) < 1, abs(input.page.height - window.height) < 1 else {
            return .init(values: [:], pending: "等待窗口方向与页面测量一致")
        }
        let missing = Set(intent.values.keys).subtracting(input.defaults.keys)
        guard missing.isEmpty else {
            let names: [ControlLayoutGroup: String] = [.direction: "方向", .instrument: "打点与力度", .primary: "主动作",
                .replay: "重打与回放", .planning: "规划", .camera: "相机", .information: "信息", .keyboard: "答题键盘"]
            return .init(values: [:], pending: "待对应阶段测量：" + missing.compactMap { names[$0] }.sorted().joined(separator: "、"))
        }
        let placement = ControlLayoutPlacement.place(intent, in: input)
        guard placement.status == .customized else {
            return .init(values: [:], pending: "旧配置在此窗口触发默认回退，保留原值等待可转换窗口")
        }
        let measuredGroups = Set(controls.values.compactMap(\.group))
        guard Set(intent.values.keys).isSubset(of: measuredGroups) else {
            return .init(values: [:], pending: "旧控件组尚无完整的单键测量")
        }
        var values: FreeControlValues = [:]
        for (id, control) in controls where FreeControlCatalog.ids(page: page, mode: mode).contains(id) {
            guard let group = control.group, input.defaults[group] != nil,
                  control.frame.width > 0, control.frame.height > 0 else { continue }
            let delta = placement.translation(for: group, from: input.defaults)
            let value = FreeControlPlacement(x: (control.frame.midX + delta.width) / window.width,
                                             y: (control.frame.midY + delta.height) / window.height)
            guard value.x.isFinite, value.y.isFinite else {
                return .init(values: [:], pending: "控件测量无效，原数据已保留")
            }
            values[id] = value
        }
        guard !values.isEmpty else { return .init(values: [:], pending: "等待此页单键接入") }
        return .init(values: values, pending: nil)
    }
}

/// Page-local logical points: origin at top left, +x right, +y down.
/// The host supplies the unchanged default table and measured native control bounds.
enum ControlLayoutPlacement {
    struct LaneRegions {
        var leading: CGRect
        var trailing: CGRect
    }
    struct Input {
        var page: CGRect
        var leading: CGRect
        var trailing: CGRect
        var defaults: [ControlLayoutGroup: CGRect]
        var obstacles: [CGRect] = []
        var defaultFits = true
        /// Floating groups keep their own native width and do not pack into the button columns.
        var groupRegions: [ControlLayoutGroup: LaneRegions] = [:]
    }
    enum Status: String { case original, customized, temporaryDefault, insufficientSpace }
    struct Result: Equatable {
        var frames: [ControlLayoutGroup: CGRect]
        var status: Status
        func translation(for group: ControlLayoutGroup, from defaults: [ControlLayoutGroup: CGRect]) -> CGSize {
            guard let frame = frames[group], let original = defaults[group] else { return .zero }
            return CGSize(width: frame.minX - original.minX, height: frame.minY - original.minY)
        }
    }

    static func place(_ intent: ControlLayoutResolved, in input: Input, allowClamping: Bool = true) -> Result {
        let fallback = Result(frames: input.defaults, status: input.defaultFits ? .temporaryDefault : .insufficientSpace)
        guard input.defaultFits, valid(input.page), valid(input.leading), valid(input.trailing),
              input.defaults.values.allSatisfy(valid) else { return fallback }
        guard !intent.values.isEmpty, !input.defaults.isEmpty else { return Result(frames: input.defaults, status: .original) }
        var frames = input.defaults
        var lanes: [ControlLayoutGroup: ControlLayoutLane] = [:]
        let ordinary = input.defaults.keys.filter { $0 != .camera && input.groupRegions[$0] == nil }.sorted { $0.rawValue < $1.rawValue }
        for group in ordinary {
            guard let original = input.defaults[group] else { continue }
            let originalLane: ControlLayoutLane = abs(original.midX - input.leading.midX) < abs(original.midX - input.trailing.midX) ? .leading : .trailing
            if case .lane(let lane) = intent[group, .lane] { lanes[group] = lane }
            else { lanes[group] = originalLane }
        }
        for lane in [ControlLayoutLane.leading, .trailing] {
            let region = lane == .leading ? input.leading : input.trailing
            let groups = ordinary.filter { lanes[$0] == lane }.sorted { a, b in
                let aOrder = order(intent[a, .order]), bOrder = order(intent[b, .order])
                if aOrder != bOrder { return aOrder < bOrder }
                let ay = input.defaults[a]?.minY ?? 0, by = input.defaults[b]?.minY ?? 0
                return ay == by ? a.rawValue < b.rawValue : ay < by
            }
            let repack = groups.contains { intent[$0, .order] != nil || intent[$0, .lane] != nil }
            let total = groups.reduce(CGFloat.zero) { $0 + (input.defaults[$1]?.height ?? 0) } + CGFloat(max(0, groups.count - 1)) * 4
            guard total <= region.height else { return fallback }
            let cluster = groups.compactMap { input.defaults[$0] }.reduce(CGRect.null) { $0.union($1) }
            var y = min(max(cluster.midY - total / 2, region.minY), region.maxY - total)
            for group in groups {
                guard let original = input.defaults[group], original.width <= region.width else { return fallback }
                // Unsupported size tiers are rejected, never silently scaled.
                if let size = intent[group, .size], size != .size(.automatic) { return fallback }
                let offset: CGFloat
                if case .offset(let value) = intent[group, .offset], value.isFinite { offset = CGFloat(value) }
                else if intent[group, .offset] != nil { return fallback }
                else { offset = 0 }
                var frame = original
                let originalLane: ControlLayoutLane = abs(original.midX - input.leading.midX) < abs(original.midX - input.trailing.midX) ? .leading : .trailing
                if originalLane != lane { frame.origin.x = region.midX - frame.width / 2 }
                let requestedY = (repack ? y : original.minY) + offset
                // Existing saved intent may be bounded at runtime after a window resize.
                // A new editor drop must be valid as requested, rather than save an offscreen intent.
                if !allowClamping && (requestedY < region.minY - 0.5 || requestedY + frame.height > region.maxY + 0.5) {
                    return fallback
                }
                frame.origin.y = min(max(requestedY, region.minY), region.maxY - frame.height)
                frames[group] = frame
                y += frame.height + 4
            }
        }
        for (group, regions) in input.groupRegions {
            guard let original = input.defaults[group] else { continue }
            guard valid(regions.leading), valid(regions.trailing), intent[group, .order] == nil,
                  intent[group, .size] == nil || intent[group, .size] == .size(.automatic) else { return fallback }
            let originalLane: ControlLayoutLane = abs(original.midX - regions.leading.midX) < abs(original.midX - regions.trailing.midX) ? .leading : .trailing
            let lane: ControlLayoutLane
            if case .lane(let selected) = intent[group, .lane] { lane = selected } else { lane = originalLane }
            lanes[group] = lane
            let region = lane == .leading ? regions.leading : regions.trailing
            guard original.width <= region.width, original.height <= region.height else { return fallback }
            let offset: CGFloat
            if case .offset(let value) = intent[group, .offset], value.isFinite { offset = CGFloat(value) }
            else if intent[group, .offset] != nil { return fallback }
            else { offset = 0 }
            var frame = original
            if lane != originalLane { frame.origin.x = region.midX - frame.width / 2 }
            let y = original.minY + offset
            if !allowClamping && (y < region.minY - 0.5 || y + frame.height > region.maxY + 0.5) { return fallback }
            frame.origin.y = min(max(y, region.minY), region.maxY - frame.height)
            frames[group] = frame
        }
        if let camera = input.defaults[.camera] {
            var frame = camera
            if let oldInstrument = input.defaults[.instrument], let newInstrument = frames[.instrument] {
                let distance = abs(camera.midX - oldInstrument.midX)
                frame.origin.x = newInstrument.midX + (lanes[.instrument] == .leading ? distance : -distance) - camera.width / 2
                frame.origin.y += newInstrument.minY - oldInstrument.minY
            }
            if case .cameraSlot(.mirrored) = intent[.camera, .cameraSlot] {
                frame.origin.x = input.page.minX + input.page.maxX - frame.maxX
            }
            frames[.camera] = frame
        }
        let sorted = frames.keys.sorted { $0.rawValue < $1.rawValue }
        for (index, group) in sorted.enumerated() {
            guard let frame = frames[group], contains(input.page, frame) else { return fallback }
            if input.obstacles.contains(where: { overlaps(frame, $0) }) { return fallback }
            if group != .camera {
                let regions = input.groupRegions[group] ?? LaneRegions(leading: input.leading, trailing: input.trailing)
                let region = lanes[group] == .leading ? regions.leading : regions.trailing
                guard contains(region, frame) else { return fallback }
            }
            for other in sorted.dropFirst(index + 1) {
                if let otherFrame = frames[other], overlaps(frame, otherFrame) { return fallback }
            }
        }
        return Result(frames: frames, status: .customized)
    }

    private static func order(_ value: ControlLayoutValue?) -> Int {
        if case .order(let order) = value { return order }
        return ControlLayoutGroup.allCases.count
    }
    private static func valid(_ rect: CGRect) -> Bool {
        [rect.origin.x, rect.origin.y, rect.width, rect.height].allSatisfy(\.isFinite) && rect.width > 0 && rect.height > 0
    }
    private static func contains(_ outer: CGRect, _ inner: CGRect) -> Bool {
        // Half a logical point covers the native stroke/measurement edge documented in B00.
        outer.insetBy(dx: -0.5, dy: -0.5).contains(inner)
    }
    private static func overlaps(_ a: CGRect, _ b: CGRect) -> Bool {
        let intersection = a.intersection(b)
        return !intersection.isNull && intersection.width > 0.5 && intersection.height > 0.5
    }
}
