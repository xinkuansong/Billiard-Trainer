import SwiftUI

struct ProfileAvatarView: View {
    @EnvironmentObject private var avatarStore: AvatarStore
    let size: CGFloat

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
        .accessibilityLabel(avatarStore.image == nil ? "默认头像" : "用户头像")
    }
}
