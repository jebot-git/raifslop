# Adding photographed locations

The initial scene uses Poly Haven's Lakeside photography. Its display name intentionally does not claim geographic coordinates or a native fish population. The foreground dock and scanned rock arrangement are authored additions.

For each new location, record source URL, creator, license, acquisition date, real location if verified, camera height, panorama rotation, scale, and every modification. Download and cache the assets locally: gameplay must not require a web request.

Use equirectangular 2:1 HDR/EXR panoramas as `PanoramaSkyMaterial`. Match water level and horizon, then add meter-scaled shore/dock geometry near the player. Limit the playable area to that supported by the actual 3D foreground; a panorama cannot provide translational parallax. Keep a verified species roster separate from the rendering assets.

For scans: import through Blender, confirm meters/orientation, decimate into LODs, use modest texture sizes, export GLB and retain attribution. Avoid placing high-density photogrammetry directly in a standalone headset build. Profile draw calls and GPU time on the target device before claiming a frame-rate budget.

For future Gaussian splats: choose a licensed dataset and a Godot renderer that explicitly supports stereoscopic OpenXR and mobile GPU budgets. Validate eye-dependent ordering, stereo depth, clipping and memory. Supply proxy geometry for collision and interaction. There is no splat renderer installed in this prototype; arbitrary `.ply` or `.splat` files cannot currently be dropped in as fishing locations.
