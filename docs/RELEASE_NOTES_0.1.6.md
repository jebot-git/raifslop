# Real AI Fishing 0.1.6

- Fly-line grabbing follows the visible line and solved avatar hand. Stripping uses tracked hand travel, with grip hysteresis and tracking-loss recovery. Mending requires a deliberate upstream sweep and confirms accepted input with a line loop, brief rod text and haptics.
- Four visibly distinct tackle tiers, each with spinning and fly-reel variants. Fly reels use an open-sided drum and short direct crank; all variants support folding and holstering.
- Fish jumps follow a continuous arc from the water, orient along the flight path and retain their landing position for subsequent retrieval. The line attaches to the fish's mouth during jumps.
- Team radio held rotation matches the FPSloppa fix. VR water selection, avatar selection and the VRM import browser support drag scrolling. Smooth-turn speed and snap angle are adjustable and saved.
- Revised Lake Pier, Coastal Rocks and Sunrise Beach reconstruction; distant inland terrain slopes beneath extended water coverage. Coastal stone footings close terrace gaps, rear rock layers add depth, and Gray Pier reeds clear the bench.
- Release cleanup removes unused model texture aliases and redundant unfolded data from folded rod files. High-quality GPU compression is applied where measurements show smaller downloads on both desktop and Android, reducing texture memory use too. Native 8K panoramas, existing HDR formats, texture deduplication and level-9 archive/APK compression are retained. Documentation, source artwork and test captures stay outside game packages; attribution remains included.

Linux and Windows x86_64 archives, Quest and Pico ARM64 APKs, notices, a build manifest and SHA256 checksums are provided. Android version code 7 retains the existing release signing identity. Update multiplayer clients and servers together.

Regression coverage includes VR input, VRM/avatar tracking, fishing, tackle, scenery, settings persistence and local multiplayer. Release packs are checked for required assets, native 8K HDR data and excluded development files; Android signatures and 16 KiB alignment are verified. Linux WiVRn runtime checks use the connected headset. Windows and standalone Quest/Pico execution are not tested on this build host; physical comfort and extreme-angle panorama alignment remain subject to headset testing.
