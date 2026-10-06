# Ultimate Boomer Simulator

Free VR fishing and shared waterside BBQ for Meta Quest, Windows OpenXR and Linux OpenXR.
Explore twelve lakes, coastal locations and rivers, discover freshwater and marine fish, choose your tackle and cook with friends.

[Downloads](https://github.com/jebot-git/raifslop/releases) · [0.1.19 release notes](docs/RELEASE_NOTES_0.1.19.md) · [Player manual](docs/MANUAL.html) · [Windows VR setup](docs/WINDOWS_OPENXR.md)

## What's new in 0.1.19

- Baked river shading and preprocessed panorama sharpening reduce shader work while retaining nearby gravel detail.
- Lakeside has fewer, more natural shore boulders and newly baked lighting and ambient occlusion.
- Native shoreline queries, avatar bounds and pose encoding reduce CPU work; avatar facial animation reuses cached lookups.
- Quest uses fixed resolution, fixed foveation and a 72 Hz target. Actual performance depends on the headset and scene; this release has not been validated on physical Quest hardware.
- Desktop builds package EOS configuration with desktop identity. Quest retains Meta entitlement and identity.
- Android custom VRM import uses the system document picker; photos save through the system media collection.
- River edge boundaries preserve the full walkable bank length. The Wels catfish model is repaired.
- BBQ food and cans can be thrown and respawn after a while; cans now face upright.

Static stereo captures on an Intel ADL-N host measured 12–33% lower GPU time across five views. These are desktop measurements, not Quest frame-rate claims. Baked river atlases use approximately 128 MiB per active river. [Measurements, visual comparisons and limitations](docs/FPSLOPPA_REUSE.md).

## Fishing and social play

Follow the complete bait → cast → bite → strike → fight → land → release loop. Classic, fly, feeder and lure tackle support different waters and fish. Read current, mend and strip fly line, watch a feeder's quiver tip, or work lures with rod movement.

Catches earn in-game currency for four tackle tiers. The handheld Field Guide records discoveries and personal bests, explains habitats and bait preferences, and includes a camera with selfie mode. Fishing achievements and leaderboards track catches, exceptional specimens, earned currency, and the longest and heaviest fish.

At the shared BBQ, use tongs to turn food, serve and eat, open the cooler, and pick up drinks. Select a bundled avatar or import a custom VRM. EOS lobbies and direct IP/LAN hosting support multiplayer; an independent Linux dedicated server is also available.

Panoramic HDR scenery surrounds walkable 3D foregrounds. Lakes and coasts use 8K photographs; Cedar Creek and Glacier Run use 4K panoramas. River banks retain their full 240-metre length with outer boundaries.

## Install and play

- **Quest:** install the signed APK and its matching expansion file. Meta release channels deliver both. For GitHub sideloading, extract the OBB ZIP and follow [expansion installation](docs/QUEST_EXPANSION.md).
- **Windows:** extract the complete ZIP, select an OpenXR runtime and run `VR.cmd`. Keep the executable, PCK and DLLs together.
- **Linux:** extract the complete ZIP and run `VR.sh` with an active OpenXR runtime.
- **Dedicated server:** extract the server ZIP and run `Server.sh`. [Hosting and server records](docs/DEDICATED_SERVER.md).

Clients and servers use **protocol 22** and must be updated together. Existing saves and Android package identity are retained from Real AI Fishing. VR clients require an initialized OpenXR runtime and tracked input. There is no keyboard/mouse gameplay mode. Pico standalone is unsupported.

## Essential controls

| Action | Touch-style controls |
| --- | --- |
| Walk / turn | Left stick / right stick; snap turning by default |
| Field station menu | Right B; point and press trigger |
| Cast | Hold right trigger, sweep back and forward, release |
| Set hook | Lift the rod sharply during the bite window |
| Reel | Hold left grip or trigger at the reel and wind physically |
| Select tackle | Press right stick, choose a direction |
| Change bait | Left X while ready |
| Field Guide | Left grip at the left-hip handle |
| Stash / retrieve rod | Right grip at the right hip |
| Inspect / release catch | Hold left grip; left trigger releases |
| Quit | Field station → Quit game |

Use the [player manual](docs/MANUAL.html) for optical hand controls, fly line handling, cooking, movement comfort and camera controls. [Avatar and tracking setup](docs/AVATAR_TRACKING.md) · [Fishing methods](docs/FISHING_DISTRIBUTION.md) · [BBQ](docs/BBQ.md).

## Build and contribute

Use Godot 4.7.2 with matching export templates. Open `project.godot` or run `./run.sh`; set `GODOT_BIN` if needed. The project uses Mobile/Vulkan rendering. Android builds require Java 17 and the Android SDK; online exports require an externally supplied EOS configuration and store builds require the established signing key.

[Build and release workflow](docs/RELEASE.md) · [Native optimization details](docs/FPSLOPPA_REUSE.md) · [EOS transport](docs/EOS_GAMEPLAY_TRANSPORT.md) · [Asset credits](ASSET_CREDITS.md)

The game is free to acquire, with no real-money purchases, subscriptions or paid currency.
