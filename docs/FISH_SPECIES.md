# Freshwater species update — 14 September 2026

Four real species were added to the original perch, carp and pike. Names and identifying traits were checked against the sources below. Reference lengths and weights are representative authored values; bait assignment and fight power are gameplay parameters.

| Species | Visual traits represented | Reference |
|---|---|---|
| Common roach — *Rutilus rutilus* | Silver scaled flanks, reddish fins and iris, forward-facing mouth | [Inland Fisheries Ireland](https://www.fisheriesireland.ie/fish-species/roach-rutilus-rutilus) |
| Tench — *Tinca tinca* | Stocky olive body, small reddish eyes, fine scales, small mouth barbels and broad tail | [Inland Fisheries Ireland](https://www.fisheriesireland.ie/fish-species/tench-tinca-tinca), [FishBase](https://fishbase.se/summary/Tinca-tinca.html) |
| Common bream — *Abramis brama* | Deep, compressed body, dark fins, long anal fin, downward mouth | [Inland Fisheries Ireland](https://www.fisheriesireland.ie/fish-species/bream-abramis-brama), [FishBase](https://www.fishbase.se/summary/abramis-brama.html) |
| Zander — *Sander lucioperca* | Elongated body, olive bars, pale belly, two separated dorsal fins | [Canal & River Trust](https://canalrivertrust.org.uk/things-to-do/fishing/caring-for-our-fish/invasive-and-non-native-fish/zander), [FishBase](https://www.fishbase.org/summary/Sander_lucioperca.html) |

## Realistic art

The new fish use detailed skin textures over modest mesh counts. Roach and tench have authored 3D bodies and separate traced fin meshes, using generated photographic-style albedo images. The bream and zander are licensed textured assets by Nullified, imported through Blender MCP and optimized. Full credits are in [ASSET_CREDITS.md](../ASSET_CREDITS.md); exact license metadata is retained in `fish_asset_licenses.json`.

These are game models, not verified scans. The generated textures are not photographs of actual specimens. Side projection on roach/tench mirrors the flank texture onto the opposite side and stretches it around the back and belly. Fins are thin meshes; there is no skeletal swimming animation or species ecology simulation.

- `assets/models/fish/{roach,tench,bream,zander}.glb`: self-contained Y-up exports, approximately one metre along X; runtime scales to the caught length. Textures are embedded, so Blender and external services are not required to play.
- `source/textures/fish/{roach,tench}_albedo.png`: retained 1536 × 1024 generated texture sources. Built-in image generation was used; prompts are in [FISH_TEXTURE_PROMPTS.md](FISH_TEXTURE_PROMPTS.md).
- `source/fish_species.blend`: optimized models, packed textures and gallery scene. Excluded from Godot import by `source/.gdignore`.
- `tools/build_fish_assets.py`: reproduces the authored fish and gallery. On a fresh Blender session it imports the retained bream/zander GLBs. For a fresh downloaded-source build, use the credited Sketchfab UIDs and name their roots `Downloaded_bream` / `Downloaded_zander`; the script normalizes and optimizes them.
- `docs/fish_species.png`: Blender asset gallery at equal reference length, for comparing forms. This is an asset preview.
- `docs/zander_catch.png`: Godot Mobile/Vulkan catch screenshot from the integration test.

Rebuild in Blender MCP with `runpy.run_path(...)`, or:

```bash
blender --background --factory-startup -noaudio --python tools/build_fish_assets.py
```

The script creates a separate authoring scene. Rebuilding from a clean Blender process keeps unrelated open scenes out of the saved source file.

## Integration

`fishing_session.gd` retains the original three indices and journal fields, appends the four species, and selects from `species_for_bait()` at the end of each cast. This removes the old assumption that a bait index is also the fish index. Desktop and VR bait hints expose the pools. Each new species has a GLB path and a small fight-power adjustment; existing species retain their previous fight parameters.

Existing journal records load unchanged. New records include scientific name, randomized length and size-related weight. Fishing remains a local simulation.

## Verification

`tests/run_tests.gd`: 78 checks covering existing fishing/reeling behaviour, bait-pool reachability, maximum-distance fights for all seven species, bounded size, length/weight consistency, single catch entries, JSON round trips and release.

`tests/fish_species.gd`: 36 checks using the actual main scene for model replacement, finite bounds, orientation, length scaling, UV-mapped skin textures and journal save/load. Use a separate `XDG_DATA_HOME` to protect personal saves. Run without `--headless` and append `-- --capture` for the rendered catch screenshot and one additional capture check.

The existing avatar/locomotion suite also passes 24 checks. Physical headset appearance and performance remain untested.

## Twelve-species catalogue expansion

Five further species and distinct ten-species location rosters are documented in [location species and bait](LOCATION_SPECIES.md), including sources, new model gallery and six-bait compatibility.

## Catch motion and fin repair — 15 September 2026

Caught fish make a short, low-amplitude body/tail twitch every 2.8–5.2 seconds, with a still interval between bursts. Two catch-local mesh shapes deform the body and fins together; the head and mouth remain fixed at the hand/string attachment. Each shape limits lateral bend to 1.8% of fish length and preserves mouth-to-tail extent. Shared imported meshes remain unchanged; only the displayed catch gets animation shapes.

The roach and tench's detached paired fins now root into the skin. Those two fish and the thirteen photographic reconstructions have thin extruded membranes so their dorsal fins do not disappear edge-on. Small disconnected tracing speckles were removed. Retained Blender sources and both build scripts include the same root repair; downloaded perch, bream and zander geometry is preserved.

The enforced avatar **body** height is 1.70 m; the 1.65 m constant is its **eye** reference. Catch sizing already uses journal centimetres × 0.01 in that same metre-based world. A 58 cm carp is therefore 0.58 m, or 34.1% of avatar height. No additional scale multiplier was needed.

Validation: `tests/catch_twitch.gd` checks all eighteen species, journal lengths, bounded deformation, fixed heads, avatar proportions, XR scale independence and rod attachment. `tests/fish_species.gd` checks imported materials and geometry. `tools/validate_fish_fins.py` checks roots, bounds and dorsal silhouettes in all fifteen repaired assets through Blender; `tests/catch_twitch_render.gd` captures neutral and bent poses beside 10 cm ruler divisions. These are desktop/simulated checks, not physical-headset validation.
