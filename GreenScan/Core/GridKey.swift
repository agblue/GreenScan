import Foundation
import simd

struct GridKey: Hashable, Codable, Sendable {
    let x: Int
    let z: Int
    func offset(_ dx: Int, _ dz: Int) -> GridKey { GridKey(x: x + dx, z: z + dz) }
}
