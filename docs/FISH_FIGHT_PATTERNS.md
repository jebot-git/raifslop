# Recognizable fish fights

Ordinary fish previously shared a nine-second run cycle, uniform random directions and alternating deep/slack dives. They now use family tendencies with individual species pacing in `scripts/fish_fight_profiles.gd`. Existing species power and stamina remain relevant. Predators retain their separate sequences and opening takeover rush.

| Style | Species | Observable clues |
| --- | --- | --- |
| Darting | Perch, roach, rudd, dace, bleak | Shorter lateral holds, frequent left/right changes; small fish tire quickly |
| Bottom-oriented | Tench, bream, crucian carp, barbel, gudgeon | Outward holds and repeated deep pulls; fewer inward rushes |
| Steady runners | Common carp, chub, white steenbras | Opening run, sustained pulls, further runs between counters |
| Ambush predators | Pike, zander | Fast initial burst, repeated lateral holds, longer recovery intervals |
| Agile | Rainbow/brown/brook trout, grayling, elf/bluefish | Short holds, changing directions and more inward slack rushes |
| Reef fish | Blacktail, galjoen, hottentot, red roman | Repeated dives and outward resistance, with species-specific timing |
| Open-water runners | Yellowtail, harder mullet | Longer outward runs and lateral turns; mullet is smaller, weaker and faster-paced |
| Large inland predator | Wels catfish | Seven-second takeover rush, longer holds, repeated deep pulls |
| Large marine predator | Bronze whaler shark | Nine-second takeover rush and more frequent long runs |

Every ordinary species has its own combination of family cadence and tempo. Each fight may mirror lateral directions and varies recovery/dive timing within narrow bounds. This gives repeatable clues without promising exact identification from a single movement. Family labels are design categories rather than taxonomic groups. No species name is revealed by ordinary fight prompts.

Run-oriented fish start with a run, and steady/open-water runners have enough space between counters to express subsequent runs. Successful counters otherwise suppressed the old periodic runs. Directional hold lengths retain at least one second of reaction margin within the six-second counter window. Dives retain the existing warning and safe-tension entry conditions.

## Biological basis and limits

These are authored gameplay interpretations, not measured species-specific fight schedules. Bottom-oriented tench behavior is informed by its vegetation-rich, slow-water habitat and bottom feeding ([USGS species account](https://nas.er.usgs.gov/queries/greatLakes/FactSheet.aspx?Potential=Y&Species_ID=652&T=)). The active bluefish interpretation is informed by swimming and schooling observations in [NOAA's biological synopsis](https://repository.library.noaa.gov/view/noaa/33309/noaa_33309_DS1.pdf). The exact timings, direction orders and grouping of other fish are game design choices that use the existing run/counter/dive mechanics.

## Takeover probability

Predator takeovers now have one **2%** roll per eligible retrieval. Eligibility, consumed-prey accounting, the opening reaction window and inherited line strain remain as documented in [predator encounters](PREDATOR_ENCOUNTERS.md).

## Validation

`tests/species_fight_patterns.gd` runs all 26 ordinary species across three seeds at 30/90 Hz, checks that correct play lands each fish and that run-oriented species actually run, checks reaction margins and distinct per-species pacing, and verifies broad family/predator tendencies. Existing full-fight, tackle, dive/haptic, takeover and scene-feedback suites provide regression coverage. Physical headset feel has not been retested.
