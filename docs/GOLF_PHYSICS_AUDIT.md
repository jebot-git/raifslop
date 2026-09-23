# Golf physics audit — 23 September 2026

Tested integrated source commit `0129a11` with a new deterministic stress fixture.
No gameplay physics coefficients or behavior were changed during this audit.

## Runtime and scope

The local WiVRn service was running, but its D-Bus state had no connected client,
no headset system name and no refresh rates. The installed server has no exposed
headset-emulation option. **These are not Quest 3 emulator or WiVRn transport
results.** WiVRn was left running and unchanged.

Native checks used installed Monado 25.1.0 simulation, Vulkan and Godot 4.7.2,
selected only for the test process using `XR_RUNTIME_JSON`. The native stress
fixture checks initialized OpenXR, a focused session and two views. Synthetic
XRControllerTracker poses are read through XRController3D into the production
sweep/impact/ball models. Stress poses represent the clubhead; they do not run
through the live grip-fitting transform, the live `_swing()` wall clock, or a
WiVRn tracking packet. Separate integrated attachment, fitting and input tests
cover those game components. Sampling intervals are simulated 72/90/120 Hz,
not measured headset frame rates or sensor accuracy. The native integrated
camera suite also exercises the actual fishing/golf scene and mirror.

This does not validate Quest standalone performance, Wi-Fi latency, headset
prediction, controller occlusion behavior, haptic feel or peak contact force.
Native and headless stress runs produced identical numerical results.

## Executed coverage

- Eight integrated regression suites: 369 PASS assertions, no failures. These
  cover physics review, full clubhead contact, surface alignment, controls/fit,
  avatar attachment, tracked UI, courses and course lanes. The lane suite also
  checked 306,162 course samples across 72 holes / 216 tee positions.
- Native integrated camera/guide/mirror suite: 27/27 passed.
- 960 deterministic swing cases: eight clubs, three sampling rates, 40 cases.
  912 expected contacts registered; 24 deliberate wide misses and 24 long
  tracking gaps produced no phantom strikes.
- Cases include ±35 mm heel/toe, ±15 mm high/low face, ±8° face/path/attack
  deviations, 70% swing speed, positional jitter ±2 mm and angular jitter
  ±0.01 rad at the sampled clubhead, and 33/80 ms intervals.
- Twenty-four seeded combined error profiles per club/rate add ±20 mm lateral
  and ±12 mm vertical impact offsets, ±6° face/path/attack, ±4° dynamic loft,
  85–115% speed and jitter. These are exploratory bounded errors, not a
  calibrated statistical model of Quest sensors or human golfers.
- 2,400 randomized impulse inputs across clubs, angular velocities, moving/spinning
  balls and fairway/rough/sand. 2,349 generated valid closing contacts; separating
  inputs return no impulse.
- 56 same-launch surface trajectories and 56 lie-adjusted trajectories: green,
  fringe, fairway, rough, sand, water and out-of-bounds. Uniform water/out tests
  exercise hazard termination, not a mapped shoreline entry.
- 135 rolling cases: five surfaces × level/±3% slope × three rates × sliding,
  backspin and pure rolling initial states. All settled and remained passive.

Original standalone GolfMinus suites were additionally path-adapted under
`test-results/physics-audit` and run against integrated code: physics 66/67,
physical club 32/33, fitting/impact/analytics 122/146. Their 26 failures are
compatibility assertions, not a clean pass:

1. One old test expects a 2 m/s zero-spin ball to travel the pure-rolling distance.
   Current skid friction exchanges translation and rotation and shortens it.
2. One expects every initial overlap to be rejected. Current code permits moving
   contact from an existing overlap; the integrated test separately proves
   stationary contact cannot launch a ball.
3. Twenty-four expect nominal loft fixed in world space irrespective of shaft
   lean. The integrated fitter now preserves the rigid authored shaft/head angle
   and explicit correction, making dynamic loft depend on shaft pose. Current
   fit tests check that invariant and actual mesh sole clearance.

Do not silently change physics to satisfy those obsolete assumptions; port the
legacy assertions to the present behavior if retaining those suites.

## Momentum, impulse and energy

For randomized impacts, maximum total linear-momentum residual was
**8.35e-7 N·s** and angular-momentum residual **5.56e-8 kg·m²/s**. No collision
created total kinetic energy; the largest energy change was negative
(-0.00255 J). Coulomb-bound residual was below 4.29e-8 N·s (floating-point scale).
All sampled calm, flat-ground ball trajectories and the rolling/slope tests had
no positive measured mechanical-energy step gain. Energy includes translational,
rotational and gravitational potential terms.

The impact solver returns an impulse in N·s, not a force-time curve. **Peak force
cannot be inferred from these tests** because contact duration/deformation is
not modeled. Momentum balance includes the solver's predicted head recoil.
The actual tracked club remains prescribed by the user/controller: its computed
post-impact linear/angular velocities are diagnostic and are not fed back into
the tracked hand. This is not a freely moving coupled club/ball rigid-body system.

Rough and sand scale incoming head linear and angular velocity by 0.88 and 0.74
before collision; momentum balances above start *after* that explicit external
turf loss. Ground/obstacle collisions dissipate momentum into an immovable world,
so ball-only momentum is intentionally not conserved. A collision-query obstacle
reflection check passed in the inherited physics suite.

Centered no-noise launch speeds varied by less than 0.009 m/s across sampling
rates. Final positions varied by less than 0.07 m. The 33 ms gap still registered
contacts; the 80 ms gap reset sampling and suppressed contact. This protects
against false hits but means a real >50 ms update stall can lose a swing.

## Measured surface behavior

Same launch state per club, calm air, infinite flat uniform surface. Values are
metres. Ground roll excludes airborne bounces; total includes them. A single
infinite green is a controlled diagnostic, not a real hole.

| Club | Landing surface | Carry | Ground roll | Total forward travel |
|---|---|---:|---:|---:|
| Driver | Green | 195.13 | 126.71 | 334.18 |
| Driver | Fairway | 195.13 | 11.55 | 226.50 |
| Driver | Rough | 195.13 | 4.17 | 205.61 |
| Driver | Sand | 195.13 | 1.64 | 198.24 |
| 7 iron | Green | 140.40 | 52.84 | 204.26 |
| 7 iron | Fairway | 140.40 | 4.21 | 162.12 |
| 7 iron | Rough | 140.40 | 1.87 | 147.56 |
| 7 iron | Sand | 140.40 | 1.77 | 143.34 |
| Putter | Green | 0.18 | 12.23 | 12.41 |
| Putter | Fairway | 0.18 | 3.16 | 3.34 |
| Putter | Rough | 0.18 | 0.92 | 1.10 |
| Putter | Sand | 0.18 | 0.18 | 0.36 |

The putter example uses the bag's 3.5 m/s head speed, yielding 5.41 m/s ball speed;
it is a strong putt, not a gentle tap. A separate pure-roll check at 1.83 m/s on
green yielded 3.041 m, matching the configured 0.55 m/s² roll resistance.
At 3 m/s, zero-spin skid rolled 5.298 m, backspin 3.280 m, sand pure-roll 0.996 m.

Off-center strikes reduce speed and change spin. For a 90 Hz driver, center
launch was 66.86 m/s; toe/heel launches approximately 64.3 m/s with opposite
side spin. Open/closed faces deflect shots to opposite sides. These directional
responses and conservation checks support numerical consistency; they do not
establish real-world launch-monitor accuracy.

## Recommended next changes

1. **Validate and tune approach-shot stopping on greens.** A 7 iron in this
   fixture travels about 64 m after first landing. It loses energy, but the
   bounce/retention/backspin-to-roll transition needs calibration against measured
   approach shots. Do not tune it by changing putt roll resistance alone.
2. **Model turf contact before ball contact.** Current lie efficiency is constant
   by surface and independent of divot depth, attack path and whether the sole
   struck ground first. Fit clearance is shown during fitting, but `_swing()`
   sweeps the head against the ball without a preceding club–terrain impulse.
   Fat/clean strikes in the same lie therefore lack a depth-dependent penalty.
3. **Treat tracking stalls explicitly in validation/UI.** The safety reset works,
   but native transport and headset tests must establish how often >50 ms gaps
   occur. Do not simply disable discontinuity protection to recover lost swings.
4. **Update legacy assertions** and retain this deterministic audit. Add measured
   swing/launch data before claiming realistic force transfer or sensor fidelity.

## Artifacts and reproduction

Raw logs, `suite-results.json`, `stress-headless.json`, `stress-native.json`,
`summary.json`, `swing-results.csv` and `surface-results.csv` are under ignored
`test-results/physics-audit/`. JSON contains per-case velocities, spin, impulse,
energy/momentum residuals, distances, bounce samples and stop reasons.
The initial suite-results file records the eight baseline suites; stress and
native-camera results are in their separate logs/JSON. A fresh runner invocation
collects all selected suites together.

```bash
python3 tools/run_golf_physics_audit.py --godot /path/to/godot
```

For native simulation, start `SIMULATED_ENABLE=1 XRT_COMPOSITOR_FORCE_XCB=1
monado-service` in a terminal, then add `--native` to that command. The script
uses the installed `/usr/share/openxr/1/openxr_monado.json`; it never changes the
system's active runtime or starts/stops WiVRn. Stop the simulation service after
testing if you started it just for the audit.

Native runs exited successfully but retained existing OpenXR shutdown diagnostics
(session stopping, spatial signal disconnect and four interaction-profile RID
allocations). Those remain recorded, not counted as physics assertion failures.
