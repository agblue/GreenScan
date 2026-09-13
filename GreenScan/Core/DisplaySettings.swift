import Foundation
import simd

struct DisplaySettings: Equatable, Sendable {
    var spacing: Float = 0.10
    var contourInterval: Float = 0.02
    var showsDots = true
    var showsContours = false
    var showsGrid = false
    var showsQuality = false
    var showsMesh = false
}
