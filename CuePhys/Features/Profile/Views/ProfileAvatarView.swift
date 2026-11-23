import SwiftUI

struct ProfileAvatarView: View {
    @EnvironmentObject private var avatarStore: AvatarStore
    let size: CGFloat
    var gender: ProfileGender = .unspecified
    var badgeAlignment: Alignment = .bottomTrailing

    var body: some View {
        ZStack {
            Circle().fill(Color.btPrimary.opacity(0.15))
            if let image = avatarStore.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Image(systemName: BTIcon.person)
                    .font(.system(size: size * 0.44, weight: .medium))
                    .foregroundStyle(.btPrimary)
            }
            if avatarStore.phase != .idle {
                Circle().fill(.black.opacity(0.28))
                ProgressView().tint(.white)
            }
        }
        .frame(width: size, height: size)
        .overlay(alignment: badgeAlignment) {
            if let symbol = gender.symbol {
                Text(symbol)
                    .font(.btFootnote.weight(.bold))
                    .dynamicTypeSize(.medium)
                    .foregroundStyle(.white)
                    .frame(width: size >= 80 ? 24 : 20, height: size >= 80 ? 24 : 20)
                    .background(Color.btPrimary, in: Circle())
                    .overlay { Circle().stroke(Color.btBGSecondary, lineWidth: 2) }
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel((avatarStore.image == nil ? "默认头像" : "用户头像") +
                            (gender == .unspecified ? "" : "，性别" + gender.title))
    }
}
