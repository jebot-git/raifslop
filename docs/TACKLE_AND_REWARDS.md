# Shekels, tackle and fish stamina

Open the Field station with **V** on desktop or **right B** in VR, then choose **Tackle**. The same tracked-pointer buttons buy and equip rods. Balance and equipped rod also appear on the fishing HUD. Equipment changes are available only when ready to cast.

New anglers start with zero shekels and the free Willow rod. Every newly landed fish pays once, immediately; holding or releasing it gives no additional reward. Missed or lost fish pay nothing. Existing journal entries are preserved and are not paid retroactively.

Payout is `round(20 × rarity × (caught length / typical species length)²)`. Typical common, uncommon and rare specimens pay 20, 40 and 60 shekels. Larger specimens earn more within every species. The catch summary and journal record the actual payout.

| Rod | Price in shekels | Line durability | Fatigue dealt |
|---|---:|---:|---:|
| Willow | Free | ×1.00 | ×1.00 |
| Reed | 150 | ×1.25 | ×1.30 |
| Heron | 450 | ×1.55 | ×1.65 |
| Kingfisher | 1,000 | ×1.90 | ×2.10 |

Purchased rods remain owned and can be equipped again for free. Durability reduces extra tension from running/reeling against a run and extends overload tolerance from 1.4 seconds to 1.4 × durability. Slack still loses the hook after 1.4 seconds. Normal reel tension recovery remains available with every rod. Fatigue improves both steady reeling and successful counters; upgrades do not remove the need to manage tension.

Species have distinct stamina capacities, represented by a normalized percentage on the HUD. These values and rarity tiers are gameplay balancing choices, not biological measurements or conservation categories.

| Species | Rarity tier | Stamina capacity |
|---|---:|---:|
| European perch | 1 | 85 |
| Common carp | 2 | 140 |
| Northern pike | 3 | 150 |
| Common roach | 1 | 60 |
| Tench | 2 | 125 |
| Common bream | 1 | 100 |
| Zander | 3 | 130 |
| Rudd | 1 | 65 |
| Crucian carp | 2 | 95 |
| European chub | 2 | 110 |
| Rainbow trout | 2 | 115 |
| Brown trout | 3 | 120 |
| European grayling | 2 | 105 |
| Common barbel | 3 | 155 |
| Common dace | 1 | 55 |
| Bleak | 1 | 45 |
| Gudgeon | 1 | 50 |
| Brook trout | 3 | 110 |

Selection within each existing location/bait pool uses inverse rarity weights (1, ½, ⅓). All previously available species remain catchable. Fresh fish add more tension during runs and escape cues; fatigue also reduces the penalty for a missed counter. A successful counter drains stamina, relieves tension, immediately ends a run and delays the next escape cue by 3.5–5.5 seconds, with longer recovery for tired fish. The run cycle restarts after this recovery period. Landing still requires the fish close to shore and below 35% stamina.

Local balance, owned rods and equipment persist in `user://tackle.json`. Saves replace the profile through a temporary file; failed purchases roll back their balance/equipment changes. Catch save failures appear in the catch message. Multiplayer participants keep individual local progression, consistent with the existing local fishing simulation; this is not a server-authoritative economy.

Validation: `tests/tackle.gd` passes 63 checks for payouts, save/load, invalid profile data, purchase rollback, fight restrictions, counter recovery, stamina-dependent tension, all 12 species with starter/top-tier rods, shorter upgraded fights, and shop controls/layout. Existing simulation118, feedback26 and menu/ambience33 checks also pass. Tests use isolated user-data directories. Existing Godot exit cleanup warnings remain. No physical-headset shop interaction or listening test was performed in this pass.
