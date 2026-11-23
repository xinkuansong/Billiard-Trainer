import SwiftUI

/// Pinned section header shared by Practice / Drill (and Training where applicable) (v28 W0).
struct BTLibrarySectionHeader<Leading: View>: View {
    let title: String
    var caption: String? = nil
    @ViewBuilder var leading: () -> Leading

    var body: some View {
        HStack(spacing: Spacing.sm) {
            leading()
            Text(title)
                .font(.btTitle2)
                .foregroundStyle(.btText)
            if let caption {
                Text(caption)
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.btBG)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("librarySectionHeader_\(title)")
    }
}

extension BTLibrarySectionHeader where Leading == BTLibrarySectionHeaderSymbol {
    init(systemImage: String, title: String, caption: String? = nil) {
        self.title = title
        self.caption = caption
        self.leading = { BTLibrarySectionHeaderSymbol(systemImage: systemImage) }
    }
}

struct BTLibrarySectionHeaderSymbol: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.btSubheadline)
            .foregroundStyle(.btPrimary)
    }
}

extension BTLibrarySectionHeader where Leading == EmptyView {
    init(title: String, caption: String? = nil) {
        self.title = title
        self.caption = caption
        self.leading = { EmptyView() }
    }
}
