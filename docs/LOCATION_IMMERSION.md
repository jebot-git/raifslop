# VR location materials and river scenery

The river pass adds measured HDR illumination and AO to the modeled banks,
scanned stone silhouettes, wet margins, normal-mapped ground, shoreline reeds
and a second treeline. The treeline covers the low panorama horizon with
geometry at two depths, including from seated and sideways viewpoints.
Existing Lake Pier and Coastal Rocks parallax cascades remain in use.

[Meadow Bend](locations/meadow_bend_immersion.png) ·
[Boulder Run](locations/boulder_run_immersion.png)

Both river banks use 1024² half-float irradiance and linear AO atlases. Cycles
bakes the actual runtime terrain, rock transforms and alpha-textured vegetation
against the retained Lakeside/Bell Park measured HDR worlds. Direct sun is
included once. The runtime suppresses additional diffuse lighting inside the
baked region and feathers back to runtime lighting outside its central
96 × 70 metre footprint. Terrain collision and the dry-bank boundary are retained.

Grass blends two texture orientations and broad color variation. Gravel and
grass use separate normals; wet gravel/stone darkens and becomes smoother at
the waterline. A 508-face closed proxy of Poly Haven's Boulder 01 replaces the
rounded primitive rocks. The 30/65 shoreline stones share one MultiMesh draw;
the three large Boulder Run obstacles retain individual collision. Reeds add
one instanced draw with a clear central casting gap. Crossed cutouts remain
fixed in world space, rather than independently turning toward each VR eye.

All photographic foregrounds now use their sky/total-light separation to let
normal detail modulate the baked sunlight within a bounded 0.75–1.25 range.
AO and restrained view-dependent sheen preserve the original HDR exposure.
Panorama sharpening fades when the source pixels become subpixel, reducing
ringing in the sky, projected ground and water. Filmic tone mapping is retained;
there are no added full-screen passes, motion blur, screen-space reflections,
SSAO or real-time scenery shadow maps.

Water adds two mipmapped capillary-wave samples fading with distance. Rivers
also have a world-space shallow-gravel approximation, restrained caustic color,
bank-edge flecks and downstream foam ribbons at the three existing obstacles.
An inexpensive bank reflection proxy reduces reflections of the source HDR's
unrelated lake shore. This is an approximation, not planar reflections or a
fluid simulation; it does not reflect individual trees or players. The existing
photographic water masks and shallow hooked-fish window are preserved.

## Sources and rebuild

The scanned rock was prepared/exported through Blender MCP from the retained
CC0 Poly Haven asset. Its editable source and 512² AO bake are in
`source/river_assets.blend`. Existing licensed grass/gravel textures and authored
foliage cutouts are reused; no new external license dependency was introduced.
See [asset credits](../ASSET_CREDITS.md).

```sh
godot --path . --xr-mode off --script res://tools/export_river_bake.gd
blender --background --python tools/bake_river_lighting.py
godot --headless --editor --path . --import --quit
```

The geometry exporter needs a real renderer: Godot's dummy renderer does not
retain MultiMesh transforms for readback. Both stages reject a collapsed layout.
The exporter records the exact deterministic meshes in
`source/{meadow_bend,boulder_run}_bake_geometry.json`. Blender retains each bake
scene beside those records. Rebuild after changing terrain or plant placement.
Runtime irradiance files live under `assets/textures/lighting/`, using the
existing lossless HDR export policy on desktop and Android. Keep mipmaps enabled
and avoid automatic VRAM compression for those lightmaps.

## Validation

Run `tests/location_immersion.gd` with `-- --capture` for standing, seated and
sideways views of all ten environments, including both rivers and the release
0.1.10 coastal locations. With an OpenXR
runtime it checks and saves both native eye buffers; without XR it captures
the display view. Output is under ignored `test-results/immersion/`.

Native stereo checks use the simulated Monado runtime. They establish shader
compatibility and separate-eye output, not physical-headset comfort or sustained
Quest/Pico performance. Existing OpenXR teardown diagnostics persist. Stereo
PNGs are inspection conversions of pre-tonemap buffers; EXRs retain the raw data.

Regression coverage includes fly fishing, grounded shoreline vegetation,
location travel, environment lighting, lossless HDR export, shore retrieval
and water wildlife. The older location-journal fixture was updated to supply
the active retrieve and cleared counter required by the latest landing rules.

The integration is based directly on release 0.1.10. Its coastal shallow-depth
coverage, ground metadata, avatar recovery and transfer fixes are retained.
Location travel passes 1,250 checks; water aiming passes 742, and fishing comfort
passes 1,733. Lighting, scenery repairs, shore retrieval, fly fishing, holstering,
fishing updates and avatar recovery/image-failure suites pass. The GPU coastal
water test confirms coverage even when opaque depth is absent.

The shared float uses one cached lathed mesh and opaque material: ivory/orange
lacquer, a brass collar and graphite keel. Local and remote anglers use the same
geometry. Protocol 5 carries bobber/bait visibility and interpolated bait
positions, including the selected freshwater, marine or fly model. Tackle tests
pass 591 checks; real dedicated/ad-hoc ENet tests include visible tackle and late
joiners. Servers and clients must update together.

Native OpenXR catch/casting tests pass 57 checks. Hanging catches permit stick
locomotion; only hand inspection reserves the sticks for fish rotation. Offhand
trigger while gripping releases the catch, with the existing face buttons
retained. Synthetic casting fixtures now aim down at water and perform the
release's required overhead backswing. Catch captures go to `test-results/xr/`.

All-ten-environment native stereo validation passes 213 checks, with sixty eye
captures across thirty standing, seated and side viewpoints. Physical headset
comfort and sustained standalone GPU performance still require device testing.
