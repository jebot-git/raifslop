# Quest 3 diagnostic build 19 — headset results, 2026-09-24

**Gameplay acceptance failed.** The user reports a club head turned 90 degrees
before fitting, requiring a sideways controller grip, and a ball that never
stops rolling. The startup fix successfully reaches gameplay in the separate
debug package. This does not validate a signed Meta release or its entitlement.

## Test coverage

- Missing OBB: download error displayed, no crash.
- Incomplete OBB: incomplete-download error displayed, no crash.
- Restored, checksum-verified OBB: fishing scene reached without the build 18
  sparse-texture failures or native startup crash.
- Home and reopen: gameplay recovered, but Android killed the background process
  for low memory. This was a cold restart, not a successful preserved warm resume.
- Hands-on capture: 517.22 seconds, 35,633 controller frames, 14 motion-only cast
  results, four fit previews, one accepted fit and one golf stroke on Spyglass
  hole 1. All 14 cast results reported launched=true; this alone does not validate
  perceived direction, range or reel-in behavior.
- The first golf preparation took 21.060 seconds and activation 2.052 seconds.
  Preparation reported a maximum 390.452 ms frame-work interval.
- Median captured frame delta was 13.89 ms, p95 15.50 ms. These are engine timing
  observations, not compositor or motion-to-photon measurements.

Follow-up source fixes and automated validation are documented in
[Quest 19 gameplay fixes](QUEST19_GAMEPLAY_FIXES.md). This report describes the
original failing headset build.

The collector and diagnostic app were stopped after preserving the capture.
The installed ALPHA package was not replaced or stopped by this cleanup.

## Club attachment failure

The user explicitly confirmed the quarter-turn is present **before fitting**.
All four previews and the accepted profile retain head correction `(0,0,-32)`;
the fit changed shaft rotation and reach, not this correction. The accepted
shaft rotation is approximately `(-2.10,-8.11,-39.78)` degrees and reach 1.2043.
No manual head adjustment is evidenced by these previews.

The default `head_correction()` in `addons/golfminus/scripts/main.gd` provides
only a hand-dependent roll. `_sync_physical_head()` derives the head frame from
the calibrated controller grip, independently of the fitted handle. This makes
the default grip-to-head mapping the next correction target. The data does not
establish the exact replacement Euler angles; applying an arbitrary world-space
90-degree rotation would not validate both hands or different address poses.

Recommended correction: establish a natural-grip attachment basis for each hand,
apply it identically to the visual head, collision mesh and preview, and keep
shaft fitting independent. Preserve explicit user head adjustments. Validate
the initial unfitted pose first, then confirm fitting cannot rotate its head.

## Persistent rolling: reproduced

The ball remains moving throughout 203.636 seconds after the recorded shot.
It travels another 7.40 metres during the last 30 seconds of the capture. A
representative fairway state has speed about 0.315 m/s on a 6.5-degree slope;
the final rough state is still moving at about 0.191 m/s.

`ball_physics.gd` reduces low-speed resistance to
`min(surface_resistance, holding_acceleration + 2 * speed)`. On the recorded
fairway slope, downhill acceleration is about 0.79 m/s², while the static
holding threshold is 0.16 m/s². This produces a stable crawl around 0.31 m/s.
The sleep condition also requires the slope force to be below the holding
threshold, so it cannot settle there. Rough reduces the speed but retains the
same problem with its 0.45 m/s² holding threshold.

Replaying the captured launch against the production Spyglass terrain for 204
seconds reproduces the failure at 72, 90 and 120 Hz: still moving in rough,
speed 0.19124 m/s, rolling distance 66.157 m. This replay excludes scene obstacle
queries and live tracking; it isolates the terrain/ball integration.

Recommended correction: replace the low-speed taper with consistent rolling
resistance and static holding behavior per surface. Handle an uphill zero-speed
crossing explicitly: settle when the surface can hold the ball, otherwise allow
gravity to reverse it. Do not use a timeout to hide the failure. Regression
coverage must include this recorded shot, shallow fairway/rough settling, steep
slope reversal, sand stopping and cadence independence. Existing tests that
require reversal on shallow slopes need physically consistent expectations.

## Evidence and limits

Local ignored artifacts: `test-results/quest19-device-suite/` and its `gameplay/`
directory. The latter contains `logcat.txt`, process/memory samples,
`controller-summary.json`, extracted controller/golf analytics, saved
`golf_controls.cfg`, and `shot-replay.json`, `replay.gd`, `replay.log`.

The startup negative cases and lifecycle checks are in `results.json` and their
individual directories. Only one golf stroke was captured; sand response,
multiple club types, left-handed play, full-course completion and menu/teleport
correctness are not signed off. Neither reported gameplay fault has been fixed
in the installed diagnostic build or production source by this analysis.
