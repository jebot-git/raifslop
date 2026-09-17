# Cage feeder fishing

Feeder fishing is a selectable rig with bottom presentation, an authored cage,
a short hooklink, and a flexible quiver tip. It reuses the existing species models,
fight profiles, landing, rewards and server leaderboard. Existing species IDs
and saved catches remain unchanged.

## Selection and interaction

While ready to cast, hold **right joystick press**, point left for classic tackle
or right for feeder, and release the press. Releasing in the central dead zone
cancels. At rivers, classic means the existing fly setup. The small two-sector
radial menu reserves right-stick turning until the stick returns to centre;
left-stick push-to-talk remains available. It closes without selecting on tracking
loss, menu opening or offhand-device use. Active casts, bites, fights and landed
catches cannot change rigs. The selected rig is saved in player preferences.
Desktop uses **Tab + Left/Right**, releasing Tab to confirm.

Cast normally and let the cage sink. Settling depth is an authored per-location
value, varied by fishing-grid row (roughly 0.9–2.8 m); this is a lightweight
presentation model, not measured bathymetry. Reeling lifts the empty cage and
pauses feeding until it settles again. A settled cast deposits feed once in its
fishing sector. Accurate recasts build attraction up to a bounded 1.55× bite
clock; feed decays over time and does not bypass population depletion or rarity.
A tip pulse and the existing bite haptics cue the strike. Lift to hook, then reel
and counter the fish normally. Tip animation never moves the controller-input
anchor, preventing automatic hook sets.

Left X cycles four hook baits. The cage is replenished automatically for each
cast; no inventory purchase or additional popup is required.

| Hook bait | Preferred eligible species |
| --- | --- |
| Earthworm | Perch, roach, tench, bream, chub, barbel, gudgeon |
| Sweetcorn | Carp, roach, tench, bream, crucian carp, barbel |
| Maggots | Perch, roach, bream, chub, barbel, dace, gudgeon |
| Bread | Carp, roach, bream, crucian carp, chub, dace |

Preferences are intersected with the location pool. Occasional off-bait catches
remain within that same feeder pool: no pike, trout or surface-only species are
chosen as feeder bites. Existing rare predator takeovers during retrieval remain
possible where the original predator rules allow them.

## Location distribution

| Location | Feeder pool |
| --- | --- |
| Lakeside | Perch, carp, roach, tench, bream, crucian carp, gudgeon |
| Lake Pier | Perch, carp, roach, bream |
| Gray Pier | Perch, carp, roach, tench, bream, crucian carp, gudgeon |
| Bell Park Pier | Perch, carp, roach, tench, bream, crucian carp, chub, gudgeon |
| Meadow Bend | Roach, chub, barbel, dace, gudgeon |

Meadow Bend adds roach, barbel and gudgeon to its overall roster. Its classic
fly pool remains brown trout, grayling, chub and dace. Boulder Run retains its
fast-water trout/grayling fly setup. Coastal locations do not offer this coarse
cage feeder; surf ledger tackle remains a separate future method.

These are authored gameplay habitats, not claims about fish present in the
photographed locations. The method/bait design draws on
[Angling Scotland's common-bream guidance](https://anglingscotland.org.uk/fish/bream-common/),
which describes groundbait, feeder methods and these coarse hook baits;
[Canal & River Trust's barbel profile](https://canalrivertrust.org.uk/things-to-do/fishing/caring-for-our-fish/freshwater-fish-species/barbel),
which describes river-bottom habitat and swim feeders; and
[Angling Trust's maggot-feeder example](https://anglingtrust.net/2016/03/03/grubbing-around-for-barbel-trying-something-different-by-james-roche/).
Exact pools, depths, weights and timing are game-design choices.

## Assets and multiplayer

`tools/build_feeder.py` authors the cage, lead shoe, swivel and packed-groundbait
texture in Blender. `source/feeder.blend` retains the source. The rod builder adds
four feeder variants; eight tapered runtime segments form the quiver tip in one draw call. Rod
cork retains its texture; cage, steel and lead use separate metallic/roughness
materials. No dynamic rigid-body chain or extra shadow-casting lights are needed.

The fly reel no longer contains the spinning-reel spindle. Its short direct
crank and grip pivot now sit against the spool face. Both unfolded and folded
fly models were regenerated, and controller reeling tests cover the new pivot.

Protocol **7** adds the selected rig. Other players see the same cage, rod and
hook bait; floats and fly-line strips remain hidden for feeder mode. Server
validation rejects unsupported rig/location/bait combinations, method changes
inside a catch attempt, and impossible feeder species. The separate dedicated
server is rebuilt without bundling these visual assets. Update clients and
server together.

## Verification

- `tests/feeder_fishing.gd`: 3,870 checks of location/bait pools, settling, feed
  deposits and decay, recasts, hook setting, rig locking and server eligibility.
- `tests/feeder_interface.gd`: 209 headless checks / 214 with stereo capture validation, including tracked joystick press/selection/release, neutral
  and focus cancellation, stable input anchors, remote cage/bait visibility,
  travel fallback, invalid wire states and stereo captures.
- Existing fly controls, fly fishing, population, tackle replication, network
  guards, leaderboard and core simulation suites cover regressions.

Stereo captures use simulated Monado OpenXR. Physical-headset comfort and
performance still need playtesting. Close-up asset inspection captures use a
small test-only fill light to expose surface detail; gameplay adds no such light.

The full multiplayer integration passed with the separate server and with an
ad-hoc host, including late-joining clients seeing the feeder and its hook bait.
Server leaderboard restart/identity tests passed. All 17 pictograms passed 97
headless import, mipmap, state and preference checks. The rod/environment suite
passed 58 checks; its older wildlife assertion was limited to photographed-shore
foregrounds, as the two authored rivers do not contain that wildlife node.

The synthetic OpenXR runtime reports its existing session-stop and interaction
profile cleanup warnings after captures complete.

Inspection captures: [radial, left eye](validation/feeder/radial_eye0.png),
[radial, right eye](validation/feeder/radial_eye1.png),
[cage and groundbait](validation/feeder/cage_eye0.png),
[feeder rod](validation/feeder/feeder-rod_eye1.png),
[corrected fly crank](validation/feeder/fly-reel-crank_eye0.png).
