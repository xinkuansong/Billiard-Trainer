import Foundation
import simd

// Research candidate. The first 256 bytes always retain the original ball ABI.
enum PreparedClothState {
    static func values(_ balls: [SIMD4<Float>], coefficients: Bool, compact: Bool = false) -> [SIMD4<Float>] {
        precondition(balls.count == 16)
        var valid = true
        var activeMask: UInt32 = 0
        for (index, b) in balls.enumerated() where b.w > 0 {
            activeMask |= UInt32(1) << index
            if !(abs(b.x) <= Float(2.5399999618530273) && abs(b.y) <= Float(1.2699999809265137)
                 && b.z >= Float(0.028575) && b.z <= Float(2.2)) { valid = false }
        }
        var ordered = compact ? balls.filter { $0.w > 0 } : balls
        let activeCount = activeMask.nonzeroBitCount
        if compact { ordered += Array(repeating: .zero, count: 16 - ordered.count) }
        var values = balls
        values.append(SIMD4(valid ? 1 : 0, Float(compact ? UInt32(activeCount) : activeMask), 0, 0))
        if compact { values += ordered }
        if coefficients {
            for b in ordered {
                let opacity = b.w / Float(0.85)
                values.append(SIMD4(b.z * b.z, opacity * Float(0.0008165306) * b.z,
                                    min(Float(1), opacity), 0))
            }
        }
        return values
    }
}
