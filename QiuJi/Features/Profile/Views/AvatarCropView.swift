import SwiftUI

struct AvatarCropView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    let onConfirm: (UIImage) -> Void
    @State private var zoom: CGFloat = 1

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xl) {
                Spacer()
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(zoom)
                    .frame(width: 280, height: 280)
                    .clipped()
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 2))
                    .accessibilityLabel("头像裁切预览")

                VStack(spacing: Spacing.sm) {
                    Text("缩放")
                        .font(.btCaption)
                        .foregroundStyle(.btTextSecondary)
                    Slider(value: $zoom, in: 1...3)
                        .tint(.btPrimary)
                        .accessibilityIdentifier("avatarCrop.zoom")
                }
                .padding(.horizontal, Spacing.xxl)
                Spacer()
            }
            .background(Color.btBG.ignoresSafeArea())
            .navigationTitle("裁切头像")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("使用") { onConfirm(AvatarImageProcessor.cropped(image, zoom: zoom)) }
                }
            }
        }
    }
}
