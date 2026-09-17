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

## Shore dressing follow-up — 17 September 2026

Natural shores and both rivers now have forked driftwood and irregular scan-based
pebble patches; piers have authored mooring coils. Blender sources include baked
vertex AO. Wood grain follows the trunk, end caps have separate UVs, and the
shader supplies filtered fibre normals and roughness. Existing rope spans use
the same material treatment. Added prop lighting has a bounded diffuse response
to the relative HDR suns, avoiding clipped white wood beside baked scenery.
The custom light stage follows [Godot's spatial shader contract](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html#light-built-ins).

Older floor coils, coarse Lakeside grass/reed triangles and the primitive inland
Tidal Strand trunks are removed from runtime mesh batches. Replacement reed
cutouts are rooted below the waterline. Support timbers, rail spans, collision,
UVs and the remaining baked surfaces are preserved.

Placement reserves expanded footprints around vegetation, rocks, benches and
rails. Pebbles avoid both the driftwood and each other. The small lily patches
at Lakeside, Gray Pier and Bell Park also use separated leaves; their geometric
slits, vein shading and gentle bobbing do not use transparent billboards.
Props remain outside the central casting lane. Decorative assets add no physics
barriers. Shared meshes use at most four dressing batches per location, plus one
replacement reed batch at Lakeside; contact shadows use small local planes.

Coastal wash follows the actual shallow submerged geometry. It uses the existing
depth sample, broad filtered edges and distance fading; absent depth still leaves
the ocean opaque. This adds no full-screen pass or additional reflection capture.

Run `tests/shore_dressing.gd -- --capture` with a real renderer to inspect all ten
locations and validate ground contact, spacing, UV/tangent/AO data and removal of
old coils. Images are written under `test-results/shore-dressing/`. Rebuild the
Blender assets with `blender --background --python tools/build_shore_dressing.py`.
Small new props use their own vertex AO and local contact shading; they do not
change the existing bank geometry or require regeneration of the bank lightmaps.

Pebble deposits now have uneven clusters offset from the logs, with sparse
outliers and varied size/orientation. They no longer trace a ring around the
reserved log footprint. The final all-location GPU placement suite passes
679 checks, including decoration clearance and ground contact.

Hoek's left sand apron and submerged toe curve towards the sea outside the
playable footprint. The left seawall parallax extends to 125 degrees. Ground
and water share a photographic anchor near the shoreline and transition back
to the sky at distance. Sand blends the photograph in its opaque baked material;
a transparent next pass was being cut off by water depth, exposing a hard
triangular seam. Existing UV/lightmap coordinates and walkable elevations are
retained. `tests/hoek_transition.gd -- --capture` checks the extension, opaque
blend and travel reset, with standing, seated, left-edge and rear-left captures.

Review captures: [river dressing](locations/meadow_bend_dressing.png),
[pier rope](locations/gray_pier_dressing.png),
[lily detail](locations/lakeside_lilies.png), and
[Hoek left shoreline](locations/hoek_left_transition.png).

Lake Pier's rear basin now has animated water beneath and beside the maintenance
bridge. The old flat concrete apron is removed by triangle selection, retaining
the landing and bridge's original geometry and UVs. The photographed harbour
wall uses a vertical projection at the bridge end; its submerged skirt yields
to water. Coverage is anchored in world space for both eyes, then fades towards
the distant harbour. This uses the existing water draw and reduces apron geometry.
Compare [previous bridge](locations/lake_pier_bridge_before.png) with the
[water replacement](locations/lake_pier_bridge_water.png) and
[rear quay view](locations/lake_pier_rear_water.png).

Final native OpenXR checks pass for Hoek (11 checks, eight eye captures) and
Lake Pier (8 checks, eight eye captures), including seated and shifted views.
All-location dressing checks pass 679 assertions; lighting, locations, scenery
repairs, shore transitions, aiming grid, retrieval and absent-depth water
coverage tests pass. Synthetic OpenXR still reports its existing session-stop
and interaction-profile teardown warnings. Physical headset comfort and
standalone frame time remain device-validation work.
