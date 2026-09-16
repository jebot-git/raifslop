# Hybrid Splat Viewer 0.1.0-splat.1

A separate testing release of the **Lake Pier and Simons Rocks environment viewer**. It combines cleaned Gaussian splats with authored walkable meshes, panorama backgrounds and shader water. This is the two-area scenery prototype, not the fishing game.

- Includes the latest Simons gap cover, enlarged Lake fishing-plan parody billboard, and connected bridge railings with matched deck shading.
- No multiplayer, server mode or voice chat components. Android packages request neither Internet nor microphone permission.
- Independent application identity and saves: `RealAIFishing-SplatTesting`. No main-game saves are imported or modified.
- Linux and Windows archives include desktop and OpenXR launchers; Linux also includes a WiVRn launcher. Quest and Pico APKs use distinct package IDs and can coexist with the main game.

Desktop: WASD walks, right mouse drag looks, 1/2 switches areas, B toggles splats, L compares Simons lighting, R resets, P captures and Escape quits. VR: left stick walks, right stick snap-turns, right A switches areas and right B toggles splats. Settings and captures are saved in the viewer's own user-data directory; `CONTROLS.txt` describes the platform paths.

Linux exported-runtime checks cover both areas, collision barriers, panorama/splat culling and persistent settings across restart. All four packages are checked for excluded components; APK signatures, alignment, separate IDs and permissions are audited. Windows execution and the new OpenXR/standalone-headset path have not been tested on hardware. Shoreline reconstruction artifacts remain, so this release is marked **prerelease** and does not replace the stable fishing-game release.

The release includes Linux and Windows x86_64 archives, signed Quest and Pico arm64 APKs, attribution notices, a build manifest and SHA-256 checksums.
