# Real AI Fishing 0.1.0

Download the matching package from [Releases](https://github.com/jebot-git/raifslop/releases). This is an early prototype release.

- **Linux x86_64:** extract the archive and run `Desktop.sh` or `VR.sh`. Keep the executable, PCK and shared libraries together. Requires Vulkan and, for VR, an active OpenXR runtime such as WiVRn/Monado or SteamVR.
- **Windows x86_64:** extract the archive and run `Desktop.cmd` or `VR.cmd`. Keep the executable, PCK and DLLs together. PC VR uses the active OpenXR runtime.
- **Quest / Pico ARM64:** install the matching APK using the headset's sideload workflow or `adb install -r RealAIFishing-0.1.0-Quest.apk` / `RealAIFishing-0.1.0-Pico.apk`. Enable developer mode first. Allow microphone permission for voice chat. The APKs use separate application IDs, optional vendor tracking features, and a local release signing key.

Desktop dedicated servers use `Server.sh` / `Server.cmd`, default UDP port 24567. Additional options include `--port 24567 --bind 0.0.0.0`. Eight slots are available, including the ad-hoc host. Hosting across the Internet requires reachable UDP; no matchmaking or NAT relay is bundled. Voice defaults to activation, and the Guide/progression remain local.

See [README](../README.md) for controls and [MULTIPLAYER](MULTIPLAYER.md) for networking. Desktop saves live in Godot's user-data directory for Real AI Fishing; Android uses app-private storage. Keep ASSET_CREDITS and the bundled third-party notices with redistributed archives.

## Rebuilding

Godot 4.7.2 with matching export templates, Android SDK/NDK, JDK 17 and Python 3.11+ are required. Commit source changes first: release tools require a clean Git checkout. Run `python3 tools/build_release.py`, optionally with `--target Linux`, `Windows`, `Quest` or `Pico`. Environment overrides: `GODOT_BIN`, `ANDROID_SDK_ROOT`, `JAVA_HOME`. Export presets and required Android OpenXR/voice libraries are included. Each target is exported into a fresh directory with a commit/hash manifest. `python3 tools/package_release.py` verifies all four targets against the current commit and packages through temporary staging, creating desktop ZIPs, named APKs, notices, `build-manifest.json` and `SHA256SUMS` in `builds/release/`.

The first Android export generates `.release-signing/fishing.keystore` and private credentials locally. This directory is ignored by Git and excluded from exports. Back up that directory privately to sign future updates with the same identity; it is not included in the public repository or release assets. Build output and Gradle project files are also excluded from source control.

## Validation and limitations

Linux exported startup, real Vulkan rod/environment rendering, fish loading/sizing, and independent ENet ad-hoc/dedicated sessions with synthetic voice were tested locally. Quest and Pico APK signatures, 16 KiB alignment, ARM64 libraries and manifest permissions were checked. Native Monado simulation supplies separate stereo views and two synthetic tracked controllers; it is not a physical headset acceptance test.

No Quest/Pico device was connected and no Windows runtime was available on the build host. Those builds therefore have packaging validation, not on-device play/performance certification. Panoramas are native 4K mono photographs; modeled objects provide stereo depth. Stereo-photo conversion and Gaussian splatting are assessed in [SCENERY_DETAIL](SCENERY_DETAIL.md) and are not enabled.
