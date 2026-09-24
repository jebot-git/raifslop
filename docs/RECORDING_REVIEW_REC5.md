# rec5 and live VR session review — 23 September 2026

The fitting complaint is confirmed. Automatic capture still replaces the head orientation, and the previous change removed manual head adjustment from the fitting sticks. Terrain materials are recognized and have different physics, but the current response is poorly balanced: shallow sand impacts retain too much speed, rough offers only a modest increase over fairway resistance, and the stopping rule suppresses rollback on substantial slopes. Ball size and club/obstacle collision shape are consistent with the visible ball.

## Evidence and scope

- Video: `/home/blux/Downloads/rec5.mp4`, 1920 × 1080, 18:46.37. Reviewed overview frames throughout and detailed sequences around 5:48–5:58, 9:22–9:30 and 16:38–17:18. These are video times; engine times below use the telemetry clock and are not interchangeable.
- Session: `builds/Rec4VRTest-2026-09-23/live-20260923-160715/`, ending normally at 16:27:03 UTC.
- 83,807 controller frames, including 71,340 golf frames; 52 cast attempts, 44 golf shots, 19 fit previews and 15 accepted fits.
- Capture continued through golf. Median frame interval 13.926 ms, 95th percentile 14.659 ms. The only gap over 100 ms was 319 ms at entry into golf. Golf telemetry reported zero dropped events; no runtime script errors were found.
- Frequent offhand tracking absence is consistent with one-controller testing; it is not itself evidence of a defect.
- Analysis and headless probes: [evidence directory](../test-results/live-review-20260923-160715/). The analysis used the existing uncommitted implementation from the live test. No gameplay changes or new VR launch were made for this review.

## 1. Automatic fitting still rotates the head

At each automatic preview, the head changes relative to the controller. Removing controller and tracking-origin rotation from the comparison establishes that these are calibration changes rather than hand movement.

| Engine time | Club | Controller movement | Head change relative to controller |
| --- | --- | ---: | ---: |
| 194.379 s | Driver | 0.137° | 68.30° |
| 306.777 s | Sand wedge | 0.027° | 70.09° |
| 609.796 s | Sand wedge | 0.081° | 162.15° |
| 615.872 s | Sand wedge | 0.115° | 151.33° |
| 1083.796 s | Pitching wedge | 0.147° | 31.42° |

![Automatic fitting rotations](../test-results/live-review-20260923-160715/fit-rotation.png)

`main.gd::_capture_stable_club_fit` passes the current head correction to `solve_grounded` only when its source is marked `explicit`. Normal previously fitted and migrated values take the other path. `club_fit.gd::solve_grounded` then constructs a new address basis from aim direction and world up. The target direction also passes through a headset-facing hemisphere test in `address_direction`, creating an additional possible near-180° change. This code explains why separating shaft and head transforms was insufficient: the automatic capture still overwrites the independent head transform.

The previous tests enforced a newly constructed nominal world orientation after capture. They did **not** enforce preservation of the existing intended orientation across capture. That was the wrong acceptance condition for the requested behavior.

**Fix:** automatic fitting must take the existing intended head orientation as input, preserve it, and solve only shaft length, handle attachment angle and head placement/sole clearance. Pin direction and gaze must not redefine the head orientation. Preserve this through recapture, accept, reload, undo and both handedness modes. If a reset to nominal orientation is useful, expose it as an explicit action separate from fitting.

## 2. Manual head adjustment was removed from fitting

There are 784 fitting frames with a stick deflected more than 0.3, at engine times 1043–1082 s. In that interval, the shaft changes by a net 36.51° relative to the controller; the head changes by only 0.000018°. The sticks are being received, but `fit_session.gd::adjust` now changes `candidate.rotation`, which controls the shaft, and never changes `candidate.head_rotation`.

The detailed video sequence at 16:38–17:18 shows the handle pitch/roll/yaw controls and changing reach/clearance. Separate “Clubface correction” controls remain available in settings, but they do not restore the manual head control that was removed from the fitting workflow. My previous change was a regression in that workflow.

**Fix:** restore a clearly selected manual head-adjustment mode alongside handle/length adjustment, usable with one controller. Automatic fitting must preserve manual head edits. Tests should require head invariance for **automatic/handle** operations and require intentional head changes for **manual head** operations. Save, cancel and undo must preserve both independently.

## 3. Casting improved, but the direction gate still rejects substantial swings

All 52 attempts used motion aiming: 45 launched and seven did not. No controller samples were rejected by the new pose filter in these traces. This supports retaining the filter change; the former virtual-tip rejection is not the remaining failure in this run. The previous run launched 48/54, so the raw launch fraction alone does not establish improved success. The tester reports improved feel, and the traces now retain fast motion.

Two early rejected attempts contain little travel. Five later failures need attention. In particular:

| Attempt | Engine release time | Gate axis X/Z | Recorded backswing travel | Recorded forward travel |
| --- | ---: | --- | ---: | ---: |
| 21 | 90.570 s | +0.588 / +0.809 | 3.07 m | 0 |
| 22 | 92.176 s | +0.750 / +0.661 | 3.41 m | 0 |
| 23 | 93.634 s | +0.407 / +0.913 | 3.45 m | 0 |
| 24, launched | 96.335 s | −0.826 / −0.563 | 0 at release | 3.06 m |

The rejected tips move strongly toward negative Z, but their positive-Z gate labels that motion as backswing. The next successful attempt has a gate in the opposite hemisphere and a substantial negative-X/negative-Z forward sweep. This implicates gate initialization and the trigger timing relative to the swing; it does not justify launching on every release. Recorded virtual-tip travel is not hand translation.

**Fix:** replay these attempts with their pre-trigger controller history. Stabilize the motion plane and its forward sign across rod poses and late trigger presses, without using head aim. Keep stationary-release and genuine tracking-jump rejection. Include attempts 21–24, 39–43 in regression fixtures.

Also, 36/45 successful casts reach the current 24 m range cap. Once the remaining gate problem is fixed, review power mapping: retaining fast tip motion has exposed how early the existing distance formula saturates. This is a tuning concern, not proof of an incorrect launch direction.

## 4. Terrain is recognized; response needs more than a friction increase

Spyglass uses the same 1 m lie map for physics and rendering. Sand is sampled as `sand`, including recorded bunker shots. The surface-alignment test passes. The evidence does not support a general recurrence of sand being classified as rough.

A headless replay used the recorded launch positions, velocities and spins against the production course and ball model. Scenery collisions were omitted, so it is a terrain isolation test, not a complete scene replay. It reproduced the recorded roll distance within 2 cm for 42/44 shots. Shots 1 and 2 differed and should not be used as exact terrain-only reconstructions.

### Sand

Landing friction and deformation depend on the normal impact speed/impulse. With a shallow arrival, both can be small even when the ball has substantial horizontal speed. After landing, sand applies a constant rolling deceleration of 4.5 m/s² in the rolling branch. There is no sustained sand penetration/ploughing model.

| Shot | Evidence |
| --- | --- |
| 3, sand wedge | Steep downward sand impact: speed falls from 22.02 to 4.33 m/s in replay; subsequent recorded roll is 1.57 m. Sand can slow the ball strongly. |
| 4, sand wedge | Speed falls from 38.22 to 14.04 m/s on first sand contact, but the ball still rolls 25.79 m entirely in sand. |
| 5, sand wedge | Shallow contact retains 95.5% of tangential speed: total speed falls only from 34.39 to 32.81 m/s. Recorded near-ground path crosses about 38.6 m of sand before reaching rough, then continues across fringe, green and fairway. Total roll is 213.70 m, **not all in sand**. |
| 10, 7 iron | An airborne arrival onto sand falls from 23.51 to 4.67 m/s on first contact; recorded roll is 1.90 m. |
| 35, 7 iron | Recorded ball enters a final sand segment at 6.09 m/s and stops after approximately 5.80 m. Resistance is active, but the travel can still appear excessive. |

**Fix:** calibrate shallow landing and sustained sand travel together. Add passive, bounded energy loss for moving through deformable sand, with appropriate dependence on speed/contact state; test shallow/skidding arrivals as well as steep landings. Do not multiply every landing impulse indiscriminately: steep sand contacts already remove substantial speed.

### Rough versus fairway

Controlled production-model probes on flat ground, starting in pure roll at 3 m/s:

| Surface | Rolling resistance | Stopping distance |
| --- | ---: | ---: |
| Green | 0.55 m/s² | 8.18 m |
| Fairway | 1.8 m/s² | 2.50 m |
| Rough | 2.5 m/s² | 1.80 m |
| Sand | 4.5 m/s² | 1.00 m |

The materials differ. However, rough has only 0.7 m/s² more rolling resistance than fairway, which is easy to miss during a fast ground shot, especially with changing slope. The model has one rough category, no grass-depth response, and resistance is constant rather than increasing with travel speed. While skidding, it uses a separate friction/spin exchange branch and omits the rolling-resistance term altogether. Terrain replays showed this branch in 12.8% of grounded substeps for shot 5 and 27.3% for shot 35; it is a contributor to audit, not the sole explanation of the long roll.

![Recorded terrain response](../test-results/live-review-20260923-160715/terrain-response.png)

**Fix:** give rough a calibrated grass-drag response that remains present while sliding as well as rolling. Compare identical entry speeds/spins on each surface and across boundaries. Verify energy dissipation and travel distance over a useful speed range, not only a slow flat-ground putt. Increasing one coefficient alone would worsen the slope holding problem below.

### Slopes and missing rollback

The production code includes projected gravity and the 5/7 solid-sphere rolling factor. It does **not** ignore slopes. However, it uses the same resistance value both to slow the moving ball and decide whether a nearly stationary ball can remain at rest. With the current rule, downhill acceleration must exceed resistance before rollback starts:

| Surface | Approximate minimum slope angle to overcome the current holding rule |
| --- | ---: |
| Green | 4.50° |
| Fairway | 14.89° |
| Rough | 20.91° |
| Sand | 39.97° |

These are consequences of the code, not recommended physical targets. A plane probe confirmed that an uphill ball on a 10% grade reverses on green, but stops without reversing on fairway, rough and sand. At a 30% grade it reverses on fairway, while rough and sand still hold it. In the recorded session, shot 7 rests on a 4.35° fairway slope and shot 12 on a 9.52° rough slope; both are held by the current model.

An uphill landing need not always reverse: incoming momentum, spin, surface softness and slope all matter. But the current holding thresholds explain why visible inclines frequently produce no rollback. Once `moving` becomes false, `step` returns immediately, so it cannot resume rolling without a new launch.

**Fix:** separate moving resistance/material drag from the condition for static equilibrium. Calibrate surface-dependent rollback thresholds and evaluate force balance before sleeping. Include a ball arriving uphill, slowing through zero, then reversing; include stable shallow slopes and embedded sand lies where staying still is intended. Validate cross-slope break and changing normals too.

## 5. Ball collider size, shape and terrain-contact limitations

- Physics radius: **0.021335 m**, diameter **0.042670 m (42.67 mm)**; mass **0.04593 kg**.
- Visible mesh: `SphereMesh` with that radius and twice the radius as height; 24 radial segments, 12 rings. `ball_mesh.position` follows the simulated ball position. No ball-specific scaling was found; captured XR world scale is 1.
- Club collision: mesh-to-sphere sweep uses the same 0.021335 m radius in `club_head.gd`; impact inertia uses the same radius in `impact_solver.gd`.
- Obstacles: `course_world.gd::sweep_ball` uses `SphereShape3D` with that radius, a 0.1 mm query margin, finite-radius motion casting and initial-overlap recovery. The narrow-phase fallback margin is 1 mm.
- Terrain: the ball is **not** a Godot rigid body colliding with the terrain through that sphere. The custom simulator samples height/normal, places the centre at `height(x,z) + RADIUS`, and resolves impact analytically. Grounded motion pins the centre back to the sampled height every substep. The mapped height grid is 2 m; normals use a 24 cm finite-difference span.

Thus the visible ball and club/obstacle collider agree in size and spherical shape. Terrain contact is the important approximation: vertical radius offset is not exact sphere support on a slope, and grounded terrain following does not test whether contact should be lost at a sharp crest. The support-height error is small on gentle slopes (about 1.4 mm vertically at 20°), so it does not explain hundreds of metres of rollout. Still, slope support, crest separation and fast lip crossings deserve dedicated tests rather than treating the obstacle sphere sweep as proof that terrain collision is exact.

## 6. Golf launch angles remain a separate concern

There are 25 face, 17 sole, one back and one heel contacts; 23/44 launches point downward. This supports fixing head orientation before retuning club impulses. It does not establish that every downward shot is a fitting error. The complete head remains a valid contact surface as requested.

Use the [44-shot contact viewer](../test-results/live-review-20260923-160715/contact-review.html) to inspect actual contact normals and incoming/outgoing velocity. Add replay checks for coupled ball/ground response after sole and steep downward contacts; do not disguise those contacts by forcing a face normal.

## Recommended order and verification

1. Preserve head orientation during automatic fitting and restore intentional manual head adjustment. Replace the incorrect test invariant with before/after orientation checks using the recorded examples.
2. Replay the remaining failed casts with pre-trigger controller history and correct motion-plane sign initialization. Keep the improved continuity filter.
3. Separate static holding from moving surface resistance; validate uphill stop/reversal on controlled slopes.
4. Calibrate rough grass drag and shallow sand impacts/rollout, using identical-entry surface comparisons plus recorded shots 4, 5, 10 and 35.
5. Audit exact sphere support and terrain contact transitions, then replay extreme golf contacts after fitting is corrected.

Headless checks performed with XR disabled and isolated user data: `golf_surface_alignment.gd` and `golf_physics_review.gd` both pass. The new diagnostic `terrain_probe.gd` exercises flat/slope rolling, landing response and the recorded-shot terrain replay. These results show that the current tests can pass while the user-visible fitting and physics expectations remain unmet; they are not an acceptance sign-off.

Key artifacts in the evidence directory: `summary.json`, `fit-changes.csv`, `casts.csv`, `extra-summary.json`, `terrain-probe.log`, `terrain-replay.json`, `terrain-frames.json`, `terrain-segments.json`, the extraction/replay scripts, video contact sheets and both regression logs.
