# Rare predator encounters

Wels catfish (*Silurus glanis*, index 26) inhabit the inland game waters; bronze whaler sharks (*Carcharhinus brachyurus*, index 27) inhabit the two maritime waters. They are available only by taking an eligible hooked fish during retrieval. Existing species indices remain stable.

## Encounter rules

Each eligible fight gets one **2% chance**, after at least six seconds of actual retrieval and two metres of progress, with the fish still at least three metres beyond the landing distance. The roll waits for a break between runs/dives and a taut line; high tension does not prevent a takeover. Waiting, stopping and restarting the reel cannot reroll the chance. Predators cannot trigger another takeover.

- Wels prey: locally available perch, roach, rudd, dace, bleak and gudgeon.
- Bronze whaler prey: locally available blacktail, elf/bluefish and harder mullet.

These are authored gameplay prey lists. The consumed fish earns no catch or currency. A takeover preserves the line position, resets stamina and counter penalties while preserving tension and accumulated line strain. A louder splash and a dedicated 1.8-second expanding water burst mark the bite, with one haptic pulse. The burst stays at the impact point while the fish swims away. Landing records only the predator, with the consumed fish’s Latin name retained in `bait_fish_latin`.

## Fight and scale

The opening immediately draws line out for seven seconds (Wels) or nine seconds (shark). A 0.6-second reaction window softens the load while the player stops reeling. Continued reeling then raises tension rapidly, with a shorter 0.45-second overload tolerance multiplied by the square root of tackle durability. Stopping starts relieving tension immediately, but an already overloaded starter line can still break. Upgraded tackle slows load buildup and tolerates more strain.

Both predators cycle through sustained directional counters, long runs, deep pulls requiring a stopped reel, and inward rushes requiring faster reeling. Correct directional counters reduce the extra load; stopping the reel during a long run controls tension. Recovery intervals permit retrieval. Predators must reach 15% stamina before landing.

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

`tests/predator_encounters.gd` checks one-roll rarity (2% target across 20,000 seeded trials), retrieval eligibility, habitat separation, takeover state, haptic event, complete fights on starter/upgraded tackle, consumed prey accounting and reset behavior. `tests/fishing_feedback.gd` verifies a single takeover audio event. Existing imported-model tests cover both fish’s metre scale, textures and journal persistence. `tools/validate_fish_fins.py` passes all 25 reconstructed models, including both predators. `tests/predator_models.gd` renders the visually inspected gallery at `test-results/predator-fish/gallery.png`; lengths are normalized for comparison in that gallery. Physical headset feel has not been retested.
