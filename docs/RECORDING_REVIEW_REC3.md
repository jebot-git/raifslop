# rec3 casting, fitting and golf physics review

The later [live-test review](RECORDING_REVIEW_LIVE_2026-09-22.md) supersedes the terrain-level head-fitting approach below with rigid head/shaft fitting, and adds further casting and round-transition fixes.

Reviewed `/home/blux/Downloads/rec3.mp4` (617.60 seconds, 1920×1080). Extracted overview frames cover the whole recording; the first minute was sampled at 4 fps, the shot/map view around 120–155 seconds at 2 fps, and the bunker sequence around 585–617 seconds at 1 fps. Images are in `test-results/rec3-review/`.

## What the recording establishes

- The opening minute shows repeated rod preparations and forward casts, including a line departing to the right around 20–22 seconds and another rightward result around 42–44 seconds. This is the lure-casting evidence missing from rec1/rec2.
- Golf begins around 70 seconds. Fitting is repeated at approximately 100, 180, 235, 260, 325, 385 and 485–555 seconds. The high-loft iron face is particularly apparent in the later fitting sequence.
- The map at approximately 142–147 seconds shows a curved recorded shot. Later ground traces and the slope grid make terrain break visible. The displayed 2.4 m/s wind is consistent with Spyglass's configured vector `(2.2, 0, 1.0)`, whose magnitude is 2.42 m/s.
- The final half-minute shows the ball and club in a visible sand depression beside the green. The footage supports the reported appearance mismatch but does not provide exact world coordinates for every lie query.

The prior VR run did not enable per-shot golf analytics. Video pixels cannot recover the controller's 3D velocity, contact normal, launch spin, or trigger timing. The changes below address reproducible code defects consistent with the reports; they are not a pose replay of this recording.

## Casting corrections

The gesture could complete during a small preparatory movement. The next negative movement then locked the saved heading, potentially preserving that preparation instead of measuring the real cast. A fresh 6 cm backswing now rearms motion measurement; a fresh 10 cm forward stroke replaces the previous candidate. An incomplete recovery retains the already accepted cast.

The previous peak estimator could select an isolated fast frame before its 80 ms window filled. It now uses an exact time window, treats its unfilled portion as rest at the reversal, and uses a time-weighted representative velocity (a vector medoid) to reject a brief lateral wrist/tracking spike. Both direction and range still come from controller movement, without headset heading. Sustained deliberately diagonal strokes remain supported. Release writes a concise `CAST_RESULT` to the client log for further diagnosis.

## Club fitting corrections

Preview and accepted play previously used different grip origins: fitting sampled the controller, while normal avatar-mounted play substituted the solved palm. Both now use the same attachment pose, including configured offsets and controller-mounted mode. Accepting a steady fit leaves the head's position and orientation unchanged.

Automatic fit previously leveled the head against world up even on sloped terrain. It now aligns to the local ground and preserves the selected club's nominal loft relative to that ground. The preview reports both terrain-relative loft and nominal club loft. Irons and wedges intentionally retain upward-facing loft (27–56 degrees); a putter retains 2 degrees and driver 11 degrees. It does not flatten every clubface to the same angle. Existing saved fits are preserved; recapture a fit to use the corrected solver.

## Flight and ground physics

The wind itself was already applied as relative air velocity (`ball velocity - wind`). No arbitrary wind multiplier or curvature clamp was added.

Two definite errors were corrected:

1. Lift magnitude used total spin while its direction used a normalized spin/airflow cross product. Near-parallel “rifle” spin could therefore produce full lift from a tiny transverse component. Lift now uses only transverse spin and approaches zero continuously when spin aligns with airflow.
2. Grounded motion instantly replaced spin with the rolling value. This discarded landing backspin and could create rotational energy from a sliding ball. Ground contact now applies friction to contact-point slip, exchanging linear and angular momentum before entering pure roll. Downhill pure-roll acceleration includes the solid sphere's rotational inertia, `5/7 g sin(slope)`, rather than treating the ball as a sliding point mass.

Controlled flat-ground comparisons (not reconstructed video shots), using launch velocity `(0, 18, -60)` m/s and backspin `(280, 0, 0)` rad/s:

| Scenario | Forward displacement to grounded state | Lateral displacement |
| --- | ---: | ---: |
| Calm, backspin only | 223.47 m | 0.00 m |
| 2.4 m/s perpendicular wind | 223.41 m | 7.45 m downwind |
| Calm, spin tilted to `(280, 100, 0)` rad/s | 219.31 m | 32.92 m |

A visibly strong curve can therefore be produced by face/path-induced spin despite mild wind. The recording does not establish which component caused each shot. Tests check mirrored wind response, spin direction, near-parallel continuity, ground-contact energy loss and frame-rate stability.

On a flat green, a ball already rolling at 1.83 m/s stops after 3.04 m with the existing 0.55 m/s² resistance (approximately a 10 ft Stimpmeter roll). At 3 m/s, a no-spin skid travels 5.30 m, the tested backspin case 3.28 m, and a ball already rolling on sand 1.00 m. Slopes extend or shorten roll; a horizontal starting velocity need not remain a straight ground path.

This remains an approximate golf simulation. Surface friction/restitution, turf retention and aerodynamic coefficients are engineering/gameplay parameters, not a calibration to a specific ball and course measurement. Research on actual golf-ball bounce also finds limitations in simple rigid-friction models: [Biber et al., *Measurements and linearized models for golf ball bounce*](https://arxiv.org/abs/2302.02758). Aerodynamic coefficients vary with spin and ball construction: [*Aerodynamics of Golf Balls in Still Air*](https://www.mdpi.com/2504-3900/2/6/238).

## Bunker alignment

The terrain used interpolated colours and material IDs from vertices 2 m apart, while physics queried the 1 m lie raster. They could disagree between vertices and at narrow bunker edges. Mapped terrain now samples the exact lie raster in the fragment shader with nearest-cell lookup and the same origin as physics. Sand appearance, lie labels, impact attenuation and rolling resistance consequently share one classification. Course layouts and the continuous play lanes are retained.

## Validation

New suites: `golf_physics_review` and `golf_surface_alignment`. Updated casting, attachment and controller fixtures cover preparation followed by a real cast, lateral outliers, fit acceptance with an offset palm, and terrain-relative loft. Full-head collision regression still covers all eight clubs and all head surfaces.

Passed headless suites: `cast_direction`, `tracked_cast`, `cast_tolerance`, `golf_controls_feedback`, `golf_attachment`, `golf_head_contact`, `golf_physics_review`, `golf_surface_alignment`, `golf_course_lanes`, `golf_courses`, `golf_loading`, `golf_vr_input`, and `lure_fishing`. Logs are in `test-results/vr-fixes/`.

The Vulkan surface test also passed on all four courses. It reads back the uploaded raster, compares thousands of rendered bunker/rough pixels with physics lookups, and checks the new palette against the old vertex-colour exposure. Final log: `test-results/rec3-review/surface-render.log`; boundary images: `bunker-*.png`. An initial fixture incorrectly assumed screenshot pixels and window coordinates had the same scale; the test now maps between their actual sizes. The exposure comparison also caught and corrected double colour-space conversion in the new palette. `git diff --check` passes.

No new VR session was launched for this review. Hardware confirmation remains separate from the automated and desktop-render checks.
