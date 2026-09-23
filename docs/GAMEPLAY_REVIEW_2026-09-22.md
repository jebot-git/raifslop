# Gameplay review — 22 September 2026, 18:19 recording

Source: `/home/blux/2026-09-22 18-19-01.mp4` (17:09.53, 1920 × 1080, 60 FPS).

Visual review used samples across the entire recording and denser sequences of fishing, first-tee setup, and later golf interactions. The exact-time contact sheet and extracted frames are in `test-results/gameplay-1819/`; `overview-exact.jpg` is the overview with explicit seek timestamps. This is a third-person desktop recording: it does not expose every headset panel or the physical button state. Input causes were checked against code and synthetic controller regressions.

## Findings and changes

- **Fishing, approximately 00:00–02:20:** lure motion and surface rings do not clearly distinguish working the lure from retrieving it. The old effect branch used lure attraction, which also rises during ordinary reeling. Twitch effects now require an accepted rod excursion. A twitch moves the lure laterally and slightly toward the angler; returning the rod does not undo that travel. The rod must return within 5 cm of its neutral tip position before another twitch. A twitch needs at least 6 cm of lateral excursion and 0.35 m/s tip speed, which also rejects small tracking jitter. Reeling still retrieves and attracts fish but does not generate twitch rings.
- **Golf from approximately 02:30 onward:** the free hand often stays away from the club, making one-controller swings look unsupported. An idle, untouched tracked offhand attaches after 0.8 seconds; an untracked offhand attaches immediately. Picking the controller up, touching its capacitive controls, or lightly pressing grip/trigger restores tracking. A nearby offhand can also grip the club using grip or trigger, with separate acquisition/release distances like the fishing reel. Only the visual hand target changes; the real striking controller still determines the club and impact. Peers receive the same resolved support-hand pose.
- **Handedness:** the popup selector has been replaced by a direct left-handed toggle in the shared golf panel. The choice saves immediately and controls the club hand, menu pointer, club bag, and address button. A temporary missing-controller fallback no longer overwrites the saved preference.
- **Club bag:** click to open; release keeps it open; deflect to highlight and return to centre to equip. Another click cancels. Opening with an already-deflected stick waits for neutral before allowing selection.
- **Fit confirmation:** the confirming A/X press is consumed until that button is released, including duplicate pressed events. It cannot fall through to address-ball teleportation.
- **Swing collision and locomotion:** either grip or trigger, including digital click input, enables collision on the club hand. While either is held, stick movement and turning are blocked. After release, sticks must return to neutral before movement resumes. Physical room-scale tracking and collision remain active. Menus, fitting, stowing, and the tablet still suppress club collision.

## Further improvements suggested by the recording

1. **Add an optional close spectator view for golf.** Across the course sequence, the full-body view leaves the ball and clubhead small. Around 08:00–08:30 nearby foliage also obscures the golfer. A ball-and-club close view or a brief impact replay would make contact and calibration easier to judge without moving the headset camera. Keep the current full-body view available for tracking checks.
2. **Offer a headset-view recording mode.** The current recording is useful for avatar posture but hides much of the menu/fitting interface. A selectable eye mirror would make future input reports much easier to diagnose.
3. **Blend the distant coast and horizon.** Around 13:00–17:09, a dark horizon band and abrupt water/terrain boundaries stand out. Extend or soften the water transition and match distant water/sky lighting before adding more foreground detail.
4. **Make swing state visible at address.** A small “Grip or trigger to swing / Release to move” state indicator near the ball would explain why locomotion is locked. The existing control hints have been updated; a dedicated in-world indicator is a separate visual improvement.

The presentation suggestions above are proposals, not claims that those visual changes are included in this build. Updated native VR testing must wait for the requested pre-launch confirmation.

## Build and verification

Updated Linux debug client and dedicated server: `builds/GameplayFeedback/`. Launch script: `builds/GameplayFeedback/VR.sh`. The changes remain uncommitted; `build-manifest.json` records source and artifact hashes. Network protocol remains 16.

Fourteen focused source suites pass, including the local ENet golf integration test. Seven exported-pack suites pass: `golf_controls_feedback`, `golf_vr_input`, `golf_camera`, `lure_fishing`, `lure_interface`, `network_guards`, and `release_pack`. The handedness check clicks the actual shared menu using a synthetic tracked aim ray. Club collision tests exercise grip, analog trigger and digital trigger, and verify stick lock/release. Offhand tests cover both handedness settings, laid-down and missing controllers, capacitive touch, manual acquisition, live avatar binding and valid network packets.

Logs, verification results, and package-content audit: `test-results/gameplay-feedback-pack/`. Native headset testing of this build is pending explicit launch confirmation.
