# GreenScan

An iPhone LiDAR prototype for visualizing putting surfaces with world-anchored dots and elevation contours.

## Open and run

Open `GreenScan.xcodeproj` in Xcode 26 or later with Swift 6.2 support. Select the **GreenScan** scheme.

- **Physical iPhone:** choose a LiDAR-equipped iPhone running iOS 26 or later, select your signing team in Signing & Capabilities, then run. Allow camera access. No account or network connection is required.
- **Simulator:** run and choose **Explore Demo**. Simulator cameras do not provide LiDAR. You can also add `--demo` to the scheme’s launch arguments.

The development environment used for the initial build is Xcode 27 beta 4. The project uses the local signing team and bundle identifier configured for Danny’s iPhone.

## Scanning

Point down and slowly sweep the same patch from at least two positions. Stable dots appear as the map receives repeated observations. Move along the putt to extend coverage.

- **Pause Scan** freezes terrain updates while camera tracking and viewing continue.
- **Resume Scan** continues refinement of the existing map.
- **Reset** clears the terrain and restarts tracking, retaining display preferences.
- **Layers** controls dots, contours, surface mesh, grid connections, and measurement quality.
- **Live camera** can be hidden or dimmed with the **Camera opacity** slider. This adjusts only the background; camera tracking and scanning continue.
- Dot spacing ranges from **5–30 cm**, defaulting to **10 cm**.
- Contour intervals are **1, 2, 5, or 10 cm**, defaulting to **2 cm**. Every fifth contour is stronger.
- Orange rings indicate fewer repeat observations when the quality layer is enabled. This is not a calibrated measurement-error estimate.

Scan from above, then pause and lower the phone to inspect. Blank areas need more coverage. After a tracking interruption, reset is required to avoid merging an uncertain coordinate alignment.

The demo is an explicitly labeled synthetic surface. Its viewpoint slider is for interface exploration, not a simulation of sensor accuracy. Reset reloads the synthetic terrain in demo mode; real scanning clears all measured terrain.


## Save and explore in 3D

Tap **Save** after capturing a surface. Saving pauses measurement updates, writes the measured height field to this iPhone, and opens a separate **Saved surface** view. It opens with dots only, without a camera image.

- Drag with one finger to orbit the terrain.
- Drag with two fingers to pan.
- Pinch to zoom; Zoom In, Zoom Out, and Fit buttons are also available.
- Open Layers to show contours, surface mesh, grid connections, or observation quality, and adjust spacing.
- Close the viewer to return to the paused scan. Resume manually when ready.
- Open **History** from the scanner to revisit saved surfaces, newest first. History survives app restarts.

Saved records contain the measured terrain and observation counts, not camera images. Derived layers can be rebuilt from those measurements, but missing regions are never filled in. A saved surface is a read-only capture: viewer controls do not modify its measurements. Demo saves are labeled Demo.

Files are versioned JSON records written atomically under Application Support/SavedScans. History loads metadata and opens terrain on demand. Save/load failures are shown; unreadable records are reported without deleting them. These are local app files, not a cloud account or a mesh export format.

## Architecture

- `Scanning`: ARKit session lifecycle and depth extraction. The camera delegate runs on the main queue; depth is copied into small, Sendable value batches.
- `Core`: a bounded 5 cm height field, robust observation fusion, and contour generation on an isolated processor actor. One integration is in flight at a time, with generation checks to reject stale reset results.
- `Rendering`: RealityKit batched dot meshes, contour ribbons, and terrain occlusion. Camera movement updates distance-based dot styling without recalculating the terrain surface.
- `Views`: SwiftUI scanning and display controls.
- `SavedScans`: local history and an independent, depth-tested Metal viewer with orbit/pan/pinch gestures.
- `Core/ScanArchive`: an actor for atomic persistence and validation of saved terrain.

The model uses confidence-weighted, per-frame cell medians, repeated-position filtering, outlier rejection with repeated-correction support, and conservative local smoothing. Contours use triangle intersections with fixed scan-relative elevation levels. Unsupported cells are not filled in.

## Tests

Core tests run on macOS:

```sh
swift test
```

UI tests run from Xcode with Product → Test on an iOS 26+ simulator. They cover demo pause/resume/reset, density changes, and the unsupported-hardware entry point.

## Prototype limits

- Actual outdoor accuracy, drift, shallow-angle capture, battery use, and sustained performance still require physical-device testing.
- The 5 cm model grid and selectable contour spacing are display/model resolutions, not sensor accuracy claims.
- The current model accepts a local surface within 65 cm vertically of its initial reference and stores at most 32,000 cells (approximately 80 m² at full coverage). Depth observations are limited to 0.25–3.5 m for this first prototype.
- This is a height field for ground-like surfaces, not a general 3D scanner. Shoes, balls, vegetation, and other objects may contaminate the terrain; there is no trained semantic ground classifier.
- Tracking-state checks cannot detect all gradual drift. No custom loop-closure or surveyed calibration is implemented.
- Live scans are held in memory until you tap Save. Ball/hole placement, ball physics, export, and resuming a saved scan in AR are deferred.
- Use as a practice/training prototype. See `PLAN.md` for rules context, sources, validation targets, and future work.

## Initial device delivery

The prototype was signed, installed, and launched on **Danny’s iPhone 16 Pro Max** on September 13, 2026, using bundle identifier `com.dtsang.puttanalyzer`. All seven core tests and both simulator UI tests pass. The final simulator run used a fresh, signed build to avoid stale unsigned test-runner caching. Simulator screenshots of the synthetic surface and layer controls are in `Documentation/`. Installation and launch do not establish real-world measurement accuracy.
