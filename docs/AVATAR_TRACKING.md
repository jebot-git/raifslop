# Avatar tracking and calibration

Open **Field station → Tracking** in VR. The fishing rig now reuses FPSloppa's body tracking, hand sampling, VRM expression binding, eye animation, leg IK and T-pose calibration. Tracked poses and expressions are also shared with other anglers in multiplayer.

## Supported inputs

- **Body:** native Godot `XRBodyTracker` joints (including runtime/bridge-provided body data), eight Vive/SteamVR tracker roles, and SlimeVR's VRChat OSC output. Hips, chest, feet, knees and elbows drive the avatar. Native joints take priority; calibrated external trackers fill available roles. A lower-leg tracker can estimate the ankle when no foot joint exists.
- **Hands/fingers:** native `XRHandTracker` joint angles, including controller-inferred joints. Each missing finger falls back individually to controller grip, trigger and touch states. Optical wrists can drive avatar hand IK. This does not replace the fishing game's controller inputs with a new hands-only interaction system.
- **Eyes/face:** measured eye gaze and eyelid weights animate VRM eye bones or expression bindings. Face-tracker jaw opening, smiles, frowns and brow motion map to the avatar's available vowel/happy/angry/sad/surprised expressions. Supported expressions depend on the imported VRM. Missing devices produce neutral expressions; eye motion is not synthesized.
- **Visemes:** FPSloppa's acoustic five-vowel estimate from outgoing voice input animates the mouth locally and remotely. Tracked jaw motion takes priority over the acoustic mouth estimate. Speech decays back to neutral when updates stop. Voice activation is the default; saved voice choices are preserved.
- **Leg animation:** FPSloppa's directional procedural gait and two-bone IK replace the previous fixed-axis stepping. Feet sample the actual ground collision; measured feet/knees override walking targets. Missing body tracking returns to procedural gait. Distance-based IK updates reduce work for remote avatars.

**Casting aim follows the center of the head viewpoint. Eye gaze never supplies the cast direction.** [Controller alignment and comfort](FISHING_COMFORT.md). Tracking loss or application focus loss clears body/face samples; focus loss also pauses movement and casting input.

## Calibration

For the proposed controller-free interaction work, see [hand tracking controls: feasibility and implementation sequence](HAND_TRACKING_CONTROLS.md).

For Vive or SlimeVR trackers, stand upright facing forward and select **Calibrate body — stand straight**. Alternatively, while idle with full-body tracking available, extend both arms in a steady T-pose for 1.1 seconds. It calibrates once, plays a short tone, and requires lowering the arms before another attempt. Native body joint orientations can also be calibrated; tracker-to-ankle offsets account for calf-mounted trackers.

**Recenter viewpoint** aligns the head's floor projection with the player capsule and sets the current viewing direction forward. Standing calibration adjusts world scale toward a 1.65 m reference height, following FPSloppa's bounded scale calibration. **Seated height calibration** instead adds a height offset while preserving real-world reach scale. Recenter resets gesture/reel velocity history and clears body corrections; recalibrate external body trackers afterward. It is blocked during a cast, while holding the Fish Guide, or without focused head tracking.

Body and expression toggles plus seated preference persist in `user://tracking.cfg`. Body correction matrices are session-only. For SlimeVR, **Toggle SlimeVR OSC** enables UDP 9000 from localhost by default. The same file supports `[slime] source_ip` and `listen_port` for an explicitly configured sender. OSC packets are bounded, restricted to the configured source IP, and stale samples expire.

## Runtime and permissions

The project enables Godot's OpenXR hand, eye-gaze, Meta body and Meta face extension requests, and adds FPSloppa's dedicated eye/tracker actions and finger-touch bindings. A runtime must actually provide the requested trackers. Quest through WiVRn/SteamVR/other bridges depends on the bridge's tracking support and headset sensors; enabling an extension cannot create missing hardware data.

The reused permission queue requests available Quest body/hand/eye/face or Pico eye permissions on corresponding Android build features. Use **Request tracking permissions** to retry denied access. Maintained Quest packaging declares the appropriate permissions and `quest_xr` feature. Pico builds are retired; the retained `pico_xr` compatibility code is not a support claim. Pico OS 6 support is a future goal requiring direct device validation. PC streaming relies on the headset/bridge's own permission settings.

## Multiplayer

Protocol version 2 adds bounded body transforms relative to the player's capsule, independent finger curls, cosmetic gaze/eyelids, mapped facial weights and five viseme weights. Remote IK interpolates body transforms and falls back when joints disappear. Face and curl values are validated before relay; full raw facial sensor arrays and local calibration settings are not sent. All clients/server must use the updated protocol.

## Validation

`tests/hand_tracking.gd` and `tests/tracking_orientation.gd` adapt FPSloppa's controller/joint and orientation tests. `tests/avatar_tracking.gd` covers VRM expression binding, independent fingers, tracked feet, gait fallback, speech decay, eye/face sampling, missing/focus-lost trackers, T-pose detection, recentering and eye-independent casting aim. `tests/network_guards.gd` rejects malformed body/face/finger/viseme data.

`tools/test_multiplayer.py` covers these additional fields in actual dedicated/hosted sessions and late joins. `tools/test_multiplayer_xr.py` uses native simulated Monado stereo, injected body/face/controllers, and a separate synthetic XR client; [stereo](multiplayer_eye0.png) and [desktop](multiplayer_desktop.png) captures show the resulting avatars. These tests do not establish physical tracker accuracy, headset permission behavior or comfort on real hardware.


## September 2026 tracking refresh

The live avatar stack now follows FPSloppa `28a719a84454ef94ac6683f11b709735948e12b9`: skinned rest-pose bounds, uniform 1.70 m model normalization, model-specific pelvis/ankle retargeting, directional gait with optional planted-tracker walking assistance, controller/optical wrist mapping, independent fingers, conservative eye motion, and one shared expression/speech writer. The fishing adapter rebases all targets into the same render frame, so room-scale movement and yaw cannot be applied twice. Loading an avatar while crouched does not resize it.

Local VRM spring overrides are disabled while IK owns the body; remote springs retain the corrected bone-index and missing-parent handling. Bridge calf trackers use full transform offsets, including sideways neutral axes. Native feet take precedence over inferred ankles.

T-pose detection tolerates normal high-refresh tracking noise and brief interruptions. It displays a countdown, then a completion message, tone and controller pulse. If body trackers are absent it reports that explicitly. Calibration also works with the field station open. The **Animate planted tracked legs when walking** option is off by default; measured leg movement takes priority when enabled.

Run `python3 tools/test_vr_fixes.py` for isolated-save regressions. `tests/vr_visual_validation.gd` renders menu and avatar captures; `tests/live_wivrn.gd` reads real tracking and captures both native eyes without injecting synthetic poses.

The joint audit additionally constrains limb bend planes, carries wrist pronation through the forearm, and uses native per-knuckle rotations locally when the runtime supplies them. Controllers without native joints use bounded curls including the thumb base. Uncalibrated native torso orientations inconsistent with measured hip/chest direction fall back to a geometric body frame; T-pose calibration remains authoritative. Inferred feet now retain FPSloppa’s full calibrated calf-to-ankle transform, including rotation while lifted; actual foot trackers remain authoritative. The earlier local sole-level override was removed because it caused severe ankle flexion when raising a leg. See [import integrity evidence](FPSLOPPA_REUSE.md#import-integrity-and-runtime-articulation-audit-2026-09-14).

Raised-leg correction: `tests/raised_ankle.gd` reproduces the screenshot’s folded ankle and compares the fix across all three avatars at 45°, 90° and 120° calf rotations. The Vita 90° case reduces excess ankle rotation from approximately 104° to 17°. The position/calibration functions now match FPSloppa HEAD `28a719a84454ef94ac6683f11b709735948e12b9` (verified again during this update).

## Failed embedded avatar images

Runtime avatar loads emit `AVATAR_LOAD_BEGIN` with the file path and SHA-256 before glTF decoding. A PNG/JPEG decoder failure can otherwise leave a null texture while glTF reports a successful parse. The loader now rejects any missing image before generating or caching the avatar scene. `AVATAR_LOAD_FAILED` identifies the file and failed image index; remote failures also identify the peer and avatar hash. The local avatar selection stays unchanged, and remote players retain their previous avatar or fallback. The menu reports the failed image and asks for an avatar re-export with valid embedded PNG/JPEG textures.

`tests/avatar_image_failure.gd` corrupts the IDAT payload of image index 6 while preserving GLB bounds and image dimensions. It checks rejection, scene-cache exclusion, error propagation, preservation of the selected avatar, and successful loading of an intact avatar afterward. This protects failure handling; it does not repair a damaged image or establish which file caused a user's report.
