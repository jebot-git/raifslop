# Rare predator encounters

Wels catfish (*Silurus glanis*, index 26) inhabit the four inland lakes; bronze whaler sharks (*Carcharhinus brachyurus*, index 27) inhabit the four coastal waters. They are available only by taking an eligible hooked fish during retrieval. Huchen (*Hucho hucho*, index 38) occupy the two authored river habitats; ragged-tooth sharks (*Carcharias taurus*, index 39) occur at Simon’s Town Rocks, Secluded Beach and Fish Hoek. Existing species indices remain stable. Where multiple predators are eligible, the single successful 3% roll selects one uniformly; chances are not added together.

## Encounter rules

Each eligible fight gets one **3% chance**, after at least six seconds of actual retrieval and two metres of progress, with the fish still at least three metres beyond the landing distance. The roll waits for a break between runs/dives and a taut line; high tension does not prevent a takeover. Waiting, stopping and restarting the reel cannot reroll the chance. Predators cannot trigger another takeover.

- Wels prey: locally available perch, roach, rudd, dace, bleak, gudgeon, silver bream and ruffe.
- Bronze whaler prey: locally available blacktail, elf/bluefish, harder mullet, horse mackerel and Atlantic chub mackerel.
- Huchen prey: locally available brown/brook trout, grayling, dace, gudgeon and ruffe. Fly, feeder and lure retrievals can qualify where the method and prey are supported.
- Ragged-tooth prey: locally available blacktail, hottentot, roman, elf, mullet, zebra seabream and both mackerels.

These are authored gameplay prey lists. The consumed fish earns no catch or currency. A takeover preserves the line position, resets stamina and counter penalties while preserving tension and accumulated line strain. A louder splash and a dedicated 1.8-second expanding water burst mark the bite, with one haptic pulse. The burst stays at the impact point while the fish swims away. Landing records only the predator, with the consumed fish’s Latin name retained in `bait_fish_latin`.

## Fight and scale

The opening immediately draws line out for seven seconds (Wels/huchen) or nine seconds (sharks). A 0.6-second reaction window softens the load while the player stops reeling. Continued reeling then raises tension rapidly, with a shorter 0.45-second overload tolerance multiplied by the square root of tackle durability. Stopping starts relieving tension immediately, but an already overloaded starter line can still break. Upgraded tackle slows load buildup and tolerates more strain.

All predators cycle through sustained directional counters, long runs, deep pulls requiring a stopped reel, and inward rushes requiring faster reeling. Correct directional counters reduce the extra load; stopping the reel during a long run controls tension. Recovery intervals permit retrieval. Predators must reach 15% stamina before landing.

| Predator | Baseline length / mass | Endurance | Starter / upgraded simulated fight |
| --- | --- | --- | --- |
| Wels catfish | 180 cm / 45 kg | 400 | 264 / 121 seconds |
| Bronze whaler | 240 cm / 100 kg | 520 | 375 / 178 seconds |

These are game baselines, with existing ±15% length variation and cubic mass scaling. Runtime geometry is normalized to one metre and scaled to the recorded catch length, consistent with the 170 cm avatar. Both use the existing subtle caught-fish twitch.

## Models and sources

Original built-in imagegen side illustrations were reconstructed into textured, volumetric Blender models. Wels has a broad head, six barbels, a small dorsal fin and long anal fin. The shark has paired spreading pectoral fins, two dorsal fins, five gill slits and an asymmetric tail. Thin fins have their roots fitted to the body. Generated anatomy and markings remain artistic approximations.

- [Exact prompts, built-in generation mode and retained paths](predator_image_prompts.json)
- References and reviewed landmarks: `source/fish_references/predators/`
- Rebuild: `tools/build_predator_fish.py`
- Packed editable source: `source/predator_fish.blend`
- Maps: `source/textures/fish/predators/`
- [Runtime models and SHA-256 manifest](predator_fish_assets.json)

Diet references: [Wels predation study in Czech lakes](https://doi.org/10.1038/s41598-017-16169-9), [Florida Museum bronze whaler profile](https://www.floridamuseum.ufl.edu/discover-fish/species-profiles/bronze-whaler-shark/), and [Two Oceans Aquarium harder mullet profile](https://www.aquarium.co.za/animals/southern-mullet). No external source artwork was copied.

## Validation

`tests/predator_encounters.gd` checks one-roll rarity (3% target across 20,000 seeded trials), retrieval eligibility, habitat separation, takeover state, haptic event, complete fights on starter/upgraded tackle, consumed prey accounting and reset behavior. `tests/fishing_feedback.gd` verifies a single takeover audio event. Existing imported-model tests cover both fish’s metre scale, textures and journal persistence. `tools/validate_fish_fins.py` passes all 25 reconstructed models, including both predators. `tests/predator_models.gd` renders the visually inspected gallery at `test-results/predator-fish/gallery.png`; lengths are normalized for comparison in that gallery. Physical headset feel has not been retested.

## Added predators in 0.1.11

Huchen has a 120 cm / 18 kg game baseline, endurance 340 and power 1.6.
Ragged-tooth shark has a 220 cm / 90 kg baseline, endurance 480 and power 1.95.
These are authored game balance, not a survey of the photographed locations.
Huchen’s river assignment follows its cool, oxygen-rich river habitat and
fish-based diet ([Danube huchen study](https://riverwatch.eu/sites/default/files/uploads/Studien/2024_2610_Huchen_Drina-min.pdf)).
Ragged-tooth habitat and prey are informed by the
[ORI species fact sheet](https://saambr.org.za/wp-content/uploads/2023/03/ORI-Fish-Fact-Spotted-ragged-tooth-shark-ZC-LB.pdf).

Original generated references, UV-textured Blender bodies, baked normals and
reviewed fin landmarks are retained under `source/fish_references/predator_expansion/`,
`source/textures/fish/predator_expansion/` and `source/predator_expansion.blend`.
Rebuild with `tools/build_predator_expansion.py`.
[Exact prompts](predator_expansion_prompts.json) used the built-in image_gen tool.
Illustrations and mirrored flank projections remain artistic approximations.

`tests/predator_expansion.gd` checks both new IDs, habitat/prey separation, shared
3% probability, no rerolls, complete starter/upgraded fights and server eligibility.
`tests/predator_expansion_assets.gd` checks textured local/remote dimensions,
normal maps, triangle budgets and all guide text bounds, with optional stereo captures.
