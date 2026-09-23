# Fishing-to-golf loading investigation

Initial investigation measured 22 September 2026, including the continuous course lanes. The findings and prototype timings below describe the **pre-implementation baseline**; raw results remain in `test-results/golf-loading/`. Recommendations 1–3 have since been implemented; see the implementation results below. `tools/profile_golf_loading.gd` now profiles the production transition and shared CPU tile algorithm.

## Findings

The delay is primarily synchronous terrain construction, not reading course data. The fishing host adds the golf controller, whose `_ready()` selects Spyglass unconditionally. The host then selects the requested course. Choosing Pebble, Cypress or Poppy therefore builds two complete course worlds on first entry. Starting/resuming the round calls `load_hole()` again, but same-course terrain reuse prevents another full build.

Full fishing-host transition, milliseconds spent inside `join_course()`:

| Course | First entry | Return visit, mesh cache populated |
| --- | ---: | ---: |
| Spyglass | 5,437 | 702 |
| Pebble | 11,946 | 697 |
| Cypress | 9,981 | 699 |
| Poppy | 9,224 | 695 |

A runtime-only prototype that skips `_ready()`'s default selection when borrowing the fishing rig reduced Cypress first entry from **9,981 to 5,210 ms (48%)**. It also reduced tracked static memory at that point by approximately **489 MiB**, by avoiding the unused Spyglass world/cache. This change was applied only to a replacement script held in the benchmark process; the production script was not edited.

Isolated course-world build, independent of fishing initialization:

| Course | Tiles | Course data/model | Terrain mesh + collision + attachment | Mesh-generation portion of terrain | Scenery | Entire world |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Spyglass | 294 | 4 ms | 4,755 ms | 3,094 ms | 473 ms | 5,231 ms |
| Pebble | 414 | 5 ms | 6,655 ms | 4,358 ms | 466 ms | 7,125 ms |
| Cypress | 286 | 3 ms | 4,641 ms | 3,014 ms | 466 ms | 5,110 ms |
| Poppy | 240 | 3 ms | 3,925 ms | 2,538 ms | 469 ms | 4,397 ms |

Each 96 m tile constructs a 49 × 49 vertex grid, generates tangents, commits an ArrayMesh and builds a triangle collision shape. The terrain covers the complete rectangular course bounds, including distant rough and ocean. Surface normals sample height repeatedly for every vertex. The existing mesh/shape cache explains why repeat visits are much faster; it is process-local and unbounded.

Guide-map raster generation takes 69–194 ms in isolation. It runs on first guide refresh/open, so it is a secondary first-use hitch rather than the main transition bottleneck. Course JSON and height/lie data loading take only 3–5 ms on this host. Mapped courses also load the 8K panorama even though their displayed sky is procedural; skipping that unused load is another small cleanup to measure separately.

## Threading experiment

The prototype extracts the existing tile algorithm without changing it, and replaces its final GPU mesh commit with `SurfaceTool.commit_to_arrays()`. Each worker owns its SurfaceTool and output arrays. Workers read a configured, immutable model; a fixed-size results array has a separate slot per tile. Rendering resources, collision shapes and scene nodes remain on the main thread.

Cypress, 286 tiles:

| CPU preparation | Array generation wall time | Main-loop frames during preparation | Following unsliced mesh/shape creation |
| --- | ---: | ---: | ---: |
| Main thread | 2,927 ms | 0 | 1,070 ms |
| 1 worker | 2,940 ms | 429 | 1,079 ms |
| 2 workers | 2,001 ms | 293 | 1,078 ms |
| 4 workers | 1,608 ms | 236 | 1,077 ms |

One worker chiefly improves responsiveness. Two and four workers also reduce CPU preparation wall time by approximately 32% and 45%. During worker preparation, the otherwise idle headless main loop's maximum measured frame interval was 7.1–7.3 ms. The prototype checks the resulting first tile's vertex, index, normal, UV, colour and tangent arrays against the existing terrain implementation.

Threading alone leaves a roughly 1.08-second main-thread stall when all mesh/collision results are committed together. A second prototype yielded between commits with a 2 ms work budget: commit wall time became **1,974 ms**, with **1,116 ms of actual work**, spread across **286 frame yields**. The longest work slice was **5.13 ms**, because one tile's indivisible operation can exceed the budget. CPU preparation for that run took 1,629 ms. This demonstrates the responsiveness/elapsed-time tradeoff; it is not yet a complete threaded transition.

Godot supports worker-pool group tasks, but the main loop should poll completion and wait only after the task has finished. Immediate `wait_for_group_task_completion()` blocks the calling thread. Completed tasks still need to be collected. See [WorkerThreadPool](https://docs.godotengine.org/en/4.7/classes/class_workerthreadpool.html).

The active scene tree is not thread-safe. Shared resource mutation and GPU-related operations need particular care; switching the renderer or physics server to another thread is not a substitute for a course-loading design. Keep preparation data separate and attach/update scene objects on the main thread. See [Godot thread-safe APIs](https://docs.godotengine.org/en/4.7/tutorials/performance/thread_safe_apis.html).

`ResourceLoader.load_threaded_request()` is useful for imported textures, models and future baked terrain resources. It will not move the current procedural `_terrain()` work to a background thread. Retrieve a resource only after its status reports loaded, otherwise `load_threaded_get()` can block. See [Godot background loading](https://docs.godotengine.org/en/4.7/tutorials/io/background_loading.html).

## Recommended implementation order

1. **Remove the redundant default course.** Keep standalone golf initialization intact; in the borrowed fishing rig, initialize only the explicitly requested course. This is the simplest measured improvement and avoids an unnecessary large allocation.
2. **Introduce staged asynchronous loading.** Snapshot course/revision and immutable surface data on the main thread. Prepare tile arrays through a low-priority worker group, initially capped at two workers, with a four-worker option to test on PC. Consume completed tiles incrementally on the main thread. Prioritize clubhouse/arrival tiles, then the selected hole, then the rest. Pipeline preparation and commits rather than waiting for the entire array batch before starting commits.
3. **Keep fishing and tracking responsive until the destination is ready.** Delay the current `_capture()`/rig transfer until required terrain and collision are ready. Expose progress and cancellation. A new selection or return-to-fishing request invalidates the pending generation; stale worker results must never activate a course. Stage geometry invisibly with collisions disabled, and enable it only during the final swap. Avoid a large deferred callback that simply moves the whole stall to the next frame.
4. **Cache bounded reusable resources.** Retain a small set of shared textures/pavilion resources and baked collision shapes where beneficial. Bound the mesh cache by memory or recent courses. Each isolated cold world increased tracked static memory by roughly 537–820 MiB; preloading all courses while fishing is therefore a poor default. Preload only the selected destination or a likely return course under a budget.
5. **Evaluate offline baking next.** The height and lie fields are already deterministic. Bake tile vertex/index/normal/tangent arrays and collision data during authoring/export, then load those resources asynchronously. This could remove repeated procedural work across application launches, but package size, decompression, GPU upload and collision reconstruction must be benchmarked before claiming a speedup. Key bakes by course revision, surface hashes and mesh-generator version.

A later geometry optimization could use coarser far-distance terrain and omit underwater collision outside reachable play areas. It carries more gameplay risk than the steps above: preserve 2 m playable terrain, its triangle diagonal, ball contact, all newly connected lanes, and remote-player visibility. HeightMapShape3D or lower-resolution collision should not replace the current collision blindly.

## Validation required before shipping

- Compare all generated tile arrays/terrain heights, seams and collision queries; keep the course-lane, golf controls, shared-menu and multiplayer regressions passing.
- Test cancel, rapid selection changes, return to fishing during preparation, resource-load failure and shutdown with work pending. Publish completed results once, and release both cancelled buffers and bounded-cache entries.
- Measure first entry and warm entry separately, peak memory, total transition time, and maximum/p95 main-frame time during both preparation and commits.
- Profile actual Windows desktop and connected WiVRn headset rendering before choosing worker count and per-frame commit budget. Worker work competes with physics, rendering and networking; the idle headless timings do not prove VR frame-rate stability.

Measurements used an Intel Core i7-12700, Linux Godot 4.7.2, source/debug execution and XR disabled. Each baseline course ran in a fresh process, then a same-process warm return. OS disk caches were not flushed. These are exploratory single-run comparisons, not release-template, Windows, GPU, headset or sustained-performance benchmarks. No VR test was launched.

Example reproduction, with an isolated XDG data directory and `--asset-root`/`--photos-root` supplied as in the existing test runner:

```sh
godot --headless --path . --xr-mode off --script res://tools/profile_golf_loading.gd -- --profile-course cypress --profile-mode transition
godot --headless --path . --xr-mode off --script res://tools/profile_golf_loading.gd -- --profile-course cypress --profile-mode threaded --profile-workers 4 --profile-commit-budget-ms 2
```

## Implemented recommendations 1–3

The production fishing-host transition now builds only the requested course. Standalone golf still starts at Spyglass. Mapped courses also skip loading the unused 8K panorama.

`terrain_job.gd` owns immutable model data and prepares the unchanged terrain arrays on a low-priority WorkerThreadPool group with two workers (loader property clamped to 1–4). Completed results cross a mutex-protected queue. Clubhouse tiles are prioritized, followed by the selected/saved hole and the remaining course. Canonical cache indices are preserved regardless of task completion order.

`course_loader.gd` pipelines those arrays into main-thread mesh uploads, triangle collision shapes, foliage, pavilion collisions and hole markers. A 2 ms work budget yields between operations; an individual tile or resource operation can exceed that budget. Imported shared textures/models use threaded resource requests, retrieved only after completion. Workers never touch scene nodes, rendering resources or physics objects.

Fishing, tracking and the shared rig remain live during preparation. The Golf page shows progress and a cancel button. Prepared scenery is hidden and every collision layer/mask is disabled. Transfer and collision activation happen only after all terrain, scenery and markers are complete. A new course, a fishing-location selection, leaving golf, or quitting invalidates the pending generation. A cast begun while loading prevents the final transfer. Cancellation drains work asynchronously; application shutdown collects remaining workers and resource requests. Only complete terrain meshes enter the existing cache.

Post-implementation measurements on the same Linux/i7-12700 headless setup:

| Course | Previous cold blocking call | New cold total transition | New warm total | Selection call returns | Longest preparation work slice | Final cold activation |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Spyglass | 5,437 ms | 2,790 ms | 612 ms | 7.1 ms | 6.6 ms | 196 ms |
| Pebble | 11,946 ms | 3,561 ms | 577 ms | 7.0 ms | 7.7 ms | 193 ms |
| Cypress | 9,981 ms | 2,677 ms | 564 ms | 6.1 ms | 7.0 ms | 188 ms |
| Poppy | 9,224 ms | 2,376 ms | 592 ms | 6.0 ms | 7.3 ms | 191 ms |

Cold elapsed time is approximately 49–74% lower than the original blocking call. The new total includes the frame that completes the transfer, so the measurement boundary is slightly more conservative. All four transitions create exactly one course world. Main-loop p95 intervals are about 7.2 ms in this headless run, with 315–486 frames processed during cold loading. Tracked static memory after first entry is approximately 902–1,188 MiB; this is not peak RSS/VRAM.

**Remaining hitch:** final golf-controller/UI initialization and rig transfer still take 188–196 ms cold (62–67 ms warm). The longest complete transition frame is 207–218 ms cold. This implementation removes the seconds-long construction stall, but does not establish a hitch-free headset transition. The unchanged mesh cache is still unbounded; bounded caching and offline baking remain recommendations 4–5.

Validation completed:

- `golf_loading`: cancellation, replacement/stale completion, hidden collision isolation, preserved rig identities, all 18 markers, all 240 Poppy tiles matching sequential vertex/index/normal/tangent/UV/UV2/colour arrays, terrain collision height, warm cache, missing resource, cast during preparation, leaving during preparation, invalid course and shutdown with pending work.
- Source suites: `golf_courses`, `golf_course_lanes`, `golf_controls_feedback`, `golf_vr_input`, `golf_camera`, and local multiplayer `golf_social` passed.
- The loading suite also passed in a desktop Vulkan Forward+ window on Intel Arc A770, XR disabled. Poppy preparation measured 2.66 s, final activation 229 ms and the largest preparation work slice 10.3 ms in that run. This fixture intentionally runs sequential geometry comparisons, so its overall `peak_frame_ms` includes test work and is not a loader benchmark.
- Exported Windows PCK passed `golf_loading`, `golf_controls_feedback`, `golf_vr_input`, `golf_course_lanes`, `release_pack` and normal `quit_game` through Linux Godot with XR off. Package asset audit passed and exported runtime-source hashes match the working tree.
- Windows debug EXE launched under Wine with XR off, exited 0 and created both logs beside `Desktop.cmd`. The forced `--quit-after` smoke exit reports an Ogg audio buffer still in use; it bypasses the game's normal audio-stop/wait path. The normal quit-button regression exits cleanly. This is not native Windows or headset validation.

Updated debug package: `builds/ThreadedGolf/RealAIFishing-0.1.15-golf.1-Windows-Debug-x86_64.zip`. Launchers retain per-run engine/console logs beside themselves, with `CLIENT_STAGE` entries for `golf_prepare` and `golf_activate`. No VR session was launched; obtain the user's approval before starting one.

Post-change raw measurements: `test-results/golf-loading-implemented/summary.json`; desktop Vulkan test: `test-results/golf-loading-vulkan/run.log`; exported-package tests: `test-results/threaded-golf-pack/`. Baseline raw measurements remain untouched. These are single-run comparisons with warm OS disk caches, not sustained frame-rate guarantees.
