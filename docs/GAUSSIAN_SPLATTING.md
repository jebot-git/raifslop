# Gaussian splatting assessment — 14 September 2026

Recommendation: proceed to a bounded experimental bank/dock scan, with the existing mesh water, gameplay objects and collision retained. Full replacement of the four locations is not ready. The principal integration obstacle is simultaneous headset and Guide-camera rendering; the principal content gap is a suitable multi-view capture. This assessment reviews current upstream documentation and pinned renderer source. No splat rendering or headset benchmark was run for this assessment.

## What our existing content can support

The repository has mono HDR panoramas and authored foreground meshes, but no `.ply`, `.splat`, `.sog`, `.spz` or `.gsplatpack` assets were found under `source/` or `assets/`. A mesh GLB is not a Gaussian capture simply because a splat importer also accepts GLB.

The original 3DGS method reconstructs a scene from calibrated views and optimizes a Gaussian representation. Our single panorama does not contain the hidden surfaces needed for faithful head translation. Generating depth or extra views from it would introduce inferred scenery; it would not recover a measured scan. [Original research and method](https://repo-sam.inria.fr/fungraph/3d-gaussian-splatting/).

For an initial real capture, choose a small static bank, rocks or dock structure. Capture overlapping viewpoints across the intended walking and selfie-camera envelope, with consistent exposure and lighting. Record scale references and capture boundaries. Mask moving people, foliage and water where necessary; validate the reconstruction along the actual play path. These are proposed acquisition requirements, not a claim that a suitable asset has been obtained. Retain explicit redistribution permission for both the photographs and trained asset.

## Renderer shortlist

| Candidate | Relevant evidence | Assessment for this game |
|---|---|---|
| [shiena/godot-gsplat](https://github.com/shiena/godot-gsplat) | MIT; Node3D path, GPU sorting, XR profile and disk-backed paging. Documents one camera order per node; independent views require duplicated nodes/worlds. Per-eye sorting is described as unverified on device. | Strong candidate for bounded streaming, but needs native extension builds and a photo-camera solution. XR presets are starting settings, not measured fishing-game budgets. |
| [ReconWorldLab/gdgs](https://github.com/ReconWorldLab/godot-gaussian-splatting) | MIT; Raster backend supports Mobile and standard multiview rendering. Compute is unsuitable for our Mobile path. Collision generation is available; mobile hardware coverage remains incomplete. | First candidate for a small integration experiment, subject to the source findings below. Generated collision must be inspected before use. |
| [Takio0304 Quest viewer](https://github.com/Takio0304/godot-quest3-gs-viewer) | Uses gdgs, so it is not a third independent renderer. Documents a backend-selection patch and a looser sort threshold to reduce mobile hitching. | Useful packaging reference. Its approximate 0.5–1M-splat guidance is an author rule of thumb, not a performance guarantee for our game or Pico. |

The gdgs backend comparison documents asynchronous CPU sorting with 1–3-frame lag and approximately 144 bytes per splat in raster data textures, before order textures and other allocations. It also distinguishes standard multiview support from Compute, which lacks it. [Backend documentation](https://github.com/ReconWorldLab/godot-gaussian-splatting/blob/main/docs/rendering-backends.md).

## Source audit and integration consequences

gdgs revision inspected: `c22024b33a24e06d8629c654825fabd0485b2dba`.

The pinned [raster backend](https://github.com/ReconWorldLab/godot-gaussian-splatting/blob/c22024b33a24e06d8629c654825fabd0485b2dba/addons/gdgs/runtime/render/raster/raster_render_backend.gd) obtains one camera through `node.get_viewport().get_camera_3d()` in `_find_camera()`. `_drive_entry()` updates an entry's single order texture from that camera direction. `_populate_entry()` constructs the data textures separately for each entry. Therefore, I infer that a second camera sharing the world will use the main camera's ordering, and merely duplicating a node is not evidence of shared GPU storage or correct per-camera selection.

Our [Guide camera](../scripts/guide_camera.gd) explicitly shares the main `World3D`. Its held preview renders at 640×360/10 Hz; photographs render at 1920×1080 over two draws. Selfie mode looks back toward the player from up to 1.5 m away. This is a substantially different view direction, not just the stereo-eye offset. Both shortlisted renderers need this addressed.

Preferred experiment: add an explicit sorting-camera override and separate order/material state for a photo-only splat instance, with distinct visibility layers. Keep immutable Gaussian data shared only if the backend actually supports it. This should preserve existing world geometry, fish and avatars in photos. An isolated photo `World3D` is an alternative, but it requires synchronized scenery and dynamic actor copies. Lowering preview refresh alone does not correct sorting. Photograph capture must wait for the photo sort to complete; the existing two-draw delay is not proof that an asynchronous sort has finished.

The pinned [backend selector](https://github.com/ReconWorldLab/godot-gaussian-splatting/blob/c22024b33a24e06d8629c654825fabd0485b2dba/addons/gdgs/runtime/render/backend/gaussian_backend_selector.gd) reads the base renderer project setting. Our project currently sets Mobile directly, so the viewer's platform-override bug is not presently triggered. Force Raster in the experiment and verify the runtime renderer if export overrides are introduced.

Our [water shader](../assets/environment/water.gdshader) does not write alpha and uses the opaque depth path. That makes ordinary depth rejection a useful starting point, but does not establish correct splat intersections along waves, poles, rod tips or shoreline edges. Keep scanned water out of the asset to avoid two competing surfaces. Retain current collision proxies, safe arrivals and selfie raycasts. Splats alone do not supply gameplay collision.

## Proposed measurements and acceptance gates

These are experiment targets, not achieved results. Start with an authored overlap fixture, then one licensed scan capped at 100k, 250k and 500k splats. The fixture can verify rendering without pretending to establish photographic quality.

| Gate | Required evidence |
|---|---|
| Cameras | Correct front/back blending in both XR eyes, Guide preview and selfie PNG while all are active; test opposed cameras, rapid turns and completed-sort capture synchronization. |
| Hybrid scene | Fish, line, rod, avatars and opaque water occlude correctly at near/far intersections; no persistent halos, stereo shimmer or duplicated water. |
| Movement | Inspect crouching, room-scale motion, locomotion and selfie reach throughout the approved capture envelope; no exposed holes at allowed positions. |
| Performance | Compare matched mesh-only and splat runs at fixed render resolution, with Guide off/on, catches and eight anglers. Record CPU/GPU p50/p95/p99, missed frames, peak process/GPU memory, load hitches and ten-minute sustained behavior. |
| Device/export | Linux and Windows PC VR, then physical Quest; Pico OS 6 is a future goal only, requiring separate device validation; verify assets and any native libraries in exports. Synthetic XR checks geometry and view handling, not device comfort or speed. |
| Lifetime | Repeatedly switch locations and open/close Guide; memory should settle and sort jobs/resources must be released safely. |

For planning, 72 Hz provides 13.89 ms per frame and 90 Hz provides 11.11 ms. Reserve roughly 20% headroom: target total application CPU and GPU times each below about 11.1 ms at 72 Hz or 8.9 ms at 90 Hz, then examine missed frames and tail latency separately. Do not mistake the 90 Hz physics setting for a measured headset refresh rate.

Using the documented 144-byte texture figure, 100k/250k/500k splats account for approximately 13.7/34.3/68.7 MiB in data textures alone. Two independently allocated 500k instances would use about 137.3 MiB before ordering, CPU copies, import peaks, render targets and the existing game. File compression does not establish resident memory cost. Measure actual allocations before choosing a shipping cap.

Next implementation step: an isolated Raster experiment with the overlap fixture and two opposed cameras, followed by a licensed static scan. Only integrate a selectable location after camera correctness and physical-device budgets pass. No renderer, scan or new runtime dependency was added by this assessment.
