# Golf physics follow-up — 23 September 2026

Implements proposal items 1, 2 and 6 on `integration/golf-fishing`, following the
[baseline audit](GOLF_PHYSICS_AUDIT.md). The baseline report preserves the original
measurements; this report describes the changed model and final rerun.

## Changes

- Ball landing uses a normal restitution impulse, Coulomb friction opposing the
  velocity of the actual spinning contact point, and dissipative turf deformation.
  The fixed horizontal speed-retention multiplier is removed. Normal landing
  energy loads an effective spring (`d = |vn| sqrt(m/k)`); indentation relative to
  ball radius determines bounded resistance to translation. Sliding friction then
  exchanges translation and rotation without reversing slip. This is a passive
  engineering contact model, not measured material calibration. Coulomb friction
  alone was insufficient: it increased the baseline's excessive rollout.
- Landing friction/stiffness are independent of sustained sliding and rolling
  resistance. Pure-roll putting coefficients remain unchanged; lofted putts can
  travel differently because their initial landing changes.
- The live XR swing tracker sweeps the club mesh's terrain-facing support point
  through terrain, integrating penetration-dependent resistance in 5 mm spatial
  steps. Only the path before first ball contact contributes. Effective linear and
  angular head speeds are reduced together so the loss of kinetic energy equals
  the accumulated work, capped at the available energy. Rough and sand have
  stronger resistance than fairway. No extra fixed rough/sand speed or face-friction
  penalty remains in the ball impact solver.
- Turf diagnostics record depth, contact distance, surface, requested/dissipated
  work and speed scale. Release, tracking reset, swing reversal and a 120 ms pause
  or clear interval discard stale losses. Follow-through contact cannot weaken an
  earlier clean strike. Multiplayer's deferred shot retains the adjusted velocity
  and contact data, without applying resistance again.
- Ported the three standalone physics, physical-club and fitting/analytics suites
  into the integrated test runner. Updated only obsolete assumptions: initial
  overlap is a contact whose closing motion is checked by the tracker; a pure-roll
  distance test now starts with matching spin; fitted loft is tested relative to
  the shaft. Added landing, turf, slope, surface-transition and synthetic-XR cases.

The mesh support search uses the local terrain plane and reuses a support vertex
until its direction changes by about 0.1°. Actual terrain height is sampled at
that vertex. This approximates contact on features smaller than the clubhead;
it is not a deformable-soil or excavated-divot simulation. The distance bound
includes head rotation, and resistance scales both velocity components rather
than solving controller/shaft compliance. The tracked hand is never displaced.

On this local machine, a 0.4 m, 20 ms sweep over the procedural Dalkey tee took
about 4.1–4.6 ms after optimizing the initial all-vertices terrain queries
(about 229 ms for the driver before optimization). These are desktop debug
microbenchmarks under concurrent testing, not Quest performance measurements.

## Reproduction

```bash
python3 tools/run_golf_physics_audit.py --godot /path/to/godot --native
```

`--native` requires an already running simulated Monado service. The runner selects
its runtime for each test process and isolates user data. It does not alter WiVRn
or system runtime settings. Without `--native`, it runs the headless suites.
Native tests validate a focused stereo OpenXR session and synthetic controller
poses. They do not emulate Quest hardware or measure WiVRn transport.

Final measurements and suite results follow. Raw
artifacts are in ignored `test-results/physics-audit/`; the baseline CSV/summary
files in that directory remain historical, while stress JSON and suite logs are
replaced on each run.

## Final surface measurements

Same controlled launches as the baseline, calm air, infinite flat surfaces.
Distances are metres; ground roll excludes airborne bounces.

| Club | Surface | Carry | Ground roll | Final forward travel |
|---|---|---:|---:|---:|
| Driver | green | 195.13 | 152.60 | 358.40 |
| Driver | fairway | 195.13 | 28.13 | 242.06 |
| Driver | sand | 195.13 | 11.19 | 208.88 |
| 7 Iron | green | 140.40 | 1.42 | 144.06 |
| 7 Iron | fairway | 140.40 | 0.00 | 138.48 |
| 7 Iron | sand | 140.40 | 0.01 | 140.18 |
| Putter | green | 0.18 | 16.86 | 17.04 |
| Putter | fairway | 0.18 | 6.32 | 6.50 |
| Putter | sand | 0.18 | 2.73 | 2.91 |

The 7-iron green case advances 3.66 m after first landing, versus 63.86 m in the
baseline. The pure-roll green check remains approximately 3.04 m at 1.83 m/s.
Driver rollout on the infinite green remains excessive, and the strong lofted
putter fixture travels farther after removing fixed bounce damping. These are
explicit remaining calibration limits. No launch-monitor data was available to
validate material stiffness, turf cutting resistance or stopping distances.
The model is numerically passive; that alone does not establish realism.

## Validation

The randomized solver check generated 2,349 closing contacts from 2,400 inputs. Maximum linear-momentum residual was 9.57e-07 N·s and angular residual 5.56e-08 kg·m²/s. The largest total impact energy change was -0.00473 J (negative). No material energy creation occurred in the calm flat-ground flight/landing or 135 roll/skid/slope cases.

All 15 final suite invocations passed (879 PASS assertions). Coverage includes:

- 207 focused landing/turf assertions, including passive impulses, clean versus
  fat contact, stronger rough/sand resistance, cadence, contact ordering, reset,
  rotated mesh support on slopes, and green-to-bunker transition.
- Legacy physical-club 33/33, physics 67/67, fitting/analytics 146/146.
- The eight existing integrated suites; 306,162 course-lane samples are additional
  to the assertion count.
- 960 swing-deviation cases and 144 added clean/fat XR-pose cases per stress run,
  all eight clubs at 72/90/120 Hz. The 912 intended deviation contacts register;
  the 48 deliberate misses/tracking gaps remain suppressed. All 144 turf cases
  register and conserve collision momentum after the explicit external loss.
- Native focused stereo OpenXR stress and 27 camera/guide/mirror assertions.
  Headless and native stress results match exactly for all numerical datasets.

Two pre-existing native Godot teardown errors remain: disconnecting the
`spatial_discovery_recommended` signal and leaking four OpenXR interaction-profile
RIDs. The runner preserves those diagnostics and fails on other error messages.
The final logs were also checked with this stricter classifier. Python runner
classification checks and `git diff --check` passed. The temporary Monado service
was stopped after testing; WiVRn was not changed.
