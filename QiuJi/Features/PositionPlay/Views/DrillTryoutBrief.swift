import SwiftUI

//
//  DrillTryoutBrief.swift
//  QiuJi
//
//  动作库试打模式进场说明卡（方案 20260709-动作库试打模式 §1.8）。
//
//  三行内容全部从既有 drill JSON 字段自动生成（硬约束：不新增文案字段）：
//  - 局面目标：`shotIntent.shots[0].pocket`（或 `animation.pocket` 兜底）+ 多杆补充。
//  - 训练重点：`coachingPoints[0]` 原文。
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
    static func lines(for drill: DrillContent) -> [Line] {
        var lines: [Line] = []
        lines.append(Line(label: "局面目标", text: goalText(for: drill)))
        if let focus = drill.coachingPoints.first, !focus.isEmpty {
            lines.append(Line(label: "训练重点", text: focus))
        }
        if let shot = drill.shotIntent?.shots.first {
            lines.append(Line(label: "参考打法", text: referenceText(for: shot)))
        }
        return lines
    }

    /// 局面目标：选袋方位转中文 + 多杆 drill 补充杆数。
    static func goalText(for drill: DrillContent) -> String {
        let pocketId = drill.shotIntent?.shots.first?.pocket ?? drill.animation.pocket
        var text = "把目标球打进\(PocketDisplay.name(id: pocketId))"
        if let count = drill.shotIntent?.shots.count, count > 1 {
            text += "；本局共 \(count) 杆，进球后继续走位下一杆"
        }
        return text
    }

    /// 参考打法：力度档（`PowerDisplay.name` 同口径）+ 杆法用语。
    static func referenceText(for shot: ShotIntent.Shot) -> String {
        "\(powerPhrase(shot.velocity)) · \(spinPhrase(x: shot.spin?.x ?? 0, y: shot.spin?.y ?? 0))"
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
    let drill: DrillContent
    /// 卡底部一行提示（D3 首次手势提示挂载位；nil 不显示）。
    var footnote: String?
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(DrillTryoutBrief.lines(for: drill)) { line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(line.label)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.btPrimary)
                        .frame(width: 52, alignment: .leading)
                    Text(line.text)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if let footnote {
                Text(footnote)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .btHudGlass(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture { onClose() }
        .accessibilityIdentifier("tryout.briefCard")
    }
}
