# Releases and build policy

Future releases target **Linux, Windows and Quest**. Pico standalone builds are retired. A user reported an immediate crash after a black screen on standard Pico 4; the cause has not been verified on hardware. Diverging Pico SDK/hardware requirements and the lack of direct device testing make continued maintenance impractical. **Pico OS 6 support is a future goal only**, contingent on hardware access and on-device validation. No current Pico support or delivery date is promised. Historical releases and their notes are retained.

## Latest published release: 0.1.10

Download the matching package from [Releases](https://github.com/jebot-git/raifslop/releases). This is an early prototype release.

See [0.1.10 changes](RELEASE_NOTES_0.1.10.md). Packages omit documentation and screenshots, retaining asset credits and license notices. Version 0.1.10 retains the Android signing key used since 0.1.1. Historical Android signing and migration details are retained in the [0.1.1 release notes](RELEASE_NOTES_0.1.1.md).

- **Linux x86_64:** extract the archive and run `Desktop.sh` or `VR.sh`. Keep the executable, PCK and shared libraries together. Requires Vulkan and, for VR, an active OpenXR runtime such as WiVRn/Monado or SteamVR.
- **Windows x86_64:** extract the archive and run `Desktop.cmd` or `VR.cmd`. Keep the executable, PCK and DLLs together. PC VR uses the active OpenXR runtime.
- **Quest ARM64:** install the APK using the headset's sideload workflow or `adb install -r RealAIFishing-0.1.10-Quest.apk`. Enable developer mode first. Allow microphone permission for voice chat. The APK uses optional vendor tracking features and a local release signing key.

Desktop dedicated servers use `Server.sh` / `Server.cmd`, default UDP port 24567. Additional options include `--port 24567 --bind 0.0.0.0`. Eight slots are available, including the ad-hoc host. Hosting across the Internet requires reachable UDP; no matchmaking or NAT relay is bundled. Voice defaults to activation, and the Guide/progression remain local.

See [README](../README.md) for controls and [MULTIPLAYER](MULTIPLAYER.md) for networking. Desktop saves live in Godot's user-data directory for Real AI Fishing; Android uses app-private storage. Keep ASSET_CREDITS and the bundled third-party notices with redistributed archives.

## Rebuilding

Godot 4.7.2 with matching export templates, Android SDK/NDK, JDK 17 and Python 3.11+ are required. Commit source changes first: release tools require a clean Git checkout. Run `python3 tools/build_release.py`, optionally with `--target Linux`, `Windows` or `Quest`. Environment overrides: `GODOT_BIN`, `ANDROID_SDK_ROOT`, `JAVA_HOME`. Export presets and required Android OpenXR/voice libraries are included. Each target is exported into a fresh directory with a commit/hash manifest. `python3 tools/package_release.py` verifies all three maintained targets against the current commit and packages through temporary staging, creating desktop ZIPs, the Quest APK, notices, `build-manifest.json` and `SHA256SUMS` in `builds/release/`.

The first Android export generates `.release-signing/fishing.keystore` and private credentials locally. This directory is ignored by Git and excluded from exports. Back up that directory privately to sign future updates with the same identity; it is not included in the public repository or release assets. Build output and Gradle project files are also excluded from source control.

To publish a validated release, push the clean source commit and matching `v<version>` tag, then run `python3 tools/publish_release.py` with an authenticated GitHub CLI (`GH_BIN` can select its executable). The publisher checks the local checksum list and commit, uploads to a draft, verifies GitHub's SHA256 digests and sizes, then makes that complete release public. It refuses retired targets and Pico artifacts before contacting GitHub, and refuses to modify an already published release. Old local Pico outputs are not used when packaging.

## Validation and limitations

Version 0.1.10 excludes the BBQ prototype and uses multiplayer protocol 4. Update all clients and the server together; protocol-3 releases cannot join. Publishing these packages does not upgrade an existing live server.

Sixty distinct regression suites passed across the full run and targeted reruns, including casting/aiming, fish boundaries, avatar recovery, scenery repairs and the hidden fight-recovery window. Dedicated and ad-hoc local multiplayer with synthetic Opus voice passed. Linux Vulkan render checks cover coastal scenery and immersive fight cues. The previous 0.1.9 WiVRn session is not a headset validation of this release.

Standalone Quest APK execution and Windows execution have not been tested on the build host. The historical Pico APK is retired following the reported Pico 4 startup failure. Those builds therefore have packaging validation, not on-device play/performance certification. Panoramas are native 8K mono photographs; modeled objects provide stereo depth. Stereo-photo conversion and Gaussian splatting are assessed in [SCENERY_DETAIL](SCENERY_DETAIL.md) and are not enabled.
