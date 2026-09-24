# Hand tracking controls: feasibility

Assessment: 17 September 2026. This is an implementation proposal; hands-only gameplay has not been enabled or validated.

Follow-up: [24 September integrated-branch review and mixed reality club fitting](INTEGRATED_HAND_TRACKING_AND_MR_FITTING.md) reassesses these findings against the shared fishing/golf rig and current attachment calibration.

## Findings

Hand controls are feasible with the existing avatar and OpenXR stack. Menus, guide interactions and photos are the best first milestone. Full fishing needs input-source handling and controls for actions currently assigned to buttons and sticks.

Evidence from this checkout and the earlier physical headset session:

- Godot 4.7.2 and WiVRn 26.9 received optical wrist poses and 15 finger-bone rotations per hand while both controller poses were unavailable. This establishes joint delivery, not gesture accuracy or hands-only playability.
- `scripts/tracking/hand_input.gd` already samples finger curls and wrist-relative rotations. `scripts/tracking/tracking.gd` supplies optical wrists to avatar IK, and multiplayer already carries these poses.
- `scripts/menu_ray.gd` can aim from native finger joints. The guide's two physical buttons already accept native index-fingertip presses, including selfie toggle and shutter in camera mode.
- `openxr_action_map.tres` already maps EXT hand pinch to trigger and grasp to grip, with aim and grip poses. However, querying the installed engine's effective project settings reports `xr/openxr/extensions/hand_interaction_profile=false`. Hand-joint tracking is enabled separately. Enabling the interaction extension is the first experiment, not sufficient proof of complete controls.
- The same settings query reports `xr/openxr/extensions/meta/simultaneous_hands_and_controllers=false`. Mixed controller/optical operation needs its own capability and headset test; it must not be assumed from successful two-hand optical tracking.

[Godot's hand-tracking documentation](https://docs.godotengine.org/en/stable/tutorials/xr/openxr_hand_tracking.html) distinguishes joint data from action-profile gestures and requires enabling the hand-interaction extension. A supported hand profile can supply poses and actions through the usual left/right positional trackers. Therefore an `XRController3D` node is not inherently incompatible with hand controls; the relevant question is whether its action pose is currently valid.

WiVRn merged [EXT hand-interaction forwarding](https://github.com/WiVRn/WiVRn/pull/396) in July 2025. Prefer this runtime gesture path where available. There is also an [open report of raw-joint pinch bouncing on Quest Pro firmware](https://github.com/WiVRn/WiVRn/issues/898). That report does not establish a fault on this headset; it motivates measuring duplicate clicks before adopting a custom fingertip-distance recognizer.

## Gaps in the game

| Area | Existing support | Work needed |
| --- | --- | --- |
| Input availability | Optical avatar wrists and fingers | Resolve a usable interaction pose per hand; distinguish physical controller, hand action profile, raw optical joints, and unavailable input. |
| Fishing | Controller trigger casting; physical reel motion | Replace controller-only pose assumptions and tracking gates in `main.gd`; prevent tracking loss from acting as a cast release. |
| Rod and guide | Hip proximity plus grip | Validate runtime grasp and hand grip orientation; provide a visible retrieval control when hip tracking is unavailable. |
| Menus | Native pointing and guide pokes | Add an accessible menu opener, pinch selection, and feedback; buttons A/B and stick clicks have no hand bindings. |
| Movement | Thumbstick locomotion and turning | Provide explicit teleport and turn controls, with confirmed destination and collision checks. |
| Photos | Native shutter/selfie buttons | Add camera-mode entry and a touch/drag distance control using the existing 0–3 m extension and collision limits. |
| Other actions | Bait/rig switching, landed-fish actions, radio | Expose these through visible contextual controls. |

Raw wrist transforms cannot simply replace calibrated controller grips: their axes and attachment offsets differ. Fishing motion must use tracked input in one consistent space, independently of the rendered IK hand. Otherwise avatar hand constraints can feed back into cast and reel measurements.

## Proposed interaction scheme

| Action | Proposed hand control |
| --- | --- |
| Open field station | Visible wrist control, tapped by the opposite index finger; avoid reserving a system palm-pinch gesture. |
| Select or scroll | Aim and pinch; keep direct pokes and existing arrow buttons available. Capture the target at pinch start so finger curling does not move the click. |
| Retrieve guide or rod | Grasp near the object; offer a chest-height retrieval control as an alternative to reaching the hip. |
| Hold rod | Latch ownership after deliberate pickup; release through a dock action, so a momentary open hand or lost tracking cannot drop it. |
| Cast | Pinch index/thumb to hold the line, sweep and release pinch while retaining rod ownership. Evaluate separately from grasp because the gestures overlap. |
| Reel or strip line | Left-hand pinch near the crank followed by circular motion; pinch/pull near the line for fly stripping. Context chooses one action. |
| Work a lure | Existing rod-motion and retrieve logic, fed by the resolved tracked rod pose. |
| Take photos | Guide shutter/selfie buttons, plus a visible camera-mode control and extension slider. |
| Move and turn | Explicit movement panel with teleport targeting and snap-turn buttons. Disable activation during casting or other hand-owned actions. |

These are candidates for testing, not established ergonomic mappings. Sustained unsupported rod holding, fast backswing tracking, two hands occluding one another near the reel, and belt retrieval are the main usability uncertainties. Mixed input—right controller for the rod and optical left hand for the guide/reel—is a useful alternative only if simultaneous tracking is verified.

## Implementation sequence

1. **Capability probe:** enable hand interaction in an isolated test configuration; log the active interaction profile, grip/aim pose validity, pinch/grasp values and edges, joint flags, source and application focus. Exercise controllers, bare hands and mixed input. Do not treat the extension being available as proof that its actions work.
2. **Menus and photos:** add input-source selection, deliberate menu entry, pinch selection, guide pickup, camera-mode entry and extension adjustment. Keep movement stationary for this milestone. Reuse existing avatar/network poses.
3. **Stationary fishing:** route cast, reel, lure and fly inputs through the same input adapter; adapt hand attachments. Add tackle and catch controls so a complete catch cycle is possible without buttons.
4. **Movement and broader support:** add teleport/turn UI and evaluate simultaneous input, seated use, other runtimes and controller handover.

The adapter should provide validity, source, grip/aim transforms, select/grasp state and intentional press/release edges per hand. Use runtime gestures first; add a joint-based fallback only where necessary. A fallback needs scale-aware thresholds, hysteresis, finite/valid joint checks and debounce. Controller-inferred finger curls must not also generate optical gestures.

Tracking loss, focus loss and source changes cancel pending gestures without emitting release actions. Hold the object's ownership while pausing the affected operation, clear cast/reel/lure velocity history, and require a neutral gesture before rearming. Smooth rendering separately from interaction measurements. Never infer a throw, reel stroke or teleport from reacquisition.

## Acceptance checks

- Record 30 deliberate pinches per hand, plus sustained pinches: one press/release pair per gesture, no repeats while held. Compare runtime actions with fingertip separation before choosing thresholds.
- Lose tracking with pinch held, during a cast and near the reel; refocus and switch between controllers and hands. No accidental cast, shutter, movement or reel increment may occur.
- Retrieve the guide, enter camera mode, switch selfie, adjust its distance and take a photo without controller input. Preserve the existing extension/collision constraints.
- Complete a bait/rig selection, cast, retrieve, fight and landed-fish action without controllers. Test lure and fly-specific gestures separately.
- Check grip alignment and shoulders through crouching, hand rotation and avatar changes; raw gesture measurements must remain independent of avatar scale and IK.
- Test seated hip access, hand overlap at the crank, fast backswing visibility, and several minutes of holding comfort on the physical headset.
- Keep existing controller tests passing; add meaningful input-adapter regressions for source transitions, overlapping gestures and invalid joint data.

The earlier WiVRn session validates joint delivery only. The standalone test below additionally validates native runtime actions. The proposed complete control scheme, simultaneous input and a hands-only fishing cycle remain untested.

## Standalone Quest 3 probe

The connected Quest 3 successfully ran a debug APK of the working tree using native OpenXR, without WiVRn. The user confirmed that the scene and diagnostic overlay were visible. Both hands activated `/interaction_profiles/ext/hand_interaction_ext`, supplied 26 valid-position joints when visible, and delivered pinch/grasp values and select edges. The first captured window contained 37 focused one-second samples, with a median of 72 FPS; startup was slower. This short run is not a sustained performance benchmark.

Boolean select changed near pinch value 0.5, including brief transitions. The capture includes arbitrary hand movements before and after the requested pinches, so its event counts do not establish one click per intended pinch. A controlled gesture/debounce test is still needed. Action grip poses also sometimes remained valid while no optical joint positions were valid; interaction availability must consider source and joint validity, rather than relying only on the action pose.

The first run exposed a separate Android avatar-directory error: `getExternalFilesDir(null)` is rejected by Godot's Java bridge. `scripts/data_paths.gd` now passes an empty String to address the same external files directory. The rebuilt APK was installed and relaunched: the app-specific `files/data/vrm` directory was created, native hand samples continued, and the captured second-run log contained no script/runtime error entries.

The temporary diagnostic builder, autoload and overlay were removed during release cleanup. The production project keeps the hand-interaction extension disabled. The user accepted Quest 3 standalone performance for the release; hands-only controls remain at the planning stage.

Local captures are retained under `test-results/quest-hand-probe/` (ignored build/test output).
