# Culling, lighting and rear-connection refinement

See the subsequent [edge cleanup](GAUSSIAN_SPLAT_EDGES.md) for the current masks, water coverage and screenshots.

16 September 2026. This updates the [two-location prototype](GAUSSIAN_SPLAT_LOCATIONS.md) after the user reported splats disappearing while moving, flat Simons lighting and Lake Pier's disconnected rear. All changes remain in the isolated experiment. No new cloud generation was used.

## Disappearing splats: reproduced and fixed

The panorama material used `depth_draw_never`. On this Mobile renderer path it could draw over the transparent splats as the camera changed position or direction. Hiding the panorama restored the splats, even with their visibility flag already true. Changing the panorama to `depth_draw_opaque` restored them at the same camera pose and kept the foreground's depth occlusion intact. No GDGS culling settings or walkable exclusion masks were weakened.

The regression deliberately switches between the old and corrected panorama shaders, at eight poses per location. It compares splats enabled/disabled at each pose, using reduced screenshots and a color-difference threshold. The rear-origin view must recover over 300 affected pixels with the fix. Both locations pass. Animated water introduces a few pixels of measurement noise; the recovered splat regions are much larger. Empty open-water views are not required to contain splats.

| Reproduced rear angle | Before | Fixed |
|---|---|---|
| Lake Pier | [old draw order](splats/refined_lake_pier_cull_before.png) | [corrected](splats/refined_lake_pier_cull_fixed.png) |
| Simons Rocks | [old draw order](splats/refined_simons_town_rocks_cull_before.png) | [corrected](splats/refined_simons_town_rocks_cull_fixed.png) |

Reports: [Lake](splats/refined_lake_pier_culling.json), [Simons](splats/refined_simons_town_rocks_culling.json). These checks cover the captured class of angle-dependent disappearance, not every possible renderer artifact.

## Simons: site-specific HDR bake

`rebake_simons.py` loads the existing lighting scene and its existing `BakedUV` atlas. Blender Cycles bakes diffuse direct/indirect illumination from the original `simons_town_rocks_8k.hdr`, with the artificial lights disabled, 48 samples and a 1024² floating-point irradiance map. Original meshes, material textures, UVs, AO and collision remain intact. The HDR retains the concentrated sunlight needed for directional shadows.

The environment vector rotates −90° around Blender Z to align Blender +Y with Godot −Z and the viewer's centered panorama. This follows [Cycles' equirectangular coordinate mapping](https://github.com/blender/blender/blob/main/intern/cycles/kernel/camera/projection.h). The panorama itself has no longitude roll for Simons. The resulting EXR is loaded only by the prototype; it adds no runtime shadow lights.

The new bake produces warm illuminated rock faces, darker shaded faces, and directional contact shadows from the foreground geometry. Photographic cutouts retain their original appearance. Generated rocks still contain reconstruction artifacts and do not perfectly match every authored texture.

| Lighting comparison | Original bake | HDR bake |
|---|---|---|
| Sea-facing floor and rocks | [original](splats/refined_simons_light_old_0.png) | [HDR](splats/refined_simons_light_hdr_0.png) |
| Side | [original](splats/refined_simons_light_old_1.png) | [HDR](splats/refined_simons_light_hdr_1.png) |
| Rear bench and terrain | [original](splats/refined_simons_light_old_2.png) | [HDR](splats/refined_simons_light_hdr_2.png) |

Press **L** in Simons to compare the two bakes. The new HDR bake is the default. [Bake metadata](splats/refined_simons_rebake.json).

## Lake Pier: rear attachment

A concrete maintenance landing immediately behind the existing rear fence joins a narrow raised gangway to the generated marina around world Z ≈ 11 m. Piles extend below the water and side rails define the connection. The added mesh starts at the rear floor boundary and is decorative, with no new walkable collision. The bench, fence, original floor and fittings remain in place.

[Initial rear view](splats/lake_pier_hybrid_1.png) → [refined rear connection](splats/refined_lake_pier_hybrid_1.png).

The fix removes the isolated-platform gap and stabilizes the marina's visibility. Fragmented generated railings and some duplicated photographic structures are still visible; this is a prototype connection, not a surveyed reconstruction.

## Validation and performance

Both location validations exit successfully, with no Godot errors. All floor rays and side-barrier capsule sweeps pass. Simons retains 17 collision proxies and six rock cards; Lake retains five proxies and adds only the decorative rear connection. Splat counts and cleanup masks are unchanged: 10,566 / 19,821 points, with zero finite-support overlap into the authored walkable footprints.

| 1280×720 desktop mono, Intel ADL-N | Lake Pier | Simons Rocks |
|---|---:|---:|
| Wall frame median / p95 | 4.694 / 6.983 ms | 3.831 / 6.221 ms |
| GPU median / p95 | 3.802 / 4.361 ms | 3.224 / 3.603 ms |
| Reported rendering memory | 119.3 MiB | 140.1 MiB |

Each process measured 600 frames after 120 warmup frames, with other prototype games closed. This is the existing desktop benchmark, not a new headset measurement. [Lake metrics](splats/refined_lake_pier_metrics.json), [Simons metrics](splats/refined_simons_town_rocks_metrics.json).

## Run and reproduce

```bash
./tools/splat_experiment/run.sh --location=simons_town_rocks
# 1/2 switch location; B toggles splats; L compares lighting at Simons.
```

P now saves a JSON pose alongside every location screenshot, including splat/water visibility and the selected lighting, so future reports can be replayed without guessing the view.

```bash
/home/blux/blender-5.2.1-linux-x64/blender --background --python tools/splat_experiment/rebake_simons.py
python3 tools/splat_experiment/setup_locations.py
# Allow Godot to import the EXR, then close interactive prototype windows.
python3 tools/splat_experiment/benchmark_locations.py lake_pier --validate
python3 tools/splat_experiment/benchmark_locations.py simons_town_rocks --validate
python3 tools/splat_experiment/benchmark_locations.py lake_pier
python3 tools/splat_experiment/benchmark_locations.py simons_town_rocks
```

Validation captures matched views, lighting comparisons for Simons, draw-order comparisons, and collision reports. Assets remain in ignored `test-results/splat-experiment/viewer`; compact evidence is retained here. The main game was not modified.
