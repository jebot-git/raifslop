# Real AI Fishing 0.1.10

Avatar recovery, coastal scenery and more readable fish fights.

- Avatar selection now acknowledges offers, cancels obsolete transfers, retries stalled requests/downloads with bounded backoff, and can use another owner when a sender disconnects. Loading errors clear when their operation recovers or is superseded.
- Custom VRMs with undecodable embedded textures are rejected before equipping or caching a partial avatar. The previous working avatar remains available, with filename/hash/image-index context in diagnostics. The original reported Windows custom file was unavailable for reproduction.
- Coastal Rocks' floating mooring cleat is grounded. Bench rear supports sit behind the backrests at all five affected locations.
- Coastal grass, wrack and the pier poster have mipmaps. Hoek Beach/Tidal Strand has a wider, subdivided rear parallax mesh to reduce stretched scenery.
- Fighting, exhaustion and renewed strength have distinct positional water sounds and water disturbances. Stamina recovery stays hidden: no meter, label or popup.
- A hidden 0.65-second recovery reaction window gives the player a brief chance to ease line tension. Existing strain is preserved; sustained over-reeling, slack and inappropriate fly-reel use remain punishable.
- Optional diagnostics record monotonic frame timing, avatar-loading stages, state-update gaps and separate voice counters. Remote catch models are built only when visible at the same water.

**Multiplayer protocol 4: update the server and every client together.** Version 0.1.9/protocol 3 cannot join these builds. Publishing this release does not change an existing live server.

The BBQ prototype remains excluded. Packages include Linux/Windows x86_64, signed Quest/Pico ARM64 APKs, notices, build manifests and SHA256 checksums. Android version code 11 retains the existing signing identity. Native 8K panoramas, desktop BC6H compression, lossless lighting atlases, texture deduplication and maximum ZIP/APK compression are retained; authoring files, tests and development outputs are excluded.

Validation: 60 distinct regression suites, dedicated/ad-hoc local multiplayer, Linux Vulkan scenery/fight renders, and exported-package audits. Windows and standalone Quest/Pico execution are not tested on the build host; the prior WiVRn session does not constitute headset validation of 0.1.10.
