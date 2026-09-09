# Resume development

This repository is the checkpoint of **Real AI Fishing**, created on 9 September 2026.

## Open and run

1. Clone this private repository and open `project.godot` with Godot **4.7.2**.
2. Let Godot complete its first import. Godot VRM 2.0.1, its MToon dependency and Godot AI MCP addon are included.
3. For desktop practice, run `godot --path . --xr-mode off`. Alternatively set `GODOT_BIN` to your engine executable and run `./run.sh --desktop`.
4. For VR, start your OpenXR runtime and run the project normally. OpenXR is enabled; the renderer is Mobile/Vulkan.

Original development path: `/home/blux/Documents/Real AI Fishing`. The launcher has a local engine fallback; set `GODOT_BIN` on another machine. `tools/start_blender.py` is a local MCP setup helper, not a game dependency. Adapt its addon path for a different Blender installation.

## Current checkpoint

- Photographed lakeside sky, animated water, scanned rocks, dock and authored walkable shore with collision.
- Free locomotion, head-relative movement, snap/smooth turning, room-scale capsule correction.
- Fishing loop: bait, cast, timed strike, gesture counters, reel, tension/stamina, land/release and local catch journal.
- VRM picker, Vita/Victoria avatars, user imports capped at **25,000,000 bytes**, persistent avatar selection, visible hands and basic head/arm/leg posing.
- Godot MCP and Blender MCP were used; external assets and plugin licenses are recorded in `ASSET_CREDITS.md`.

Read `README.md` for controls and architecture, and `docs/VALIDATION.md` for verification details. `docs/avatar_picker.png` and `docs/walkable_shore.png` are runtime captures. `source/fishing_assets.blend` retains the packed Blender source; it is excluded from Godot's automatic importer by `.gdignore`.

## Validation to rerun

```bash
godot --headless --path . --xr-mode off --script res://tests/run_tests.gd
godot --headless --path . --xr-mode off --script res://tests/avatar_locomotion.gd
godot --headless --path . --xr-mode off --quit-after 90
```

Last verified: **20 fishing checks + 24 avatar/locomotion checks passed**, and the headless main scene exited cleanly. Desktop rendering, avatar selection and simulated OpenXR startup/menu were inspected. A physical headset and controller validation is still needed.

## Outstanding work

- Test actual headset locomotion comfort, stereo appearance, controller ray UI, casting/reeling, hand orientation and performance.
- Improve scenery, fish models/animation and avatar IK calibration. Carp/pike still use geometric stand-ins; trees and shore props are authored prototype geometry.
- Additional real locations and Gaussian splat support are not implemented. The sky panorama has no translational parallax.
- Standalone Android packaging and headset-native file browsing are not implemented. Future exports must include raw `assets/avatars/*.vrm` for runtime loading.

Godot's `.godot` cache, Blender backup files and machine-local `user://` saves are intentionally not versioned. Imported personal avatars and catch records stay on the local machine; the two bundled avatar assets are included.
