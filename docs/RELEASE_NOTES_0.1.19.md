# 0.1.19

Fishing and BBQ maintenance release with native CPU optimizations and cheaper scenery shading.

- Removed minigolf, its menus, assets and subsystems.
- Repaired the Wels catfish geometry; made BBQ food and cans throwable with timed respawn and corrected can orientation.
- Preserved the full river length while adding outer boundaries.
- Fixed desktop EOS identity/config packaging and Android VRM import/photo storage integration.
- Disabled Quest dynamic resolution and retained the 72 Hz target with fixed foveation.
- Added native shoreline queries, avatar bounds calculation and compatible pose encoding; cached avatar morph lookup.
- Baked river shading while retaining nearby gravel detail and preprocessed panorama sharpening.
- Replaced Lakeside's 24 faceted front-shore rocks with eight natural boulders and rebaked lighting and ambient occlusion.

Android version code 28. Install the Quest APK with its matching `main.28.org.jebot.raifslop.quest.obb`; Meta channel installation delivers both. GitHub distributes the expansion in a lossless ZIP. Clients and the dedicated server use protocol 22 and must be updated together.

Automated regression coverage includes the native kernels, multiplayer packet compatibility, maintenance fixes, shoreline geometry and scenery. Static stereo GPU measurements on Intel ADL-N showed 12–33% lower GPU time across five views; these are not XR2 measurements. Physical Quest performance, thermal behavior and live Meta/EOS login remain unverified. Active river bake atlases use approximately 128 MiB of texture memory including mipmaps. See [performance and visual comparison details](FPSLOPPA_REUSE.md).
