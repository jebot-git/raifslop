# Lake Pier and Simons Rocks hybrid prototype

Initial test: 16 September 2026. **Superseded in part by the [culling, lighting and rear-connection refinement](GAUSSIAN_SPLAT_REFINEMENT.md).** The initial captures below include the subsequently fixed draw-order bug, so they understate splat coverage from affected viewing angles. Gray Pier is archived; the standalone launcher now opens Lake Pier and allows switching to Simons Rocks. The main game assets, scenes and project settings are unchanged.

## Running the prepared prototype

```bash
./tools/splat_experiment/run.sh
./tools/splat_experiment/run.sh --location=simons_town_rocks
```

1 = Lake Pier, 2 = Simons Rocks, B = splats on/off, WASD = walk, right mouse = look, R = reset, P = screenshot and camera pose. Generated files and the Godot project live under ignored `test-results/splat-experiment/`.

## Result

Both environments now combine nearby generated splats, the oriented source panorama for distant scenery, opaque animated shader water, and the original walkable meshes, fittings and barriers. Simons retains its six curved photographic rock cards and mesh stone shoulders. Only the oversized concrete/gravel/grass apron outside the protected floor is clipped; nearby decorations remain.

The result is a usable comparison prototype, **not a demonstrated complete fix for the visual mismatch**. Simons gains spatial depth around the side and rear boulders, but the generated dark rocks still differ in lighting and surface appearance from the authored lighter rocks. Lake Pier gains local structure beside the long pier, but thin railings and undersides fragment visibly when viewed from the side. Open-water cropping reduces floating debris; residual edge fragments remain outside that mask. Those artifacts are visible in the retained comparisons rather than hidden by favorable camera selection.

B toggles splats within this revised prototype. The baseline screenshots use the same revised meshes, water and panorama as the hybrid; they are **not captures of the untouched production level**.

| Final desktop measurement | Lake Pier | Simons Rocks |
|---|---:|---:|
| Source splats | 500,000 | 500,000 |
| Retained near splats | 10,566 | 19,821 |
| Wall frame median / p95 | 4.343 / 6.606 ms | 3.456 / 5.482 ms |
| GPU median / p95 | 3.511 / 4.060 ms | 2.799 / 3.121 ms |
| Godot reported rendering memory | 119.1 MiB | 131.8 MiB |
| Floor ray / side capsule sweep | pass / pass | pass / pass |
| Authored collision proxies | 5 | 17 |
| Walkable support overlaps | 0 | 0 |

Godot 4.7.2, Mobile Vulkan renderer, Intel Graphics ADL-N, 1280×720 mono. Each independent process used 120 warmup frames and 600 measured frames with a matching camera movement. Screenshot capture occurred after timing. This validates these desktop runs; it is not a new stereo-headset measurement. User testing had already established that the hybrid approach fits the relevant VR performance constraints.

## Matched visual evidence

Four identical camera poses per location are retained, with splats off/on: front (0), rear (1), translated right-facing (2), translated left-facing (3).

| View | Splats off | Hybrid |
|---|---|---|
| Lake front | [baseline](splats/lake_pier_baseline_0.png) | [hybrid](splats/lake_pier_hybrid_0.png) |
| Lake rear | [baseline](splats/lake_pier_baseline_1.png) | [hybrid](splats/lake_pier_hybrid_1.png) |
| Lake side, exposed railing artifacts | [baseline](splats/lake_pier_baseline_2.png) | [hybrid](splats/lake_pier_hybrid_2.png) |
| Lake opposite side | [baseline](splats/lake_pier_baseline_3.png) | [hybrid](splats/lake_pier_hybrid_3.png) |
| Simons front | [baseline](splats/simons_town_rocks_baseline_0.png) | [hybrid](splats/simons_town_rocks_hybrid_0.png) |
| Simons rear | [baseline](splats/simons_town_rocks_baseline_1.png) | [hybrid](splats/simons_town_rocks_hybrid_1.png) |
| Simons side boulders | [baseline](splats/simons_town_rocks_baseline_2.png) | [hybrid](splats/simons_town_rocks_hybrid_2.png) |
| Simons opposite coast | [baseline](splats/simons_town_rocks_baseline_3.png) | [hybrid](splats/simons_town_rocks_hybrid_3.png) |

## Generation and alignment

Two private Marble 1.1 worlds were generated from the existing location panoramas, seed 20260916:

- Lake Pier: `c5354e0a-d300-47c2-bab8-b97cecee3e14`.
- Simons Rocks: `72732597-670c-489d-b1a2-0bdf2e70bec1`.

Each used one 1,500-credit panorama request: 3,000 credits total, equivalent to $2.40 at 1,250 credits per dollar ([World Labs pricing](https://docs.worldlabs.ai/api/pricing)). No paid regeneration was needed for cleanup.

Blender resized the original 8K HDR panoramas to 4096×2048, tone-mapped with AgX and rolled longitude to preserve game forward (original sky yaw: Lake −100°, Simons 180°). Both downloaded 500k SPZ files are legacy v2, SH degree 0. The converter preserves source coordinates. The viewer flips OpenCV Y/Z and restores the centroid removed by GDGS. GDGS remains pinned to `c22024b33a24e06d8629c654825fabd0485b2dba`.

Scale is an experimental water-height alignment, not a surveyed metric reconstruction. Using ground-offset metadata alone put generated water above the authored shader water. The central open-water source median was therefore matched to the authored water level: Lake scale 1.8355764 at world Y −2.48, Simons scale 2.6212282 at Y −1.98. The original metadata and calibration method remain in ignored `location_profiles.json`.

## Deterministic cleanup

`prepare_locations.py` keeps finite, sufficiently opaque splats within 32 m (Lake) or 28 m (Simons), removes large supports and points near/below the water plane, and clears a forward open-water wedge. It excludes the union of authored floor footprints using conservative 4.25-sigma support plus a 20 cm margin. Minimum retained support clearance is 24.74 cm / 24.87 cm. This is a finite rendering-support test, not a claim about mathematically infinite Gaussian tails. An 80 cm outside fade and 8 m outer-radius fade soften cropping. The source export remains intact.

Cleanup and collision reports: [Lake cleanup](splats/lake_pier_cleanup.json), [Simons cleanup](splats/simons_town_rocks_cleanup.json), [Lake checks](splats/lake_pier_review.json), [Simons checks](splats/simons_town_rocks_review.json). Raw timing summaries: [Lake](splats/lake_pier_metrics.json), [Simons](splats/simons_town_rocks_metrics.json).

## Reproduce locally

The existing standalone viewer and pinned renderer are prerequisites; see the experiment README. Preparing panoramas requires Blender's `bpy`; cleanup requires NumPy. Local cleanup never invokes the API.

1. Run Blender with `--background --python tools/splat_experiment/prepare_location_panos.py`.
2. For a new generation only, configure the API credential locally and use `marble.py --location lake_pier submit` (or `simons_town_rocks`), then `status` and `download`. **Submit is paid.** Existing request markers prevent accidental duplicates. Keep credential files and signed asset metadata out of version control.
3. Convert each downloaded `{id}_500k.spz` to `viewer/{id}_500k.ply` using `spz_to_ply.py`.
4. Run `python3 tools/splat_experiment/setup_locations.py`, then `prepare_locations.py` with NumPy available. This writes the two scene profiles, copied mesh assets, shaders, cleaned PLYs and placement metadata.
5. Open the isolated project and allow Godot imports to finish. Run `locations.tscn`. Calling `review_location()` through Godot MCP captures all eight matched views for the selected location and checks collisions.
6. Stop the interactive game before benchmarking:

```bash
python3 tools/splat_experiment/benchmark_locations.py lake_pier
python3 tools/splat_experiment/benchmark_locations.py simons_town_rocks
```

Both benchmark runners passed without Godot errors. Changed Python utilities compile and the launcher's shell syntax check passes. The main game's networking and gameplay were not changed.
