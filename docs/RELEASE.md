# Releases and build policy

Release **0.1.12** targets Linux x86_64, Windows x86_64, Quest standalone and a
separate asset-free Linux dedicated server. Quest 3 performance passed physical
device testing and was accepted by the user. The signed Quest APK is included in
build, packaging and publishing validation. Hand-tracking controls remain in planning.
Pico standalone builds remain retired after the reported Pico 4 startup failure;
**Pico OS 6 support is a future goal only**, requiring hardware testing.
Historical releases remain available without a claim of current device support.

Download from [GitHub Releases](https://github.com/jebot-git/raifslop/releases).
See [0.1.12 changes and validation](RELEASE_NOTES_0.1.12.md).

- Linux: extract the ZIP and run `VR.sh` with an active OpenXR runtime or
  `Desktop.sh`. Keep the executable, PCK and shared libraries together.
- Windows: extract the ZIP and run `VR.cmd` or `Desktop.cmd`; retain the PCK/DLLs.
  See [Windows OpenXR setup and capture troubleshooting](WINDOWS_OPENXR.md) for
  VDXR and SteamVR runtime selection and verification.
- Quest 3: sideload the signed APK with `adb install -r RealAIFishing-0.1.12-Quest.apk`; launch Real AI Fishing from the headset app library. Controllers remain the supported gameplay input.
- Dedicated Linux server: extract the Server ZIP and run `Server.sh`; optional
  arguments include `--port 24567`, `--bind 0.0.0.0` and `--leaderboard-path`.
  This binary embeds shared server scripts but no visual/audio assets or extensions.
  Desktop packages also retain their existing server launchers.

Multiplayer uses **protocol 10**; update clients and server together. Publishing
packages does not upgrade an existing live server. Eight slots, direct UDP
connections and local guide/progression remain unchanged. Accomplishment records
are saved only by the server. Keep bundled asset credits and notices when sharing.

## Rebuilding and publishing

Godot 4.7.2 with matching Linux/Windows/Android export templates, Java 17, the
Android SDK and Python 3.11+ are required for this release. Commit source first; release tools require a clean
checkout. `python3 tools/build_release.py` exports all four targets, or use
`--target Linux`, `Windows`, `Server` or `Quest`. Set `GODOT_BIN` if needed.
`python3 tools/package_release.py` verifies commit/hash manifests, builds fresh
staging directories, writes ZIPs with maximum deflate compression, then verifies
archive integrity, copies the compressed signed Quest APK, and creates `SHA256SUMS` and `build-manifest.json`.

The export plugin deduplicates byte-identical imported texture payloads, uses
BC6H compression for desktop HDR panoramas and retains lossless lighting atlases.
Source scenes, reference images, tests, tools, screenshots, private data and
editor plugins are excluded from runtime packages. Editable source is retained
in Git. Old generated output is replaced per target; user data is never cleaned.

Push the reviewed clean source commit and matching `v<version>` tag, then run
`python3 tools/publish_release.py` with authenticated GitHub CLI (`GH_BIN` override
supported). The publisher validates local hashes, uploads to a draft, verifies
GitHub SHA256 digests and sizes, then publishes the complete release. It rejects
missing/excluded targets and refuses to modify an already published release.

## Limits

Simulated Monado/OpenXR and Linux Vulkan checks do not establish physical-headset
comfort or frame rates. Windows runtime testing is unavailable on this Linux host.
Quest 3 standalone and WiVRn headset behavior were tested; other Quest models remain untested. Pico is retired. Panoramas remain native 8K
mono photographs with authored stereo foreground geometry.
