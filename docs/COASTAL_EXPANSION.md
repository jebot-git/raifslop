# Secluded Cove and Tidal Strand

Two additional coastal waters extend the existing photographic/3D scene pipeline.
Open **V → Waters → Fish here** on desktop, or **right B → Waters** in VR.
There are now ten selectable locations: four inland photographs, four coastal
photographs and two procedural rivers.

| Location | Foreground | Water and atmosphere |
| --- | --- | --- |
| Secluded Cove (`secluded_beach`) | 12 × 13 m sand apron, rounded rock shoulders, rear bench and weathered rope boundaries | Sheltered morning cove, four gulls, sparse quiet surf |
| Tidal Strand (`fish_hoek_beach`) | 20 × 13 m sand apron, inland driftwood and low rope boundaries | Misty open beach, seven terns, broader surf washes |

In-game captures: [Cove facing water](locations/secluded_beach_front.jpg),
[cove rear](locations/secluded_beach_rear.jpg),
[strand facing water](locations/fish_hoek_beach_front.jpg),
[strand rear](locations/fish_hoek_beach_rear.jpg).

Both shores continue beneath the waterline. Actual sand geometry catches landing
rays beyond the flat walking proxy. The water reveals shallow sand at the contact
edge using scene depth, while the distant surf remains photographic. Seaward
casting space is clear; side and rear ropes mark the protected walking area.
Generated grass uses two crossed cards per clump; generated kelp/shell wrack lies
on the sand. Neither adds collision to the walking or casting path.

## Assets

- Native 8192 × 4096 CC0 panoramas by Greg Zaal from
  [Secluded Beach](https://polyhaven.com/a/secluded_beach) and
  [Fish Hoek Beach](https://polyhaven.com/a/fish_hoek_beach), with backplates
  credited to Rico Cilliers. [Verified downloads](locations/coastal_expansion_sources.json).
- [Rock Boulder Dry](https://polyhaven.com/a/rock_boulder_dry), CC0 tileable 1K
  photographed PBR maps by Dimitrios Savva and Rico Cilliers.
  [Verified maps](locations/coastal_expansion_material.json).
- Original built-in imagegen [dune grass](../assets/environment/shore_details/coastal_dune_grass.png)
  and [kelp wrack](../assets/environment/shore_details/coastal_wrack.png).
  [Exact prompts](locations/coastal_expansion_prompts.json).
- Separate authored GLBs, collision proxies and 1024² sky, irradiance and AO maps.
  Sun direction, color and energy are measured from each retained HDR panorama.
- Two deterministic 128-second stereo surf mixes from the retained CC0 recordings;
  credits are in [source/audio/CREDITS.md](../source/audio/CREDITS.md).

[Runtime asset sizes and SHA-256 checksums](locations/coastal_expansion_assets.json)
cover the new panoramas, previews, GLBs, extracted textures, lightmaps, audio and
generated cutouts. They total approximately 238 MB before export compression,
mostly the two native HDR panoramas. Foregrounds contain 10,412 and 10,860 triangles.

The original photographic sites inspire these artistic layouts. They are not
surveyed reconstructions. The panoramas retain rotational scenery without
positional parallax; the foreground meshes, vegetation, birds and water have
actual 3D depth. Fish rosters are authored gameplay, not ecological surveys.

## Rebuild

Run from the repository root with Blender on PATH:

```sh
blender --background --factory-startup -noaudio --python tools/build_coastal_expansion.py
blender --background --factory-startup -noaudio --python tools/bake_foregrounds.py -- secluded_beach
blender --background --factory-startup -noaudio --python tools/bake_foregrounds.py -- fish_hoek_beach
blender --background --factory-startup -noaudio --python tools/prepare_locations.py
python tools/build_coastal_ambience.py -- secluded_beach fish_hoek_beach
godot --headless --path . --xr-mode off --editor --import
```

The expansion builder merges its two manifest entries and writes
`source/coastal_expansion.blend`; it preserves the older source libraries.
The bake command also performs panorama-derived lighting calibration. Runtime
assets and source files are retained locally; rebuilding needs no downloads.

## Validation

`tests/coastal_locations.gd` covers all four coastal locations, supported walking
and shoreline landing rays, marine casting, ambience, generated details and water
preset resets. `-- --capture` saves standing, seated, rear, edge and foundation
views under `test-results/coastal-locations/`.

The location, foreground, marine bait, species, lighting and wildlife suites cover
the expanded catalogue. Physical headset comfort and device performance require
hardware acceptance; desktop views do not establish those results.

Verified on 16 September 2026: location travel/persistence (1,250 assertions),
walking/edge collision (53), location species/bait (232), coastal travel/landing,
marine bait switching, baked lighting and wildlife all passed. Standing, seated,
rear, edge and foundation captures were inspected using the Mobile renderer.
The older location test now reels to complete its catch fixture, matching the
current landing rule; the walking test measures progress from each spawn instead
of requiring every pier to extend past the same world coordinate. The lighting
suite still emits the documented resource-cleanup diagnostics after passing.
