# rec5 fixes and playtest plan

Implemented against the 23 September 2026 live-session analysis. This is a debug testing snapshot, with new terrain coefficients that require gameplay evaluation.

## Changes

- Automatic fitting always preserves the current controller-relative club head orientation, including recapture after manual changes. Target/gaze no longer constructs a replacement head basis. Only handle angle, length and placement are fitted.
- During fitting, **grip toggles Head/Handle**, **stick click cycles yaw/pitch/roll**, horizontal stick adjusts the selected angle, and vertical stick adjusts reach. Either controller works. Trigger captures/recaptures; A/X accepts; B/Y cancels. Existing face corrections are retained; use manual Head adjustment or Controls → Club attachment calibration to correct a previously bad face angle.
- Motion casting can recognize controller preparation during the 0.6 seconds before trigger-down. This supplies a backswing direction only; a measured forward stroke after trigger-down is required for power and release. Accepted motion in the 80 ms velocity window is robustly averaged to reduce cadence-dependent direction changes.
- Rough/sand have speed-dependent bulk drag during both sliding and rolling. Low-speed rolling resistance approaches a separate surface holding threshold, allowing uphill-to-downhill reversal. Small rest hysteresis avoids endless imperceptible motion at large world coordinates.
- Ball support accounts for slope-normal radius; a sharp crest can release a grounded ball into flight. Terrain remains a custom height-field simulation, not general rigid-body terrain collision.
- New-hole tee placement lifts the bottom of the ball **35 mm above turf**, matching the visible tee. Ball diameter stays **42.67 mm**. Putting practice and ordinary ground placements are unchanged.
- Controller capture now records ball lie, ground normal, grounded state, stop reason, tee state and manual fitting mode directly.

## Automated verification

Run `python3 tools/run_vr_test_suite.py --focus rec5 --output test-results/rec5-verification`.

The focused suite contains 24 suites: recorded rec4/rec5 casting, casting direction/tolerance/tracking, fit invariants and controller interactions, full-head club contact, tee effects, terrain response, tree collision, physics stress, course loading/surface alignment and continuous analytics capture. Fixtures in `tests/fixtures/rec5_casts.json` retain preparation before trigger-down; `rec5_shots.json` contains selected recorded launches.

Key checks:

- All five substantial rec5 casting failures (21, 22, 23, 39, 42) complete at 72/90/120 Hz and rotated play-space headings. Short stationary taps remain rejected. Preparation alone never permits launch.
- Automatic fitting preserves the head before/after capture for every club and both hands, including changed targets. Manual head controls change the head independently; recapture, accept and undo preserve the intended values.
- Identical flat-ground 15 m/s rolling entries stop after approximately **55.9 m fairway / 14.3 m rough / 4.2 m sand**. Sliding variants also distinguish surfaces and dissipate energy.
- Controlled uphill rolls reverse on 3% green, 6% fairway and 12% rough grades; shallow stable slopes and moderate sand slopes settle. Infinite downhill planes are expected to keep rolling rather than falsely sleep.
- Recorded shallow sand shot 5 now rolls approximately **6.2 m**, ending in sand, versus **213.7 m** across several surfaces previously. The terrain replay omits scenery collisions.
- All four courses, 18 holes and three tee options have the 35 mm lift. The ball remains supported until struck, the visible tee meets its underside, and the tee ejects only on an accepted shot.

## Headset checks

1. Start a fresh round and inspect the first ball/tee from the side. Strike with the driver, then check the next hole's tee. Check putting practice separately.
2. Enter fitting with a comfortable club angle. Capture repeatedly while looking in different directions. The head must retain its angle while the handle fits behind the ball.
3. Use grip to select Head, then adjust all three axes with the stick. Recapture and accept. Verify the correction survives reopening fitting and restarting. Check cancel/undo and repeat with one controller and left-handed play.
4. Cast overhand and sidearm, including pressing trigger late in preparation. Look away from the intended direction while motion aim is enabled. Verify direction, release reliability and short/long swings. Also check head-aim casting separately.
5. Compare comparable low and fast entries into fairway, rough and sand. Test shallow bunker arrivals as well as high chips; check that slowing feels credible rather than abrupt. Test a fast ball crossing into sand.
6. Roll a ball uphill, wait for reversal and follow its downhill path. Check gentle slopes where it should stop, cross-slope break, bunker lips and crests. Report any ball that appears stationary while the game continues waiting for it.
7. Compare intended face hits with deliberate toe/sole contacts. The entire visible club head remains collidable; body contacts can still produce different launch angles.

Record video and retain the controller and client logs. A new live headset run must be explicitly requested before launch. Automated headless results do not certify VR feel or real-world material calibration. Cast range mapping remains unchanged for now; review its 24 m saturation during the next test.
