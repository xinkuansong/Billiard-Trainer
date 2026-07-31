import SwiftUI
import UIKit

/// 运行时加载离线烘焙的「USDZ 球桌 2D 顶视」缩略图 PNG（`Resources/DrillThumbnails/<id>.png`）。
/// 内存缓存，零 SceneKit 运行时成本。取代旧的实时 Canvas 缩略图（`BTDrillTableView` / `BTMiniTable`）。
enum DrillThumbnailStore {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(for drillId: String) -> UIImage? {
        if let cached = cache.object(forKey: drillId as NSString) { return cached }
        guard let url = Bundle.main.url(forResource: drillId, withExtension: "png",
                                        subdirectory: "DrillThumbnails"),
              let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        cache.setObject(image, forKey: drillId as NSString)
        return image
    }
}

/// 动作库 / 计划用的烘焙缩略图视图（2:1）。缺图时回退到干净台呢占位。
///
/// - Note: Default `.fill` keeps square row slots (64² etc.) ball-readable via center crop
///   (v24 D-v24-1=C). Pass `.fit` only when a future caller wants a letterboxed full table.
struct BTBakedDrillTable: View {
    let drillId: String
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let image = DrillThumbnailStore.image(for: drillId) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(2.0, contentMode: contentMode)
            } else {
                fallback
            }
        }
        .clipped()
    }

    private var fallback: some View {
        ZStack {
            Color.btTableFelt
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.white.opacity(0.35))
        }
        .aspectRatio(2.0, contentMode: .fit)
    }
}
