import SwiftUI

struct BTShimmer: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: max(0, phase - 0.3)),
                            .init(color: .white.opacity(0.4), location: phase),
                            .init(color: .clear, location: min(1, phase + 0.3)),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geo.size.width * 2, height: geo.size.height)
                    .offset(x: -geo.size.width * 0.5)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

extension View {
    func btShimmer() -> some View {
        modifier(BTShimmer())
    }
}

// MARK: - Drill Card Skeleton (Row variant — used by PlanList etc.)

struct BTDrillCardSkeleton: View {
    var body: some View {
        HStack(spacing: Spacing.md) {
            RoundedRectangle(cornerRadius: BTRadius.sm)
                .fill(Color.btBGTertiary)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.btBGTertiary)
                    .frame(width: 140, height: 16)

                HStack(spacing: Spacing.sm) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.btBGTertiary)
                        .frame(width: 50, height: 12)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.btBGTertiary)
                        .frame(width: 36, height: 12)
                }
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }
}

// MARK: - Drill Grid Card Skeleton

private struct BTDrillGridCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.btBGTertiary)
                .aspectRatio(2.0, contentMode: .fit)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.btBGTertiary)
                    .frame(height: 14)

                HStack(spacing: Spacing.sm) {
                    RoundedRectangle(cornerRadius: BTRadius.full)
                        .fill(Color.btBGTertiary)
                        .frame(width: 48, height: 12)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.btBGTertiary)
                        .frame(width: 28, height: 12)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }
}

// MARK: - Drill List Skeleton (2-column grid)

struct BTDrillListSkeleton: View {
    private let columns = [
        GridItem(.flexible(), spacing: Spacing.md),
        GridItem(.flexible(), spacing: Spacing.md),
    ]

    var body: some View {
        VStack(spacing: Spacing.xl) {
            ForEach(0..<2, id: \.self) { section in
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.btBGTertiary)
                        .frame(width: 80, height: 16)
                        .padding(.horizontal, Spacing.lg)

                    LazyVGrid(columns: columns, spacing: Spacing.md) {
                        ForEach(0..<(section == 0 ? 4 : 2), id: \.self) { _ in
                            BTDrillGridCardSkeleton()
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                }
            }
        }
        .btShimmer()
    }
}

#Preview("Shimmer Skeleton") {
    ScrollView {
        BTDrillListSkeleton()
    }
    .background(Color.btBG)
}

#Preview("Shimmer Skeleton Dark") {
    ScrollView {
        BTDrillListSkeleton()
    }
    .background(Color.btBG)
    .preferredColorScheme(.dark)
}
