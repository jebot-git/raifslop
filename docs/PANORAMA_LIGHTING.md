# Panorama lighting and rear scenery

Lake Pier uses the authored maintenance bridge and fishing-plan billboard from
the isolated scenery prototype, now in the game's baked foreground. The bridge
stays beyond the existing rear fence. Its concrete, supports, rails, billboard
frame and printed face have atlas space in `lake_pier.glb`. The billboard is
60 cm farther toward open water and 15 cm closer to the pier to cover the nearby
panorama seam. Its Korean copy uses heavy Noto Sans CJK KR Bold outlines in the
SVG, so every renderer displays the glyphs and their baked lighting consistently.
`tools/build_fishing_poster.py` regenerates the lettering with fonttools and the
locally installed Noto font; no font file is needed in the game.

Lake Pier and Coastal Rocks have a connected rear photographic mesh with five
depth bands. The lower apron, middle ground and approach to the horizon occupy progressively
larger radii. The mesh ends below the horizon to keep towers and masts straight. The panorama is projected from the original arrival viewpoint,
with continuous sampling across band boundaries and a feathered outer perimeter.
This reduces the metres of geometry covered by each degree of near-horizon image,
which previously stretched scenery along shallow ground. It is an approximation
of depth from a single panorama: substantial movement can still reveal distortion.
The original rock formations and playable collision are retained.

## Rebuild

Run from the project root with Blender:

```sh
blender --background --factory-startup --python tools/bake_panorama_lighting.py
```

Pass IDs after `--` to rebuild selected locations. The tool reads the existing
lighting scenes, preserving UV2 except when adding Lake Pier's structures. It
measures the brightest upper-hemisphere lobe in the original 8K HDR, integrates
its excess radiance using solid-angle weights, and accounts for the game's sky
yaw and energy. A local sky estimate replaces the extracted solar cap. Cycles
bakes diffuse sky and total irradiance separately at 1024² / 48 samples. Sunlight
is represented only once, by the measured directional light. AO is regenerated
when Lake Pier's atlas changes. Existing material colour and normal maps remain.

`assets/textures/lighting/panorama_lighting.json` records the inferred world-space
direction, linear colour, energy, cap size and source panorama. The game reads
this same data for lighting moving objects. All export presets include it.
Energy is relative to the HDR's exposure, not a calibrated real-world lux reading.
Overcast Gray Pier uses a weak, broad lobe rather than an invented sharp sun.

Six photographic foregrounds are rebaked. The river maps share the measured sun
of their source panoramas (Lakeside and Bell Park Pier), with a separate
[HDR bank and vegetation-shadow bake](LOCATION_IMMERSION.md). Retained Blender scenes pack a compact diffuse
sky; solar measurement always uses the original HDR on a fresh rebuild.

`tools/bake_foregrounds.py` also calls the panorama bake after rebuilding an atlas
from base authoring geometry, so it restores the added Lake Pier details.

## Verification

`tests/rear_scenery.gd` checks depth ordering, reduced near-horizon projection
stretch, baked bridge/print geometry, UV2, baked shadows, and the agreement between
Godot's light basis and the HDR direction. Run with `-- --capture` for arrival,
left/right rear, poster and front views; add `--compare` to capture both versions in one run, or `--before` to hide the
depth mesh for an otherwise matching comparison. Images go to `test-results/rear-scenery/`.
Existing location, coastal and environment-lighting suites cover travel,
foreground loading, contact occlusion and fishing-area support.

Validation completed: location travel (1,231 checks), coastal support/travel,
environment lighting, and rear scenery suites all passed. Final rendered checks
include the moved Korean billboard and both revised rear meshes.

- [Korean billboard](locations/lake_pier_korean_poster.png)
- [Lake Pier rear](locations/lake_pier_rear_layers.png)
- [Coastal Rocks rear](locations/coastal_rocks_rear_layers.png)
