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
