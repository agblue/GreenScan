# Golf Putting Surface Visualizer — Implementation Plan

Date: September 13, 2026
Status: First prototype implemented, signed, installed, and launched on Danny’s iPhone 16 Pro Max. All seven core tests and both simulator UI tests pass. Physical LiDAR and outdoor accuracy validation remain outstanding.

## Objective

Build an iOS app that uses a supported iPhone’s LiDAR and camera tracking to map a putting surface and display a stable grid of dots over the live camera image. Users can move around and lower the phone to inspect the measured terrain from different viewpoints. Additional observations refine the surface rather than replace the map.

The first release is a surface visualization and accuracy-validation prototype. Reliable ball-path prediction is a later milestone, contingent on measured terrain quality.

## First-version experience

1. Open the app, grant camera access, and begin scanning once tracking is ready.
2. Point toward the ground and sweep slowly to collect overlapping observations.
3. Display dots only where there is sufficient surface evidence; extend coverage as the user moves.
4. Refine previously scanned areas using additional reliable observations.
5. Pause scanning to inspect the frozen surface from any camera angle.
6. Adjust dot density, contour intervals, and layer visibility at any time.
7. Resume scanning to improve or extend the map, or reset to start over.

Scan primarily from above; viewing from near ground level is supported, but shallow-angle observations may be less useful for measuring the surface.

## Scanning controls and state

| Control | Required behavior |
| --- | --- |
| Pause Scan | Stop accepting measurements and freeze terrain updates. Keep camera rendering and position tracking active. |
| Resume Scan | Continue collecting and combining measurements with the existing map once tracking is reliable. |
| Reset Scan | Clear all accumulated measurements, surface geometry, contours, and confidence history; establish a fresh scan and resume collection. Preserve display preferences. |

Show an explicit status such as Initializing, Scanning, Paused, or Tracking Limited. Tracking Limited temporarily blocks measurement integration without discarding the map or changing the user’s pause preference. If alignment cannot be recovered, offer a fresh scan rather than combine incompatible measurements.

Handle camera permission denial and unsupported hardware with clear instructions. Query actual LiDAR/depth capability instead of relying solely on device model names.

## Surface estimation

- Use ARKit depth, confidence data, camera pose, and gravity alignment to accumulate observations in a shared world coordinate system.
- Maintain a fixed horizontal grid origin and orientation for the scan. Refine estimated heights without sliding or reseeding the grid as the viewpoint changes.
- Build a local terrain height model appropriate for a putting green, excluding unsupported areas and obvious above-ground objects where practical.
- Weight reliable observations more strongly and reject isolated outliers using local surface agreement and observation history.
- Avoid treating repeated, nearly identical frames as independent evidence. Account for viewpoint diversity when estimating scan quality.
- Allow credible repeated evidence to correct earlier estimates; do not permanently lock an incorrect early reading.
- Apply conservative spatial and temporal smoothing to reduce noise and visible jitter without flattening meaningful terrain.
- Track coverage and measurement quality. ARKit confidence is a useful input, not a calibrated error bound in millimeters.
- Pause integration when tracking is unreliable. Averaging reduces random noise but cannot correct systematic bias or pose drift.
- Compare depth-derived terrain with ARKit reconstruction during development. Avoid plane-flattening behavior that could erase the slopes being measured.

The same terrain model must drive dots, contours, and future surface-dependent features. Measurement collection remains independent of display density.

## Dot grid

Default spacing: **10 cm**. Adjustable range: **5–30 cm**.

| Preset | Spacing | Purpose |
| --- | --- | --- |
| Dense | 5 cm | Close inspection |
| Standard | 10 cm | Default view |
| Sparse | 20–30 cm | Cleaner overview |

- Density changes immediately redraw the existing surface, including while paused; no rescan is required.
- A denser display does not imply independently measured detail at that spacing.
- Use high-contrast dots with a subtle outline so the grass remains visible.
- Use perspective sizing with a minimum readable screen size and gentle distance fading.
- Distinguish measurement quality from distance using separate visual cues.
- Use a small rendering offset or equivalent depth handling to avoid dots flickering into the surface. Keep this separate from the measured terrain heights.
- Preserve true geometric scale in the live camera view.

## Contours

Provide a separate contour toggle, usable with or without dots. Contours connect equal-elevation locations on the terrain model and interpolate between samples where needed.

- Starting elevation interval: **2 cm**, adjustable during scanning or pause. Treat this as a display setting, not an accuracy guarantee.
- Use a stable scan-local elevation reference aligned with gravity, rather than a reference that changes as new areas are scanned.
- Make every fifth contour visually stronger.
- Smooth conservatively to avoid small false loops caused by noise.
- Do not bridge substantial unmeasured or unreliable regions.
- Closed loops naturally surround hills and depressions. On continuous slopes, contours may cross the map and terminate at coverage boundaries; never force them into circles.
- If the terrain uncertainty makes a selected interval misleading, indicate insufficient quality or recommend a coarser interval.

## Layers and interface

First-version layers:

- Surface dots: on by default.
- Contours: optional.
- Thin grid connections: optional.
- Scan coverage/quality: optional, with essential tracking status always visible.

Keep the live camera dominant. Put Pause/Resume and Reset within easy reach, and group density, contour interval, and layer controls in a compact panel.

Potential follow-up layers include downhill arrows, relative-elevation colors, and a diagnostic measured-point cloud. A separate 3D inspection view may later offer clearly labeled vertical exaggeration.

## Technical direction

- Native iOS application, with ARKit for tracking and LiDAR depth.
- SwiftUI for controls, with the rendering approach selected after a small performance prototype; RealityKit and custom Metal rendering are candidates.
- Keep measurement processing separate from rendering and interface state.
- Bound scan memory and avoid retaining every camera frame or depth sample indefinitely.
- Process locally for the prototype; no account, backend, or cloud upload is required.
- Live scans remain in memory until Save is tapped. Saving and history are now implemented; export and AR relocalization remain later features.
- Handle interruptions and foreground return explicitly; resume measurement only when alignment is reliable.

## Validation and decision criteria

Rendering a convincing surface does not establish measurement accuracy. Validate repeatability and agreement with independent measurements separately.

1. Scan a known flat surface and check for false slopes and false contour loops.
2. Scan independently measured slopes and compare direction and magnitude over defined patch sizes.
3. Repeat from different directions, heights, and distances; compare independent scans as well as cumulative refinement.
4. Revisit the starting area after walking around to look for tracking drift and seams.
5. Test real greens in sun and shade, with different turf and moisture conditions where available.
6. Check that additional observations reduce error or uncertainty rather than only making the display smoother.
7. Verify pause freezes terrain updates while viewpoint motion and display controls continue working.
8. Verify resume refines the existing map and reset removes all previous terrain.
9. Check visibility, frame rate, heat, battery use, and memory during sustained outdoor sessions.

Record height error, slope error over stated distances, repeatability, coverage, and tracking failures. Set quantitative acceptance thresholds after initial device measurements, before making accuracy claims or investing in path prediction.

A 1% slope corresponds to only 1 cm of rise over 1 meter. This is why local slope must be estimated from multiple observations over an appropriate area, rather than inferred directly from adjacent noisy dots.

## Implementation milestones

1. **AR foundation:** hardware checks, permissions, live camera, tracking status, and depth diagnostics.
2. **Accumulated terrain:** stable coordinates, observation fusion, confidence handling, and default dot grid.
3. **Scan lifecycle:** pause, resume, reset, and interruption handling.
4. **Visual controls:** dot spacing, layer toggles, perspective styling, and contours from the shared model.
5. **Field validation:** measured surfaces and real greens; tune filtering, coverage requirements, and performance from evidence.

## Later features

- Manually mark ball and hole positions on the measured surface.
- Show distance, elevation profile, and downhill direction.
- Export saved scans and explore AR relocalization of previous captures. Saving, history, and the separate 3D inspection view are implemented.
- Explore ball-path simulation using terrain, green speed, launch speed, and aim direction. Support multiple pace/line choices rather than imply a uniquely correct path.
- Consider automatic ball/hole recognition only after manual placement and terrain accuracy work well.

## Product context and references

Position the app initially for practice and training. Live elevation measurement and recommended lines are restricted during rounds under the Rules of Golf.

- [Apple: ARDepthData](https://developer.apple.com/documentation/arkit/ardepthdata)
- [Apple: Displaying a point cloud using scene depth](https://developer.apple.com/documentation/arkit/displaying-a-point-cloud-using-scene-depth)
- [Apple: Visualizing and interacting with a reconstructed scene](https://developer.apple.com/documentation/ARKit/visualizing-and-interacting-with-a-reconstructed-scene)
- [USGA: Rule 4](https://www.usga.org/content/usga/home-page/custom-search-pages/rules/2019-golf-rules-and-interpretations/fr-rule-4.html)

Existing products reviewed during planning include [PuttView](https://www.puttview.com/products/app/), [ProSide](https://apps.apple.com/us/app/proside-green-reader/id6760280733), [PutterForce](https://putterforce.com/manual/), and [BreakTrace](https://breaktrace.com/). Their advertised functionality overlaps with terrain visualization and future path prediction; their accuracy has not been independently tested here.

## Details to settle during implementation

No additional product decisions are required to begin the prototype. Confirm the available physical LiDAR-equipped test iPhone and deployment setup when device testing starts. Tune contour intervals, filtering, scan limits, and readability from actual measurements rather than assuming ideal sensor performance.

## Implemented extension: saved surfaces and camera visibility

- Save pauses the live scan, persists its terrain atomically, and opens a dots-only 3D viewer.
- One finger rotates; two fingers pan; pinch zooms. Fit and zoom buttons provide alternate controls.
- Saved-view layers include dots, contours, mesh, grid connections, and quality. No camera layer is available because images are not saved.
- History lists local saved captures newest first and survives app relaunch.
- Missing measurements remain missing in every derived layer.
- Live-camera visibility and a 0–100% opacity/brightness slider affect only the background, leaving overlays bright and tracking active.
- Returning from inspection leaves scanning paused until Resume is tapped.
