import Foundation

actor TerrainProcessor {
    private var map = TerrainMap()
    private var generation = 0

    func reset(generation: Int) {
        self.generation = generation
        map = TerrainMap()
    }

    func integrate(_ samples: [DepthSample], camera: SIMD3<Float>, time: Double, generation: Int) -> TerrainSnapshot? {
        guard generation == self.generation else { return nil }
        map.integrate(samples, camera: camera, time: time)
        return map.snapshot()
    }

    func geometry(_ snapshot: TerrainSnapshot, settings: DisplaySettings) -> DisplayGeometry {
        TerrainGeometry.build(snapshot, settings: settings)
    }
}
