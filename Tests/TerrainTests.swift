import XCTest
import simd
@testable import GreenScanCore

final class TerrainTests: XCTestCase {
    private func patch(outlier: Bool = false) -> [DepthSample] {
        (-5...5).flatMap { x in
            (-5...5).map { z in
                let height: Float = outlier ? -0.85 : -1 + Float(x) * 0.05 * 0.02
                return DepthSample(position: SIMD3(Float(x) * 0.05, height, Float(z) * 0.05), weight: 1)
            }
        }
    }

    func testRepeatedStationaryFramesDoNotManufactureConfidence() {
        var map = TerrainMap()
        for time in 0..<10 { map.integrate(patch(), camera: .zero, time: Double(time)) }
        XCTAssertTrue(map.snapshot().heights.isEmpty)
        map.integrate(patch(), camera: SIMD3(0.2, 0, 0), time: 11)
        XCTAssertFalse(map.snapshot().heights.isEmpty)
    }

    func testSlopeSurvivesFusionAndSingleOutlier() throws {
        var map = TerrainMap()
        map.integrate(patch(), camera: .zero, time: 1)
        map.integrate(patch(), camera: SIMD3(0.2, 0, 0), time: 2)
        let before = map.snapshot()
        map.integrate(patch(outlier: true), camera: SIMD3(-0.2, 0, 0), time: 3)
        let after = map.snapshot()
        XCTAssertEqual(before.heights, after.heights)
        let left = try XCTUnwrap(after.heights[GridKey(x: -3, z: 0)])
        let right = try XCTUnwrap(after.heights[GridKey(x: 3, z: 0)])
        XCTAssertEqual((right - left) / 0.3, 0.02, accuracy: 0.0001)
    }

    func testRepeatedCredibleCorrectionCanReplaceInitialError() throws {
        var map = TerrainMap()
        map.integrate(patch(), camera: .zero, time: 1)
        map.integrate(patch(), camera: SIMD3(0.2, 0, 0), time: 2)
        for i in 0..<4 {
            map.integrate(patch(outlier: true), camera: SIMD3(Float(i) * 0.2 + 0.5, 0, 0), time: Double(i + 3))
        }
        XCTAssertEqual(try XCTUnwrap(map.snapshot().heights[GridKey(x: 0, z: 0)]), -0.85, accuracy: 0.001)
    }

    func testContourInterpolationIsAtRequestedElevation() {
        let triangle: [SIMD3<Float>] = [SIMD3(0, 0, 0), SIMD3(1, 0.1, 0), SIMD3(0, 0.1, 1)]
        let lines = TerrainGeometry.contours(triangle, reference: 0, interval: 0.02)
        XCTAssertFalse(lines.isEmpty)
        for line in lines {
            XCTAssertEqual(line.start.y, line.end.y, accuracy: 0.00001)
            XCTAssertEqual(line.start.y / 0.02, (line.start.y / 0.02).rounded(), accuracy: 0.00001)
        }
    }

    func testMissingCoverageDoesNotCreateSurfaceOrContours() {
        let snapshot = TerrainSnapshot(heights: [GridKey(x: 0, z: 0): 0, GridKey(x: 1, z: 1): 0.1], quality: [:], reference: 0, revision: 1, atCapacity: false)
        var settings = DisplaySettings()
        settings.showsContours = true
        settings.showsGrid = true
        let geometry = TerrainGeometry.build(snapshot, settings: settings)
        XCTAssertTrue(geometry.contours.isEmpty)
        XCTAssertTrue(geometry.grid.isEmpty)
        XCTAssertTrue(geometry.surfaceTriangles.isEmpty)
    }

    func testDensityChangesDisplayWithoutChangingTerrain() {
        let snapshot = TerrainGeometry.demo()
        let original = snapshot.heights
        var settings = DisplaySettings()
        settings.spacing = 0.05
        let dense = TerrainGeometry.build(snapshot, settings: settings)
        settings.spacing = 0.20
        let sparse = TerrainGeometry.build(snapshot, settings: settings)
        XCTAssertGreaterThan(dense.dots.count, sparse.dots.count * 8)
        XCTAssertEqual(snapshot.heights, original)
    }

    func testResetRejectsOldGeneration() async {
        let processor = TerrainProcessor()
        await processor.reset(generation: 1)
        let stale = await processor.integrate(patch(), camera: .zero, time: 1, generation: 0)
        XCTAssertNil(stale)
        let fresh = await processor.integrate(patch(), camera: .zero, time: 2, generation: 1)
        XCTAssertNotNil(fresh)
    }
}
