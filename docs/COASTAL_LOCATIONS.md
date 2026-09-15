# Coastal scenery trials

Two additional selectable locations use the established photographed-panorama pipeline:

| Location | Foreground | Atmosphere |
| --- | --- | --- |
| Coastal Rocks | 9 × 10 m stone terrace, boulder margin, sagging rope on weathered posts and a bench | Clear daylight, sheltered rocky bay, gulls and restrained surf |
| Sunrise Beach | 18 × 15 m walkable sand shore, sloping underwater margin and low inland dunes | Soft dawn, sandy shoreline, terns and spaced surf washes |

Both use native 8192 × 4096 CC0 Poly Haven HDRIs, 768 × 384 AgX menu previews, tiling photographed PBR materials, separate 1024² sky/irradiance/AO atlases, collision proxies, per-location lighting and shared sky/water grading. Sources and verified download checksums are in [coastal_sources.json](locations/coastal_sources.json).

The playable ground remains at world Y=0, consistent with the 170 cm avatar. The rock terrace extends to Y=-1.3 m and the beach slope to Y=-1.2 m, beneath the -0.35 m waterline. Foreground terrain fades into the panorama outside the playable footprint; coastal rocks and barrier posts remain opaque. Coastal Rocks limits water animation to a feathered open-water region, preserving photographed rocks. Sunrise Beach meets local water on a modeled sand slope and blends into the distant photographed surf. A CC0 Aerial Beach 01 sand texture supplies the ground detail. The rocks at Simon’s Town reach Y=-1.2 m and sit outside the rope barrier’s collision envelopes with a checked clearance. The rope sags between weathered posts for a softer shoreline boundary. The view opens seaward at panorama yaw 180°.

These are artistic layouts, not surveyed reconstructions. Panoramas have rotational detail but no positional parallax. The beach's distant breaking surf is photographed; local water uses the existing restrained ripple shader. Real recorded wave excerpts form quiet, seam-continuous 128-second ambience beds. Coastal birds use animated lightweight 3D meshes, with no inland insect swarm.

## Catch roster

Both locations have marine-only catch rosters and six saltwater bait choices. Coastal Rocks includes resident reef fish; Sunrise Beach includes white steenbras and harder mullet. Catches retain the selected location. See [marine fish](MARINE_FISH.md) for species, models and bait details.

## Rebuild

Run from the repository root, substituting your Blender executable:

```sh
blender --background --factory-startup -noaudio --python tools/build_coastal_foregrounds.py
blender --background --factory-startup -noaudio --python tools/bake_foregrounds.py -- simons_town_rocks
blender --background --factory-startup -noaudio --python tools/bake_foregrounds.py -- blouberg_sunrise_2
blender --background --factory-startup -noaudio --python tools/prepare_locations.py
blender --background --factory-startup -noaudio --python tools/build_coastal_ambience.py
```

The coastal builder merges its manifest entries and retains its own `source/coastal_foregrounds.blend`, preserving the existing inland source library. Baked sources are retained in `source/locations/`. Preview generation reads the retained HDR originals; no network connection is required for rebuilding.

## Validation

`tests/coastal_locations.gd` checks travel, supported casting positions, submerged foundations and beach margin, panorama masks, surf loading and every bait. Run with `-- --capture` in the Mobile renderer for standing, seated, rear, edge and foundation images under `test-results/coastal-locations/`. Existing location, foreground, lighting, wildlife and bait suites also include both additions. Physical headset inspection remains necessary for final comfort and visual approval.

`tools/validate_coastal_geometry.py` verifies every rock component clears every barrier envelope and that Sunrise contains a continuous dry sand area and submerged margin, with only sand and grass geometry.
