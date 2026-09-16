# Hybrid detail refinement — 16 September 2026

The latest four captured viewpoints were replayed in the isolated prototype. Simons now has an additional photographic rock formation behind its left authored boulders, covering the opening left by splat cleanup. All six original rock cards and both previous corner covers remain (nine total). The walkable footprint and splat exclusion remain intact.

Lake's billboard panel is now 2.60 m tall, twice its previous 1.30 m height, with the bottom held in place. It features an original DPRK-style fishing-plan parody. The illustration is SVG geometry; Godot Label3D nodes provide the lettering because the SVG importer omits font-dependent text. A conservative support mask excludes splats touching the enlarged panel and the space immediately in front of it. Lake now uses 8,795 splats; Simons remains at 15,361. Both retain zero finite-support overlap with the walking floor, with minimum clearance of 24.7 cm and 24.9 cm respectively.

The bridge deck now meets the authored floor at the same elevation and uses its concrete texture, base color and texture coordinates. Baked irradiance and AO sampled along the authored rear edge are transferred into vertex colors on the connection. This avoids interpolation across unrelated lightmap atlas islands and extends the nearby lighting onto the new deck; it is not a new full-scene bake. Rail endpoints and posts share their coordinates, with upper and lower rails joined. The connection remains decorative behind the existing barrier.

| Issue | Original capture | Updated capture |
|---|---|---|
| Simons left opening | [Before](splats/details_simons_hole_before.png) | [Covered](splats/details_simons_hole_after.png) |
| Lake billboard splat overlap | [Before](splats/details_lake_poster_close_before.png) | [Cleared](splats/details_lake_poster_close_after.png) |
| Bridge railing | [Before](splats/details_lake_bridge_before.png) | [Joined](splats/details_lake_bridge_after.png) |
| Bridge deck texture and shading | [Before](splats/details_lake_deck_before.png) | [Matched](splats/details_lake_deck_after.png) |

[Full poster view](splats/details_poster_full.png).

Both desktop validation runs pass without Godot errors. Floor rays and side-barrier sweeps pass (5 Lake / 17 Simons proxies). The isolated panorama-depth regression passes its unchanged >300-pixel threshold: 1,094 recovered pixels for Lake and 417 for Simons. The original 500k exports are retained. Changes are confined to prototype tools, isolated assets and these review records.

## WiVRn mode prepared; headset validation deferred

The WiVRn server was running but reported `HeadsetConnected=false`. The user requested desktop testing now and XR later. No new headset performance or stereo rendering claim is made.

```bash
# Desktop
./tools/splat_experiment/run.sh --location=lake_pier
# Later, with the WiVRn headset connected and awake
./tools/splat_experiment/run.sh --xr --location=lake_pier
```

The XR launcher selects the installed WiVRn runtime per process, enables OpenXR at engine startup, and uses an XROrigin3D/XRCamera3D rig. It reuses the game's room-scale collision motor and OpenXR action map: left stick walks, right stick snap-turns, right A switches locations and right B toggles splats. Keyboard 1/2 and R remain available. An unavailable runtime produces an explicit error. `test-results/splat-experiment/viewer/xr_session.json` records view count, target size, head pose, FPS and GPU time every 300 frames during an XR session. Headset tracking, stereo splat rendering, controller bindings and headset performance remain to be verified on the later connected run.

Setup copies the XR resources and enables XR shaders only in the isolated viewer project. The main game is unchanged. The runtime setup follows [Godot's OpenXR settings](https://docs.godotengine.org/en/stable/tutorials/xr/openxr_settings.html) and [XR setup](https://docs.godotengine.org/en/4.6/tutorials/xr/setting_up_xr.html).

## Final desktop timing

1280×720 mono, Intel ADL-N, 120 warmup and 600 measured frames.

| Location | Wall median / p95 | GPU median / p95 |
|---|---:|---:|
| lake_pier | 4.778 / 7.269 ms | 3.933 / 4.308 ms |
| simons_town_rocks | 3.977 / 6.355 ms | 3.250 / 3.622 ms |
