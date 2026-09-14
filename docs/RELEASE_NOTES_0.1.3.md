Real AI Fishing 0.1.3 reduces download and installed size while retaining all four native 8K HDR environments. Desktop builds use BC6H HDR textures; Quest and Pico retain lossless HDR textures. Identical imported textures are stored once, development files and unused editor assets are excluded, and ZIP/APK compression is stronger. Credits and licenses remain included.

This release also includes the recent session-feedback changes:

- Cross-water shoulder radio, threaded ENet transport, and voice focus recovery. Hold the left-shoulder radio and press its trigger to transmit; desktop radio uses B.
- More gradual line tension and earlier haptic warnings. Failed counters recover fish stamina; completed fights preserve the fish's position. Gesture casting rearms after a snapped line.
- Raised-rod counter detection, visibly distinct bait, held bobber/bait, and a brief bait-change label.
- Uniform avatar scaling and calibration, solved-hand rod attachment, external VRM folders, and photos in Pictures/Real AI Fishing on desktop.
- Lower Lake Pier water with panorama foreground protection, plus different birds and insects at each water.

Update both clients and servers together: multiplayer now uses protocol 3. WAN tests passed two complete radio runs and repeated reconnects, but an earlier intermittent packet-loss event remains unresolved. Windows and standalone Quest/Pico headset behavior still require device validation; Android package signatures and alignment are verified during the build.

Desktop archives provide Desktop, VR and Server launchers. Quest and Pico APKs retain the existing local release signing identity. Documentation stays in the repository; attribution is supplied in each desktop archive and the Notices archive.
