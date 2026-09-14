# Real AI Fishing

A Godot 4.7 VR fishing prototype built with Godot MCP and Blender MCP. 18 real fish species, 14 catchable at each location, six bait choices, four selectable photographed waterside settings, four distinct walkable 3D foregrounds, selectable VRM avatars, a tracked rod and an end-to-end bait → cast → bite → strike → fight → land → release loop.

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
| Cast | Look toward open water; hold right trigger, swing rod forward, release | Space or Cast Line |
| Set hook | Lift rod sharply during the 1.8-second bite window | Space |
| Reel | Hold left grip near the reel; circle left hand in the crank plane | Hold R or left mouse |
| Counter a fish | Sweep rod left/right or lift as prompted | Left / Right / Up arrow |
| Aim | Move/rotate the right controller, full 6DoF | Right mouse drag |
| Field Guide | Left grip near lower handle at left hip; release to dock | G to open/close |
| Guide camera / shutter / selfie | While held: left trigger / right trigger / right A | While open: C / Space / F |
| Browse Field Guide | Left X/Y or either joystick while holding | Left/right arrows |
| Inspect caught fish | Hold left grip to bring fish to left hand; release grip to hang it from rod | Automatic display |
| Rotate caught fish | Either joystick: spin around vertical axis | Automatic rotation |
| Release / retry | Right A (left Y also works) | Space or button |
| Quit | Runtime system menu | Escape |

VR casting aims along the horizontal direction at the **center of the headset view**, with no eye tracking. Forward rod-tip motion sets casting power; both translating and rotating the controller can produce a cast. Looking toward the shore rejects the cast.

In VR, landed fish hang head-up below the rod tip on the line. Hold left grip to grasp the string 8 cm above the fish’s mouth; lift your hand to inspect the fish hanging beneath it; releasing grip returns it to the rod. The fish stays vertical and head-up in both positions, regardless of hand tilt. Either joystick axis spins it around the vertical axis at up to about 103°/s, with a deadzone; stick walking and turning are suppressed while a catch is displayed. Physical room-scale movement remains available. Right A releases the catch and restores stick locomotion.

Keep tension in the green band. Stop reeling during runs; resume before the line becomes completely slack. Directional counters reduce stamina and tension. A tired fish can be landed inside 1.6 m. Prolonged extreme tension snaps the line; slack lets the hook slip. Catch records persist in Godot's `user://journal.json`.

Open **V → Locations** (VR: **right B → Locations**) to choose Lakeside, Lake Pier, Gray Pier or Bell Park Pier. Select **Fish here** while ready to cast. Each spot has its own lighting and water preset; selection persists, and catches record their location. Walk a gravel cove at Lakeside, a concrete harbour quay at Lake Pier, a weathered reed boardwalk at Gray Pier, or a moored fishing boat at Bell Park Pier. Travel places you at a safe arrival point on the new model.

A handheld **Field Guide** records discovered fish, their names, descriptions, species silhouettes and your longest specimen of each species. Smaller or equal catches never replace the record. Existing catches populate it from the saved journal. In VR, grab the lower handle at your left hip with left grip; the hand stays below the screen and controls. Fishing pauses while inspecting. See [Field Guide details and captures](docs/FIELD_GUIDE.md).

## Walking and avatars

Each location has its own walkable floor, obstacles and protected water edges. Photographed gravel, concrete and timber textures give the authored geometry local surface detail. The boat stays stationary for VR comfort. See [foregrounds](docs/FOREGROUNDS.md) for images and dimensions. A capsule handles ground and obstacle collision; room-scale head offsets update the capsule without doubling physical movement. Movement speed is 2 m/s. Snap turns pivot about the head; enable **Smooth turn** in the avatar menu for continuous 75°/s turning. Opening the menu pauses both movement and fishing.

New profiles start with **SharkPerson**, the bundled CC0 avatar by Polygonal Mind. Existing avatar selections are preserved. Choose SharkPerson, **Vita**, or **Victoria Rubin**, or use **Import .vrm** to select a local avatar. The Godot VRM 2.0.1 plugin supports VRM 0.x and 1.0 humanoids at runtime. The file picker is an OS desktop dialog; in PC VR, select the file on your monitor, then continue in the headset. Bundled/cached avatars are directly selectable through the in-world VR panel.

The hard limit is **25,000,000 bytes per VRM**, including embedded textures. Files above the limit are rejected before model decoding/caching; the cached copy and every subsequent load are checked again. Use self-contained binary VRMs with embedded textures and a humanoid skeleton. Imports are copied into `user://avatars/`; the equipped selection persists in `user://avatar.cfg`. Rejected models do not replace the active avatar.

The avatar body follows the player, with basic two-bone arm/leg IK, tracked head orientation, crouch adjustment, a procedural walking stride and grip curl. Visible hands belong to the selected VRM. First-person meshes exclude the head through the plugin's layer split; the picker preview shows the full model. Optional full-body and finger trackers supplement estimated joints; terrain-aware feet and reach limits provide a fallback when trackers are absent. Avatar proportions and controller grip orientations still need checking on a physical headset.

Twelve real freshwater species are catchable across four distinct rosters of ten species each. Each cast selects with equal probability from the intersection of its location roster and bait pool. Earthworm, sweetcorn and spinner are joined by maggots, bread and wet flies. See [location rosters and all bait choices](docs/LOCATION_SPECIES.md). Primary bait assignments and reference sizes:

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

- Four real 2K waterside panoramas, animated 3D water, and distinct textured cove, quay, boardwalk and boat models connected to modeled shore.
- Room-scale tracked head and controller poses; rod follows the right hand. Off-hand reeling is measured in rod-local coordinates so moving the rod does not itself turn the crank. Tracking loss pauses the simulation; re-grabs and tracking jumps reset the reel sample.
- Bite timing, directional responses, fish runs, stamina, line tension, win/loss/retry and local catch persistence. Audio and controller vibration mark bites and successful counters.
- World-space VR status and avatar panels, a separate desktop interface, collision-based free locomotion, and selectable runtime VRM avatars with visible hands.

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

For future exported builds, include the raw `assets/avatars/*.vrm` files in the export filter: runtime loading uses the original VRM bytes, not only Godot's imported scene cache. Standalone headset file browsing/export packaging is not provided yet.

Meta avatar option research: [Quest and PC feasibility](docs/META_AVATARS_FEASIBILITY.md). This is an integration assessment; current builds use VRM avatars.

## Multiplayer and voice

Open the **Together** tab to host or join up to eight anglers. Casts, catches, avatars, tracked head/hands and locomotion are shared; Fish Guide records stay local. Voice activation is the default for new profiles; saved choices are preserved. Listen only and push to talk (**T** / **left stick click**) remain available. Voice is positional within each location.

Run `./run.sh --server --port 24567` for a headless dedicated server. LAN/Internet connections use direct UDP; Internet hosts need port forwarding or a reachable server. See [setup, controls and limitations](docs/MULTIPLAYER.md) and [FPSloppa code reuse](docs/FPSLOPPA_REUSE.md).

## Avatar tracking

The **Tracking** tab enables FPSloppa-derived body tracking (native XR, Vive roles, SlimeVR OSC), finger tracking, VRM visemes, eye/face expressions, terrain-aware leg IK and seated/standing recentering. Hold a steady T-pose while idle to calibrate available full-body trackers. These poses and expressions replicate in multiplayer; casting continues to aim through the center of the viewpoint. [Controls, runtime requirements and validation](docs/AVATAR_TRACKING.md).

## Field station menu and ambience

Open the menu with **V** on desktop or **right B** in VR. Five tabs—**Avatar**, **Waters**, **Together**, **Tracking**, and **Sound**—share a pine-green, cream and brass field-station theme. FPSloppa-derived selectors and drag scrolling work inside the VR panel; focusing a connection text field opens a controller-operated keyboard.

Each location has a distinct 128-second water, bird and wind soundscape. Travel crossfades the surroundings over two seconds; occasional timber creaks have a position in the pier or boat scene. **Sound** controls environment volume and mute independently of voice chat. Preferences persist locally. See [sources, preparation and checks](docs/PRESENTATION.md).

## Fishing feedback

Casting swishes, crank-speed reel sounds and positional fight/landing splashes accompany the minigame. Surface wakes show the fish's escape direction: pull opposite a sideways wake, or lift against an outward escape. Blue line color indicates slack; red indicates high tension. Ease reeling during runs while keeping enough tension to hold the hook. [Mechanics comparison and validation](docs/FISHING_FEEDBACK.md).

## Soft lighting and shadows

All four foregrounds use baked sky/bounce lighting, static sun shadows and AO, with restrained normal maps and broad material highlights. FPSloppa-derived MToon lighting helps avatars fit those surroundings. **Avatar → Moving shadows** selects soft contact blobs or dynamic shadows; static scenery shadows remain baked in either mode. [Pipeline, previews and performance comparison](docs/ENVIRONMENT_LIGHTING.md).

## Release downloads

Windows, Linux, Quest and Pico packages are published on the [GitHub releases page](https://github.com/jebot-git/raifslop/releases). Desktop archives include VR, desktop and dedicated-server launchers. Quest/Pico APKs are separately signed ARM64 sideload builds. See [release and build instructions](docs/RELEASE.md).

The latest visual pass adds [thirteen reconstructed fish](docs/PHOTOGRAPHIC_FISH.md), [realistic spinning tackle, native 4K panoramas and animated wildlife](docs/SCENERY_DETAIL.md). The original four additional fish retain their existing appearance.
