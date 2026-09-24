# Releases and build policy

Release **0.1.17** is branded **Ultimate Boomer Simulator** and targets Linux x86_64, Windows x86_64, Quest standalone and a separate Linux dedicated server. The icon and existing save locations are preserved. Historical releases retain their original branding and filenames.

Download from [GitHub Releases](https://github.com/jebot-git/raifslop/releases).
See [0.1.17 changes and validation](RELEASE_NOTES_0.1.17.md).

- Linux: extract the ZIP and run `VR.sh` with an active OpenXR runtime.
- Windows: extract the ZIP and run `VR.cmd`; retain the executable, PCK and DLLs. See [Windows OpenXR setup](WINDOWS_OPENXR.md).
- Quest: sideload the signed APK. Use the same signing certificate for upgrades. The final fixes have automated regression coverage; this package has not been retested on physical hardware. The GitHub sideload key differs from the Meta ALPHA key, so this APK cannot update that installation.
- Dedicated Linux server: extract the Server ZIP and run `Server.sh`; optional arguments include `--port 24567`, `--bind 0.0.0.0` and `--leaderboard-path`. The binary embeds shared server scripts and course data but no visual/audio assets or extensions.

Multiplayer uses **protocol 16**; update clients and server together. Publishing packages does not upgrade a live server. Eight slots, direct UDP connections and local progression remain unchanged. Accomplishment records are saved by the server. Keep bundled asset credits and notices when sharing.

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
Earlier Quest 3 standalone and WiVRn headset behavior was tested; this build and other Quest models remain untested on hardware. Pico is retired. Panoramas remain native 8K
mono photographs with authored stereo foreground geometry.
