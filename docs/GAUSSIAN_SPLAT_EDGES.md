# Hybrid edge cleanup

16 September 2026. Follow-up to the [lighting and culling refinement](GAUSSIAN_SPLAT_REFINEMENT.md). The five user screenshots were replayed using their saved camera positions and rotations. The original screenshots are retained alongside the final captures below.

| Reported issue | Before | After |
|---|---|---|
| Simons splat patch in left authored rocks | [capture](splats/edges_simons_left_before.png) | [cleaned](splats/edges_simons_left_after.png) |
| Simons exposed ground corner | [capture](splats/edges_simons_corner_before.png) | [covered](splats/edges_simons_corner_after.png) |
| Lake front-left duplicate splats | [capture](splats/edges_lake_front_left_before.png) | [removed](splats/edges_lake_front_left_after.png) |
| Lake photographed structures beneath rear bridge | [capture](splats/edges_lake_rear_before.png) | [extended water](splats/edges_lake_rear_after.png) |
| Lake right-side double representation | [capture](splats/edges_lake_right_before.png) | [splat foreground and billboard](splats/edges_lake_right_after.png) |

## Changes

Simons excludes splat support intersecting the authored left boulder row. The terrain apron has rounded outer corners, and two additional photographic rock cards cover the exposed rear corners. The original six cards, authored floor, rock meshes, HDR bake, bench and barriers remain. The mask still protects the complete walkable floor.

Lake removes the generated front-left markers and fragments, keeping their panorama counterparts. The nearby right-hand photographed jetty is suppressed in the background so the splats provide its geometry. A shared background sampling function fills that sector from open lake and neighboring sky; it is used by both the panosphere and water. Feathered boundaries retain the surrounding distant panorama. The reconstructed pier still has thin fragmented splats, and the background transition remains soft near the distant shoreline.

Opaque shader water now extends to rear Z=34 m, with a 2 m boundary blend, covering the old photographed platform, rails and supports below the bridge and marina splats. Its distance blend moves from 12–30 m to 24–40 m for Lake only. A fixed authored harbour information billboard sits at X≈3.2 m, just beyond the right fence at X=2.5 m. It masks part of the nearby splat underside without changing the playable area or fence.

Final splat counts: **9,486 Lake** (previously 10,566), **15,361 Simons** (previously 19,821). Both retain zero conservative finite-support overlap into the walkable footprints; minimum support clearance remains approximately 24.7–24.9 cm. Original 500k exports remain intact.

## Validation

Both visual validation runs pass without Godot errors. Floor rays and side-barrier sweeps pass; collision counts remain 5 and 17. Simons reports eight rock cards; Lake reports the rear connection and right billboard.

The culling regression now isolates panorama/splat draw order by hiding water and disabling the location-specific background mask during its comparison, then restores both. This keeps the test independent of intentional water occlusion and background cleanup. Its original >300 recovered-pixel threshold is unchanged: Lake recovers 1,105 pixels and Simons 435 in the rear-origin test. The full-composite inspection screenshots above are captured separately with water and cleanup enabled.

Reports: [Lake cleanup](splats/edges_lake_pier_cleanup.json), [Simons cleanup](splats/edges_simons_town_rocks_cleanup.json), [Lake culling](splats/edges_lake_pier_culling.json), [Simons culling](splats/edges_simons_town_rocks_culling.json).

## Desktop performance

1280×720 mono on Intel ADL-N, 120 warmup frames and 600 sampled frames; captures excluded from timing. These are desktop measurements, not a new headset test.

| Location | Wall median / p95 | GPU median / p95 |
|---|---:|---:|
| lake_pier | 4.821 / 7.376 ms | 3.938 / 4.334 ms |
| simons_town_rocks | 4.651 / 8.195 ms | 3.466 / 3.919 ms |

[Lake metrics](splats/edges_lake_pier_metrics.json), [Simons metrics](splats/edges_simons_town_rocks_metrics.json).

## Reproduce

```bash
python3 tools/splat_experiment/setup_locations.py
/home/blux/blender-5.2.1-linux-x64/5.2/python/bin/python3.13 tools/splat_experiment/prepare_locations.py
# Allow the isolated Godot editor to finish importing the updated PLYs.
python3 tools/splat_experiment/benchmark_locations.py lake_pier --validate
python3 tools/splat_experiment/benchmark_locations.py simons_town_rocks --validate
./tools/splat_experiment/run.sh
```

Validation replays the five saved inspection poses when those local JSONs are present. The prepared local prototype includes them. Controls remain 1/2 for location, B for splats, L for Simons lighting, WASD/right mouse for movement/look, and P for screenshot plus pose.

All work is confined to the isolated prototype and its preparation tools. No new cloud generation or changes to the main game were made.
