# FPSloppa source reuse

Upstream: https://github.com/jebot-git/FPSloppa

Source revision: `5105fb8cfa38c76aa1d5d172af3047fe2d12ae0d`.

Adapted from the clean committed files in the local checkout `/home/blux/Documents/Entryway/Godot`, whose origin is that GitHub repository. Reuse was explicitly requested by the project owner. The inspected FPSloppa checkout contains no repository-wide LICENSE file; this document does not assign a new license to its project-authored source. Retain upstream notices and resolve project-level distribution terms before attributing a permissive license to that code.

| Fishing path | FPSloppa origin / adaptation |
| --- | --- |
| `scripts/network/session.gd` | `deathmatch/arena.gd`: ENet hosting/client lifecycle and 20 Hz snapshot conventions; fishing-specific handshake, validation and replication |
| `scripts/network/avatars.gd` | `deathmatch/avatars/network.gd`: verified, throttled, windowed avatar transfer; fishing actor/progress adapters, timer-free busy retry |
| `scripts/network/avatar_library.gd` | `deathmatch/avatars/library.gd`: metadata, geometry, texture and cache validation; fishing VRM loader and bundled defaults |
| `scripts/network/disk_worker.gd` | `deathmatch/network/disk_worker.gd`: serial worker and bounded main-thread callbacks |
| `scripts/network/asset_jobs.gd` | `deathmatch/network/asset_jobs.gd`: checksum/cache jobs; FPS map jobs removed |
| `scripts/voice/{chat,microphone,preferences,visemes}.gd` | `deathmatch/voice/`: Opus capture, packet guards, jitter buffering, spatial playback and settings; fishing controls, VRM visemes and local mouth-level bookkeeping, location filtering |
| `scripts/voice/permissions.gd` | `deathmatch/vr/permissions.gd`: permission queue; microphone and optional Quest/Pico tracking permission queues |
| `tests/opus_fixture.gd` | `deathmatch/tests/opus_fixture.gd`: deterministic native Opus fixture |
| `addons/twovoip/` | Entire native addon, helper scripts, platform binaries, build notes, binary checksum manifest and licenses retained |

TwoVoIP is MIT licensed; its included Opus, RNNoise, SpeexDSP and godot-cpp notices retain their respective terms. See `addons/twovoip/LICENSE.txt`, `OPUS-COPYING.txt`, `RNNOISE-COPYING.txt`, `SPEEXDSP-COPYING.txt`, `GODOT-CPP-LICENSE.md`, and `FPSLOPPA-NOTES.md`. No FPS maps, characters, sounds, weapons or unrelated assets were copied. Native library filenames and upstream binary hashes are preserved.

## Avatar tracking extension

The same FPSloppa revision supplies `vr/{tracking,t_pose,body_basis,osc,hand_input,eyes,poses}.gd` under `scripts/tracking/`, `avatars/pose.gd` adapted into `scripts/avatar_ik.gd`, and `avatars/{mouth,eyes}.gd` under `scripts/avatar_{mouth,eyes}.gd`. Fishing adapters add capsule-relative pose frames, fishing-speed gait, a tracking menu, seated/standing recentering, face-to-VRM expression mapping and protocol-2 replication. The prior analytic elbow helper remains for stable reach limits. The action map merges the dedicated tracking/gaze actions and controller finger-touch bindings; unrelated hand action subpaths are removed. No FPS weapon, death, recoil or combat animation behavior is included.

## Field station menu

`scripts/ui/choice.gd` and `scripts/ui/drag_scroll.gd` adapt `deathmatch/ui/{choice,drag_scroll}.gd` at the same revision, with fishing theme colors and a project-specific selector group. `scripts/avatar_menu.gd` follows the settings panel's tab/stepper structure. `scripts/ui/keyboard.gd` uses the deferred input-delivery approach from `deathmatch/vr/keyboard.gd`, implemented with native Godot controls without adding XRTools. No FPS visual or audio assets were copied.

## Subdued avatar lighting

`addons/Godot-MToon-Shader/mtoon_common.gdshaderinc` reuses the MToon lighting/filtering changes from the same clean FPSloppa revision. `scripts/avatar_lighting.gd` adapts `deathmatch/avatars/lighting.gd` with a fishing-specific preparation marker. It preserves material identity for expressions, caps direct/emissive response and suppresses rim/matcap shimmer. Original MToon license notices remain. [Environment lighting](ENVIRONMENT_LIGHTING.md).


## Live VR correction port (2026-09-14)

The IK/tracking refresh uses upstream commit `28a719a84454ef94ac6683f11b709735948e12b9`, fetched from the same FPSloppa repository. `scripts/avatar_ik.gd` contains the live solver from `deathmatch/avatars/pose.gd`; fishing supplies its own controller targets and retains the degenerate-pole fallback. `avatar_gait.gd` and `avatar_rest_bounds.gd` reuse the upstream locomotion and skinned-rest-bounds implementations. `avatar_rig.gd` adapts normalization, target framing, pelvis/foot fit, and local spring isolation. The eye/mouth mixer and `tracking/{tracking,t_pose,body_basis,osc,hand_input,face_expressions}.gd` use this revision as well. Fishing retains protocol-2 network payloads and expression ordering; local validation also accepts per-knuckle hand orientations, while outgoing snapshots retain the five-curl fallback.

The three modified `addons/vrm/vrm_{secondary,spring_bone,spring_bone_logic}.gd` files match this upstream revision, preserving the addon license. Scaling, rotated-wrist, optical-hand, calf-axis and knee-direction regressions are adapted from FPSloppa's tests. No weapon, damage or death behavior is added to fishing.

## Import integrity and runtime articulation audit (2026-09-14)

All 51 files under upstream `addons/vrm/` are byte-identical to this checkout at `28a719a84454ef94ac6683f11b709735948e12b9`. Two additional local `.svg.import` files are generated icon descriptors. Runtime extension order, GLTF flags (8), image handling, and head-hiding mode match; visibility layer numbers differ to fit fishing's cameras.

`tests/vrm_import_integrity.gd` compares each complete model's skinned rest vertices before VRM processing (plain GLTF import) and after VRM retargeting, accounting for the documented whole-model 180-degree facing conversion. SharkPerson: 3,049 vertices, max displacement 0.000000121 m; Vita: 19,086 vertices, 0.0000000614 m; Victoria: 21,126 vertices, 0.000000121 m. This verifies preservation of these three rest meshes, not every possible third-party VRM or every animated pose.

The remaining runtime fixes intentionally extend upstream's solver: constrain segment roll to the elbow/knee plane, move the clavicle with arm reach, carry pronation through the forearm, animate the thumb metacarpal, use valid wrist-relative native finger rotations including splay, and retain the calibrated calf-to-ankle transform for inferred feet, matching upstream. Actual tracked feet retain their supplied articulation. Imported rest transforms and skin weights are untouched. `tests/vr_ik.gd`, `hand_tracking.gd`, `tracking_orientation.gd`, and `joint_visual.gd` exercise these extensions.

### Generated-instance pose correction

The original rest-geometry check was insufficient to rule out the import path. A later audit reproduced ankle spikes and arm tearing: after `GLTFDocument.generate_scene`, several bone **poses** still contained pre-retarget offsets/rotations while their **rests** were correctly retargeted. Examples include `LeftToes`, `RightToes`, `J_Sec_*_UpperArm`, and `J_Sec_*_LowerLeg`. The local rig now calls `skeleton.reset_bone_poses()` after removing imported animation players and before installing IK. This synchronizes every bone, including helpers and toe bones that the live solver does not otherwise write. The addon remains byte-identical to FPSloppa; this is a local initialization correction around its generated scene. New all-bone assertions and close-up renders verify the correction on all three bundled models.

Raised-leg follow-up: the local floor-level estimated-foot override was incorrect for airborne legs. `estimated_foot` again returns `lower_leg * ankle_offset`, as in upstream HEAD `28a719a84454ef94ac6683f11b709735948e12b9`; `calibrate_foot` also retains the same full-transform offset calculation. No VRM importer changes were made for this correction.
