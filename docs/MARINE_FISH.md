# Marine fish

Coastal Rocks, Sunrise Beach, Secluded Cove and Tidal Strand have marine-only rosters. The original freshwater species and their journal indices remain unchanged; the original eight marine species occupy indices 18–25, with four additional species at 28–31. Rare predator indices 26–27 remain unchanged. See the [expanded catalogue, current rosters and model gallery](MARINE_EXPANSION.md). These are authored southern African coastal game rosters, not a survey of the photographed sites.

| Species | Typical game catch | Coastal Rocks | Sunrise Beach |
| --- | --- | --- | --- |
| Blacktail — *Diplodus capensis* | 30 cm / 0.65 kg | Yes | Yes |
| Galjoen — *Dichistius capensis* | 38 cm / 1.2 kg | Yes | Yes |
| Hottentot — *Pachymetopon blochii* | 35 cm / 0.8 kg | Yes | |
| Red roman — *Chrysoblephus laticeps* | 40 cm / 1.4 kg | Yes | |
| White steenbras — *Lithognathus lithognathus* | 65 cm / 3.2 kg | | Yes |
| Elf / bluefish — *Pomatomus saltatrix* | 45 cm / 1.1 kg | Yes | Yes |
| Cape yellowtail — *Seriola lalandi* | 85 cm / 5.5 kg | Yes | Yes |
| Harder mullet — *Chelon richardsonii* | 32 cm / 0.4 kg | | Yes |

The table above records the original eight species. Each coastal roster now contains nine regular targets, drawn from twelve marine species. All four rosters are distinct and support every saltwater bait slot; [current rosters](MARINE_EXPANSION.md#coastal-selection) include the four additions.

Sizes are gameplay baselines with the existing ±15% length variation and cubic weight scaling. They are not species maxima. Fighting uses the shared directional counters, submerging mechanics and tackle progression. Catch models retain metre-based scaling and the existing subtle twitch.

## Bait and travel

The same six input slots select ragworm, squid, spinner, prawn, sardine and saltwater fly at the coast. Each has a local, nonempty catch pool. Rod tackle geometry, HUD names, hints and guide status switch with the location; travelling inland restores earthworm, sweetcorn, spinner, maggots, bread and wet fly. Existing freshwater pools are unchanged. Marine bait choices are gameplay groupings, not a detailed diet simulation.

## Sources and asset pipeline

Species identities and distinguishing characteristics were checked against [SAAMBR / Oceanographic Research Institute fish fact sheets](https://saambr.org.za/fish-fact-sheets/), the [ORI galjoen sheet](https://saambr.org.za/wp-content/uploads/2023/03/ORI-Fish-Fact-Sheet-Galjoen.pdf) and [WWF-SASSI species catalogue](https://wwfsassi.co.za/sassi-list/). Reference illustrations are original built-in imagegen outputs, not photographs or scans. No third-party source artwork was copied.

- Original generated side references: `source/fish_references/marine/{species}.png`.
- Built-in imagegen mode and exact per-asset prompts: [marine_image_prompts.json](marine_image_prompts.json).
- Reviewed body, eye, pectoral and external-fin regions: `source/fish_references/marine/anatomy.json`.
- Rebuild with Blender: `tools/build_marine_fish.py`, using the established photographic-style reconstruction builder.
- Editable packed source: `source/marine_fish.blend`.
- Generated albedo and normal maps: `source/textures/fish/marine/`.
- Runtime models: `assets/models/fish/`; [file manifest and checksums](marine_fish_assets.json).

Bodies are volumetric with mirrored side textures, inset corneas, paired pectoral fins and attached, thin external fin surfaces. This retains the established VR asset approach; generated anatomy and markings are artistic approximations. Freshwater reconstruction now has a main guard so the marine builder can reuse its functions without rebuilding existing fish.

## Original eight-species validation

`tests/location_species.gd` verifies habitat separation, every local species reachable by actual casts, every bait nonempty and distinct location rosters. `tests/marine_species.gd` exercises coastal/inland travel, bait names and model switching, and optionally renders the gallery. At this stage, species, guide, fight and catch-twitch suites covered all 26 species. `tools/validate_fish_fins.py` includes all eight marine exports in the attachment and dorsal-silhouette audit.

Original checks passed (see [current expansion checks](MARINE_EXPANSION.md#runtime-previews-and-validation)): simulation 230, location/bait 173, imported model integration 179, field guide 41, and tackle 105 assertions; network guards, coastal travel, marine bait switching and catch-twitch suites reported no failures. Blender validated all 23 reconstructed fish (including eight marine fish) for attached fin roots, dorsal silhouettes and bounds. The corrected runtime gallery was visually inspected. Logs and gallery are under `test-results/marine-fish/`. Physical headset appearance and feel were not retested. The gallery normalizes fish lengths for comparison; caught fish use the journal's actual metre scale.
