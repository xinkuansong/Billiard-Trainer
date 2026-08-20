import Foundation

/// Shared 8-track toggle for atlas pages (高低杆 / 左右塞).
/// Default: all on. Turning off the last remaining track is a no-op.
enum AtlasSpinTrackSelection {
    static let trackCount = 8
    static let allEnabled: Set<Int> = Set(0..<trackCount)

    /// Toggle `index` in `current`. Out-of-range is a no-op.
    static func toggle(_ current: Set<Int>, index: Int, count: Int = trackCount) -> Set<Int> {
        guard (0..<count).contains(index) else { return current }
        if current.contains(index) {
            if current.count <= 1 { return current }
            var next = current
            next.remove(index)
            return next
        }
        var next = current
        next.insert(index)
        return next
    }
}
