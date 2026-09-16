# Real AI Fishing

A Godot 4.7 VR fishing prototype built with Godot MCP and Blender MCP. Freshwater and marine fish, six bait choices per habitat, eight photographed waterside settings plus two rivers, distinct walkable 3D foregrounds, selectable VRM avatars, a tracked rod and an end-to-end bait → cast → bite → strike → fight → land → release loop.

Open `project.godot` in Godot 4.7.2 and press F6/F5, or launch:

```bash
./run.sh --desktop   # Keyboard/mouse practice, even with a simulated XR runtime installed
./run.sh             # OpenXR; start your headset's PC VR runtime first
```

Set `GODOT_BIN` to your engine executable on another machine. The project uses Mobile/Vulkan rendering and a saved OpenXR default action map. Compatibility rendering on the development machine failed stereo shader compilation; use Mobile for VR. If no OpenXR interface initializes, the game falls back to desktop controls. A simulated runtime may initialize without usable controllers; use `--desktop` in that case.

Catches now earn **shekels** based on species rarity and specimen size. Open **Field station → Tackle** to buy rods with stronger lines and faster fish fatigue. Species have different stamina capacities; successful counters stop runs and delay the next escape attempt. [Rewards and tackle](docs/TACKLE_AND_REWARDS.md).

## Controls

| Action | VR (Touch-style names) | Desktop |
|---|---|---|
| Walk / strafe | Left thumbstick; head-relative | WASD |
| Turn | Right thumbstick; 30° snap by default | Q / E |
| Look around | Headset tracking | Middle mouse drag |
| Avatar, locations & movement menu | Right B; point right controller and press trigger | V or click Avatar & Locations |
| Choose bait | Left X cycles while ready | 1–6 or click a bait |
| Cast | Aim at the water marker; hold right trigger, sweep back then forward, release | Right-drag to aim; hold Space for the backswing, then release |
| Set hook | Lift rod sharply during the 1.8-second bite window | Space |
| Reel | Hold left grip or trigger near the reel; hand snaps to the handle; circle to wind | Hold R or left mouse; add Shift to wind faster |
| Counter a fish | Sweep rod left/right or lift as prompted | Left / Right / Up arrow |
| Aim | Move/rotate the right controller, full 6DoF | Right mouse drag |
| Field Guide | Left grip near lower handle at left hip; release to dock; unavailable during bites/fights | G to open/close; unavailable during bites/fights |
| Guide camera / shutter / selfie | While held: left trigger / right trigger / right A | While open: C / Space / F |
| Browse Field Guide | Physically press ‹ / ›, left X/Y, or either joystick while holding | Left/right arrows |
| Inspect caught fish | Hold left grip to bring fish to left hand; release grip to hang it from rod | Automatic display |
| Rotate caught fish | Either joystick: spin around vertical axis | Automatic rotation |
| Release / retry | Right A (left Y also works) | Space or button |
| Read tutorial | Right B → Tutorial | V → Tutorial |
| Quit | Right B → Quit game | Escape or menu Quit game |

VR casting projects the **center of the headset view** onto the water, with no eye tracking. The water marker is the landing destination, within a 5–24 metre reach. Hold the trigger, sweep the rod back then forward, and release. Desktop uses a held Space backswing and release, with right-drag controlling the marker. Looking toward the shore rejects the cast.

In VR, landed fish hang head-up below the rod tip on the line. Hold left grip to grasp the string 8 cm above the fish’s mouth; lift your hand to inspect the fish hanging beneath it; releasing grip returns it to the rod. The fish stays vertical and head-up in both positions, regardless of hand tilt. Either joystick axis spins it around the vertical axis at up to about 103°/s, with a deadzone; stick walking and turning are suppressed while a catch is displayed. Physical room-scale movement remains available. Right A releases the catch and restores stick locomotion.

Use the line colour and haptic feedback to judge tension. Stop reeling during runs; resume before the line becomes completely slack. Directional counters reduce stamina and tension. Retrieve tired fish all the way to the shoreline or pier edge to land them; exhaustion alone never awards a catch. In fly fishing, winding the reel outside an inward rush or final retrieval adds a steep tension penalty; strip line during the fight. Prolonged extreme tension snaps the line; slack lets the hook slip. Catch records persist in Godot's `user://journal.json`.

Strong repeated rod-hand pulses mean your counter is working; releasing or pulling the wrong way stops them. The left hand feels crank detents while reeling. A quiet water ripple announces the hooked fish and escape attempts. During submerging moves, follow the prompt: **stop reeling** against a deep pull, or **reel faster** when the fish rushes inward and creates slack. Dives sink the float; inward rushes leave a surface wake toward the angler. Each move gives a brief warning before tension changes rapidly.

Fish occupy a 3×3 grid of nine sectors. Different species start in separate quadrants and migrate independently between neighboring sectors every 25–55 seconds. Subtle feeding ripples mark sectors holding fish attracted to your bait. There is a 15% chance of an incidental off-bait species when one exists in the location. Repeated catches rapidly deplete that species; populations recover over about four minutes and survive recasts and travel during the session. Ordinary bite waits vary from 4–32 seconds, with quiet or depleted sectors taking longer. River takes keep a shorter 4–14 second base window, modified by drift quality. [Tuning and validation](docs/FISHING_DISTRIBUTION.md).

Open **V → Locations** (VR: **right B → Locations**) to choose Lakeside, Lake Pier, Gray Pier or Bell Park Pier. Select **Fish here** while ready to cast. Each spot has its own lighting and water preset; selection persists, and catches record their location. Walk a gravel cove at Lakeside, a concrete harbour quay at Lake Pier, a weathered reed boardwalk at Gray Pier, or a moored fishing boat at Bell Park Pier. Travel places you at a safe arrival point on the new model.

A handheld **Field Guide** records discovered fish, their names, descriptions, species silhouettes and your longest specimen of each species. Smaller or equal catches never replace the record. Existing catches populate it from the saved journal. In VR, grab the lower handle at your left hip with left grip; the hand stays below the screen and controls. Fishing pauses while inspecting. See [Field Guide details and captures](docs/FIELD_GUIDE.md).

## Walking and avatars

Each location has its own walkable floor, obstacles and protected water edges. Photographed gravel, concrete and timber textures give the authored geometry local surface detail. The boat stays stationary for VR comfort. See [foregrounds](docs/FOREGROUNDS.md) for images and dimensions. A capsule handles ground and obstacle collision; room-scale head offsets update the capsule without doubling physical movement. Movement speed is 2 m/s. Snap turns pivot about the head; enable **Smooth turn** in the avatar menu for continuous 75°/s turning. Opening the menu pauses both movement and fishing.

New profiles start with **SharkPerson**, the bundled CC0 avatar by Polygonal Mind. Existing avatar selections are preserved. Choose SharkPerson, **Vita**, or **Victoria Rubin**, or use **Import .vrm** to select a local avatar. The Godot VRM 2.0.1 plugin supports VRM 0.x and 1.0 humanoids at runtime. In VR, **Import .vrm** opens a folder browser inside the headset, with Home, Downloads, Up and an editable path. Select a folder or VRM and press Open. Desktop mode uses the OS file picker. Bundled/cached avatars are directly selectable through the in-world VR panel.

The hard limit is **25,000,000 bytes per VRM**, including embedded textures. Files above the limit are rejected before model decoding/caching; the cached copy and every subsequent load are checked again. Use self-contained binary VRMs with embedded textures and a humanoid skeleton. Imports and downloaded models share the external `data/vrm/` folder beside the desktop executable (`res://data/vrm/` in the editor, app external files on Android). Drop VRMs there before launch or use Import VRM / VRM folder. `--asset-root PATH` overrides the data root. Older avatar caches are copied across without deleting originals, and the equipped selection persists in `user://avatar.cfg`. Rejected models do not replace the active avatar.

The avatar body follows the player, with basic two-bone arm/leg IK, tracked head orientation, crouch adjustment, a procedural walking stride and grip curl. Visible hands belong to the selected VRM. First-person meshes exclude the head through the plugin's layer split; the picker preview shows the full model. Optional full-body and finger trackers supplement estimated joints; terrain-aware feet and reach limits provide a fallback when trackers are absent. Avatar proportions and controller grip orientations still need checking on a physical headset.

Eighteen fish species are available across four distinct rosters of fourteen species each. Each cast selects with equal probability from the intersection of its location roster and bait pool. Earthworm, sweetcorn and spinner are joined by maggots, bread and wet flies. See [location rosters and all bait choices](docs/LOCATION_SPECIES.md). Primary bait assignments and reference sizes:

| Bait | Species | Reference length / weight |
|---|---|---|
| Earthworm | European perch (*Perca fluviatilis*) | 32 cm / 0.65 kg |
| Earthworm | Common roach (*Rutilus rutilus*) | 25 cm / 0.25 kg |
| Sweetcorn | Common carp (*Cyprinus carpio*) | 58 cm / 3.8 kg |
| Sweetcorn | Tench (*Tinca tinca*) | 42 cm / 1.4 kg |
| Sweetcorn | Common bream (*Abramis brama*) | 45 cm / 1.2 kg |
| Spinner | Northern pike (*Esox lucius*) | 72 cm / 2.9 kg |
| Spinner | Zander (*Sander lucioperca*) | 60 cm / 2.0 kg |
| Earthworm | Rudd (*Scardinius erythrophthalmus*) | 28 cm / 0.35 kg |
| Sweetcorn | Crucian carp (*Carassius carassius*) | 30 cm / 0.65 kg |
| Earthworm | European chub (*Squalius cephalus*) | 40 cm / 0.90 kg |
| Spinner | Rainbow trout (*Oncorhynchus mykiss*) | 42 cm / 1.10 kg |
| Spinner | Brown trout (*Salmo trutta*) | 38 cm / 0.80 kg |

Catch lengths vary ±15%; weight scales with the cube of that size variation. Roach and bream are easier to bring in; tench and zander pull farther during runs and resist reeling more. Landed catches show common and scientific names, length and weight, and persist in the existing journal. Bait pools, sizes and fight strength are simplified game choices, not a survey of the photographed lake or an ecological simulation.

The perch uses an attributed third-party model; carp and pike currently use simple geometric stand-ins. Nine additional fish have textured models, displayed at the caught length. Rudd, crucian carp, chub and both trout have authored scale/spot patterns and species-specific profiles ([gallery](docs/additional_fish.png)); roach and tench have authored bodies with detailed generated skin textures, while bream and zander use licensed, optimized assets. See [species references and asset details](docs/FISH_SPECIES.md) and the [Blender model gallery](docs/fish_species.png).

## Scope of this first version

- Eight native 8K waterside panoramas with animated water and walkable foregrounds, including a rocky coast and walkable sunrise beach. [Coastal locations](docs/COASTAL_LOCATIONS.md) have distinct marine rosters with twelve [marine species](docs/MARINE_EXPANSION.md) and saltwater baits.
- Room-scale tracked head and controller poses; rod follows the right hand. Off-hand reeling is measured in rod-local coordinates so moving the rod does not itself turn the crank. Tracking loss pauses the simulation; re-grabs and tracking jumps reset the reel sample.
- Bite timing, directional responses, fish runs, stamina, line tension, win/loss/retry and local catch persistence. Audio and controller vibration mark bites and successful counters.
- A world-space VR menu, handheld guide status, a separate desktop interface, collision-based free locomotion, and selectable runtime VRM avatars with visible hands.

The panorama has rotational scenery only: it does not acquire 6DoF parallax when the player moves. The cove, quay, boardwalk, boat, rod and water are actual 3D geometry. This is a hybrid scene, not a full reconstruction of a surveyed fishing spot. Gaussian splat rendering, skeletal fish animation, bendable rod physics, fish ecology and real-headset performance tuning are future work. Textured carp/pike models and standalone Quest/Pico exports are included. “AI” is the project name; fish behavior is local rule-based simulation, with no external AI service.

The game takes inspiration from Real VR Fishing's broad bait/timing/tension/gesture loop. It does not include that game's code, branding or assets.

## Development

`scripts/fishing_session.gd` contains the independent simulation. `reel_tracker.gd` measures crank motion. `locomotion.gd` handles movement, `shore.gd` loads the selected foreground and collision manifest, and `avatar_library.gd`, `avatar_rig.gd`, `avatar_ik.gd` and `avatar_menu.gd` handle VRMs. `main.gd` connects these systems; `hud.gd` draws the fishing interface. `source/fishing_assets.blend` holds the optimized source assets; `.gdignore` prevents Blender from being required for normal Godot imports. The game loads exported GLBs.

```bash
godot --headless --path . --xr-mode off --script res://tests/run_tests.gd
godot --headless --path . --xr-mode off --script res://tests/avatar_locomotion.gd
XDG_DATA_HOME=/tmp/real-fishing-species godot --headless --path . --xr-mode off --script res://tests/fish_species.gd
XDG_DATA_HOME=/tmp/fishing-locations ./run.sh --desktop --headless --script res://tests/locations.gd
godot --headless --path . --xr-mode off --quit-after 30
```

See [asset credits](ASSET_CREDITS.md) for licenses and [location pipeline](docs/LOCATION_PIPELINE.md) for sources, preparation and runtime captures. Native synthetic stereo/controller tests and eye captures are documented in [validation](docs/VALIDATION.md). The included Godot AI editor addon retains its own license and enables further MCP editing.

For future exported builds, include the raw `assets/avatars/*.vrm` files in the export filter: runtime loading uses the original VRM bytes, not only Godot's imported scene cache. Quest/Pico sideload packages are included; native file browsing still depends on the platform.

Meta avatar option research: [Quest and PC feasibility](docs/META_AVATARS_FEASIBILITY.md). This is an integration assessment; current builds use VRM avatars.

## Multiplayer and voice

Open the **Together** tab to host or join up to eight anglers. Casts, catches, avatars, tracked head/hands and locomotion are shared; Fish Guide records stay local. Voice activation is the default for new profiles; saved choices are preserved. Listen only and push to talk (**T** / **left stick click**) remain available. Voice is positional within each location. Hold **B**, or grab the left-shoulder radio and hold its trigger in VR, to talk to all waters. Radio requires the updated protocol-3 server and clients.

Run `./run.sh --server --port 24567` for a headless dedicated server. LAN/Internet connections use direct UDP; Internet hosts need port forwarding or a reachable server. See [setup, controls and limitations](docs/MULTIPLAYER.md) and [FPSloppa code reuse](docs/FPSLOPPA_REUSE.md).

## Avatar tracking

The **Tracking** tab enables FPSloppa-derived body tracking (native XR, Vive roles, SlimeVR OSC), finger tracking, VRM visemes, eye/face expressions, terrain-aware leg IK and seated/standing recentering. Hold a steady T-pose while idle to calibrate available full-body trackers. These poses and expressions replicate in multiplayer; casting continues to aim through the center of the viewpoint. [Controls, runtime requirements and validation](docs/AVATAR_TRACKING.md).

## Field station menu and ambience

Open the menu with **V** on desktop or **right B** in VR. Six tabs—**Avatar**, **Waters**, **Tackle**, **Together**, **Tracking**, and **Sound**—share a pine-green, cream and brass field-station theme. FPSloppa-derived selectors and drag scrolling work inside the VR panel; focusing a connection text field opens a controller-operated keyboard.

Each location has a distinct 128-second water, bird and wind soundscape. Travel crossfades the surroundings over two seconds; occasional timber creaks have a position in the pier or boat scene. **Sound** controls environment volume and mute independently of voice chat. Preferences persist locally. See [sources, preparation and checks](docs/PRESENTATION.md).

## Fishing feedback

Casting swishes, crank-speed reel sounds and positional fight/landing splashes accompany the minigame. Surface wakes show the fish's escape direction: pull opposite a sideways wake, or lift against an outward escape. Blue line color indicates slack; red indicates high tension. Ease reeling during runs while keeping enough tension to hold the hook. [Mechanics comparison and validation](docs/FISHING_FEEDBACK.md).

## Soft lighting and shadows

All eight photographed foregrounds use baked sky/bounce lighting, static sun shadows and AO, with restrained normal maps and broad material highlights. FPSloppa-derived MToon lighting helps avatars fit those surroundings. Moving players use soft contact shadows. Dynamic player shadows and their setting have been removed; static scenery shadows remain baked. [Pipeline, previews and performance comparison](docs/ENVIRONMENT_LIGHTING.md).

## Release downloads

Windows, Linux, Quest and Pico packages are published on the [GitHub releases page](https://github.com/jebot-git/raifslop/releases). Desktop archives include VR, desktop and dedicated-server launchers. Quest/Pico APKs are separately signed ARM64 sideload builds. See [release and build instructions](docs/RELEASE.md).

The latest visual pass adds [thirteen reconstructed fish](docs/PHOTOGRAPHIC_FISH.md), [realistic spinning tackle, native 8K panoramas and animated wildlife](docs/SCENERY_DETAIL.md). The original four additional fish retain their existing appearance.


VR interaction fixes: the Guide's handle docks at the left hip, its held pose follows the controller's thumb/palm axes, and its two buttons accept right-index fingertip presses, using native hand tracking or the visible avatar finger with controllers. In camera mode, ‹ toggles selfie and › takes a photo. Reel animation follows both directions of physical winding. Menu pages support right-stick scrolling, visible scrollbars, trigger dragging, and fixed ↑/↓ buttons. The fixed menu header has a Tutorial button; instructions appear inside the menu, with no automatic popup. [Tracking refresh and tests](docs/AVATAR_TRACKING.md#september-2026-tracking-refresh).

Tester feedback update: counters drain hidden resistance through sustained pulls, with rumble for bites, fights and tension rises. Catch models match reported length. The Fish Guide now holds location, shekels and equipment status; tutorial instructions are available only through the menu’s Tutorial button. The menu footer has **Quit game**. Location ambience and panorama-matched water have been rebuilt. [Behavior and validation](docs/TESTER_FEEDBACK.md).

Rod holster: bring the right hand to the right hip and squeeze grip to fold/stash the rod; release and squeeze again there to pick it up. Stashing cancels the current line and rearms the selected bait. Fully retrieving an empty line also readies the next cast. The hand remains free while the rod is stashed.

Benches and boat seats are noncollidable. Successful travel closes the menu. VR has no floating status/tracking window; holding a catch in the left hand shows its name, length and weight as text above the fish.

All six locations ship native 8192 × 4096 HDR panoramas through one standard loading path, with restrained sharpening, mipmapped filtering and shared sky/water color processing. Holding the guide keeps the rod in the right hand; stashing is explicit at the right hip. [Visual settings and validation](docs/PANORAMA_QUALITY.md).

### Fly-fishing rivers

Meadow Bend and Boulder Run add fly casting, dry flies/nymphs, drifting, upstream mending and line stripping. Nymphs use a small strike indicator; dry flies signal surface takes. [Controls, river environments and validation](docs/FLY_FISHING.md).

## Additional coastal waters

**Secluded Cove** and **Tidal Strand** are available under **V → Waters → Fish here**
(VR: right B → Waters). Secluded Cove has a sheltered sandy casting pocket framed by
granite boulders; Tidal Strand has a broad pale-sand shore, misty hills and driftwood.
Both use native 8K Poly Haven photographs, authored walkable shores, measured baked
lighting, generated dune grass and kelp details, recorded surf and distinct marine
rosters. [Sources, rebuild instructions and captures](docs/COASTAL_EXPANSION.md).

## Shore BBQ prototype branch

`prototype/shore-bbq` includes Secluded Cove and Tidal Strand and a shared leisure BBQ at all ten waters. Open **V / right B → BBQ → Start BBQ & visit**, or press **H** on desktop. Finish the current cast before visiting; your rod is stowed and bait stays ready. Use either pair of tongs to grill, turn and serve free food. Everyone at the location can watch or join. See [prototype controls, scope and validation](docs/BBQ_PROTOTYPE.md). This branch uses multiplayer protocol **4**; run matching prototype clients and servers. Published 0.1.8 remains separate.
