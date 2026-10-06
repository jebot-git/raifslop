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

## Cross-water radio — 15 September 2026

`scripts/voice/radio_audio.gd` copies the generated click cues and filter chain from `deathmatch/voice/radio_audio.gd` at `8898d03a33f42e6eec472506fccce6d68dad83d1` in `/home/blux/Documents/FPSloppa`. `shoulder_radio.gd` adapts that revision’s `deathmatch/vr/shoulder_radio.gd` to fishing’s left support hand, grip/trigger inputs and Guide/reel exclusion. `chat.gd` adapts the explicit radio-channel routing and monotonic channel history from `deathmatch/voice/{relay,chat}.gd`; all connected anglers share the radio channel instead of FPS teams. Radio remains push-to-talk even with local voice activation.

## Native acceleration reuse audit (2026-10-06)

Inspected the clean local FPSloppa checkout at `80220c9cf1f997218a0c952982a2fadf044eecfe` (2026-09-30). This is the inspected source revision, not a claim that GitHub has no newer commits.

`scripts/avatar_eyes.gd` now adapts the channel table and dirty-write optimization from `deathmatch/avatars/eyes.gd` at that revision. Resolve overlapping eye, expression and speech bindings once during setup, then compose each channel without allocating nested dictionaries every update. Preserve fishing's existing expression ordering (`surprised` before `relaxed`) and its single expression writer. Mouth-only channels also reset when speech is disabled. This uses GDScript on every platform and adds no extension dependency. Existing source attribution above continues to apply.

The focused Linux headless probe compares fishing rc.2, FPSloppa's cached GDScript mixer, the deployed fishing adaptation, and FPSloppa's compiled `FPSPose.compose_morphs`. Run:

```sh
python3 tools/benchmark_native_reuse.py --fpsloppa /path/to/FPSloppa --godot /path/to/godot
```

Measured median cost per call was 41.58–41.75 µs for rc.2, 12.84–12.94 µs for upstream cached GDScript, 13.13–13.22 µs for the deployed adaptation, and 1.99–2.03 µs for native composition. Maximum output difference in the parity probe was zero. The deployed adaptation reduced this measured mixer cost by about 68% (3.2× faster).

The report is `test-results/native-reuse.json`. It includes output parity checks, reversed-order timing blocks and the exact upstream revision. The workload is synthetic: one mesh, 12 morph channels, 29 bindings, one changing weight per timed call. It includes the extension call boundary but excludes avatar loading, rendering, networking and XR. It must not be interpreted as whole-game or Quest FPS. The native library is copied only into a disposable probe project.

| Candidate | Reuse assessment |
| --- | --- |
| Cached facial channels | Ported now; avoids repeated dictionary construction and unchanged blend-shape writes, without platform binaries. |
| Native facial composition | Closest C++ reuse candidate; same 12 eye/expression + 5 speech input shape. Keep fishing's binding order and add an optional extension with GDScript fallback. Local binaries contain Linux client/server only; Android ARM64 and Windows DLL paths are declared but those binaries are absent. |
| Native hair/clothing springs | Promising next avatar optimization. FPSloppa maps VRM resources onto Godot's built-in `SpringBoneSimulator3D`, rather than adding its own C++ spring extension. Its archived eight-avatar headless benchmark reports median 4.777 ms legacy versus 2.038 ms native, with springs-off 1.167 ms. These are upstream desktop results. Fishing disables local-body springs already, so expected benefit is primarily remote/preview avatars with springs enabled. Preserve modifier ordering, avatar-scale handling, local-body isolation, collider conversion and teleport resets; validate third-party VRMs before adopting. |
| Native IK and preparation | Requires an adapted port. `FPSPose.solve` uses shortest-arc segment rotation; fishing now constrains segment roll to the elbow/knee plane. Upstream preparation also expects combat fields and animation-budget properties absent here. Copying it directly would discard fishing's shoulder, forearm and optical-finger corrections. Small helpers such as orientation/capture are candidates, but must retain corrected behavior and pass tracking regressions. |
| Native tracking interpolation | Not directly compatible: upstream accesses `weapon`, `offhand_weapon` and `left_handed`; fishing's tracked pose schema differs. |
| Native network packing | Not a replacement for fishing's format-2 pose codec or protocol-22 validation. Reuse low-level techniques only after profiling and byte-for-byte schema tests. |
| Projectiles, combat traces and bots | Predominantly FPS workload; no demonstrated fishing bottleneck or immediate reuse benefit. |

Validation: `avatar_morph_cache` and `shark_ambience_menu` pass. Facial/viseme checks in `avatar_tracking` pass, but its four startup/standing recenter assertions fail with both the original rc.2 facial mixer and the optimized mixer in this headless environment. Those failures are not introduced by this port; the complete suite is not claimed as passing. No Quest hardware timing was available.

## Other C++ candidates measured (2026-10-06)

The follow-up study measures production functions on the local Intel N95, Godot 4.7.2 official Linux build, headless. `tools/profile_native_candidates.py --godot /path/to/godot` runs isolated fixtures and writes `test-results/native-candidates.json`. Nine measured batches follow a warmup; figures below are approximate batch medians, not frame percentiles. Avatar bounds use ten measured calls following warmup. The fixtures exercise three actual location geometries and all three bundled avatars. Automatic scene callbacks and loading are outside the timed kernel batches. No native replacement or Quest performance was measured in this study.

| Priority | Code | Measured GDScript cost and interpretation |
| --- | --- | --- |
| High for travel/loading | `main.gd::_configure_fishing_grid`, `fish_water_boundary.gd::segment_obstructed` | Grid setup around 0.59 s lakeside, 1.62 s Simon's Town, 0.80 s meadow bend. Sampled individual segment queries about 0.47–1.44 ms across 4,316–10,942 ground triangles. Setup repeatedly scans all ground triangles for line of sight. This runs on location changes, not every frame. |
| High for avatar-loading stalls | `avatar_rest_bounds.gd::mesh_bounds` | About 4.8 ms SharkPerson, 19.8 ms Vita, 22.2 ms Victoria for uncached bounds. Nested vertex/influence loops are suitable for a bulk native operation. Results are already cached per decoded model; these costs must not be multiplied by FPS. |
| Medium for busy multiplayer | `network/pose_codec.gd`, `network/state.gd::valid` | Full-body/face fixture: encode about 0.14 ms, decode about 0.12 ms, standalone validation about 0.07 ms. Head/hands plus face: encode about 0.07 ms, decode about 0.06 ms. Encode/decode timings already include their internal validation. Clients send at 20 Hz, with eight players maximum. Additional validation occurs in session admission/application. |
| Low at current scale | `fish_population.gd`, `fishing_session.gd` | Population updates about 7 µs for one visited water, 52 µs for all 12. Ready tick about 9 µs; ordinary fight tick about 23 µs including fixture field resets. Current fish behavior is not a large flock simulation. |
| Low at current scale | `main.gd::_update_line` | Waiting-line updates about 42–71 µs, including visual updates and engine mesh calls. The curve uses 25 vertices. Reducing redundant property writes or mesh rebuilding should precede a native port. Headless timing excludes GPU work. |

Ten airborne BBQ objects cost about 40 µs/step at lakeside and 81 µs/step at meadow bend (including synthetic reset overhead); idle station processing costs about 4 µs. This does not justify a dedicated native subsystem at the current item count.

The complete profiling runner finished successfully with no script errors. These are warm CPU microbenchmarks with uncontrolled system clocks; use the saved report for exact samples.

The best implementation boundaries would be:

- A persistent native shoreline-query object: upload geometry once, construct a spatial acceleration structure once, and batch visibility/sweep queries. `blocked()` already uses a small grid and measured only about 2–22 µs in these samples; `segment_obstructed()` does not use that index. A spatial index or precomputed authored fishing sectors could provide substantial gains in GDScript too. Do that algorithmic work before crediting C++ with the whole potential improvement. Preserve swept collision, radius clearance, height clipping and bank coverage.
- A native skinned-bounds function: take packed vertices, bone indices, weights and the rest palette in bulk; return one AABB. Preserve four/eight influences, imported transforms and malformed-data rejection. Keep scene traversal/import orchestration in GDScript. Existing rest-geometry regressions are required for any port.
- A native fishing pose codec with validation: one call per packet rather than a C++ helper per scalar. Preserve format 2/protocol 22 byte layout, finite-value checks, truncation/trailing-data rejection and transform/weight limits. Retain admission, replay and ownership guards. FPSloppa's generic codec is not wire-compatible. Comparing against an unsafe encoder with validation removed would not demonstrate an acceptable optimization.

For scale, seven remote full-body players at 20 Hz generate 140 incoming snapshots/s. At roughly 0.12 ms/decode this is about 17 ms CPU/s, or 0.24 ms averaged over a 72 Hz frame, before the additional session validation and state application. Updates can arrive in bursts. This arithmetic is a desktop workload estimate, not a headset prediction or a promised saving; a native implementation would still have nonzero cost. The codec is worth considering, but cannot plausibly explain all frame instability by itself.

Water/panorama shading, texture bandwidth and draw calls are GPU/renderer work; translating their GDScript setup to C++ would not remove that work. Opus/resampling/denoising and ENet transport already use native implementations. The transport worker's locking/queue behavior and avatar transfer/loading deserve profiling under real multiplayer traffic before considering a broader native rewrite.

Only profiling tools and this assessment were added for this follow-up. No speculative native runtime dependency was introduced. The earlier facial-channel optimization remains the implemented change; further ports should be compared in the same scene on Quest with CPU/GPU frame timings, including cold loads and an eight-player session.

## Implemented native targets (2026-10-06)

The three targets identified above are now implemented in the project-authored
`addons/fishing_native/` GDExtension. The previous audit's “profiling only” status
is superseded by this section.

- Shoreline visibility builds a balanced AABB tree when ground geometry is
  collected, then visits only candidate leaves. It uses Godot's existing
  triangle-intersection predicate to retain edge behavior. The GDScript fallback
  also gains a conservative 32-triangle chunk broad phase. Height-dependent fish
  clearance, swept collision and the complete river banks remain unchanged.
- Skinned rest bounds pass each surface's packed vertices, four/eight bone
  influences, rest palette and transforms to one native batch. Empty/invalid
  geometry retains the reference behavior, and per-model caching is preserved.
- The native codec reads/writes complete format-2 packets, using bounded reads
  and explicit little-endian fields. GDScript semantic validation, ownership,
  replay/rate guards and face normalization remain in place. There is no protocol
  change: clients and servers still use protocol 22. Reference encode/decode
  functions remain available for differential tests and fallback.

`--gdscript-native` disables all three native paths. Missing extensions fall back
to GDScript; maintained release builds additionally verify binary/source hash
receipts so an accidentally stale or missing native library cannot be shipped.
Linux x86-64, Windows x86-64 and Android ARM64 binaries are included. Android load
segments use 16 KiB alignment. The server build includes the Linux library and
its notices; distribute `libfishing_native.so` beside the executable. A deliberate
`tools/build_server.py --without-native` build retains the script-only option.

Build with CMake/Ninja and a C++ compiler:

```sh
python3 tools/build_fishing_native.py --target linux
python3 tools/build_fishing_native.py --target android --ndk /path/to/android-ndk
# Linux/Windows cross builds can use Zig (tested with 0.13.0):
python3 tools/build_fishing_native.py --target windows --zig /path/to/zig
```

The tool downloads hash-verified, pinned godot-cpp sources unless `--bindings` is
supplied. Runtime/toolchain notices are retained alongside the extension. The
optional Zig/Linux path supplies the shared-library destructor hook missing from
Zig 0.13's glibc CRT; clean engine shutdown is part of the regression checks.

### Measurements and validation

On the same Intel N95/Godot 4.7.2 headless fixture:

| Work | Original implementation | Native implementation |
| --- | ---: | ---: |
| Lakeside grid setup | 588 ms | 32 ms |
| Simon's Town grid setup | 1,618 ms | 98 ms |
| Meadow Bend grid setup | 798 ms | 53 ms |
| SharkPerson / Vita / Victoria bounds | 4.9 / 20.4 / 21.6 ms | 0.87 / 3.79 / 3.88 ms |
| Full-body encode / decode, including validation | 143 / 124 µs | 109 / 90 µs |

Grid “original” figures are the recorded exhaustive baseline; the improved
GDScript fallback itself measures 57 / 179 / 86 ms. Bounds and codec comparisons
use the post-change `--reference` run. These are warm kernel measurements, not
whole-frame or headset results; clocks were not pinned. See
`test-results/native-candidates-{accelerated,fallback}.json` and
`tools/profile_native_candidates.py` for reproduction. The fixture stops ambience
before freezing nodes so audio playback does not leak across teardown or distort
the CPU comparison.

Differential tests cover exact packet bytes, truncated and mutated packets,
random and authored shoreline queries, all nine sector positions across three
waters, all three bundled VRMs, eight bone influences and invalid palette
indices. `native_kernels`, `pose_codec`, `shoreline_index`,
`vrm_import_integrity`, `avatar_scaling`, `vr_ik`, `network_guards` and `quit_game`
pass. The pre-existing `aim_water_grid` aiming assertions still fail with the
original exhaustive boundary code too; they are not counted as passing.
`tools/test_native_export.py` verifies Linux/Windows library bytes, launches the
exported Linux fixture, and checks the ARM64 library bytes in an unsigned Quest
fixture APK. The built dedicated server passes restart, duplicate-rejection and
identity-continuity tests with a native writer and a GDScript observer. Nine store
release unit tests pass. Windows runtime and Quest hardware measurements remain
outstanding.

### Synthetic stereo GPU study (2026-10-06)

`tools/native_candidates/stereo_gpu.gd` renders the actual lake, coast and river
scenery through two independent Mobile/Vulkan viewports. The machine has an Intel
N95 with Intel Graphics (ADL-N), Mesa 26.0.8; ADB detected no connected headset.
These measurements are **host GPU measurements, not XR2 timings or predictions**.
No architecture or TFLOPS scaling factor is applied.

Each eye uses a 90-degree vertical field of view, 64 mm eye separation, fixed
12-degree downward pitch and the location's player spawn. Screenshots verify the
fishing-facing views. Gameplay callbacks and audio are stopped, local avatar/UI
hidden, and the desktop's extra 3D pass disabled. Water shader animation remains
active. The fixture compares production full reflections with
`low_cost_reflections=true`, using fixed resolutions and no MSAA. Each case warms
36 frames and samples 90 frames. A second sweep reverses location, resolution and
reflection order. Clocks are not locked, and this is not a sustained thermal test.

The 1024×1072 and 1440×1584 sizes are synthetic sampling points. The 1832×1920
size matches Quest 2's **physical display** per eye, as documented by
[Qualcomm](https://www.qualcomm.com/xr-vr-ar/device-finder/meta-quest-2).
It is not an assertion about the application's OpenXR render target: the runtime
selects that target separately. Two ordinary viewports also do not reproduce
OpenXR multiview, fixed foveation, lens distortion, compositor work, reprojection,
Adreno drivers, memory behavior or headset thermals. The fixture has no remote
avatars, menus or active fishing simulation, so it cannot certify the 72 Hz
target (13.89 ms total frame budget).

Raw reports: `test-results/stereo-gpu.json` and `stereo-gpu-repeat.json`;
corresponding PNGs show each measured view. `gpu_ms_p50/p95` are percentiles of
the sum of both viewport GPU timestamp durations. CPU submission and wall frame
percentiles are recorded separately; GPU duration is not converted into a claim
of headset FPS. Software renderers and unavailable GPU timestamps are rejected.

Both sweeps completed all 18 cases (36 measured cases in total). With Quest's
cheaper reflection path enabled, the range of GPU medians across the two runs was:

| Location | 1024×1072 per eye | 1440×1584 per eye | 1832×1920 per eye |
| --- | ---: | ---: | ---: |
| Lakeside | 12.17–12.31 ms | 23.97 ms | 35.42–35.43 ms |
| Simon's Town rocks | 10.37–10.67 ms | 20.34–20.72 ms | 29.82–30.36 ms |
| Meadow Bend | 15.03–17.32 ms | 28.81–33.80 ms | 41.99–49.55 ms |

Paired full/cheap comparisons show approximately 3–6% lower GPU duration with
cheap reflections in both sweeps. Meadow Bend's absolute timings varied by
roughly 15% between runs, which prevents treating small absolute differences as
precise hardware predictions. Across each sweep, increasing pixel count by 3.2×
raised GPU duration about 2.8–2.9× while draw counts remained fixed (36 lake,
30 coast, 38 river across both eyes). CPU rendering submission was roughly
0.3–0.6 ms. This supports investigating fragment shading, overdraw and texture
bandwidth; it does not identify which of them dominates or prove the same
bottleneck on Adreno. The native CPU kernels do not reduce this measured GPU work.

The initial inland-facing calibration was discarded after inspecting screenshots;
the reports above contain only the corrected fishing-facing views. Both
sweeps emitted a one-object ObjectDB leak warning during teardown after saving all
samples; this fixture cleanup warning is not a GPU measurement or gameplay test
failure. Logs are retained alongside the reports.

Reproduce with a real display/GPU, substituting the Godot binary path:

```bash
XDG_DATA_HOME=/tmp/fishing-gpu-user Godot --path . \
  --rendering-method mobile --rendering-driver vulkan --xr-mode off \
  --audio-driver Dummy --resolution 640x480 \
  --script tools/native_candidates/stereo_gpu.gd -- --xr-test
```

For the reverse-order repetition, append
`--reverse-order --gpu-output=res://test-results/stereo-gpu-repeat.json`.
Do not use `--headless`, which bypasses the hardware rendering this test measures.

#### Component cost estimate

Follow-up ablations use 1440×1584 per eye and cheap reflections. A baseline is
sampled before and after each location's cases; these baseline medians differed
by less than 0.04 ms within each run. Values below are reductions against their
mean, not additive profiler pass timings or achievable savings at equal quality.

| Shader substitution | Lakeside | Simon's Town | Meadow Bend |
| --- | ---: | ---: | ---: |
| Flat foreground mesh materials | 6.46 ms (27%) | 4.52 ms (22%) | 16.26 ms (48%) |
| Flat water fragment shader | 6.39 ms (27%) | 5.73 ms (28%) | 7.51 ms (22%) |
| Constant sky background | 6.46 ms (27%) | 6.21 ms (31%) | 5.32 ms (16%) |
| Disable sky/water panorama sharpening | 4.70 ms (20%) | 4.12 ms (20%) | 3.36 ms (10%) |

An additional bank-only run identifies `assets/environment/rivers/bank.gdshader`
as the largest individual material candidate in the worst location: replacing
only that material reduced the stereo GPU median from 28.72 ms to 18.82 ms,
**9.90 ms / 34.5%**, with identical draw and primitive counts. Absolute baseline
times still varied between runs, so only comparisons within each run are used.
The bank shader blends several grass/gravel samples, normal maps, roughness, AO,
irradiance and procedural wetness across a large visible surface. This points
to its per-pixel shading/texture workload, not the bank geometry count, as the
first river-specific optimization target. It does not separate ALU from bandwidth.

The largest broadly shared candidate is panorama sampling: turning off its
four-neighbor sharpening in sky and water alone removes 10–20% of measured GPU
time. A visually evaluated simpler bank material and preprocessed panorama
sharpening are higher-priority GPU experiments than further native C++ rewrites.
No production materials or quality settings were changed by this study.

Reproduce by appending `--ablation
--gpu-output=res://test-results/stereo-gpu-ablation.json` to the command above;
use `--bank-only --gpu-output=res://test-results/stereo-gpu-bank.json` for the
isolated bank test. Reports, logs and screenshots share those basenames.

Flat foreground replaces MeshInstance3D materials; instanced stones/foliage stay
unchanged and original material cutouts may differ. Flat water retains vertex
displacement and transparent ALPHA output but removes fragment depth reads and
associated work. Constant sky preserves the environment's sky ambient lighting.
No-sharpen affects sky and water only. These destructive visual substitutions
estimate removable cost; they are not shippable optimization implementations.

### Baked shading and shore revision

`tools/bake_bank_materials.gd` evaluates the original bank shader on the exact
runtime terrain triangles into full-length 8192×4096 atlases. Runtime shading uses
albedo, packed normal XY/roughness and emission (sRGB-encoded with a fixed 4×
emission range). It preserves the original direct-light function and interpolated
bake coverage. A nearby gravel detail ratio restores frequencies below the
atlas's 3.125 cm texel size; the initial atlas-only trial was visibly too soft.
Temperate rivers share identical albedo/normal maps. Glacier Run has its own
snow material maps, and all four rivers retain individual lighting atlases.

The eight source atlases use mipmapped BPTC/ASTC imports. A live river uses three
atlases, approximately 128 MiB including mipmaps, plus its fine-detail tile.
This is a deliberate texture-memory tradeoff for lower per-pixel shader work;
Quest memory/thermal behavior still needs a device run. Godot documents the
[quality and memory tradeoffs of VRAM texture compression](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html).
Regenerate with a real renderer:

```bash
Godot --path . --xr-mode off --rendering-method mobile \
  --script tools/bake_bank_materials.gd
Godot --headless --editor --path . --import --xr-mode off
```

Lakeside's front row of 24 seven-sided stones is replaced at load time with eight
irregular boulders using the existing credited granite scan. The original full
shore boundary remains. `tools/export_lakeside_rocks.gd` exports their exact
transforms/geometry, and `tools/rebake_lakeside_shore.py` removes the old row from
the retained Blender lighting scene and rebakes sky fill, total irradiance and
AO with the replacement boulders. Terrain UVs and collision are preserved.

After comparing the shading, `tools/preprocess_panoramas.py` bakes the bounded
six-percent luminance sharpening and color grade into the HDR panoramas. Raw
sources and SHA-256 receipts live in `source/panorama_originals/`, outside exports.
Longitude taps wrap and pole taps clamp; HDR range and image dimensions are
retained. Runtime sky, water and projected shore materials share the preprocessed
flag, avoiding double grading. Ordinary filtered mipmaps approximate the previous
derivative-dependent sharpening fade; the new path is not bit-identical at every
FOV, and reflections now use the same preprocessed panorama. Lighting tools always
read the retained raw HDRs so panorama preprocessing cannot compound baked light.

For visual review, the stereo fixture accepts `--shading-review` (fixed water
animation, five locations) and optional `--review-location=...`. Add
`--reference-bank-shading`, `--reference-lakeside-rocks` or `--reference-panorama`
to isolate changes. The panorama reference is a debug-only raw source load.

Final measurements on the Intel ADL-N host (1440×1584 per eye, static water,
36 warmup/90 measured frames):

| Location | Original scene GPU median | Final GPU median | Reduction |
| --- | ---: | ---: | ---: |
| Lakeside | 23.88 ms | 20.91 ms | 12.4% |
| Meadow Bend | 29.31 ms | 19.67 ms | 32.9% |
| Boulder Run | 29.16 ms | 20.95 ms | 28.1% |
| Cedar Creek | 27.74 ms | 20.75 ms | 25.2% |
| Glacier Run | 27.76 ms | 20.42 ms | 26.4% |

The original captures include Lakeside's old rock row and lighting. A separate
clean reverse-order reference using the new shore but original bank shaders/raw
panoramas measured 25.59/29.30/29.14/27.59/28.25 ms respectively, supporting
18–33% shader savings with matching geometry. No import/build/test jobs ran
during the final sweep or reverse reference. Intermediate `bank-preview`,
`bank-detail-preview`, `rocks-review`, and the first two `shading-baked` timing
rows overlap other work and are used only for visual review, not timing claims.

Reports: `test-results/shading-before.json`, `shading-final.json`, and
`shading-reference-repeat.json`. Three-column screenshots are
`test-results/shading-comparison-<location>.png` (original, baked materials/new
shore, then preprocessed panorama). In the four river images, the near-ground
crop's mean absolute normalized sRGB channel change is 0.74–0.99%; panorama
preprocessing changes the full images by 0.05–0.20% on average. These pixel
averages support visual inspection, not a perceptual-quality guarantee or a
test of stereo shimmer in a moving headset. The new bake removes the obsolete
black rock-shadow strip at Lakeside. Whole-game 72 Hz remains unverified on Quest.

Validation: all nine relevant suites pass: `baked_shading`, `shoreline_index`,
`maintenance_fixes`, `location_immersion`, `scenery_repairs`, `locations`,
`hdr_bake_compression`, `coastal_locations`, and `shore_transitions`. The last
two stale test assumptions were updated for the existing Glacier Run rock wakes
and the procedural river lighting path. Final import and capture logs contain
no script errors. All ten panorama source/output hashes and sharpening bounds
were verified. Test, bake, import and capture logs are retained in `test-results/`;
intermediate test logs include failures resolved by the final verification run.
