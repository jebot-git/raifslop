# Real AI Fishing 0.1.7

- Lake Pier now includes the authored maintenance bridge and harbour billboard in the main game. The billboard moves toward the water to cover the nearby panorama seam and displays Korean fishing-plan slogans in bold propaganda-style lettering. Outlined Hangul renders without a runtime font dependency.
- Lake Pier and Coastal Rocks use five connected rear depth bands to reduce ground-projection stretching. The new geometry ends below the horizon to keep poles, masts and the skyline straight.
- All six photographic foregrounds have new lighting bakes derived from their original HDR panoramas. Sun direction, colour, intensity and softness account for each panorama's orientation and exposure. Runtime lights use the same measured data; the two procedural river maps share their source panorama's sun settings.
- Bridge, billboard structure and printed face receive baked lighting. The sign's planar irradiance is filtered to reduce sampling noise while retaining sharp artwork.
- Release packages retain texture deduplication, desktop BC6H HDR compression, native Android HDR and level-9 archive/APK compression. Source artwork, Blender scenes, screenshots, tests and development tools remain outside the game packages; attribution is included.

Linux and Windows x86_64 archives, Quest and Pico ARM64 APKs, notices, a build manifest and SHA256 checksums are provided. Android version code 8 retains the existing signing identity. Update multiplayer clients and servers together.

Scenery, location travel and lighting regression checks passed, including 1,231 location checks and rendered before/after comparisons. Release validation checks packaged assets, HDR preservation, Android signatures and 16 KiB alignment. Single-panorama depth remains approximate at extreme viewpoints. Windows and standalone Quest/Pico execution are not tested on this build host.
