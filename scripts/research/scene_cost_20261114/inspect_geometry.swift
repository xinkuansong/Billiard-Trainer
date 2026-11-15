import Foundation
import SceneKit

let scene = try SCNScene(url: URL(fileURLWithPath: CommandLine.arguments[1]), options: nil)
var rows: [[String: Any]] = []
scene.rootNode.enumerateChildNodes { node, _ in
    guard let geometry = node.geometry else { return }
    rows.append(["node": node.name ?? "", "vertices": geometry.sources(for: .vertex).map(\.vectorCount),
        "elements": geometry.elements.enumerated().map { i, e -> [String: Any] in
            let material = geometry.materials.isEmpty ? nil : geometry.materials[i % geometry.materials.count]
            return ["index": i, "primitiveType": e.primitiveType.rawValue, "primitiveCount": e.primitiveCount,
                    "indexBytes": e.bytesPerIndex, "material": material?.name ?? "",
                    "doubleSided": material?.isDoubleSided ?? false,
                    "depthRead": material?.readsFromDepthBuffer ?? false,
                    "depthWrite": material?.writesToDepthBuffer ?? false,
                    "transparency": material?.transparency ?? -1]
        }, "renderingOrder": node.renderingOrder, "hidden": node.isHidden])
}
let report: [String: Any] = ["scope": "Raw USDZ import only; not installed production finishes or GPU cost", "nodes": rows]
try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted])
    .write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
for row in rows { print(row) }
