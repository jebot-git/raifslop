# Avatar tracking and calibration

Open **Avatar → Tracking & calibration** in desktop or VR. The fishing rig now reuses FPSloppa's body tracking, hand sampling, VRM expression binding, eye animation, leg IK and T-pose calibration. Tracked poses and expressions are also shared with other anglers in multiplayer.

## Supported inputs

- **Body:** native Godot `XRBodyTracker` joints (including runtime/bridge-provided body data), eight Vive/SteamVR tracker roles, and SlimeVR's VRChat OSC output. Hips, chest, feet, knees and elbows drive the avatar. Native joints take priority; calibrated external trackers fill available roles. A lower-leg tracker can estimate the ankle when no foot joint exists.
- **Hands/fingers:** native `XRHandTracker` joint angles, including controller-inferred joints. Each missing finger falls back individually to controller grip, trigger and touch states. Optical wrists can drive avatar hand IK. This does not replace the fishing game's controller inputs with a new hands-only interaction system.
- **Eyes/face:** measured eye gaze and eyelid weights animate VRM eye bones or expression bindings. Face-tracker jaw opening, smiles, frowns and brow motion map to the avatar's available vowel/happy/angry/sad/surprised expressions. Supported expressions depend on the imported VRM. Missing devices produce neutral expressions; eye motion is not synthesized.
- **Visemes:** FPSloppa's acoustic five-vowel estimate from outgoing voice input animates the mouth locally and remotely. Tracked jaw motion takes priority over the acoustic mouth estimate. Speech decays back to neutral when updates stop. Voice still starts in listen-only mode; enable its existing microphone mode to speak.
- **Leg animation:** FPSloppa's directional procedural gait and two-bone IK replace the previous fixed-axis stepping. Feet sample the actual ground collision; measured feet/knees override walking targets. Missing body tracking returns to procedural gait. Distance-based IK updates reduce work for remote avatars.

**Casting aim remains the center of the head viewpoint. Eye tracking is cosmetic and never supplies the cast direction.** Tracking loss or application focus loss clears body/face samples; focus loss also pauses movement and casting input.

## Calibration

For Vive or SlimeVR trackers, stand upright facing forward and select **Calibrate body — stand straight**. Alternatively, while idle with full-body tracking available, extend both arms in a steady T-pose for 1.4 seconds. It calibrates once, plays a short tone, and requires lowering the arms before another attempt. Native body joint orientations can also be calibrated; tracker-to-ankle offsets account for calf-mounted trackers.

**Recenter viewpoint** aligns the head's floor projection with the player capsule and sets the current viewing direction forward. Standing calibration adjusts world scale toward a 1.65 m reference height, following FPSloppa's bounded scale calibration. **Seated height calibration** instead adds a height offset while preserving real-world reach scale. Recenter resets gesture/reel velocity history and clears body corrections; recalibrate external body trackers afterward. It is blocked during a cast, while holding the Fish Guide, or without focused head tracking.

Body and expression toggles plus seated preference persist in `user://tracking.cfg`. Body correction matrices are session-only. For SlimeVR, **Toggle SlimeVR OSC** enables UDP 9000 from localhost by default. The same file supports `[slime] source_ip` and `listen_port` for an explicitly configured sender. OSC packets are bounded, restricted to the configured source IP, and stale samples expire.

## Runtime and permissions

The project enables Godot's OpenXR hand, eye-gaze, Meta body and Meta face extension requests, and adds FPSloppa's dedicated eye/tracker actions and finger-touch bindings. A runtime must actually provide the requested trackers. Quest through WiVRn/SteamVR/other bridges depends on the bridge's tracking support and headset sensors; enabling an extension cannot create missing hardware data.

The reused permission queue requests available Quest body/hand/eye/face or Pico eye permissions on corresponding Android build features. Use **Request tracking permissions** to retry denied access. Future standalone Android packaging must declare these permissions and the appropriate `quest_xr`/`pico_xr` feature; an Android export is not supplied by this change. PC streaming relies on the headset/bridge's own permission settings.

## Multiplayer

Protocol version 2 adds bounded body transforms relative to the player's capsule, independent finger curls, cosmetic gaze/eyelids, mapped facial weights and five viseme weights. Remote IK interpolates body transforms and falls back when joints disappear. Face and curl values are validated before relay; full raw facial sensor arrays and local calibration settings are not sent. All clients/server must use the updated protocol.

## Validation

`tests/hand_tracking.gd` and `tests/tracking_orientation.gd` adapt FPSloppa's controller/joint and orientation tests. `tests/avatar_tracking.gd` covers VRM expression binding, independent fingers, tracked feet, gait fallback, speech decay, eye/face sampling, missing/focus-lost trackers, T-pose detection, recentering and center-of-view casting aim. `tests/network_guards.gd` rejects malformed body/face/finger/viseme data.

`tools/test_multiplayer.py` covers these additional fields in actual dedicated/hosted sessions and late joins. `tools/test_multiplayer_xr.py` uses native simulated Monado stereo, injected body/face/controllers, and a separate desktop client; [stereo](multiplayer_eye0.png) and [desktop](multiplayer_desktop.png) captures show the resulting avatars. These tests do not establish physical tracker accuracy, headset permission behavior or comfort on real hardware.
