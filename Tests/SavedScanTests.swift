import XCTest
import simd
@testable import GreenScanCore

@MainActor
final class SavedScanTests: XCTestCase {
    func testArchiveRoundTripPreservesAllMeasuredDataAndSurvivesReopen() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let archive = ScanArchive(directory: directory)
        let scan = SavedScan(snapshot: TerrainGeometry.demo(), isDemo: true)
        try await archive.save(scan)
        let reopened = ScanArchive(directory: directory)
        let restored = try await reopened.load(scan.id)
        XCTAssertEqual(restored.snapshot.heights, scan.snapshot.heights)
        XCTAssertEqual(restored.snapshot.quality, scan.snapshot.quality)
        XCTAssertEqual(restored.snapshot.reference, scan.snapshot.reference)
        XCTAssertEqual(restored.date, scan.date)
        XCTAssertTrue(restored.isDemo)
        let history = try await reopened.history()
        XCTAssertEqual(history.scans.map(\.id), [scan.id])
    }

    func testHistorySortsNewestFirstAndReportsDamagedFiles() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let archive = ScanArchive(directory: directory)
        let old = SavedScan(snapshot: TerrainGeometry.demo(), isDemo: false, date: Date(timeIntervalSince1970: 1))
        let recent = SavedScan(snapshot: TerrainGeometry.demo(), isDemo: false, date: Date(timeIntervalSince1970: 10))
        try await archive.save(recent)
        try await archive.save(old)
        try Data("broken".utf8).write(to: directory.appending(path: UUID().uuidString + ".json"))
        let history = try await archive.history()
        XCTAssertEqual(history.scans.map(\.id), [recent.id, old.id])
        XCTAssertEqual(history.unreadableCount, 1)
    }

    func testEmptyAndInvalidScansAreRejected() async {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let archive = ScanArchive(directory: directory)
        do {
            try await archive.save(SavedScan(snapshot: .empty, isDemo: false))
            XCTFail("Empty scans must not be saved")
        } catch { XCTAssertTrue(error is ScanArchiveError) }
        let corrupt = TerrainSnapshot(heights: [GridKey(x: .min, z: 0): 1], quality: [:], reference: 0, revision: 0, atCapacity: false)
        XCTAssertThrowsError(try SavedScan(snapshot: corrupt, isDemo: false).validate())
    }

    func testSavedGeometryKeepsHolesAndStartsWithDotsOnly() throws {
        let snapshot = TerrainSnapshot(heights: [GridKey(x: 0, z: 0): 0, GridKey(x: 4, z: 4): 0.1], quality: [:], reference: 0, revision: 0, atCapacity: false)
        let restored = try JSONDecoder().decode(SavedScan.self, from: JSONEncoder().encode(SavedScan(snapshot: snapshot, isDemo: false)))
        let geometry = TerrainGeometry.build(restored.snapshot, settings: DisplaySettings())
        XCTAssertEqual(geometry.dots.count, 2)
        XCTAssertTrue(geometry.contours.isEmpty)
        XCTAssertTrue(geometry.grid.isEmpty)
        XCTAssertTrue(geometry.surfaceTriangles.isEmpty)
    }

    func testCameraProjectsTargetIntoTheCenterOfTheVisibleDepthRange() {
        var camera = OrbitCamera()
        camera.fit(TerrainGeometry.demo(), aspect: 0.46)
        let projected = camera.viewProjection(aspect: 0.46) * SIMD4(camera.target, 1)
        XCTAssertGreaterThan(projected.w, 0)
        XCTAssertEqual(projected.x / projected.w, 0, accuracy: 0.00001)
        XCTAssertEqual(projected.y / projected.w, 0, accuracy: 0.00001)
        XCTAssertGreaterThan(projected.z / projected.w, 0)
        XCTAssertLessThan(projected.z / projected.w, 1)
    }

    func testOrbitPanZoomAndFitDoNotChangeSavedTerrain() {
        let snapshot = TerrainGeometry.demo()
        var camera = OrbitCamera()
        camera.fit(snapshot, aspect: 0.46)
        let fittedPosition = camera.position
        let originalDistance = camera.distance
        camera.rotate(x: 100, y: 20)
        XCTAssertNotEqual(camera.position, fittedPosition)
        let target = camera.target
        camera.pan(x: 50, y: 20, viewportHeight: 800)
        XCTAssertNotEqual(camera.target, target)
        camera.zoom(scale: 2)
        XCTAssertEqual(camera.distance, originalDistance / 2, accuracy: 0.001)
        camera.zoom(scale: 0)
        XCTAssertTrue(camera.distance.isFinite)
        camera.fit(snapshot, aspect: 0.46)
        XCTAssertEqual(camera.position, fittedPosition)
        XCTAssertEqual(snapshot.heights, TerrainGeometry.demo().heights)
    }
}
