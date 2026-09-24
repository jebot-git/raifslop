# rec4 gameplay review — 23 September 2026

Reviewed `/home/blux/Downloads/rec4.mp4` (18:04) alongside the stopped WiVRn run on `e934c1f`, its controller recordings, cast traces, and both golf telemetry sessions. This report proposes changes; it does not implement gameplay fixes or launch another VR session.

The strongest findings are a reproduced cast-sampling failure, a mismatch between the fitting implementation and the requested behavior, and a reproduced ground-level trunk collision gap. Unexpected shot angles correlate with club orientation and contact location; they do not yet establish a general ball-physics defect.

## Evidence and coverage

- Live data: `builds/FullVRTest-2026-09-23/live/`.
- 54 motion-cast attempts: 48 launched, six rejected. A launch is not proof of correct direction or power. No head-aim casts were recorded in this run.
- 30 golf launches and completions, 33 contact attempts, 11 accepted fits.
- Video reviewed through a full-duration frame overview and closer sampling of the fishing section. The headset recording supplies visual context; numerical conclusions below come from telemetry and code/probe results.
- Event times below are **engine monotonic seconds**, not video timestamps. `rec4.mp4` has no common timestamp metadata, so exact frame-to-event synchronization has not been established.
- Analysis, plots, replay scripts and probe results: `test-results/vr-analytics-2026-09-23/` (local, ignored output). `analyze.py` regenerates cast statistics; `detail.py` generates the plots and selected raw replay input.

**Capture limitation:** the newly added continuous controller recorder was disabled when entering golf. There is a frame gap from 276.127 to 491.098 seconds and no continuous frames after 496.583 seconds. Button signals and separate golf telemetry continued, including controller-derived velocities and short contact windows. These allow shot analysis but not reconstruction of every missed swing or full fitting gesture. Fix capture persistence before the next test; do not treat the missing golf frames as tracking loss.

## 1. Motion casting: valid fast strokes cross the discontinuity filter

In `scripts/main.gd::_sample_cast_swing`, a virtual rod-tip step over `max(0.5 m, delta × 35 m/s)` is discarded. At 72 Hz this is approximately 36 m/s. The tip is 1.68 m beyond the controller, so wrist rotation can cross this limit while the hand itself moves normally. The code advances `cast_last_tip` before rejecting the step, permanently removing that travel from the gesture measurement.

Reconstruction from calibrated controller poses found over-limit samples in 50 of 54 attempts; 46 lost more than 10 cm of forward-axis travel. These counts identify filtered motion, not 50 proven bad casts. Recorded right-controller tracking remained valid throughout the analyzed attempts.

### Reproduced example: cast 39, 223.306 s

Four samples in the main forward sweep are rejected. Controller hand speed in those samples is 3.8–5.8 m/s; rotational steps are 24–38 degrees, supported by recorded runtime angular velocities of 22–38 rad/s. The extended tip reaches approximately 83 m/s. Reconstructed tip positions agree with the recorder's direct tip values to under one micrometre.

A headless Godot replay using the current production `cast_motion.gd` reproduces the logged result:

| Input | Measured cast speed | Horizontal swing vector |
| --- | ---: | --- |
| Accepted original trace | 3.299 m/s | `(0.263883, 0, 0.003753)` |
| Raw controller samples with current filter | 3.299 m/s | `(0.263882, 0, 0.003753)` |
| Same samples without the tip-jump filter | 47.534 m/s | `(3.792708, 0, -0.276091)` |

The retained measurement comes from a small early movement; the main forward sweep disappears. Removing the filter in this isolated replay demonstrates the cause, **not a proposed production fix by itself**.

![Cast 39 filtered forward sweep](../test-results/vr-analytics-2026-09-23/cast39-filter.png)

There are two additional consistency problems:

- A new backswing resets candidate measurement but leaves `swing_travel`, `swing_speed` and the host's completed-stroke latch intact. Twenty-one launches have a current forward accumulator below 10 cm and reuse an earlier completed swing. Retaining follow-through is useful, but the two gesture states can disagree after a deliberate new backswing.
- The gate direction is selected from the rod orientation at activation. Cast 52 selects almost the opposite horizontal gate from nearby attempts. This supports auditing sign changes near vertical rod poses; headset direction should remain diagnostic only when head aim is disabled.

**Proposed fix:** validate discontinuities using actual controller translation, quaternion continuity, tracking confidence and elapsed sample time. Derive tip velocity from accepted controller motion, with a bounded robust window. Replace the separate completion latches with one explicit backswing/forward/committed/released state. Rearm only on a deliberate new backswing, preserve a completed follow-through, and establish a stable motion-derived casting plane without headset steering.

**Acceptance:** replay recorded fast casts and preparation wiggles at 72/90/120 Hz; rotate the same motion around the play space and require correspondingly rotated launch direction. No stationary-trigger cast; no power/direction from head movement; genuine tracking jumps still rejected. Several rejected attempts in this run are very short taps with little accepted travel, so do not simply make every trigger release launch.

Replay evidence: `cast-replay.log`, `cast_replay.gd`, `cast39-raw.json`, `cast-analysis.csv`.

## 2. Fitting: keep the head address orientation independent of shaft fit

All 11 accepted fits retain the same saved right-head correction, approximately `(2.86°, -1.45°, -39.33°)`. This run does **not** show automatic fitting rewriting that correction. However, `club_fit.gd::head_pose` and `main.gd::_sync_physical_head` construct the head basis from the fitted shaft basis. Changing the handle angle therefore still changes the head's world orientation.

Manual fitting also explicitly edits `candidate.head_rotation` in `fit_session.gd::adjust`, and the offhand trigger reverses the face. The preview instructions advertise head yaw/pitch/roll. These controls conflict with the requested fitting behavior.

**Proposed fix:** separate the intended head address frame (face direction, loft and sole orientation) from the fitted handle/shaft frame. At the captured controller pose, fit only shaft length and handle attachment angle, preserving the head address orientation. Connect the shaft to the head's attachment point; keep the rendered head and collision geometry on exactly the same transform. After fitting, ordinary controller rotation must still move the whole club naturally.

Both automatic fitting and stick adjustment should obey this invariant. Remove head rotation/reversal from the fit workflow. Version saved calibration and distinguish any explicit face correction from old fitting-generated values before migration; blindly preserving an old correction can preserve the problem, while blindly clearing all corrections can discard intentional settings.

**Acceptance:** across both hands and every club, varying reach/handle angle at a fixed captured pose leaves the head's face normal, loft and sole orientation unchanged within numerical tolerance. Preview, accept, reload, cancel and undo preserve the invariant. Head collider and mesh remain coincident.

## 3. Unexpected golf angles: examine orientation and actual contact surface first

Nine of 30 launches are classified as club-body contacts. Thirteen launch downward, including six body contacts. Contact timing around the examples is approximately 13–14 ms with negligible initial penetration; the records do not suggest a gross overlapping-start or long-frame explanation for these hits.

| Engine time | Club / second-session shot | Contact evidence in head-local space | Initial launch elevation |
| --- | --- | --- | ---: |
| 642.367 s | 7 Iron / 5 | Sole, normal about `(0.16, -0.98, -0.09)` | −29.3° |
| 784.021 s | Driver / 10 | Sole, normal about `(-0.06, -1.00, -0.04)` | −51.3° |
| 951.163 s | Putter / 17 | Upper surface/edge, normal about `(0, 0.90, -0.43)` | +47.9° |
| 1113.337 s | Driver / 27 | Sole, normal about `(-0.05, -1.00, -0.04)` | −47.4° |
| 1132.227 s | Driver / 28 | Back of head, normal about `(0, -0.02, 1.00)` | +6.8° |

![Golf launch elevations](../test-results/vr-analytics-2026-09-23/shot-launches.png)

These impulses are being calculated from the encountered mesh surface. A visually plausible swing can strike with the sole or back if the fitted head is rotated. Fixing head orientation should precede tuning launch parameters. The data does not establish that every unexpected angle is a fitting consequence or that all current impulses are physically correct.

**Proposed fix/audit:** preserve collision over the entire head as requested. Add explicit face/sole/toe/heel/crown/back contact labels and a replay overlay showing contact point, normal, incoming velocity and outgoing velocity. Replay the extreme examples after correcting fitting. Test the coupled ball/ground response for downward contacts, including high spin and low-speed putts; establish that the subsequent ground resolution does not inject energy or leave penetration. Avoid forcing all contacts to use the nominal face normal, which would hide real body contacts.

**Acceptance:** deterministic mesh sweeps at known head poses produce the expected surface normal; equal swings with different fit lengths preserve face orientation; off-centre and body hits remain possible and explainable. Ground contact dissipates energy appropriately. A missed-swing review needs the repaired continuous capture, not just launched-shot records.

## 4. Tree trunks: existing colliders miss the visible base

Tree colliders already exist and include the golf ball collision layer. `connected_course_world.gd::add_foliage_tree` uses a capsule with radius `0.3 × size`, height `5 × size`, and centre `2.5 × size` above ground. Its bottom hemisphere tapers to a point at ground level. For a unit-size tree, the capsule cross-section at ball-centre height (21.335 mm) is only about 111 mm in radius, despite a nominal trunk radius of 300 mm.

Separately, `course_world.gd::sweep_ball` casts a centre-line ray, so it ignores ball radius and does not recover a ball already inside an obstacle.

A headless Godot probe using the actual course-world tree builder confirms:

- At ball height, rays 150 mm and 250 mm from the trunk centre pass through.
- The same paths at one metre height collide.
- A path 310 mm from the axis misses, although a finite-radius ball should graze a 300 mm trunk.
- A ray beginning inside the trunk misses.

The first golf session's second shot stops 162 mm horizontally from a mapped tree centre (`-403.56, 90.92`, scale 1.33), well inside its nominal 399 mm trunk footprint. This supports the tester's report and the close trunk view in the recording. The isolated probe establishes the geometry defect independently of video timing.

**Proposed fix:** use a cylinder/convex trunk base extending below terrain, or bury the capsule's lower hemisphere enough to maintain the intended width at ground level. Sweep the actual ball sphere and handle initial overlap with controlled depenetration. Match trunk dimensions to the visible asset and test slopes and scaled trees.

**Acceptance:** ground-level centre/glancing/high-speed shots, uphill and downhill trunks, scaled foliage, and initial overlap cannot leave the ball inside the visible trunk. Preserve predictable bounce and tangential motion rather than teleporting the ball arbitrarily.

Probe evidence: `tree_probe.gd`, `tree-probe.json`, `tree-probe.log`; run headless with `--xr-mode off`.

## Suggested implementation order

1. Keep controller capture and client metrics alive across fishing/golf transitions; verify real process callbacks during both modes.
2. Fix cast discontinuity handling and unify gesture state; add recorded-motion replays.
3. Separate head orientation from handle fitting and migrate calibration deliberately.
4. Correct trunk base geometry and finite-radius ball sweeps.
5. Re-run the recorded shot contacts with corrected fitting, then adjust impact/ground physics only where replay demonstrates a remaining defect.

No new VR launch was performed for this review. The probes run headlessly with XR disabled. Existing test-suite changes remain in the workspace.
