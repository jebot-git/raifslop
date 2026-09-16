# Soft environment lighting and shadows

Updated 14 September 2026. The original authored foreground source and collision manifest are preserved.

## Static scenery

All four locations now load a baked foreground GLB from `assets/models/locations/lit`. Nearby scenery has a separate, non-overlapping UV atlas; far terrain and thin vegetation retain inexpensive ordinary materials. Blender Cycles bakes 48-sample diffuse lighting and AO at 1024² per location. Separate half-float EXR atlases hold sky fill and total lighting including the sun and static shadows; an AO PNG supplies restrained contact shading. A broad 12-degree sun (25 degrees for overcast Gray Pier) produces soft static penumbras. The sky and sun passes retain indirect diffuse bounces, with albedo excluded so the original photographed surface textures can tile independently.

The runtime shader uses the baked total light without adding ambient/direct light twice. Static shadows remain in the total irradiance atlas. The dynamic shadow option and its shader branch have been removed. AO is applied gently rather than turning every seam black. Normal maps retain the original tile coordinates; baked maps use UV2. Atlas mipmaps limit shimmer in VR.

Sun energy is 0.55 / 0.30 / 0.08 / 0.40 for Lakeside, Lake Pier, Gray Pier and Bell Park respectively. Sky brightness and ambient fill are also reduced. Timber, stone and concrete normal depth is 0.28; weathered timber now has the missing photographed normal and roughness maps. Painted surfaces are nonmetallic, metals have broader highlights, and roughness floors of 0.68–0.78 suppress hot reflections. Water retains subdued sky reflection with higher roughness than before.

Rebuild each location with:

```bash
blender --background --threads 4 --python tools/bake_foregrounds.py -- lakeside
# Repeat for lake_pier, gray_pier, bell_park_pier.
```

Run Godot's editor import afterward. Keep atlas `mipmaps/generate=true` in the supplied import files. The script explicitly targets `BakedUV`; original material maps use `UVMap`. Sources with their bake setup are saved under `source/locations/*_lighting.blend`. Blender MCP was reconnected and used to inspect the source scenes and optimize EXR storage; background Cycles jobs performed the bakes. [Asset sizes and hashes](lighting_assets.json).

## Avatars

The MToon shader and one-time material policy reuse FPSloppa revision `5105fb8cfa38c76aa1d5d172af3047fe2d12ae0d`. Soft wrapped diffuse response, bounded light accumulation, a small texture-colored fill, and restrained authored emission replace harsh rim/matcap highlights. PBR/unlit VRM materials use a subdued lit fallback. Materials keep their types and references so VRM vowel/blink/color expression bindings continue working. No per-frame light queries or extra outline passes are added. [Reuse provenance](FPSLOPPA_REUSE.md).

## Moving shadows

Moving avatars always use soft contact shadows. There is no shadow setting or command-line override; legacy `graphics.cfg` values are ignored.

Soft contact shadows use one two-triangle translucent footprint per visible local/remote avatar. Each footprint is projected onto the physics floor and oriented to its normal. Unsupported water, hidden avatars and other-location avatars receive no blob. Real-time sun shadow maps are disabled; the sun still lights moving objects, and static shadows remain baked.

A blob provides grounding rather than a body/rod silhouette. It cannot reproduce shadows on walls, detailed self-shadowing, or a moving fish's shape. Baked shadows assume static scenery and the current per-location lighting preset; moving props or changing sun direction requires rebaking.

## Validation and comparison

`tests/environment_lighting.gd` passes 50 checks for baked scene loading, UV2, actual material/normal/atlas bindings, nonconstant AO and preserved avatar expressions. `tests/blob_shadows.gd` checks location collision floors, water rejection, hidden avatars and removal of the dynamic shadow setting. Existing foreground collision tests pass 29 checks; avatar tracking passes 26 checks after the MToon changes. Native Monado plus desktop multiplayer passes 13 checks, including stereo eye readback and replicated body/face/finger poses. The existing menu/ambience suite passes 31 checks. A rendered blob on/off comparison darkens 5,747 sampled floor pixels, confirming that the footprint affects the baked material.

The historical comparison below used four visible SharkPerson rigs in Lakeside and Gray Pier. Each mode warms for 90 frames, then records 120 frames; order is dynamic/blob/blob/dynamic. Results use median viewport GPU time, rendering CPU time, frame interval and Godot's draw-call monitor. Desktop runs without VSync; native stereo uses Monado's simulated HMD. Driver clocks and compositor scheduling still affect timings, so these are local comparisons rather than physical Quest performance claims.

[Four location previews](locations/lakeside_soft_lighting.png), [Gray Pier](locations/gray_pier_soft_lighting.png), [Lake Pier](locations/lake_pier_soft_lighting.png), [Bell Park](locations/bell_park_pier_soft_lighting.png).

[Desktop measurements](shadow_benchmark.json), [synthetic stereo measurements](shadow_benchmark_xr.json), [blob preview](shadow_blob.png), [dynamic preview](shadow_dynamic.png). The monitored scene draw-call count does not expose the shadow-map workload separately; GPU time is the useful comparison here. Known Godot/Monado shutdown diagnostics and some scene resource cleanup warnings remain.


### Measured results

Intel integrated ADL-N GPU, Godot 4.7.2 Mobile/Vulkan; four avatars. Values below average the two block medians for each mode.

| View | Location | Dynamic GPU ms | Blob GPU ms | GPU reduction |
| --- | --- | ---: | ---: | ---: |
| Desktop | lakeside | 13.15 | 7.62 | 42.0% |
| Desktop | gray_pier | 11.93 | 6.17 | 48.3% |
| Synthetic stereo | lakeside | 14.13 | 8.67 | 38.6% |
| Synthetic stereo | gray_pier | 14.51 | 8.25 | 43.1% |

Soft contact shadows are the sole runtime policy. Static scenery shadows remain baked. Synthetic stereo draw calls fell from 31 to 24 at Lakeside and 26 to 23 at Gray Pier in this view. Physical Quest/PCVR headset performance is not measured.
