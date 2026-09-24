# Golf tracking tolerance and control reliability

Implements the first-priority changes from [the Golf+ analysis](GOLF_PLUS_GAMEPLAY_ANALYSIS.md), with the requested **2 mm starting allowance**.

## Contact behavior

The original exact whole-head sweep runs first. If it finds a collision, its contact geometry and impulse inputs remain unchanged. Only an exact miss gets a second sweep with up to 2 mm of surface separation. That fallback must reach a front-face triangle with a forward-facing contact normal. Back, sole and side near misses are not rescued; exact collisions with those surfaces still work.

The fallback retains the real mesh point, head transform, contact normal and off-center lever arm. It never changes the ball radius used by the impact solver, adds speed, aims toward the target, or removes turf resistance. Metadata distinguishes `exact` from `tracking_tolerance`, and records the correction and allowed distance in metres. Correction is the separation at the detected event, not a measured sensor error or minimum distance over the entire swing.

Both bounding controller poses must report high tracking confidence for the fallback. Lower-confidence valid poses retain exact collision behavior. Tracking loss, discontinuities, long frame intervals, stationary poses and receding motion do not gain a contact through the allowance. High confidence is a runtime signal, not proof of millimetre accuracy.

`club_head.gd::TRACKING_TOLERANCE` is the single 0.002 m limit. The practice-only exact-contact switch disables the fallback and persists in golf preferences. Normal rounds retain the fixed allowance. The existing server authorizes strokes/turns; it does not independently reconstruct controller geometry. This change preserves that authority model rather than claiming server-side physical validation.

## Controls, acceptance and feedback

- Grip/trigger engages above 0.55 and remains armed above 0.45. Full release and blocking states disarm immediately. Digital inputs still work independently. Locomotion uses the same activation state.
- Addressing preserves the selected or lane-planned direction. Load, resume, practice placement and penalty relief establish the appropriate lane aim before addressing.
- Rejected contacts release the accepted-shot cooldown. Accepted shots retain duplicate suppression. Pending multiplayer requests block new collision attempts until resolved; authorization uses the original deep-copied contact, including tolerance and turf adjustment. Denials and disconnections report rejection rather than silently consuming a hit.
- Lost tracking is recorded before the sampler returns, and reacquisition gets its own event. Swing samples include the full physical head pose, ball velocity, rescue eligibility and runtime confidence without fabricating hardware timestamps; captured contact windows can therefore support subsequent replay comparisons.
- The HUD distinguishes ready, settling, tracking loss, released input and other blocked states. Practice shows the last accepted contact region, face/path angle, launch speed, local horizontal/vertical contact offset, turf speed loss and applied allowance. These are game-model values, not launch-monitor measurements.

## Verification

New suites:

- `tests/golf_tracking_tolerance.gd`: exact geometry/launch invariance; 1 mm rescue and 2.1 mm rejection; hard cap; actual mesh contact; stationary, receding and wide misses; back-face exclusion; reliable bounding poses; tracking outages; cooldown and grip hysteresis; all eight clubs at 72/90/120 Hz.
- `tests/golf_pending_contact.gd`: request deduplication, deep-copy preservation, accepted/denied commands and out-of-turn rejection through the production host's interception and result methods, using a deterministic service fixture.
- Extended `tests/golf_controls_feedback.gd`: integrated rig addressing, grip hysteresis, pending-contact inhibition, rejection recovery, loss/reacquisition telemetry.

The new standalone suites are included in `tools/run_golf_physics_audit.py`. Run:

```sh
python3 tools/run_golf_physics_audit.py --godot /path/to/godot
```

Headless and recorded-pose tests establish deterministic behavior; they do not measure headset latency, occlusion accuracy or perceived haptics. Compare exact and 2 mm practice captures on supported hardware before increasing the allowance.

Validation on 24 September 2026: all 16 headless audit suites passed (1,139 PASS assertions, no reported errors), including the synthetic stress suite. The final integrated-controls rerun passed 104 assertions and the recorded `rec4` replay passed 187 assertions. Audit output is in ignored `test-results/physics-audit/`; final rerun logs are in `/tmp/golf-final-*-stdout.log`.

## Remaining measurement work

Impact-local velocity estimation, shallow turf forgiveness, material/flight calibration and a measured cup capture envelope remain follow-up work. Existing filtering, turf depth response, flight coefficients and cup capture are retained. Changing them requires reference swings/launches and a held-out validation set; passing synthetic tests alone would not substantiate improved realism. The new diagnostics and exact-contact comparison support that collection.
