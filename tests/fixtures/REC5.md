# rec5 fixtures

Source: user-provided `rec5.mp4` and the matching live session in
`builds/Rec4VRTest-2026-09-23/live-20260923-160715/`.

`rec5_casts.json` retains calibrated controller-local positions/quaternions
(xyzw, metres), tracking validity and engine microsecond timestamps. Selected
attempts include 0.6 seconds before the first cast-trace sample, used as a
trigger-down approximation (within one render frame). It contains the two
short taps, five substantial failed casts, and adjacent successful casts.
No headset direction is an input. Tests interpolate poses at 72/90/120 Hz and
rotate the entire controller trajectory to verify direction equivariance.

`rec5_shots.json` retains world-space position, velocity and angular velocity
for shots 4, 5, 10 and 35 on Spyglass. Replay uses course terrain and wind but
omits scenery obstacles; it is a terrain regression, not a full scene replay.

See `docs/RECORDING_REVIEW_REC5.md` for the original findings and
`docs/REC5_FIX_TEST_SUITE.md` for the updated acceptance criteria.
