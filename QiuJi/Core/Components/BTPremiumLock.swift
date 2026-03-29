import SwiftUI

struct BTPremiumLock: View {
    var onSubscribeTap: () -> Void = {}

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.md) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.btAccent)

                Text("付费内容")
                    .font(.btTitle)
                    .foregroundStyle(.btText)

                Text("解锁全部训练内容，提升你的球技")
                    .font(.btCallout)
                    .foregroundStyle(.btTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onSubscribeTap) {
                Label("解锁全部内容", systemImage: "crown.fill")
            }
            .buttonStyle(BTButtonStyle.primary)
            .padding(.horizontal, Spacing.xxxxl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

#Preview("Light") {
    ZStack {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Text("被遮挡的内容")
                    .font(.btTitle)
                Text("这些内容应被模糊遮罩覆盖")
                    .font(.btBody)
            }
            .padding()
        }
        .background(.btBG)

        BTPremiumLock()
    }
}

#Preview("Dark") {
    ZStack {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Text("被遮挡的内容")
                    .font(.btTitle)
                Text("这些内容应被模糊遮罩覆盖")
                    .font(.btBody)
            }
            .padding()
        }
        .background(.btBG)

        BTPremiumLock()
    }
    .preferredColorScheme(.dark)
}
