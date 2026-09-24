# Full VR test and controller collection

Run automated checks with `python tools/run_vr_test_suite.py --godot /usr/bin/godot`. This combines the gameplay/tracking suite, golf physics/contact/stress cases, controller-recorder validation, retirement/resume tests, and a server with two network clients. Every invocation uses fresh profiles and writes a structured report. Headless synthetic controllers are not a substitute for the hardware checks below.

## Live session capture

Launch the client with `--vr-test-capture --client-metrics --network-metrics --vr-capture-dir=<session>/controllers` after the Godot `--` separator. Controller capture is opt-in and does not change the player's settings or poses.

- `controllers/controllers-*.jsonl`: both raw controller poses and velocities, aim and calibrated poses, tracking validity/confidence, analog trigger/grip/stick, digital press/release events, headset and origin transforms, focus, user height, hip pose when available, fishing state, cast gesture, and golf club/ball/fitting state.
- Raw/local controller and headset poses use tracking-origin space; origin, club and ball poses use world space. Positions are metres, angular velocities radians/second, rotations quaternions in xyzw order. `us` is engine monotonic microseconds; each segment header supplies UTC. Samples are render-clock observations, not unique device timestamps.
- `run.log`: startup, client performance, casting results and detailed cast windows. Existing golf telemetry automatically records contacts, misses, fit previews and ball flight when a course opens.
- `tools/collect_vr_test.py`: save snapshots, copied golf analytics, runtime events and process statistics. Optional `--window-id` records only the desktop game window, silently, in two-minute video segments. Video is a third-person mirror, not a headset eye recording. Its UTC start is in `events.jsonl`.
- Controller capture flushes each second and rotates at 32 MiB, with a one-hour/1 GiB cap. The companion collector defaults to one hour and stops when the game exits. Video stops on game-window loss, collector shutdown or low disk space. No microphone or network identity collection.

For the rec4 fixes and focused regressions, see [REC4_FIX_TEST_SUITE.md](REC4_FIX_TEST_SUITE.md).

## Hardware sequence

Allow a moment between steps. If an issue occurs, repeat it twice before changing settings; keep the controller motion natural. Treat each failed or ambiguous outcome as a finding, not a pass.

| ID | Action | Expected result / evidence |
| --- | --- | --- |
| T01 | Stand still, look around, walk and turn; open/close settings. | Focus and both tracked hands stay valid; pose and inputs match motion; menus accept clicks. |
| T02 | Lower one controller, temporarily cover it, then restore it. | The valid hand keeps working; logs distinguish loss of tracking from stationary tracking. |
| T03 | With hip tracking available, turn hips independently, lean over a low rail, then straighten. | Hip objects follow facing; no forced backward push or twisting legs/head. Record absent tracker as not tested. |
| F01 | Turn head-aim OFF. Perform ten back/forward casts, including slow, fast, sidearm and overhand starts. | Heading follows the swing; faster motion increases range; no unintended rightward launch. |
| F02 | Repeat matched swings while looking left/right; start two swings with the rod already behind the head. | Head motion does not redirect the cast; behind-head starts remain castable. |
| F03 | Release immediately at the end of the forward swing, then repeat with a delayed release. | Both release timings accept a completed swing; idle trigger presses and forward-only motion do not cast. |
| F04 | Turn head-aim ON and repeat ten casts, including looking above the horizon before preparing. | Valid casts release reliably to the selected target. |
| F05 | Twitch lure once, hold the rod displaced, return near neutral, twitch again; then reel steadily. | Twitch causes visible travel; another twitch needs reset; reeling alone does not produce twitch ripples. |
| G01 | Join a course and choose Start new solo round. | Hole 1, zero strokes, ball at the selected tee. |
| G02 | Open shared golf/controls menus and clubhouse wall menu with each hand; change handedness. | Every click registers; club and pointer switch hands. |
| G03 | Open club radial, release click, select a club, then open/close without selection. | Radial remains open until selection or the closing click. |
| G04 | Reset the selected hand attachment, auto-fit, inspect shaft/head, accept with A, undo, and fit again. | Head keeps its intended address orientation while the handle is fitted; accepting does not teleport; full head clears turf. |
| G05 | Adjust attachment offsets/rotation, cancel a preview, then accept a preview; switch controller/palm mount. | Preview and collision agree with the visible club; settings persist and cancel/undo work. |
| G06 | Grip-only and trigger-only swings; touch either stick while collision is armed. | Either input arms collision; locomotion/turning remain blocked until release and neutral sticks. |
| G07 | Putt/chip/drive with toe, heel, centre and edges of head, including slow grazing contact and quick swings. | Whole visible head participates; misses and impacts are logged, with no phantom shaft/hand hit. |
| G08 | Lay down the offhand, swing and open menus; repeat with the other hand as the only tracked controller. | Offhand follows club support grip; active controller supports golf and menus. |
| G09 | Grab the tablet with right hand, then left hand; dock it and resume play. | Either hand can hold it; grabbing doesn't trigger a shot. |
| G10 | After shots in different directions, press A to address the ball; repeat looking down. | Adequate spacing, previous stance relative to the new shot, reliable facing, no repeated-teleport drift. |
| G11 | Play from fairway, rough and sand; inspect bunker edges, uphill/downhill roll and wind drift. | Visible surface and lie agree; turf contact, friction and flight are plausible; no spontaneous acceleration. |
| G12 | Visit clubhouse or fishing, then Return to round. | Current hole, stroke count and lie resume. |
| G13 | Retire, return to the same course, then repeat after a fishing break. | New round at first-hole tee, zero strokes, no stale restore. |
| G14 | Join Spyglass, Pebble, Cypress and Poppy; inspect each first hole and transition timing. | Courses load, tee-to-hole play lane is continuous; no scenery across it. |
| N01 | If another player is available, join/retire/rejoin a round and compare club/ball state. | Session ownership and remote state remain consistent. Otherwise mark hardware multiplayer not tested. |
| T04 | Finish by standing still for ten seconds, then quit normally. | Frame timings settle; logs flush and capture stops. |

## Review

Correlate button events with the nearest controller frames and cast/contact records using engine `us`/`monotonic_us`. Distinguish tracking loss, inactive collision, rejected gesture and genuine swept-head misses. Compare video by UTC, allowing for mirror/render/streaming latency. Do not infer the user's physical swing direction from an avatar hand alone.

The live session is intentionally left open for manual testing. Automated failures are recorded separately and must not be reported as a clean test pass merely because VR starts successfully.
