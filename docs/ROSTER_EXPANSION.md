# Six species across the fishing styles

The roster grows from 32 to **38 species**. Six original textured fish models,
new Fish Guide entries and silhouettes, habitat pools and bait preferences cover
classic bait, river fly, cage feeder and active lure fishing. Existing IDs 0–31,
scientific identities and saved personal bests remain unchanged. New IDs are
appended, 32–37.

| ID | Species | Typical catch | Primary gameplay presentations | Added waters |
| --- | --- | --- | --- | --- |
| 32 | Silver bream (*Blicca bjoerkna*) | 25 cm / 0.24 kg | Classic and feeder: worm, corn, maggots, bread | All four lakes |
| 33 | Ruffe (*Gymnocephalus cernua*) | 15 cm / 0.04 kg | Classic and feeder: worm, maggots | Lakeside, Lake Pier, Gray Pier, Meadow Bend |
| 34 | Ide (*Leuciscus idus*) | 42 cm / 1.05 kg | Classic baits; feeder baits; dry fly/nymph; spinner/minnow | Lakeside, Lake Pier, Bell Park Pier, Meadow Bend |
| 35 | Asp (*Leuciscus aspius*) | 65 cm / 2.6 kg | Classic spinner/wet fly; active spinner/minnow | Lake Pier, Bell Park Pier, Meadow Bend (lure only) |
| 36 | Leervis (*Lichia amia*) | 85 cm / 5 kg | Sardine, coastal spinner/saltwater fly; active spoon, jig or minnow | Secluded Beach, Fish Hoek Beach |
| 37 | Atlantic chub mackerel (*Scomber colias*) | 35 cm / 0.42 kg | Squid, sardine, coastal spinner/saltwater fly; active spoon, jig or minnow | Simon’s Town Rocks, Blouberg Sunrise, Fish Hoek Beach |

Typical sizes, rarity, fighting strength, timing and exact pools are authored game
balance. These habitats are not claims of surveyed populations in the panorama
photographs. The full [location matrix](LOCATION_SPECIES.md) includes old and new
species. Silver bream are not bottom specialists like ruffe; the feeder assignment
represents a usable coarse-fishing presentation.

Brook trout also extend from the existing lake roster into Boulder Run’s cold-water
fly and lure pools. Meadow Bend fly fishing now includes ide, while asp and ruffe
stay outside its dry/nymph pool. Dry flies favour surface-feeding dace there; the
nymph pool excludes dace. Feeder baits retain their four choices and lure tackle
retains its three. Incidental catches cannot cross a method’s eligible pool.

Every fish uses the shared tackle progression. The new fight profiles range from
short bottom-oriented ruffe fights to sustained asp/leervis runs. Correct-play
simulations cover the free Willow rod and upgraded tackle; leervis power was
reduced during validation so starter tackle can land it.

## Fish Guide

All 38 pages show **habitat, preferred presentation, eligible methods and named
waters**. Identity and silhouette remain hidden until caught. New descriptions
identify characteristic anatomy and feeding habits. Existing journal catches still
unlock by scientific name; smaller catches never overwrite an earlier personal
best. Page layout fits the existing physical guide, including the longest new
name, and adds no in-world tutorial text.

## Authored assets

References were generated separately with the built-in image_gen tool, then used
as original texture inputs for Blender meshes. They are generated illustrations,
not photographs or scans of real specimens. Reviewed anatomical landmarks define
each volumetric body, eyes and fin roots. Fins have thin volume, paired pectoral
fins lift from the flank, and all models face +X at one metre reference length so
local and remote catches scale consistently.

- Runtime meshes: `assets/models/fish/{silver_bream,ruffe,ide,asp,leervis,atlantic_chub_mackerel}.glb`.
- Retained reference images and landmarks: `source/fish_references/roster_expansion/`.
- Packed source: `source/roster_expansion.blend`.
- Texture/bake outputs: `source/textures/fish/roster_expansion/`.
- Builder: `tools/build_roster_expansion.py`, using the established photographic
  reconstruction helper with optional lower sampling density for these assets.
- Exact prompts and generation provenance: [prompt set](roster_expansion_prompts.json).
- Export hashes, triangle counts and material counts: [asset manifest](roster_expansion_assets.json).

Each fish has one mesh and three material surfaces: skin, fins and wet corneas.
UV colour textures, restrained baked normal relief and separate roughness/coat
settings preserve scales and eyes in close VR views. Meshes stay below 35,000
triangles each. The source workflow mirrors flank textures across the body, so
back/belly projection is approximate; it does not add skeletal swimming animation.
No new third-party asset licence is required.

## Research basis

Species traits and method choices were checked against these sources. Exact
location and bait weights remain game design rather than biological predictions.

- [Canal & River Trust: silver bream](https://canalrivertrust.org.uk/things-to-do/fishing/caring-for-our-fish/freshwater-fish-species/silver-bream) — large eyes, reddish fin bases and slow-water habitat.
- [Scottish Federation for Coarse Angling: ruffe](https://www.sfca.co.uk/go-fishing/know-your-fish/ruffe/) — bottom presentations with worms and maggots.
- [Fishing.fi: ide in running water](https://finland.fishing.fi/fishing-methods-and-species/say/hei/vir/casting-on-running-waters-ide-in-finland) — slow currents, lake margins and spinner presentations; [Kajana Club’s first-hand ide fly fishing](https://kajanaclub.com/sayne-unicorn-river/) supports the fly crossover.
- [HELCOM’s asp profile](https://helcom.fi/wp-content/uploads/2019/08/HELCOM-Red-List-Aspius-aspius-1.pdf) — species and habitat context; source uses the older name *Aspius aspius*.
- [Oceanographic Research Institute’s southern African linefish profiles](https://www.oritag.org.za/Content/UserContent/documents/Southern_African_Marine_Linefish_Species_Profiles.pdf) — leervis distribution and fish-based diet.
- [SAIAB’s Western Indian Ocean fish plates](https://saiab.ac.za/wp-content/uploads/2022/11/2._wiof_volume_5_colour_plates.pdf) — Atlantic chub mackerel identification and a South African specimen.

## Compatibility and validation

Protocol **9** requires the expanded roster on clients and servers, preventing
older clients from receiving unknown fish IDs. The separate dedicated server is
rebuilt with the new species and method validation, without visual assets. No
changes restore retired Pico release targets.

- `tests/roster_expansion.gd`: 31,963 checks of stable IDs, method/bait/habitat pools,
  guide discovery and server catch eligibility.
- `tests/roster_assets.gd`: 230 checks of local/remote size matching, UV materials,
  normal maps, triangle limits and guide text bounds; additional render checks.
- Core fishing: 326 checks; tackle: 141 checks; all 38 species’ fight profiles are
  exercised at multiple seeds and frame rates.
- Existing model/journal, guide, population, marine, fly, feeder, lure, leaderboard
  and network guard suites cover regressions.
- Simulated Monado OpenXR captures inspect both eyes; physical headset comfort
  and frame budget remain untested. Existing synthetic-runtime teardown warnings
  remain after successful capture.

- Dedicated and ad-hoc multiplayer integration passed with the new asp catch and
  all tackle styles. The first run logged an engine peer-disconnect diagnostic;
  a complete repeat passed without it.
- The asset-free server persistence test passed: an exceptional lure-caught asp
  retains its species identity, statistics and player ownership after restart
  and a renamed reconnect; clients do not save leaderboard data.

## Reviewed captures

[Side gallery](validation/roster/gallery.png) ·
[Angled gallery](validation/roster/gallery-oblique.png).

Guide pages: [silver bream](validation/roster/guide-32.png),
[ruffe](validation/roster/guide-33.png), [ide](validation/roster/guide-34.png),
[asp](validation/roster/guide-35.png), [leervis](validation/roster/guide-36.png),
[mackerel](validation/roster/guide-37.png).

Simulated OpenXR stereo captures (left / right):

- Silver bream and ruffe: [left](validation/roster/fish-pair-0_eye0.png) / [right](validation/roster/fish-pair-0_eye1.png).
- Ide and asp: [left](validation/roster/fish-pair-1_eye0.png) / [right](validation/roster/fish-pair-1_eye1.png).
- Leervis and mackerel: [left](validation/roster/fish-pair-2_eye0.png) / [right](validation/roster/fish-pair-2_eye1.png).
- Guide: [left](validation/roster/guide-ide_eye0.png) / [right](validation/roster/guide-ide_eye1.png).
