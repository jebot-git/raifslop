# Lure fishing and shared tackle progression

While ready to cast, hold **right joystick press**, point **up**, and release to
select Lure. Left selects Classic (Fly at rivers); right selects Feeder where
available. Neutral release cancels. Desktop uses Tab + Up/Left/Right. Left X cycles
three lures; bait names remain the brief permitted textual popup. No additional
world-space guide text is introduced. Gameplay pictograms remain optional.

Cast normally, then turn the reel with the offhand. Steady retrieves work best;
excessive speed reduces effectiveness. Jig and minnow presentations also respond
to changes in rod lift and brief pauses after winding. An unattended lure never
starts a bite clock. Lift on the existing bite haptic, then fight and land normally.
Retrieve the empty lure fully before changing method or bait. Lures sink to bounded
presentation depths, shallower in rivers; this is an inexpensive gameplay model,
not a fluid or underwater terrain simulation.

| Lure | Presentation and preferred fish, where locally available |
| --- | --- |
| Inline spinner / coastal casting spoon | Steady retrieve; perch, chub, trout, elf, yellowtail and horse mackerel |
| Paddle-tail jig | Slower, deeper retrieve and short pauses; perch, pike, zander, trout, blacktail, roman and kob |
| Diving minnow | Moderate retrieve, twitches and brief pauses; pike, zander, chub, rainbow/brown trout, elf, yellowtail and kob |

Feeder fishing retains **four** distinct hook baits: earthworm, sweetcorn, maggots
and bread. Its preferences and bottom-feeding mechanics remain separate. See
[feeder details](FEEDER_FISHING.md).

## Authored location pools

| Location | Eligible lure fish |
| --- | --- |
| Lakeside | Perch, pike, zander, chub |
| Lake Pier | Perch, pike, zander, chub, rainbow trout, brown trout, brook trout |
| Gray Pier | Perch, pike, zander, brown trout |
| Bell Park Pier | Perch, pike, chub, rainbow trout, brown trout, brook trout |
| Meadow Bend | Chub, brown trout |
| Boulder Run | Rainbow trout, brown trout |
| Simon's Town Rocks | Blacktail, roman, elf, yellowtail, kob, horse mackerel |
| Blouberg Sunrise | Blacktail, elf, yellowtail, kob, horse mackerel |
| Secluded Beach | Blacktail, roman, elf, horse mackerel |
| Fish Hoek Beach | Blacktail, elf, yellowtail, kob, horse mackerel |

Preferences intersect these pools; occasional off-bait strikes stay within the
same pool. Population depletion, sector presence, rarity and existing predator
takeovers still apply. Species IDs and saved catches are unchanged.

These are gameplay habitats, not surveys of the photographed waters. Freshwater
method choices are informed by [Canal & River Trust's urban lure-fishing example](https://canalrivertrust.org.uk/things-to-do/fishing/fishing-features/urban-fishing)
and [Daiwa's trout-on-soft-plastics guidance](https://daiwafishing.com.au/blogs/news/how-to-catch-trout-on-soft-plastics).
Exact preferences, depths, timings and regional pools are game-design choices.

## Every style follows the same progression

One purchase unlocks a tier across classic, fly, feeder and lure rods. Selecting
a rig changes its construction, reel, handle and terminal tackle; it preserves
ownership, equipped tier, balance, fatigue and line-durability bonuses.

| Tier | Price | Durability / fatigue | Shared visual identity |
| --- | ---: | --- | --- |
| Willow | Free | 1.00 / 1.00 | Green blank and reel, olive trim, textured cork |
| Reed | 150 | 1.25 / 1.30 | Blue blank, silver trim and reel, EVA grip |
| Heron | 450 | 1.55 / 1.65 | Red blank, brass trim and reel, textured cork |
| Kingfisher | 1,000 | 1.90 / 2.10 | Turquoise blank and reel, bright anodised trim, EVA grip |

`tools/rod_styles.py` is the shared palette for both rod builders. Each style has
four held and four folded models. Lure rods have split grips, casting guides,
a finger trigger, a compact baitcaster and a rotating double-paddle crank. The
short spindle and tracked grip anchor fit that reel. VR reel-hand snapping and
desktop/remote hand placement use the selected style's grip anchor.

Original Blender assets and packed cork/EVA/lure-scale textures are retained in
`source/lure_tackle.blend`; `tools/build_lure_tackle.py` reproduces them.
`tools/build_folded_rods.py` includes the lure variants. Metal, polymer and grip
surfaces have separate roughness/metallic materials. No extra gameplay lights,
rigid-body tackle chain or third-party asset dependency is introduced.

## Multiplayer and validation

Protocol **8** supports all three rigs. Peers see the equipped tier, correct
casting reel, selected lure (including the coastal spoon), terminal position and
swimming/hanging orientation. Lure mode hides the float and cage. Server validation
rejects unsupported rig/bait combinations and impossible lure catches. Update
clients and server together. The dedicated binary is rebuilt from shared scripts
without these visual assets or native client extensions.

- `tests/lure_fishing.gd`: 5,726 checks of all location/bait combinations, active
  retrieves, pauses, depths, empty retrieves, hook setting and server eligibility.
- `tests/rig_progression.gd`: 113 checks across 16 tier/style combinations,
  purchases, persisted ownership, folded models and shared fight bonuses.
- `tools/test_rod_styles.py`: 128 material/texture checks across 32 shipped models.
- `tests/lure_interface.gd`: 1,103 headless checks of tracked radial selection, bait cycling, remote
  tier/lure/pose replication, invalid packets, crank input and stereo captures.
- Existing feeder, fly, tackle, pictogram, network and leaderboard regressions.
- Actual dedicated/ad-hoc multiplayer, including a late joiner; server leaderboard
  restart and identity tests.

Stereo captures use simulated Monado OpenXR; physical-headset comfort and frame
budget still need playtesting. Close-up inspection uses a test-only fill light.
The synthetic runtime has existing session-stop warnings during shutdown.

Inspection captures: [radial, left eye](validation/lure/radial_eye0.png),
[radial, right eye](validation/lure/radial_eye1.png),
[Willow](validation/lure/casting-willow_eye0.png),
[Reed](validation/lure/casting-reed_eye0.png),
[Heron](validation/lure/casting-heron_eye0.png),
[Kingfisher](validation/lure/casting-kingfisher_eye0.png),
[double paddle](validation/lure/casting-crank_eye0.png),
[lure selection](validation/lure/lures_eye0.png). Both eyes are retained for each.
