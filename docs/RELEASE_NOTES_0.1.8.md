# Real AI Fishing 0.1.8

- Comfortable rod-swing casting now applies to both fishing styles. Trigger press locks the water aim point; extra full fly-casting strokes deliberately extend that target. Low, sideways and backward swings are rejected.
- Fly reels support left grip or trigger and snap the offhand to their smaller crank. Loose-line stripping remains separate. Winding against an active fly fish sharply raises tension; reserve the reel for inward rushes and final retrieval.
- Exhausted fish still require active retrieval to the physical shoreline or pier edge. Landing follows the fish's current direction, including river drift. Stashing the rod or fully retrieving an empty line rearms the selected bait.
- Fish occupy nine grid sectors per water and migrate independently. Bait-responsive fish leave subtle surface ripples, with a 15% chance of incidental off-bait catches. Repeated catches rapidly deplete a species, with gradual recovery over four minutes. Bite timing varies.
- Dive moves sink the float and require releasing the reel. Inward rushes create surface wakes and require faster reeling. The Field Guide cannot be grabbed during bites or fights; ambient presence ripples keep animating while it is held.
- Launch recenters the player. Lake Pier's small mooring cleat is grounded. Dynamic player shadows are removed; soft contact shadows remain.
- Original HDR lighting atlases retain their lossless imported bytes on every platform. Baked foreground brightness is tuned to 86% of the source intensity; the beach sand tint boost is removed. Desktop panoramas retain BC6H compression, texture deduplication and level-9 archive/APK compression.

Linux and Windows x86_64 archives, Quest and Pico ARM64 APKs, notices, a build manifest and SHA256 checksums are provided. Android version code 9 retains the existing signing identity. Update multiplayer clients and servers together.

Validation includes simulation, tracked-controller input, casting, reel/strip ownership, shoreline retrieval, fish populations, scenery, lighting and packaging checks. Connected WiVRn testing has exercised physical casting, hooking and reel input. Windows and standalone Quest/Pico execution are not tested on this build host.
