# Fly fishing and river locations

Fly mode activates automatically at **Meadow Bend** and **Boulder Run**. It uses the existing tackle progression, fish assets, journal and fight mechanics. It adds dry-fly/nymph presentations, authored river currents, stripping, upstream mending and a lightweight animated casting loop.

## Controls

| Action | VR | Desktop |
| --- | --- | --- |
| Fly cast | Hold right trigger, sweep back then forward, release | Hold SPACE at least 0.2 seconds, then release |
| Extend cast | Repeat the back/forward stroke before releasing | A longer hold adds distance, up to the basic cast limit |
| Strip line | Hold left grip and pull the hand toward you; release to reach forward | R or left mouse button; Shift for faster retrieval |
| Mend upstream | Sweep rod upstream, toward world left in the initial river view | Fresh LEFT arrow press |
| Strike | Lift rod promptly when the fly/indicator signals a take | SPACE during the take |
| Change fly | Left X | 1: dry fly; 2: nymph |

The forward stroke must follow the backstroke within 1.5 seconds. Each completed stroke adds distance; casts remain within 8–20 metres. The HUD quick-cast button supplies an accessible single-click cast. Normal fishing controls return when travelling to a lake/coast. Menus, guide use, holstering and tracking loss pause fishing and cancel unfinished cast/strip input.

## Presentation and indicator

Dry flies are visible at the surface without a conventional float. A take draws the fly under, makes a subtle ripple and gives a gentler bite pulse. Nymphs use a bead-headed fly beneath a small strike indicator, about one third of the original float's size. On a take the indicator pauses with the drift and dips. Strike windows are 1.25 seconds for dry flies and 1.6 seconds for nymphs.

The line is rendered as a short sampled curve, with an animated loop during casting and an upstream bow when mended. It is an authored approximation rather than a full flexible-line physics simulation. Fly line remains above the surface while drifting. Stripping produces reel/line audio and left-hand haptic detents, and the existing reel input remains available during fights.

## Currents, fish and landing

Meadow Bend has a slower central channel and gentler edges. Boulder Run has a faster channel and three sheltered downstream pockets associated with the visible boulders. Both flow downstream toward world +X. Nymphs travel somewhat more slowly than dry flies. Stronger differential current and active stripping increase drag; upstream mends reduce it, while downstream mends increase it. Mending has a 0.7-second cooldown.

Only productive channel water advances bite timing, weighted by drift quality and holding water. A fully dragging fly earns no bite progress. Retrieving into the bank or reaching 32 seconds ends the drift and permits another cast. Current adds a bounded load during fights, and fish positions remain inside the river channel. Landing stops short of the near bank.

| Location | Roster | Character |
| --- | --- | --- |
| Meadow Bend | Brown trout, grayling, chub, dace | Open gravel bank, grassy margins, sparse alders |
| Boulder Run | Rainbow trout, brown trout, grayling | Faster water, rock pockets, denser alder groups |

These are authored fictional river settings, not species surveys of the reused panoramic photography. Large-predator takeovers are excluded from these small-river rosters. Trout retain their jump opportunities and rapid-tug counters.

## Environment assets

The near bank, riverbed, opposite bank and boulders are deterministic runtime geometry in `scripts/river_foreground.gd`, with walkable-bank collision and a low edge barrier to prevent wading. Existing Lakeside and Bell Park HDRs supply distant light/landscape; the playable river channel is modeled and uses moving water shading.

The initial cone-tree blockout was replaced with original generated photographic-style alder and shrub cutouts. Shrubs occupy separated depth layers, with varied scale, yaw and mirroring. Shrubs now use three intersecting planes and distant alders two perpendicular planes. These stay fixed in the world, retaining silhouettes from side views and giving binocular/motion parallax. Shrub bases sample the modeled bank across their footprint and sink slightly below its lowest point; near-bank clumps are kept inland so none overhang unsupported water. Photographic color uses consistent shading across faces to avoid dark intersecting panels. There are two instanced vegetation draws per location, alpha cutout edges, mipmapped textures and subtle wind motion. Close banks blend damp gravel into a new grass/moss/pebble texture with an irregular transition. These are layered textured surfaces, not fully volumetric trees.

- [Built-in imagegen mode and exact prompts](river_image_prompts.json)
- [Saved files, original output paths and checksums](river_assets.json)
- Runtime textures: `assets/environment/rivers/river_shrubs.png`, `river_alder.png`, `river_bank.png`
- Original synthetic ambience: `assets/audio/ambience/meadow_bend.ogg`, `boulder_run.ogg`; reproducible using `tools/build_river_audio.py`.
- Location previews are rendered from the actual scenes by `tests/fly_fishing.gd -- --capture`.

## Validation and limitations

`tests/fly_fishing.gd` checks current flow, sheltered pockets, drift quality, mend benefit, cast timing, stripping, both fly types, successful takes and strikes, travel, actual cast acceptance, full river fights/landing, spawn collision, indicator sizing, normal-tackle restoration and depth-separated vegetation instances. Existing location/roster, simulation, tackle, predator, feedback and network-guard suites cover regression behavior. Standing and seated desktop Vulkan views were inspected; headset gesture feel, stereo appearance and performance still need physical-device validation. No release package was built for this change.
