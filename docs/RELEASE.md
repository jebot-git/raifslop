# Releases and build policy

Release **0.1.11** targets Linux x86_64, Windows x86_64 and a separate asset-free
Linux dedicated server. **Quest builds are excluded pending device testing.**
The Quest development preset and signing credentials workflow remain available
for future validation, but automated release tools do not export/package Quest
and the publisher rejects APKs or stale Quest artifacts.
Pico standalone builds remain retired after the reported Pico 4 startup failure;
**Pico OS 6 support is a future goal only**, requiring hardware testing.
Historical releases remain available without a claim of current device support.

Download from [GitHub Releases](https://github.com/jebot-git/raifslop/releases).
See [0.1.11 changes and validation](RELEASE_NOTES_0.1.11.md).

- Linux: extract the ZIP and run `VR.sh` with an active OpenXR runtime or
  `Desktop.sh`. Keep the executable, PCK and shared libraries together.
- Windows: extract the ZIP and run `VR.cmd` or `Desktop.cmd`; retain the PCK/DLLs.
- Dedicated Linux server: extract the Server ZIP and run `Server.sh`; optional
  arguments include `--port 24567`, `--bind 0.0.0.0` and `--leaderboard-path`.
  This binary embeds shared server scripts but no visual/audio assets or extensions.
  Desktop packages also retain their existing server launchers.

Multiplayer uses **protocol 10**; update clients and server together. Publishing
packages does not upgrade an existing live server. Eight slots, direct UDP
connections and local guide/progression remain unchanged. Accomplishment records
are saved only by the server. Keep bundled asset credits and notices when sharing.

## Rebuilding and publishing

Godot 4.7.2 with matching Linux/Windows export templates and Python 3.11+ are
required for this release. Commit source first; release tools require a clean
checkout. `python3 tools/build_release.py` exports all three targets, or use
`--target Linux`, `Windows` or `Server`. Set `GODOT_BIN` if needed.
`python3 tools/package_release.py` verifies commit/hash manifests, builds fresh
staging directories, writes ZIPs with maximum deflate compression, then verifies
archive integrity and creates `SHA256SUMS` and `build-manifest.json`.

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
Quest is withheld pending testing; Pico is retired. Panoramas remain native 8K
mono photographs with authored stereo foreground geometry.
