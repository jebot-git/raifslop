# Fishing methods and roster expansion

Design study, 17 September 2026. These are proposals, not new selectable modes.
The current roster has 32 species. Float/bait fishing covers the lakes and coast;
two river locations use dry-fly/nymph casting, stripping and mending. Selecting a
spinner currently changes attraction, not a dedicated retrieve simulation.

## Recommended order

| Priority | Method and tackle | Distinct VR interaction | Existing roster to validate it | Logical expansion |
|---|---|---|---|---|
| 1 | Bottom / feeder: sinker, short leader, cage feeder, quiver tip | Cast, let the rig settle, watch tip knocks; feed one chosen patch | Bream, tench, carp, barbel; coastal kob and steenbras | Silver bream, ruffe and ide in suitable European waters; validate individual habitat before adding each |
| 2 | Spinning / soft-plastic jig: weighted lure, optional wire leader | Reel speed and rod lifts control depth; pause on the drop | Perch, pike, zander; elf and yellowtail | Asp in an appropriate European river; smallmouth/largemouth bass only with a regionally appropriate new water |
| 3 | Light rock fishing / drop-shot | Hold the lure near structure; small wrist twitches and controlled descent | Blacktail, roman, zebra seabream, horse mackerel | Local gobies or wrasses after confirming Cape species, substrate and depth; avoid generic worldwide species pools |
| 4 | Surf ledger: sand sinker, baited trace, longer rod | Choose a channel between sandbars; follow wave-driven tension and tip bites | White steenbras, stumpnose, kob | A regional flatfish or ray package after species/location research; flatfish need new body animation and bottom behaviour |
| 5 | Streamer / wet-fly retrieve and expanded nymph depth | Reuse fly casts and stripping, add sinking leader and retrieve cadence | Brown/rainbow trout, chub and grayling | Atlantic salmon or sea trout only in a suitable seasonal river/estuary; do not add them indiscriminately to the current river pools |

Bottom and jig fishing target a genuinely different depth/presentation niche.
The Recreational Boating & Fishing Foundation describes bottom fishing with
weighted rigs: [bottom fishing](https://www.takemefishing.org/how-to-fish/how-to-fish-with-live-bait/how-to-bottom-fish/).
The Canal & River Trust describes worm-bait compatibility across coarse species
and successful lure fishing for perch, pike and chub:
[chopped worm](https://canalrivertrust.org.uk/things-to-do/fishing/learn-to-fish/fishing-baits/chopped-worm),
[lure-method context](https://canalrivertrust.org.uk/things-to-do/fishing/caring-for-our-fish/invasive-and-non-native-fish/zander/zander-faqs).
These support the method choices; the candidate additions in the table are design
proposals requiring local ecological validation, not claims of presence in every
existing panorama.

New Jersey Fish & Wildlife describes moving bottom baits and bucktails for
summer flounder, and crab/sinker rigs for tautog:
[flounder](https://www.nj.gov/dep/fgw/flukefsh.htm),
[tautog](https://www.nj.gov/dep/fgw/arttautog08.htm).
Those are useful references for mechanics and a future North Atlantic location,
not justification for placing these American species on the Cape beaches.

## Implementation shape

Separate `method`, `rig`, `bait`, `depth_band` and `retrieve_pattern`. Keep the
current species indices stable; append new species and retain journal identity.
Add method/depth/substrate eligibility to the location's species pool before
applying bait preference, rarity and population recovery. Rig suitability should
change encounter access and presentation, rather than simply multiplying rewards.

Start with one sinker/leader rig and one single-hook jig. Reuse the current cast,
line, haptics, fatigue and landing systems. Add a cheap authored depth/substrate
map per location; panosphere pixels alone cannot define underwater habitat.
Simulate terminal tackle with a few analytic points, not a many-body rope.
A tip pulse, line change, small symbol and positional sound replace textual prompts.
Use the Field Guide to explain depth, lure action and new species discoveries.

For each method, author a small textured terminal rig and rod-tip response.
Network the selected method/rig and terminal position so remote anglers see the
same gear; version the wire protocol when its schema changes. Extend server catch
validation alongside each new method and size distribution. Never award a second
catch for an extra hook on the same event without an explicit new catch identity.

Acceptance: distinguish methods through input and fish eligibility; preserve
seated reach and offhand access; verify both eyes, casting boundaries, travel,
remote tackle and server record continuity. Add region-specific models, guide
entries and fighting behaviour for each species before enabling encounters.

Trolling, deep-sea jigging and ice fishing are later location-scale expansions:
they need boats/deep-water or ice access, and contribute less to the current shore
locations. Multi-hook sabiki is also later work because several simultaneous
fish complicate offhand handling, the fight state machine and replication.
