# Shore vegetation and river cutout review

## Implemented scope

- **Lakeside:** 16 small shrub clumps along the outer grass banks and rear boundary. They replace the separate coarse grass mesh. Soft grass/soil patches blend their bases into the existing ground.
- **Gray Pier:** 14 reed/sedge clumps beside the pier and rear landing replace the coarse reed mesh and its detached seed heads, while preserving submerged pier supports. Dry clumps receive soft ground-cover patches; water reeds extend below the water surface.
- **Meadow Bend and Boulder Run:** shrubs now use three intersecting planes at 60-degree intervals; distant alders use two perpendicular planes. The previous single planes lost their silhouette from oblique views.

Vegetation stays fixed in the world, uses real transparent texture edges, mipmaps, small wind motion and varied scale/orientation. Consistent photographic shading avoids black backfaces and obvious lighting seams between crossed planes. Linear color multipliers are tuned to each panorama: Lakeside .45, Gray Pier .25, Meadow Bend .4, Boulder Run .22, before per-clump variation. Cutout texture wrapping is disabled; alpha-border correction and mipmaps remain enabled to prevent edge fringes. These remain lightweight cutouts; very close inspection can reveal their planes.

## Grounding

River terrain height is sampled using the same grid and triangle interpolation as the collision surface. Each shrub is anchored to the minimum height sampled around its footprint, with another 8% of plant height buried to conceal transparent root margins. Near-bank clumps are moved inland enough to keep their whole footprint supported. This intentionally buries more of the uphill side instead of leaving the downhill side in air.

No decorative plant adds collision. Existing paths and fishing collision remain intact. Shore vegetation is one instanced batch per location (six triangles per clump); rivers retain two vegetation batches (six triangles per shrub and four per alder). Soft shoreline patches add one quad per dry clump. Mobile headset fill rate and stereo appearance still need an on-device check.

## Assets

The reed cutout is an original built-in imagegen asset, saved unchanged with its alpha channel at `assets/environment/shore_details/lakeshore_reeds.png`. [Exact prompt, generation mode and saved path](shore_cutout_prompt.json). [Source checksum](shore_cutout_asset.json).

Shrub and ground textures reuse the original [river assets and prompts](FLY_FISHING.md). Existing panorama and terrain credits remain in `ASSET_CREDITS.md`.

## Validation

- `tests/shore_transitions.gd`: all four locations load; dry shore plants have supporting ground; decorative plants add no collision; river mesh arrays contain the expected crossed geometry; 16 collision rays around every river shrub footprint confirm bank support and buried bases.
- `tests/fly_fishing.gd`: fly-fishing regression checks pass.
- Texture-edge inspection found no white background in transparent pixels. The stray white line in early captures was the hidden rod's retained fishing line; the scenery test now clears it. No obvious white cutout fringes or bright card intersections remain in the reviewed views.
- Vulkan captures from standing, seated and oblique views are under `test-results/transition-{location}-{view}.png`.

## Simon's Town rear rock trial

Two low granite cutout formations soften portions of the bare rear strip while leaving the central photographed boulders visible. They sit beyond the rear rope, at different depths, with their image margins buried beneath the modeled mainland. Each card uses eight shallow curved segments (16 triangles), avoiding the conspicuous opaque intersections that crossed rock billboards would introduce. One instanced draw covers both formations. Wind and dynamic shadows are disabled; linear exposure .32 matches the restrained coastal lighting. Existing foreground rocks, collision and rope remain in place.

The initial three-clump trial was too bright and repetitive; the retained two-clump layout is a modest improvement from the playable terrace. It is still a photographic approximation: extreme close/side views reveal limited depth, so these should remain beyond the barrier rather than replace nearby modeled boulders. No headset stereo/performance claim is made.

Original built-in imagegen asset: `assets/environment/shore_details/simons_granite.png`, preserved with generated alpha. [Exact prompt and mode](simons_rock_prompt.json), [original path and checksum](simons_rock_asset.json).

`tests/simons_rear_render.gd` captures standing, seated, left, right and rear-barrier views; `--before` hides the new formations for a matched comparison. Results are `test-results/simons-rear-{before|after}-{view}.png`. Visual checks cover base contact, brightness, silhouette edges and card intersections; no obvious white border or floating base was seen in these desktop renders.
