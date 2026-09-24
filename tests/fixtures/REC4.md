# rec4 regression fixtures

Derived from the user's 23 September 2026 local WiVRn gameplay recording and matching controller/golf telemetry on `e934c1f`. These fixtures contain only the numerical samples needed by the regression tests, with session identifiers and unrelated headset/avatar/input data removed.

- `rec4_casts.json`: attempts 4 (stationary hold), 14, 25, 39 (fast wrist casts), and 52 (inverted initial direction). Calibrated controller positions are metres in tracking-origin space, quaternions are xyzw, `dt` is seconds. `seed` precedes the recorded trigger window. Original results are diagnostic, not expected corrected outcomes. Replays resample poses with quaternion interpolation at 72/90/120 Hz and rotate the entire trace around the play space.
- `rec4_contacts.json`: all 30 accepted head contacts. Positions, velocities and normals are in world space; head basis arrays are its X/Y/Z columns. SI units; angular velocities are radians/second. Original launch/spin are retained to detect unintentional changes to the impact solver. The tests also run each launch through ground resolution at three cadences.

Run `python tools/run_vr_test_suite.py --focus rec4` for the focused regressions and contact overlay. These synthetic replays do not establish device tracking accuracy or replace a live headset test.
