# Tester feedback debug build — 14 September 2026

`builds/Debug-TesterFeedback/RealAIFishing-debug.x86_64` includes the previous avatar/VRM initialization and guide interaction fixes, plus this feedback pass.

## Fishing

A directional counter now has internal resistance, hidden from the player. The HUD shows direction/hold cues and line tension, with no fish resistance or energy bars. Correct input drains it over `2.0 + species.power * 0.6` seconds within a six-second opportunity. Releasing or pulling the wrong way stops progress; input events alone never clear it. Clearing resistance creates the existing recovery window, with tension and fish energy relief spread over the hold. VR requires 24 cm of rod-tip displacement relative to the head, with release hysteresis at 18 cm. The direction frame is captured at cue onset, so head turns alone cannot score. Tracking interruptions and menus reset the physical baseline. Desktop arrow keys must be held.

The right controller receives distinct pulses on bites, hook sets, directional fights, runs, landing/loss, and rising tension. Tension pulses are rate limited. All 18 catch models, including perch and remote catches, scale from their actual mesh bounds to reported length in metres.

## Interface

The Fish Guide starts on a session page showing location, available shekels, last-catch earnings, bait and rod. The right index fingertip presses the physical arrows to cycle through the collection and return to session status. Native hand joints are used when available; controller users press with the visible avatar index fingertip, sampled after IK. Swept front contact catches quick pokes; a 2 cm withdrawal rearms the next press, and holding cannot repeat. Tracking-source changes reset contact history; camera controls remain available. The guide redraws status while held. Persistent location/economy status is removed from the floating HUD. Desktop bait tiles remain input controls.

The tutorial is opened explicitly through the fixed menu header’s **Tutorial** button and read inside that menu. Automatic tutorial popups, saved visibility and the idle right-A/H toggles have been removed. The fixed menu footer includes **Quit game**, saving the catch journal and equipment before leaving multiplayer and stopping audio.

## Environments

The four 128-second ambience beds use quiet recorded audio: bird-rich lakeside lapping; muted harbour wash; airy park ambience without water at Gray Pier; and water with sparse distant birds at Bell Park. Tester feedback rejected the initial synthetic wave textures, so those layers were removed and the final recorded mix lowered. Travel still crossfades. Timber details play only at Lake Pier and Bell Park. Only the occasional timber creak remains synthesized, at a further 6 dB lower level; rebuild with `tools/build_ambience.py`. Decoded audio checks found finite levels and no clipping.

Water samples the selected HDR panorama using Godot's sky projection and location rotation. World-space animated normals and water Fresnel produce reflections; distant water blends into the matching photographed background. This is a lightweight environment reflection, without local object reflections. All four locations use native 8K sources by default, with shared bounded sharpening and colour enhancement for sky and water. There is no separate 4K runtime variant.

## Validation

- Seventeen headless regression suites passed, including simulation, tackle, feedback, guide navigation/physical presses, tracking/VRM/IK, menus, network guards, and quit/save behavior. The rapid quit test exposed an audio streaming shutdown leak; the Quit path now lets the mixer release buffers before exiting.
- Sustained counters tested at 30, 72 and 90 FPS; microinputs, release, wrong direction and head-only turns cannot bypass resistance. All species can be landed with starter and upgraded rods.
- Actual mesh bounds match reported lengths for all 18 species.
- Desktop Vulkan renders cover all four water presets, guide status, fight cues and Quit footer.
- Connected WiVRn stereo readbacks cover tutorial, fight, guide and Quit menu. Short samples reported 71–72 FPS with head and both controllers tracked. Haptic event generation and runtime calls were exercised; perceived strength and soundscape preference still require player feedback.
- Live test shutdown retains the pre-existing Godot OpenXR spatial callback/profile RID diagnostics. No gameplay script or water shader errors occurred.

Reproduce regressions with `python3 tools/test_vr_fixes.py`; visual checks use `tests/tester_feedback_render.gd` and `tests/tester_feedback_live.gd`. Evidence is in `test-results/vr-fixes/feedback-*`.

## Right hip rod holster

While ready (or after losing a fish), bring the right hand to the right hip and squeeze grip once to fold and stash the rod. Release grip before squeezing again at the hip to pick up and unfold it. Grip holds, tracking recovery, and menus cannot accidentally toggle the holster. Stashing during a cast, fight, or unreleased catch is rejected with a message. The empty hand cannot cast or reel, and pickup resets motion samples to prevent a false cast. Desktop J is available for local practice.

All four equipped rods have folded geometry built from their original meshes/materials by `tools/build_folded_rods.py`. Three folded sections occupy about 71 cm including line guides; the rod follows tracked hips or the head-derived hip position. The Fish Guide reports the stashed equipment state. Updated multiplayer clients derive the folded state from the existing independent rod/grip poses for VR anglers, preserving protocol 2.

`tests/rod_holster.gd` covers grip edges, right-side/body-relative placement, tracking recovery, blocked fishing actions, safe pickup, all four folded models, and network pose interpretation. `tests/rod_holster_render.gd` captures the worn folded rod.

The rod stays visible in the right hand while the guide is held. Folding and right-hip stashing remain explicit actions. Raised estimated feet now use FPSloppa’s full calibrated calf-to-ankle transform; the local floor-level orientation override was removed after reproducing the screenshot’s ankle fold.

Latest gameplay follow-up: **Fish here** is in a fixed action row above the menu footer, outside the scrolling location list. The landing distance is calculated per cast using foreground visibility and room for lateral fight movement, with a 0.65 m margin before obstruction. Untired fish remain outside this limit; a cast too short to reach visible water is rejected with an explanation.

Three failed six-second counters during one fish fight now let the fish break free, regardless of rod tier. Sustained tension at or below 10% or at or above 90% loses the fish after a 1.4-second recovery window (overload tolerance scales with rod durability). Returning to safe tension resets that timer. Escapes clear the cue and attached line, with no catch reward. Tests cover all four foregrounds, every rod tier, recoverable excursions and normal successful fights.

Validation for the latest follow-up: all 21 regression suites passed; the four-location landing and fixed-menu render check passed. Connected WiVRn stereo captures covered menu instructions and fight feedback at 72 FPS in short samples. The final Linux debug export is `builds/Debug-PierGameplay/RealAIFishing-debug.x86_64`.

Tracking warning follow-up: compositor focus loss is no longer labelled controller loss. Focus is refreshed from the runtime session state; warning state updates before menu/guide/holster early returns, clears immediately on recovery and appears only after 0.5 seconds of continuous controller loss. Fishing pauses immediately during invalid tracking. A connected WiVRn check observed both controllers tracked without warnings in all ten samples (71–72 FPS). Settings persistence audit: see [settings and exit validation](SETTINGS_PERSISTENCE.md).

Fingertip menu pointer: native right index tip/distal joints supply origin and finger direction; controller mode uses the visible avatar index tip and OpenXR aim orientation, with an estimated fingertip when the avatar lacks finger bones. The rod transform never supplies UI aim. A thin beam connects fingertip to menu hit, is hidden on invalid tracking or outside the panel, and is excluded from guide photographs. Lost tracking releases pending menu drags. `tests/menu_ray.gd` covers native and avatar sources, world scale, rod independence, beam endpoint agreement and dropout; the connected WiVRn location/menu suite passed 48 checks.

VR presentation follow-up: all five benches and both boat seats retain their visible meshes but have no collision body. Floors, hull boundaries, railings and other props remain collidable. The foreground generator now tags seating separately so future asset rebuilds preserve this choice.

Successful **Fish here** travel closes the menu and restores locomotion; failed travel keeps its explanation in the menu. The floating VR HUD mesh and dedicated render viewport have been removed. Desktop HUD remains available; VR menu, guide and existing line/wake/haptic feedback remain. A billboarded, outlined text label above the left-hand catch displays the recorded species, length in centimetres and weight in kilograms. It has no background panel and hides for rod-hanging/released fish, guide inspection, menu viewing or unavailable left-hand tracking.

`tests/vr_presentation.gd` checks collision-free seats at all four locations, retained walkable floors, successful/rejected travel, the VR UI construction path, actual recorded catch text and label visibility/placement.

The held-label stereo inspection also exposed an older perch asset orientation error: its length runs along Z, while the other fish models use X. Measuring its thickness as length made a reported 32 cm perch about 2.13 m long. Local and remote fish now apply species orientation before sizing; the perch hangs head-up at its recorded length. The earlier length assertion missed this because it checked only X extent. The strengthened all-species regression also requires X to be the longest axis.

Validation: all 24 headless suites passed; the affected presentation, fish sizing and network suites passed again after the perch correction. Connected WiVRn catch tests passed 51 checks and location/menu travel passed 48 checks. A separate stereo readback showed the corrected 32 cm perch and plain text label at 72 FPS, with no VR HUD surface. Live input checks use synthetic controller poses with actual OpenXR rendering. The only runtime diagnostics were the existing OpenXR shutdown callback/profile cleanup errors. Build: `builds/Debug-CatchText/RealAIFishing-debug.x86_64`.

VR menu input follow-up: controller-derived finger curls no longer steer UI aim. The laser is drawn from the fingertip to the stable OpenXR aim intersection, with light cursor smoothing; trigger events use the displayed cursor rather than resampling a newly curled finger. Drag scrolling starts only on empty page background, so buttons, text fields, sliders, keyboard keys and the modal file browser retain ownership of their presses.

Import is a fixed Avatar action and opens a headset-rendered VRM folder browser in VR; the OS picker remains for desktop mode. The keyboard shows the edited text, shift state, slash/underscore, caret arrows, Backspace and Done. It repositions after font layout so its bottom row stays inside the VR surface. Closing the menu closes both overlays.

Validation: `tests/menu_controls.gd` injects real viewport pointer events with 12-pixel press movement, imports/equips a VRM fixture, types and deletes text, verifies preference updates, rejects background clicks through the file browser, and checks deliberate background dragging. Connected WiVRn `tests/menu_controls_xr.gd` exercises the fingertip laser, trigger curl, browser opening, text entry, every keyboard key's bounds and clicking Done; stereo captures are under `test-results/menu-input-xr/`. Runtime samples reported 67–71 FPS, with the existing OpenXR shutdown cleanup diagnostics.
