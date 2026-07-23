import SwiftUI
import UIKit

/// 点按走一步、长按延迟后加速连发的圆形方向键。
///
/// 交互与打点盘四向微调同源：按下立即一步 → 0.4s 后连发（起步 ~8 次/秒，
/// 渐进提到 ~20 次/秒）；`onStep` 返回 `false` 时换硬触觉并停连发（撞墙）。
struct BTHoldRepeatButton: View {
    let icon: String
    let accessibility: String
    /// 执行一步；返回是否真的发生了变化（false = 撞墙 / 无效）。
    let onStep: () -> Bool

    @State private var repeatTimer: Timer?
    @State private var ticks = 0
    @State private var isPressing = false

    var hitSize: CGFloat = 40
    var iconSize: CGFloat = 30

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white.opacity(isPressing ? 1 : 0.82))
            .frame(width: iconSize, height: iconSize)
            .background(.white.opacity(isPressing ? 0.24 : 0.12), in: Circle())
            .frame(width: hitSize, height: hitSize)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressing else { return }
                        isPressing = true
                        step()
                        scheduleNext(after: 0.4)
                    }
                    .onEnded { _ in stop() }
            )
            .onDisappear { stop() }
            .accessibilityLabel(accessibility)
            .accessibilityAddTraits(.isButton)
    }

    private func step() {
        if onStep() {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
        } else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.9)
            repeatTimer?.invalidate()
            repeatTimer = nil
        }
    }

    private func scheduleNext(after delay: TimeInterval) {
        repeatTimer?.invalidate()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            guard isPressing else { return }
            ticks += 1
            step()
            scheduleNext(after: max(0.05, 0.12 - Double(ticks) * 0.005))
        }
    }

    private func stop() {
        isPressing = false
        ticks = 0
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}
