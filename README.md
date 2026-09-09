# Real AI Fishing

A Godot 4.7 VR fishing prototype built with Godot MCP and Blender MCP. One photographed lakeside setting, a walkable 3D shore, selectable VRM avatars, a tracked rod and an end-to-end bait → cast → bite → strike → fight → land → release loop.

Open `project.godot` in Godot 4.7.2 and press F6/F5, or launch:

```bash
./run.sh --desktop   # Keyboard/mouse practice, even with a simulated XR runtime installed
./run.sh             # OpenXR; start your headset's PC VR runtime first
```

Set `GODOT_BIN` to your engine executable on another machine. The project uses Mobile/Vulkan rendering and a saved OpenXR default action map. Compatibility rendering on the development machine failed stereo shader compilation; use Mobile for VR. If no OpenXR interface initializes, the game falls back to desktop controls. A simulated runtime may initialize without usable controllers; use `--desktop` in that case.

## Controls

| Action | VR (Touch-style names) | Desktop |
|---|---|---|
| Walk / strafe | Left thumbstick; head-relative | WASD |
| Turn | Right thumbstick; 30° snap by default | Q / E |
| Look around | Headset tracking | Middle mouse drag |
| Avatar & movement menu | Right B; point right controller and press trigger | V or click Avatar & Movement |
| Choose bait | Left X cycles while ready | 1 / 2 / 3 or click a bait |
| Cast | Hold right trigger, swing rod forward, release | Space or Cast Line |
| Set hook | Lift rod sharply during the 1.8-second bite window | Space |
| Reel | Hold left grip near the reel; circle left hand in the crank plane | Hold R or left mouse |
| Counter a fish | Sweep rod left/right or lift as prompted | Left / Right / Up arrow |
| Aim | Move/rotate the right controller, full 6DoF | Right mouse drag |
| Release / retry | Right A (left Y also works) | Space or button |
| Quit | Runtime system menu | Escape |

Keep tension in the green band. Stop reeling during runs; resume before the line becomes completely slack. Directional counters reduce stamina and tension. A tired fish can be landed inside 1.6 m. Prolonged extreme tension snaps the line; slack lets the hook slip. Catch records persist in Godot's `user://journal.json`.

## Walking and avatars

Walk freely around the dock and the authored 25 × 15 m shoreline, with paths, benches, trees, rocks and perimeter railings. A capsule handles ground and obstacle collision; room-scale head offsets update the capsule without doubling physical movement. Movement speed is 2 m/s. Snap turns pivot about the head; enable **Smooth turn** in the avatar menu for continuous 75°/s turning. Opening the menu pauses both movement and fishing.

Choose **Vita** (14.2 MB) or **Victoria Rubin** (15.3 MB), or use **Import .vrm** to select a local avatar. The Godot VRM 2.0.1 plugin supports VRM 0.x and 1.0 humanoids at runtime. The file picker is an OS desktop dialog; in PC VR, select the file on your monitor, then continue in the headset. Bundled/cached avatars are directly selectable through the in-world VR panel.

The hard limit is **25,000,000 bytes per VRM**, including embedded textures. Files above the limit are rejected before model decoding/caching; the cached copy and every subsequent load are checked again. Use self-contained binary VRMs with embedded textures and a humanoid skeleton. Imports are copied into `user://avatars/`; the equipped selection persists in `user://avatar.cfg`. Rejected models do not replace the active avatar.

The avatar body follows the player, with basic two-bone arm/leg IK, tracked head orientation, crouch adjustment, a procedural walking stride and grip curl. Visible hands belong to the selected VRM. First-person meshes exclude the head through the plugin's layer split; the picker preview shows the full model. This is basic IK, not full-body tracking: elbow/knee positions are estimated, feet do not individually conform to arbitrary slopes, and targets beyond an avatar's limb reach are clamped. Avatar proportions and controller grip orientations still need checking on a physical headset.

Earthworm targets European perch (*Perca fluviatilis*), sweetcorn targets common carp (*Cyprinus carpio*), and spinner targets northern pike (*Esox lucius*). These are deliberately simplified game affinities and representative fish sizes, not a field guide or a survey of the photographed lake. The perch uses an attributed third-party model; carp and pike currently use simple geometric stand-ins.

## Scope of this first version

- Real 2K equirectangular lakeside photography, animated 3D water, a dock and an optimized scanned boulder.
- Room-scale tracked head and controller poses; rod follows the right hand. Off-hand reeling is measured in rod-local coordinates so moving the rod does not itself turn the crank. Tracking loss pauses the simulation; re-grabs and tracking jumps reset the reel sample.
- Bite timing, directional responses, fish runs, stamina, line tension, win/loss/retry and local catch persistence. Audio and controller vibration mark bites and successful counters.
- World-space VR status and avatar panels, a separate desktop interface, collision-based free locomotion, and selectable runtime VRM avatars with visible hands.

The panorama has rotational scenery only: it does not acquire 6DoF parallax when the player moves. The dock, shore rocks, rod and water are actual 3D geometry. This is a hybrid scene, not a full reconstruction of a surveyed fishing spot. Gaussian splat rendering, additional locations, lifelike carp/pike models, skeletal fish animation, bendable rod physics, fish ecology, multiplayer, standalone Android exports, and real-headset performance tuning are future work. “AI” is the project name; fish behavior is local rule-based simulation, with no external AI service.

The game takes inspiration from Real VR Fishing's broad bait/timing/tension/gesture loop. It does not include that game's code, branding or assets.

## Development

`scripts/fishing_session.gd` contains the independent simulation. `reel_tracker.gd` measures crank motion. `locomotion.gd` handles movement, `shore.gd` builds the walkable foreground, and `avatar_library.gd`, `avatar_rig.gd`, `avatar_ik.gd` and `avatar_menu.gd` handle VRMs. `main.gd` connects these systems; `hud.gd` draws the fishing interface. `source/fishing_assets.blend` holds the optimized source assets; `.gdignore` prevents Blender from being required for normal Godot imports. The game loads exported GLBs.

```bash
godot --headless --path . --xr-mode off --script res://tests/run_tests.gd
godot --headless --path . --xr-mode off --script res://tests/avatar_locomotion.gd
godot --headless --path . --xr-mode off --quit-after 30
```

See [asset credits](ASSET_CREDITS.md) for licenses and [location pipeline](docs/LOCATION_PIPELINE.md) for expansion notes. The included Godot AI editor addon retains its own license and enables further MCP editing.

For future exported builds, include the raw `assets/avatars/*.vrm` files in the export filter: runtime loading uses the original VRM bytes, not only Godot's imported scene cache. Standalone headset file browsing/export packaging is not provided yet.
