# rec4 fixes and next VR test

The focused suite runs locally with synthetic tracking and **does not launch VR**:

```sh
python tools/run_vr_test_suite.py --focus rec4
```

It runs 22 suites: the new recorded-motion, fitting, trunk and contact regressions plus the related casting, golf controls, physics, loading, mesh contact and recorder tests. Each invocation uses a fresh profile and saves logs, `suite-results.json`, and an offline `contact-review.html` viewer. Run without `--focus rec4` for the complete gameplay and network suite.

## Changes under test

- Casting validates actual hand translation, orientation continuity and tracking confidence before calculating rod-tip movement. Motion mode has one authoritative gesture state. A deliberate new backswing invalidates the old release; a downward follow-through retains the completed swing. The initial direction handles rods pointing down behind the player, and the measured backswing refines the casting plane.
- Head orientation is independent of fitted handle angle and shaft length. Automatic fitting establishes the intended address face and loft, with the whole head above terrain. Stick adjustments affect the handle. The head and shaft remain connected at the hosel; normal controller motion rotates both. Explicit face correction remains a separate controls setting.
- Legacy fitted orientations are converted without an immediate orientation jump, with original values archived in the profile. Their provenance is marked `legacy`. **Capture a new address fit during this test** to replace the old tilted calibration with the new intended head frame. New explicit corrections are tracked separately and survive refitting.
- Trunk capsules extend below ground so the visible base has a full-width collider. Ball collision sweeps a sphere and resolves initial overlap; a collision only reflects velocity entering the surface and preserves tangential motion.
- Telemetry identifies face/sole/crown/heel/toe/back impacts and the local contact normal. Recorded impulses and ground resolution pass replay checks; impact coefficients have not been retuned.
- Controller capture and client metrics persist through golf transitions. The recorder test verifies actual automatic polling in fishing, golf and after returning, rather than manually calling its process function.

## Automated acceptance

| Test | Coverage |
| --- | --- |
| `rec4_cast_replay` | Recorded attempts 4, 14, 25, 39 and 52; 72/90/120 Hz; three play-space rotations; stationary rejection, hand/rotation jumps, stale release and tracking recovery. |
| `tracked_cast`, `cast_direction`, `cast_tolerance` | Host integration, head-aim mode, trigger release-frame movement, head independence, slow/fast/overhand casts and follow-through. |
| `golf_fit_invariants` | Both hands, all eight clubs, handle axes and reach changes, fixed head frame, hosel connection, controller rotation, accept/undo and versioned profile migration. |
| `golf_attachment`, `golf_controls_feedback`, `golf_fitting_analytics` | Preview/accept/reload consistency, calibrated controller/palm mounts, controls, turf clearance and fit confirmation consumption. |
| `golf_tree_collision` | Three tree scales, flat/uphill/downhill terrain, ground-level and grazing sphere paths, deep overlap and slow/fast glancing motion. |
| `rec4_golf_replay` | All 30 recorded contacts; unchanged impulses, contact labels, finite trajectories, passive energy and no turf penetration at three cadences. |
| `vr_test_capture` | Real frame callbacks across course enter/leave; digital and analog inputs, tracking loss, golf state and orderly flush. |

Other focused suites retain full-head mesh collision, turf/contact feedback, wind/rolling physics, physics stress, course loading and surface-map checks. A synthetic pass does not certify headset ergonomics or sensor accuracy.

## Live sequence after launch authorization

`tools/launch_vr_test.sh` is prepared for the connected WiVRn server. It starts the game, controller recorder and analytics collector, writing logs under `builds/Rec4VRTest-2026-09-23/live-<UTC>/`. It uses the existing user profile so the migration can be tested. Capture is bounded to one hour; video is not started automatically. The launcher has not been run as part of implementation.

1. **Capture continuity:** stand still ten seconds; join golf; wait ten seconds; return to fishing. Confirm `CLIENT_METRICS` continues and controller frames include golf state without a mode-long gap. Pause testing if capture is missing.
2. **Motion casting:** head aim off; repeat five slow, five fast overhand and five sidearm casts. Include rod-behind-head/downward starts, preparation wiggles, looking sideways, immediate release and delayed release. Direction must follow the measured swing, and slow casts must remain shorter. Hold trigger without moving: no cast. Start a new backswing and release before its forward stroke: no reuse of the earlier cast.
3. **Head-aim casting:** repeat five fast wrist casts and five slow casts with the gaze initially above the horizon. Valid back/forward strokes release reliably.
4. **Fresh fitting:** enter Controls, note the older-fit notice if present, capture a new address fit, and inspect every club. The head should have its intended loft rather than tilt with the handle. Change each handle axis and reach while holding the controller still: head orientation stays fixed. Accept, undo, recapture, leave/rejoin; verify the mesh and collision remain aligned. A confirms without teleporting. Repeat left-handed and with one controller.
5. **Contacts:** centre-face putt/chip/drive, then deliberate heel/toe/sole/back touches. Preserve whole-head contact. Note the approximate time of each surprising angle and each apparent miss. Contact replay should distinguish actual surface hits from inactive collision or tracking gaps.
6. **Trunks:** slow ground roll into a trunk, grazing roll, fast shot, and a tree on a slope. The ball must stop/bounce outside the visible trunk. A restored embedded lie must move to the nearest outside surface when motion resumes, without an arbitrary upward jump.
7. **Controls and return:** grip-only and trigger-only collision; sticks cannot move/turn the player while armed. Verify radial, handedness, offhand support, tablet and course retirement/resume. Return to fishing, stand still ten seconds, then quit normally.

Record not-tested hardware conditions explicitly (for example absent hip tracker or second player). Keep any new failure separate from an automated pass.

## Reviewing the next run

The live folder contains `controllers/controllers-*.jsonl`, `run.log`, copied golf telemetry, profile snapshots, `session.json`, and collector events. Engine monotonic timestamps correlate input and shot records. Video needs its own timing anchor; do not assume its elapsed time equals engine time.

Generate a contact viewer from copied golf telemetry files:

```sh
python tools/review_golf_contacts.py path/to/golf-session-1.jsonl path/to/golf-session-2.jsonl --output test-results/next-contact-review.html
```

The viewer shows measured contact/ball positions and incoming, outgoing and normal directions in three head-local projections. Vector display lengths are normalized; speeds are listed in metres per second. It describes actual contacts, not the player's intended shot.
