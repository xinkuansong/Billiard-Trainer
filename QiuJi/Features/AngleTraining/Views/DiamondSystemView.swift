import SwiftUI

/// 反射解球器 — 2D top-down kick-shot solver.
/// Place the cue & target balls anywhere; the app solves cushion-first kick routes
/// (cue off 1–3 rails into the target) with the real physics engine.
///
/// W4 版面（20260709 翻袋反射页重构方案 §1.2，与翻袋页同构，无袋口点选与切角读数）：
/// 顶部 1 行库数 chip；右缘纯力度柱（力度 = 求解输入）；右下贴边动作列（下一解 / 重置）；
/// 底部球库带（拖入 = 障碍球，真实碰撞体进反解模拟）。
///
/// W5（C18）：壳层收进 `SolverStageChrome`；本文件仅配置 + 注入。
struct DiamondSystemView: View {
    @StateObject private var vm = DiamondSystemViewModel()

    var body: some View {
        SolverStageChrome(
            vm: vm,
            title: "反射解球器",
            coordinateSpaceName: "reflection",
            onPocketTapped: nil,
            infoTitle: "反射解球原理",
            infoBlocks: Self.infoBlocks
        )
    }

    private static let infoBlocks: [PrincipleBlock] = [
        PrincipleBlock(
            title: "这是什么",
            body: "一个通用的反射解球器：把母球和目标球放到台面任意位置，用真实物理引擎反解母球经过 1 库、2 库、3 库反弹后碰到目标球的走位路线。"
        ),
        PrincipleBlock(
            title: "原理：入射角 = 反射角",
            body: "「入射角 = 反射角」是台球走位的几何基础，著名的颗星 / 钻石公式（CB − TR = FR）正是该反射模型在「母球贴库、平行库」特例下的算术近似。求解先用「镜像展开」枚举候选撞库顺序，真实路线在此之上由物理引擎逐段模拟：低力度下反射「偏短」（库呢吸收）、滑动到滚动的状态过渡都会如实反映。"
        ),
        PrincipleBlock(
            title: "操作",
            body: "拖动母球（白）与目标球（黑）到任意位置（松手后自动求解）；顶部选「自动」按好打程度排序，或手选 1–3 库。白色实线即母球解线、金点是碰库点、虚线是碰到后两球的真实去向。多条解时点「下一解」切换；点「击打」演示这一杆（出杆 → 真实物理回放 → 自动复位，可重复击打）；点「重置」恢复默认摆球。"
        ),
        PrincipleBlock(
            title: "障碍球",
            body: "从底部球库把球拖上桌即成障碍球（拖回球库移除）。障碍球是真实碰撞体：母球绕库途中撞上障碍的候选路线会被物理引擎自然淘汰，不做几何近似过滤。"
        ),
        PrincipleBlock(
            title: "自由模式",
            body: "顶部切到「自由」即可亲手试打：拖动台面或左侧刻度轮瞄准，点右上打点盘设加塞，拖力度柱调力度，点「击球」真实物理开打——球停在哪是哪。选中解会以暗虚线留在台面供你照着练。「上一杆」撤销上次击打、「回放」重看、左下「恢复球形」回到最近一次求解的球形，切回「求解」立即显示原解。"
        ),
        PrincipleBlock(
            title: "真实物理求解与力度",
            body: "每条解都由完整物理引擎反解并复核——画面即物理。力度是求解输入：拖动右侧力度柱（m/s）会重新求解，力度不足够绕库时该路线会自动消失；该设置与翻袋解球器共享并会被记住。"
        ),
        PrincipleBlock(
            title: "好打优先",
            body: "多条解按「好打程度」排序：综合首库入射角、库数、路线长度评出难度档（易 / 中 / 难），再对每条解做小幅瞄准与力度扰动测出「容错」——容错越高，执行误差下仍能碰到目标球的概率越大。"
        ),
    ]
}
