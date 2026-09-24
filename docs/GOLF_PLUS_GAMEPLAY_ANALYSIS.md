# Golf+ gameplay comparison and improvement analysis

Research date: 24 September 2026. Scope: golf physics, controls and hit registration in this repository. This is an analysis and implementation specification; it does not change gameplay. The requested small allowance for imperfect tracking is included below.

Implementation update: the subsequent [2 mm tolerance and control reliability changes](GOLF_TRACKING_TOLERANCE.md) implement the initial priorities. The analysis below remains the pre-implementation research snapshot.

## Recommendation

Keep the existing physical clubhead, impact and turf models. Prioritize trustworthy registration, clear control state and repeatable calibration before changing ball-flight coefficients. Add a narrowly bounded contact tolerance, evaluated against both clean hits and deliberate misses. Preserve the player's face angle, path, speed and meaningful mishits.

The most concrete current issue is unrelated to collision precision: `address_ball()` overwrites the lane-aware aim with a direct line to the pin. Addressing a ball can therefore undo the intended safe direction. This should be fixed alongside the next controls work.

## Evidence and limits

Sources span different versions, difficulty settings and sensing systems. They are not a controlled benchmark of today's Golf+ physics. Reviews describe experiences, marketing describes intended behavior, and footage shows interfaces/results without exposing the internal solver.

| Source | Material examined | Relevant evidence and limits |
|---|---|---|
| [Golf Simulator Videos: Quest 3S full review](https://www.youtube.com/watch?v=KCooUKcuK4c), 23 June 2025, 19:04 | Retrieved primary-video English automatic captions; inspected 18 public storyboard frames around the practice/bunker and difficulty-menu sequences. | Demonstrates practice tools and club/aim controls. At 01:30–02:00 the presenter describes forgiving contact; 05:20–06:05 discusses opening the face in sand; 09:11 onward discusses recentering; 14:03–14:26 identifies partial aim assistance and proposes switching to Pro. Earlier outcomes are not an unassisted benchmark. Automatic captions can contain errors. |
| [Creator's accompanying article](https://golfsimulatorvideos.com/golf-on-meta-quest-3s-the-ultimate-vr-golf-experience-full-review-discount/) | Full article and disclosure. | Affiliate-supported. Its broad claim that fat shots are accurately represented conflicts with the video's description of forgiving strikes. Do not use this article to establish collision fidelity. |
| [Golf Para Latinos archived livestream](https://www.youtube.com/watch?v=Hr5GhHc1pdo), 15 September 2026, 26:26 | Primary metadata identifies a completed livestream, titled “Jugando Golf+ en vivo: Mi primer intento en el torneo semanal”; inspected 27 storyboard frames, approximately 03:00–04:20, 08:55–10:15 and 14:52–16:12. | Frames show a real room/putting mat alongside the virtual green, contour lines, putter, score panels and next-hole control. This is mixed-reality putting evidence, not a controller full-swing test. Metadata title differs from the search listing. Caption download was rate-limited, so no spoken claims are attributed to this stream. |
| [Plugged In Golf, Matt Saternus](https://pluggedingolf.com/golf-virtual-reality-golf-review/), 15 December 2022 | Firsthand review; historical, before later swing updates. | Difficulty materially changes assistance. The reviewer values course-management decisions and recoverable controls, while distinguishing attachment feel from a real club. Affiliate disclosure applies. |
| [MyGolfSpy, Connor Lindeman](https://mygolfspy.com/we-tried-it/the-truth-about-virtual-reality-golf/), 12 March 2024 | Firsthand play review with an attachment; historical. | Reports convincing face/path response and short-game feel, weaker thin/fat penalties, and distances unsuitable as launch-monitor measurements. Useful experience evidence, not instrumented accuracy data. Affiliate disclosure applies. |
| [VR Golf Bag community guide](https://www.vrgolfbag.com/gplusguide), accessed 24 September 2026 | Controls, attachment, calibration and troubleshooting guidance. | Describes recentering, club selection, swing-speed calibration and attachment adjustment. Reports tracking limitations and workarounds. Unofficial and evolving; do not interpret its troubleshooting advice as measured defect rates. |
| [Golf+ explanation of face-to-path](https://blog.golfplusvr.com/tips-to-fix-a-slice/), 29 May 2024 | Official instructional article. | Establishes the intended relationship between face orientation, start direction and curvature. It does not disclose or validate the proprietary implementation. |
| [Golf+ Immersive Putting](https://blog.golfplusvr.com/immersive-putting/), 9 September 2026 | Official feature description. | Describes tracking a real ball's launch direction/speed and then simulating its roll. This differs fundamentally from inferring impact from a tracked controller. Its accuracy statements are vendor claims. |

Continuous playback was unavailable: the attempted review media fetch returned HTTP 403. Storyboard frames are sparse visual samples, not frame-by-frame impact footage. Public captions and metadata were accessible for the review. Consequently this study does **not** establish input latency, missed-hit rates, exact contact tolerance, shot dispersion or numerical parity with Golf+. No paywall or access restriction was bypassed. Source media/captions remain temporary research material under `/tmp`; copyrighted footage is not added to the repository.

### What transfers to this game

The source set supports three design directions: make calibration and recentering predictable; show enough shot feedback to explain outcomes; and distinguish assistance settings when interpreting performance. It does not justify copying apparent distances or making every contact a centered strike. Those are design inferences from the evidence above, not claims about Golf+'s hidden algorithms.

## Local implementation assessment

Paths below are relative to the repository. Findings describe the working tree inspected on the research date, including the recent terrain/guide changes.

| Area | Existing behavior | Improvement and priority |
|---|---|---|
| Aiming and address | [`main.gd`](../addons/golfminus/scripts/main.gd), `address_ball()`, recomputes aim from pin minus ball. `_reset_lane_aim()` is used elsewhere. | **P0, confirmed control-flow issue:** preserve a user-selected direction, otherwise use the lane-aware target. Add an integrated test that addresses a ball on a dogleg and verifies the guide remains inside the route. Existing model-only guide tests cannot catch this override. |
| Contact geometry | [`club_head.gd`](../addons/golfminus/scripts/golf/club_head.gd) sweeps the rotating whole head against the moving ball; handles face, toe, heel, sole and other regions. | **Keep.** This already addresses tunnelling better than checking a club-tip point once per frame. Add the bounded near-contact policy below without replacing physical contact classification. |
| Sampling and velocity | [`swing_tracker.gd`](../addons/golfminus/scripts/golf/swing_tracker.gd) sweeps measured endpoints but solves impact with exponentially filtered velocity (10.6 ms time constant), with a raw-velocity reversal fallback. Rejects intervals over 50 ms and extreme pose changes. | **P1, measurement needed:** compare impact-local velocity estimates on accelerating and decelerating recorded swings. Smooth visuals independently if necessary. Current constant-speed cadence tests do not establish accuracy around an accelerated impact. Preserve discontinuity rejection. |
| Tracking diagnostics | `main.gd::_swing()` returns on lost tracking before recording its swing observation; a later `tracking_lost` inactive reason is therefore unreachable on that path. | **P1, confirmed diagnostic gap:** emit a loss/reacquisition event before returning. Record pose validity/confidence where exposed by the runtime, sample age where available, reset reason and pending shot state. Do not invent unavailable sensor timestamps. |
| Arming | `club_input_active()` accepts grip or trigger above 0.55, or click inputs; menu, fitting, guide, locomotion and moving-ball states can inhibit striking. | **P1, hypothesis to test:** use explicit arming state and modest input hysteresis so threshold noise does not interrupt a committed swing. Continue to honor intentional release and UI/focus changes immediately. Display why striking is unavailable. |
| Contact acceptance | Tracker starts an 0.8 s cooldown before `strike()` accepts the impact. `strike()` can reject it or defer it through the multiplayer host. | **P1, confirmed ordering; impact frequency unmeasured:** separate detected, rejected, pending and accepted contacts. Rejected contacts must not blindly consume the full accepted-shot cooldown. Pending network shots must retain duplicate protection. |
| Impact and turf | [`impact_solver.gd`](../addons/golfminus/scripts/golf/impact_solver.gd) models finite-mass impulse, friction and off-center contact; [`club_turf.gd`](../addons/golfminus/scripts/golf/club_turf.gd) subtracts penetration work before ball contact. | **Keep, then calibrate.** Material constants are engineering assumptions. Ground-depth noise deserves separate measurement; simply widening the ball collider would not cure an excessive turf penalty. |
| Flight and rolling | [`ball_physics.gd`](../addons/golfminus/scripts/golf/ball_physics.gd) uses small substeps, drag/lift, spin, sliding/rolling contact and slope response. | **P2:** validate controlled launches against measured reference data across clubs and lies. Avoid tuning from videos with unknown assistance, wind or power calibration. Existing passivity and cadence checks are useful but not empirical realism validation. |
| Cup capture | Green capture uses a swept proximity test, a height window and speed below 1.65 m/s, then places the ball in the cup. | **P2, confirmed simplification:** add a measured entry-speed/offset capture envelope, then lip interaction if useful. The hard threshold can create abrupt changes near its boundary; visual smoothness alone will not resolve them. |
| Feedback | Accepted shots produce sound/haptics and extensive telemetry; turf also produces haptics. | **P1:** expose a compact practice explanation: contact location, face-to-path, launch speed, turf loss and tracking allowance used. Give rejected/paused swings a distinct cue without a fake impact sound. |

The [existing physics follow-up](GOLF_PHYSICS_FOLLOWUP.md) already documents turf and landing improvements, synthetic jitter cases and limitations of simulated XR. Preserve that work; it would be misleading to recommend those features as entirely missing.

## Small tracking allowance: proposed behavior

The user explicitly permits slight leeway from real golf to accommodate tracking imperfections. Implement it as a bounded correction to contact detection, separate from directional or power assistance. The following numbers are **prototype settings to evaluate**, not measured Quest error or inferred Golf+ settings.

1. **Exact contact first.** Run the existing sweep unchanged. A genuine face, edge, sole or back contact retains its original classification and physical result.
2. **Rescue only a small near miss.** If the exact sweep misses, evaluate a continuous closest approach within a trial 2 mm contact shell; compare 0, 2 and 4 mm variants in replay tests. Use the measured club transform, actual ball radius and a contact projected onto the physical head surface. Do not feed an inflated ball radius or invented sweet-spot location into the impulse solver. Initially restrict rescue to the playable face and its immediate edge; retain exact whole-head collisions everywhere.
3. **Require trustworthy motion.** Both bounding poses must be valid, the swing armed, the face approaching the ball, and no locomotion/teleport/focus reset occurring. Never infer a hit across a tracking outage. Poor tracking must not earn an increasingly large hit zone.
4. **Preserve the swing.** Do not rotate the face toward the target, straighten the path, add launch speed, erase an off-center lever arm, or pull the ball toward the club. Keep turf resistance and meaningful fat/thin penalties. Track the correction distance and original closest approach.
5. **Bound ground forgiveness separately.** Measure fitting error and stationary sole-height noise first. If a shallow turf allowance is needed, evaluate a small smooth depth transition rather than abruptly zeroing work. Apply it only to uncertain shallow penetration and keep deeper penetration penalties. Do not stack several independent tolerances into a large effective correction.
6. **Keep control intent clear.** Trial separate grip engage/release thresholds (for example 0.55/0.45) rather than a long release grace period. Cancel immediately on explicit release, menu entry, tracking loss or recenter. Arming must not itself create a sweep from stale poses.
7. **Make outcomes auditable.** Store exact/rescued/rejected status, tolerance and reason in the existing shot record. Use a consistent policy across multiplayer clients and host validation. Offer exact mode for comparison and apply competition rules consistently.

A universal enlarged ball or large invisible clubface would accept deliberate misses and alter contact normals. A small fallback contact query offers a more controlled experiment. Its value must be demonstrated on recorded headset swings, not assumed from synthetic success.

## Validation and rollout

### Checks executed for this analysis

Godot 4.7.2, headless, XR disabled, isolated user data:

| Suite | Result |
|---|---:|
| `tests/golf_head_contact.gd` | 96 assertions passed |
| `tests/golf_physics_review.gd` | 87 assertions passed |
| `tests/rec4_golf_replay.gd` | 187 assertions passed |
| Total | **370 passed; zero reported failures/errors** |

The physics review's controlled pure-roll green case travelled 3.0677 m from 1.83 m/s. This is a model sanity check, not proof of actual green realism. These runs do not test physical headset occlusion, perceived haptic timing or the proposed allowance. Logs: `/tmp/golf-research-<suite>-stdout.log` for the three suite names above.

### Acceptance gates for implementation

- First fix address aim and complete lost-tracking/rejected-contact telemetry. Exercise address, recenter, club change, left/right hand, menu exit and post-shot transitions through the integrated scene.
- Build a replay corpus from the actual supported headset/controller/attachment combinations. Include putts, short chips, accelerating full swings, toe/heel and fat/thin strikes, stationary jitter, intentional near misses, occlusion and grip-release transitions. Label ambiguous captures rather than counting them as certain hits.
- Compare exact/2 mm/4 mm policies on identical samples at 72/90/120 Hz and with irregular intervals. Report rescued valid contacts, false hits, duplicates, launch-speed/angle/spin changes and tracking cancellations separately. Use held-out sessions to select the smallest useful allowance.
- Require identical results for exact contacts when the fallback is unused. Require zero phantom hits in the deliberate-miss, stationary, release, teleport and tracking-outage regression fixtures. Those fixtures are release gates, not estimates of real-world failure probability.
- Compare accepted-shot latency distributions and missed-hit rates in headset sessions; do not substitute desktop frame timing. Separate tracking failure from physical misses and UI inhibition in every report.
- Validate multiplayer pending/acknowledged/rejected shots so retries do not create duplicates or extra strokes. Test host/client agreement on tolerance metadata.
- After registration is stable, calibrate launch/roll data and sweep cup entry speeds and lateral offsets. Keep coefficient fitting, user distance calibration and tracking tolerance independently configurable for diagnosis.

Recommended order: **aim and diagnostics → arming/acceptance state → measured small contact allowance → calibration and practice feedback → flight/material and cup refinement**. No physics rewrite is warranted by the evidence collected here.
