# Quest 19 gameplay fixes — 2026-09-24

The headset pass found a sideways club before fitting and a shot still rolling
after 204 seconds. Both have source fixes and automated regressions. The
installed UBS Startup Test 19 APK still contains the old behavior; a rebuilt
package and hands-on confirmation are needed before claiming a headset pass.

## Natural controller grip

The default club now maps its authored down-handle axis to OpenXR grip +Z,
with its striking face oriented for the trail-hand palm in both handedness
modes. This follows the [OpenXR standard grip pose axes](https://registry.khronos.org/OpenXR/specs/1.1-khr/html/xrspec.html#semantic-path-standard-pose-identifiers).
The previous identity attachment treated grip Y as the handle axis, putting
the implement across the hand. The existing club-specific lie correction and
authored loft apply after the grip mapping.

The live head, collision sweep and settings preview continue to share the same
head transform. Fitting and manual handle adjustments remain independent of
head rotation. Manual head adjustment remains available.

Profile version 3 migrates unused identity handle defaults and identifiable
head defaults saved by version 2 fitting. It archives replaced values under
`grip_axis_v2`, retains fitted handle angles/reach, and preserves explicit or
unclassified legacy head corrections. A fit made while compensating with a
sideways hand should be recaptured with a natural grip. Reset selected hand
attachment restores the corrected defaults.

## Rolling and settling

Rolling resistance remains at the existing surface value down to zero speed.
The low-speed taper to a smaller holding force has been removed: it allowed a
stable crawl even where the surface's normal rolling resistance exceeded
gravity. Gravity is applied before bounded resistance, allowing the ball to
stop on a supportable slope or reverse downhill when gravity exceeds it.
Sleep uses the same resistance threshold. No shot timeout was introduced.

The captured Spyglass hole 1 shot now rests after approximately **7.29 seconds**
and **7.56 metres of rolling**, at the same position across 72, 90 and 120 Hz.
Previously it remained active after 204 seconds with 66.16 metres of rolling.
The replay uses the recorded launch and production terrain without scene
obstacle queries. The surface constants remain gameplay tuning parameters,
not experimentally measured course properties.

## Validation

- All 19 suites in `python3 tools/run_golf_physics_audit.py` pass: collision
  sweeps, impulse/energy checks, input, menus, fitting, attachment, courses,
  recorded terrain cases and the new Quest regressions.
- Additional hosted attachment checks pass for both hands, before fitting
  and after independent handle edits, plus stowed-club alignment: 69 attachment
  assertions in total.
- Natural address checks cover all eight clubs, both hands and three world
  orientations; fitting preserves the corrected head basis.
- The actual captured version 2 profile migrates without losing fitted reach
  or shaft settings; manual/legacy head settings and migration idempotence pass.
- Shallow uphill/downhill lies settle, steeper uphill shots reverse, sand and
  rough slow the ball, and ground contact remains dissipative.
- Restoring the old grip basis or old ball physics makes the new regression
  suite fail on the corresponding observed defect, without script errors.

Evidence: `test-results/quest19-gameplay-fix/` and `test-results/physics-audit/`.
Portable shot/profile fixtures are in `tests/fixtures/quest19_*`; the main
regression entry point is `tests/quest19_golf_regressions.gd`.
