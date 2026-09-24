# Integrated hand tracking and mixed reality club fitting

Assessment: 24 September 2026, `integration/golf-fishing` at `b61e1a3`.
This is a source review and feasibility proposal, not an implemented feature or a headset validation.
It extends [the earlier hand tracking study](HAND_TRACKING_CONTROLS.md) and [attachment calibration](GOLF_CLUB_ATTACHMENT.md).

## Recommendation

Build a stationary mixed reality attachment-alignment mode first, using the mounted controller as the authoritative club pose and an ordinary controller pointer for adjustments. Add optical offhand controls after simultaneous input has been measured on the target runtime. Passthrough does not require hand tracking, so these milestones can be tested independently.

Hand tracking remains a good fit for menus, the guide and photos. The integration has not made hands-only fishing or golf complete. In particular, do not enable the hand interaction extension globally and assume existing trigger/grip handlers constitute a finished control scheme.

## What remains valid from the earlier study

The September 17 study records successful Quest 3 native EXT hand actions and valid optical joints, and a separate WiVRn joint-delivery test. Those observations support the feasibility of a new probe. They do not establish current mixed input, intentional-gesture reliability, fast swing tracking or passthrough support.

The installed Godot 4.7.2 engine, loading this checkout, reports:

| Effective project setting | Value |
| --- | --- |
| Hand tracking | `true` |
| Hand interaction profile | `false` |
| Meta simultaneous hands and controllers | `false` |
| Meta passthrough | `false` |

`OpenXRFbPassthroughGeometry` is registered in the installed build. This proves plugin class availability, not runtime support. The vendored OpenXR Vendors notes identify version 5.1.0 with a Linux face-tracking patch; its changelog includes simultaneous hands/controllers. Preserve that patch if the vendor plugin is upgraded.

Godot distinguishes joint tracking from action-profile input. Keep that distinction in the adapter and in diagnostics. See [Godot hand tracking](https://docs.godotengine.org/en/4.7/tutorials/xr/openxr_hand_tracking.html).

## Changes introduced by the integrated game

| Code path | Finding and implication |
| --- | --- |
| `scripts/tracking/hand_input.gd` | Samples curls and wrist-relative finger rotations for avatar rendering; it is not an interaction-source resolver. Do not convert controller-inferred curls into optical gestures. |
| `scripts/menu_ray.gd`, golf `core/menu_ray.gd` | Native fingertip pointing and runtime aim poses already exist. Source choice and deliberate select/cancel still need a shared policy. |
| `scripts/main.gd`, `scripts/xr_startup.gd` | Client is VR-only. Tracking loss cannot fall back to desktop controls. Casting/reeling still query controller nodes directly. |
| `golf/fishing_host.gd` | Golf reuses the host rig, avatar, tracking manager and controls. Put source resolution at the shared rig boundary, not in two activity-specific gesture systems. |
| Golf `main.gd`, `golf/attachment_controls.gd` | Per-hand offsets, independent shaft and head orientation, controller-mounted mode and a collision-free cyan preview are reusable for MR alignment. |
| Golf `main.gd` fit handlers | Capture uses trigger; accept/cancel use A/B or X/Y; sticks adjust and grip changes head/handle mode. A hands-only user cannot complete the full workflow through those bindings. Add visible controls. |
| `golf/support_hand.gd` | Automatically poses a support hand when the offhand controller is absent or idle. It is visual IK, not proof of optical offhand input. Optical interaction needs explicit ownership so the displayed hand does not snap to the shaft while selecting UI. |

Recommended shared adapter: per-hand source, active profile, pose validity, joint validity, grip/aim poses, select/grasp states and intentional edges. Use runtime pinch/grasp first. Keep raw optical gestures as a separately validated fallback. Track controller and optical availability independently for simultaneous input.

For fishing, cancel pending casts and clear motion history on source/focus/tracking transitions. For golf, invalidate swing history and fit sampling on those transitions, without accepting a fit or releasing an action. Require neutral input before rearming. Controller grip offsets must never be applied unchanged to optical wrists. Keep physical attachment tracking on the mounted controller even when its user's other hand is optical.

## Mixed reality view: feasible, with two separate calibration tasks

**Attachment alignment** matches the virtual grip and shaft to the visible physical accessory. Show passthrough, a thin grip marker, shaft centreline and head/face axes. A short weighted controller accessory may have no real clubhead: label the virtual head as a reference, and do not force virtual reach to equal the accessory's physical length.

**Address fitting** chooses playable virtual reach and clearance relative to a ball and ground. The existing `club_fit.gd::solve_grounded()` uses the course's `world.surface_height`; `accept_club_fit()` also checks that virtual turf. The real room floor is a different reference. For the first milestone, align the attachment in MR and return to VR for the existing address fit. A later MR address solver needs an explicitly established real floor plane and target, with its own acceptance check. Merely turning on passthrough does not supply either.

The current code keeps clubhead orientation relative to the calibrated grip separately from shaft rotation. Preserve that representation in the overlay and saved candidate. Do not reconstruct head orientation from shaft rotation, or let a grounded fit silently overwrite a manually aligned face.

### Rendering design

Use reconstruction passthrough for the first experiment: the room is visible behind a small fitting panel and alignment guides. Query `get_supported_environment_blend_modes()` before offering the mode. If alpha blending is unavailable or activation fails, retain VR calibration with an explanation.

Godot's supported route is an alpha blend environment plus a transparent XR viewport and background. Quest requires the vendor integration and corresponding Android export configuration. See [Godot AR/passthrough](https://docs.godotengine.org/en/4.7/tutorials/xr/ar_passthrough.html). The current Android preset has no explicit passthrough feature entry; configure passthrough as optional for an application that returns to VR, and retain the boundary.

In this project, PC stereo renders through `host.xr_view` (`HeadsetViewport`), while standalone uses the main viewport. Changing only `host.get_viewport().transparent_bg` would target the PC mirror instead of stereo. Apply the setting to the active XR output. Its `World3D` is shared with the spectator, so isolate fitting visibility with camera layers and a camera-specific environment where possible. Check actual sky, terrain, water, foliage, avatar and remote-player visibility: a transparent background does not remove opaque world geometry.

Snapshot blend mode, viewport transparency, camera environment/cull mask and affected visibility before entering. Restore the exact snapshot on exit, failure, course change and shutdown. Avoid overwriting the activity boundary's own snapshots. Do not promise the desktop mirror or saved photos will include the room camera image: compositor passthrough is separate from the application render target.

[Meta projected passthrough](https://godotvr.github.io/godot_openxr_vendors/manual/meta/passthrough.html) offers a later portal around the attachment. Its hole-punching and reconstruction-priority rules make it a separate design; it is unnecessary for the first stationary calibration experiment. Neither variant automatically recognizes an accessory or measures its shape.

### Interaction and persistence

1. Enter **Align attachment in mixed reality** from Golf Controls with a stopped ball and a valid mounted controller. Block locomotion and ball contact; reset swing history.
2. Show the physical room and current alignment. Keep an accessible panel with position/rotation steps, preview opacity, reset, accept and cancel. Support controller pointing first, including a delayed capture when the mounted controller's buttons are awkward to reach.
3. Stage edits in a candidate containing both hands' mount settings and shared reach. Current attachment controls save immediately, whereas the address-fit session stages only its existing fit fields. The MR editor needs an expanded transaction; cancel must restore offsets and mounted flags too.
4. Accept only with a valid source and deliberate UI selection; persist through the golf preferences path. Cancel restores the baseline. Return to VR address fitting if reach/ground calibration is desired.
5. On tracking/focus loss, pause adjustments and hide stale guides. After restoration, require neutral input and reset all sampling/velocity history. Test the single-controller path separately from simultaneous optical offhand input.

Keep metres and transforms in the same tracking space, independent of avatar height/IK. Verify `XRServer.world_scale`, origin transforms and recentering against a known physical length. Start with slow alignment movements; compare repeated poses to distinguish a fixed offset from time-dependent passthrough/tracking error. Optical hand mesh occlusion and automatic object registration are later additions.

## Runtime validation plan

| Target | First evidence required |
| --- | --- |
| Quest 3 standalone | Optional passthrough export, supported blend modes, actual room visible, correct overlay registration, restoration to VR. Earlier native hand-action evidence does not validate MR. |
| Quest through WiVRn | Probe the application-facing runtime for blend modes and independent controller/hand sources. A headset's native capabilities do not establish which features survive streaming. Treat support as unverified. |
| Other PC OpenXR runtimes | Capability-gated VR fallback. Do not assume passthrough or simultaneous input from the runtime name. |

Run controlled pinch holds and 30 deliberate pinches per hand, source handovers, occlusion and focus loss. Require one selection per intended gesture, no accidental cast/shot/fit acceptance and no stale motion on reacquisition. In MR, test both hands, one controller, cancelled/accepted edits, recentering, course transitions and exact restoration of mirror/headset rendering. Log profile, source, valid joints, poses, focus, blend modes and frame timings. No success criterion should rely solely on a simulated headset screenshot.

Recommended order: (1) standalone passthrough/overlay probe, (2) controller-operated staged MR alignment, (3) shared hand adapter with menus/photos and visible fit controls, (4) measured simultaneous offhand input, (5) stationary fishing and broader hands-only controls. Full hands-only golf swings remain experimental because visibility, two-hand occlusion and fast motion have not been measured.

## Verification performed for this assessment

- Read the integrated implementation and previous study; checked current primary Godot/vendor documentation.
- Ran the installed-engine settings probe described above. No feature flags were changed.
- `tests/hand_tracking.gd`: 21 checks passed. This covers joint/curl sampling and bindings, not hands-only gameplay.
- Launched Godot. MCP session discovery returned no sessions; the editor reported bundled plugin 4.0.4 versus running server 4.1.0 on port 8000. No service was replaced.
- Attempted a native OpenXR probe: the configured Monado runtime could not connect to `/run/user/1000/monado_comp_ipc` and returned `XR_ERROR_RUNTIME_UNAVAILABLE`. No physical runtime blend modes or headset behavior were measured.
- Attempted `tests/golf_attachment.gd`; missing imported assets prevented reliable scene construction, so the run was stopped. No passing integrated attachment-test claim is made. Complete asset import before repeating that suite.

The editor's automatic `project.godot` normalization was reverted. This study changes documentation only.
