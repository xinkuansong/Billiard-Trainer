import SwiftUI

//
//  DrillTryoutBrief.swift
//  QiuJi
//
//  动作库试打模式进场说明卡（方案 20260709-动作库试打模式 §1.8）。
//
//  三行内容全部从既有 drill JSON 字段自动生成（硬约束：不新增文案字段）：
//  - 局面目标：`shotIntent.shots[0].pocket`（或 `animation.pocket` 兜底）+ 多杆补充。
//  - 训练重点：`coachingPoints[0]`，按当前球桌朝向显示。
//  - 参考打法：velocity/spin 转人话（与既有力度档名 `PowerDisplay.name`、
//    打点语义同口径）；无 shotIntent 的 drill 省略此行。
//  明确不放 `standardCriteria`（实球计分口径，无计分模式下有误导）。
//
//  交互红线（守住「不做预览页」拍板）：非 modal、无确认按钮、不阻断操作；
//  首次交互自动淡出或点卡关闭；顶栏 info 图标可召回。
//

// MARK: - Content generator

enum DrillTryoutBrief {

    struct Line: Identifiable {
        let label: String
        let text: String
        var id: String { label }
    }

    /// 三行说明（缺素材的行自动省略，至少含「局面目标」）。
    /// 有出片序列球形（D4，与视频示范同源）时局面目标/参考打法取序列首杆真实参数；
    /// 无序列 drill 走原 shotIntent 路径。
    static func lines(for drill: DrillContent,
                      formation: DrillTryoutFormation? = nil,
                      orientation: PocketDisplay.Orientation) -> [Line] {
        var lines: [Line] = []
        lines.append(Line(label: "局面目标", text: goalText(for: drill, formation: formation, orientation: orientation)))
        if let focus = drill.coachingPoints.first, !focus.isEmpty {
            lines.append(Line(label: "训练重点", text: DrillCopyDisplay.text(focus,
                drillID: drill.id, field: "coachingPoints[0]", orientation: orientation)))
        }
        if let shot = formation?.firstShot, !shot.isFree {
            lines.append(Line(label: "参考打法", text: referenceText(
                velocity: shot.velocity, spinX: shot.spinX, spinY: shot.spinY)))
        } else if formation == nil, let shot = drill.shotIntent?.shots.first {
            lines.append(Line(label: "参考打法", text: referenceText(for: shot)))
        }
        return lines
    }

    /// 局面目标：选袋方位转中文 + 多杆补充杆数。
    static func goalText(for drill: DrillContent,
                         formation: DrillTryoutFormation? = nil,
                         orientation: PocketDisplay.Orientation) -> String {
        if let formation {
            return goalText(forFormation: formation, orientation: orientation,
                            mode: formationMode(for: drill, formation: formation))
        }
        let pocketName = drill.shotIntent?.shots.first.map {
            PocketDisplay.name(id: $0.pocket, orientation: orientation)
        }
        // A legacy animation pocket alone does not establish the ball's teaching role.
        var text = pocketName.flatMap { $0 == "—" ? nil : "把目标球打进\($0)" }
            ?? "按本球形示范练习"
        if let count = drill.shotIntent?.shots.count, count > 1 {
            text += "；共 \(count) 杆示范"
        }
        return text
    }

    /// 序列球形版局面目标：首杆选袋 + 杆数（首杆自由球/袋口缺失时省略袋口句）。
    static func goalText(forFormation formation: DrillTryoutFormation,
                         orientation: PocketDisplay.Orientation,
                         mode: DrillContent.DoseMode? = nil) -> String {
        var parts: [String] = []
        if let shot = formation.firstShot, !shot.isFree, !shot.targetKey.isEmpty {
            let pocketName = PocketDisplay.name(id: shot.pocket, orientation: orientation)
            if pocketName != "—" {
                parts.append("把目标球打进\(pocketName)")
            }
        }
        if formation.stepCount > 1 {
            switch mode {
            case .sequence:
                parts.append("共 \(formation.stepCount) 杆，按顺序接续完成")
            case .repetition:
                parts.append("共 \(formation.stepCount) 杆示范，各杆按示范摆位练习")
            case nil:
                parts.append("共 \(formation.stepCount) 杆示范")
            }
        }
        if parts.isEmpty {
            parts.append("按视频示范球形自由练习")
        }
        return parts.joined(separator: "；")
    }

    /// Match authored training semantics, not physical board equality: a continuous
    /// cue-ball drill may restore its target after every shot. Unknown tokens stay neutral.
    static func formationMode(for drill: DrillContent,
                              formation: DrillTryoutFormation) -> DrillContent.DoseMode? {
        let matches = (drill.sets.perFormation ?? []).filter { $0.token == formation.token }
        return matches.count == 1 ? matches.first?.mode : nil
    }

    /// 参考打法：力度档（`PowerDisplay.name` 同口径）+ 杆法用语。
    static func referenceText(for shot: ShotIntent.Shot) -> String {
        referenceText(velocity: shot.velocity,
                      spinX: shot.spin?.x ?? 0, spinY: shot.spin?.y ?? 0)
    }

    /// 参考打法（通用入口）：`PlannedShot` 与 `ShotIntent.Spin` 打点符号语义一致
    /// （x +左塞/−右塞，y +高杆/−低杆），两路共用。
    static func referenceText(velocity: Double, spinX: Double, spinY: Double) -> String {
        "\(powerPhrase(velocity)) · \(spinPhrase(x: spinX, y: spinY))"
    }

    /// 力度档名转人话（口径 = `PowerDisplay.name` 的五档分桶）。
    static func powerPhrase(_ velocity: Double) -> String {
        switch PowerDisplay.name(velocity) {
        case "轻推": return "轻推"
        case "轻":   return "小力度"
        case "中":   return "中等力度"
        case "中大": return "中大力度"
        default:     return "大力"
        }
    }

    /// 打点转杆法用语（与 `BTSpinMiniIcon`/`ShotIntent.Spin` 语义同口径：
    /// y +高杆/−低杆，x +左塞/−右塞；幅值 < 0.05R 视为中心）。
    static func spinPhrase(x: Double, y: Double) -> String {
        let threshold = 0.05
        var parts: [String] = []
        if y > threshold { parts.append("高杆") } else if y < -threshold { parts.append("低杆") }
        if x > threshold { parts.append("左塞") } else if x < -threshold { parts.append("右塞") }
        return parts.isEmpty ? "中杆" : parts.joined()
    }
}

// MARK: - Card view

/// 半透明说明卡：贴球桌上方淡入，点卡或首次交互淡出。
struct DrillTryoutBriefCard: View {
    @Environment(\.pocketDisplayOrientation) private var pocketOrientation
    let drill: DrillContent
    /// 出片序列球形（D4）：非 nil 时局面目标/参考打法取序列首杆真实参数。
    var formation: DrillTryoutFormation?
    /// 卡底部一行提示（D3 首次手势提示挂载位；nil 不显示）。
    var footnote: String?
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(DrillTryoutBrief.lines(for: drill, formation: formation, orientation: pocketOrientation)) { line in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Text(line.label)
                        .font(.btCaption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 52, alignment: .leading)
                    Text(line.text)
                        .font(.btCaption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if let footnote {
                Text(footnote)
                    .font(.btMicro)
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .btHudGlass(in: RoundedRectangle(cornerRadius: BTRadius.md, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: BTRadius.md, style: .continuous))
        .onTapGesture { onClose() }
        .accessibilityIdentifier("tryout.briefCard")
    }
}
