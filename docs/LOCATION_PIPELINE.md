# Photographed fishing locations

Four locations are playable: the original Lakeside plus Lake Pier, Gray Pier and Bell Park Pier. Open **V → Locations** on desktop, or **right B → Locations** in VR, select a preview and press **Fish here**. Finish the current cast and release the catch before travelling. Selection persists in `user://location.cfg`; new journal entries include location ID and display name. Older catch records remain readable.

## Procured assets — 14 September 2026

| Photograph | Creator | Use | Source coordinates (latitude, longitude) |
|---|---|---|---|
| [Lake Pier](https://polyhaven.com/a/lake_pier) | Alexander Scholten | Playable; sunrise harbour/lake | 47.650393, 9.472654 |
| [Gray Pier](https://polyhaven.com/a/gray_pier) | Sergey Rudavin | Playable; overcast reed-lined water | Not published |
| [Bell Park Pier](https://polyhaven.com/a/bell_park_pier) | Greg Zaal | Playable; reservoir and green hills | -28.955231, 29.437319 |
| [River Alcove](https://polyhaven.com/a/river_alcove) | Dimitrios Savva (photography), Jarod Guest (processing) | Reference only; too little visible water for the current foreground | -25.843463, 27.65949 |

These real photographs were downloaded through Blender MCP's Poly Haven asset library. All four assets are [CC0](https://polyhaven.com/license), permitting modification and redistribution. Coordinates and authors come from the source API; camera height is not published. The source names identify the photographs, without claiming a surveyed fishing venue or native fish population. Lighting descriptions are presentation presets.

## Preparation and runtime budget

The four playable sky originals live once under `assets/environment/locations/*_4k.hdr`, at native **4096 × 2048** resolution. `tools/prepare_locations.py` generates **768 × 384 JPEG** menu previews with AgX tone mapping from those originals; it does not resample the runtime sky. Source URLs and hashes are recorded in [native_4k.json](locations/native_4k.json), with original acquisition provenance in [sources.json](locations/sources.json).

The previous 2K runtime derivatives and unused River Alcove download were removed during release cleanup. Earlier optimization records describe the retired 2K stage. Browsing loads only small previews; location changes retain one active sky, with a 128-pixel reflection radiance map. Measured device performance remains an acceptance task.

`locations.gd` stores panorama paths, yaw, sky brightness, sunlight, ambient energy, water colour, roughness and ripple presets. `main.gd` applies them together with a distinct foreground GLB and collision layout, relocating the player to a safe arrival point. Current yaw values are 0° (Lakeside), -100° (Lake Pier), 108° (Gray Pier), and -72° (Bell Park Pier), calibrated against the default forward view. Lakeside uses a gravel cove, Lake Pier a concrete quay, Gray Pier a reed boardwalk, and Bell Park Pier a moored boat. See [foreground construction and captures](FOREGROUNDS.md). Travel cannot interrupt fishing or overwrite existing catch records. No network access is needed during play.

## Visual limits and expansion

These are hybrid scenes: a photographed sky plus authored 3D foreground. The panoramas provide rotational scenery but no translational parallax or surveyed collision. The foreground layouts are artistic interpretations; the distant shoreline transition and water reflections remain approximations; the photographs were not reconstructed into terrain. Each location has a distinct fourteen-species gameplay roster; these are not surveys of the source locations’ ecology. See [rosters](LOCATION_SPECIES.md).

River Alcove was evaluated as a reference and removed during release cleanup; its acquisition record remains for provenance. No Gaussian splat renderer is installed. For future scans, retain licenses, normalize metres/orientation in Blender, decimate and create LODs, then export modest GLB assets. For splats, first select a Godot renderer supporting stereoscopic OpenXR, validate sorting/depth/clipping and GPU budgets, and supply collision proxies.

## Verification and captures

`tests/locations.gd` covers all locations, texture bounds, persistence, light/water changes, foreground replacement and safe arrival, menu selection, active-cast rejection and journal round trips. Use a separate save directory:

```bash
XDG_DATA_HOME=/tmp/fishing-location-tests ./run.sh --desktop --headless --script res://tests/locations.gd
XDG_DATA_HOME=/tmp/fishing-location-captures ./run.sh --desktop --script res://tests/locations.gd -- --capture
```

Current foreground captures: [Lakeside](locations/lakeside_foreground.png), [Lake Pier](locations/lake_pier_foreground.png), [Gray Pier](locations/gray_pier_foreground.png), [Bell Park Pier](locations/bell_park_pier_foreground.png). See [validation](VALIDATION.md) for native OpenXR synthetic results and limitations.
