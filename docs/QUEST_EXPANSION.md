# Quest APK/OBB delivery

Store builds (`--target Quest --store-release`) place the hash-deduplicated
texture payloads into an uncompressed Godot PCK v2 carried as a Meta OBB. The
original texture bytes, HDR precision, dimensions and mipmaps are unchanged.
The icon payload stays in the APK for engine startup. Scripts, scenes, import
remaps, native libraries and other resources stay in the APK.

The name is `main.<Android version code>.org.jebot.raifslop.quest.obb`.
`quest_expansion.json` inside the signed APK binds the filename, package,
version, length, SHA256 and entry count. Version code is now 17; increase it
for any subsequent uploaded revision. APK and OBB must always be updated as a
pair. Non-store exports remain monolithic for the existing release workflow.

The Quest feature selects `scenes/quest_bootstrap.tscn`. Before the main game
scene or its resource dependencies are loaded, it obtains the current app's
OBB directory through AndroidRuntime, checks installed package/version,
verifies length and SHA256 on a worker and mounts the pack. A headset-visible
loading message remains while verification runs. Missing, incomplete, corrupt
or mismatched files stop startup with recovery instructions. Relaunch after
completing/reinstalling the download. No network call, Google Play licensing,
copy of the 2.66 GB payload, or shared-storage permission is required.

Verification runs at every launch; physical-device timing remains to be measured.
The loader does not cache a successful checksum and silently trust a subsequently
modified file. Desktop and dedicated server entry points are unchanged.

## Build and verification

Use the signing environment in [STORE_RELEASE.md](STORE_RELEASE.md), from a
clean committed checkout:

```bash
python3 -m unittest discover -s tests -p test_quest_expansion.py
python3 tools/test_quest_expansion.py --godot "$GODOT_BIN"
python3 tools/build_release.py --target Quest --store-release
python3 tools/audit_release.py builds/Quest/UltimateBoomerSimulator.apk
python3 tools/store_release.py quest
```

The audit automatically discovers the exact OBB from signed metadata, verifies
its hash and rejects missing/extra expansion files, overlapping resources,
unexpected expansion content, dangling remaps and changed HDR bytes. Candidate
provenance includes both files. APK and OBB limits are checked separately.
Godot runtime regression tests cover checksum failures and actual pack/resource
loading in an isolated project; they do not exercise Android's storage API.

## Installation and upload

A sideload test requires both files. For the current version:

```bash
adb install -r builds/Quest/UltimateBoomerSimulator.apk
adb shell mkdir -p /sdcard/Android/obb/org.jebot.raifslop.quest
adb push builds/Quest/main.17.org.jebot.raifslop.quest.obb /sdcard/Android/obb/org.jebot.raifslop.quest/
```

This shell path is for developer installation on the primary device user; the
runtime obtains the current user's actual directory from Android. Stop the app
before replacing the pair. Retain user saves during ordinary upgrade tests.

For store testing, verify candidate SHA256SUMS and upload both files with Meta's
Platform CLI to an internal channel. Check the installed CLI's help for the
current OBB argument and authenticate privately. Meta Quest Developer Hub's
APK-only upload cannot deliver this expansion. No automatic upload is performed.

## Pending physical-device acceptance

Record candidate commit/hash and Quest OS/device for each result:

- Channel clean install and first launch; measure verification time and memory.
- Offline launch with installed OBB; every location/course and their textures.
- Signed upgrade retaining progression; exact new-version OBB selected.
- Missing, truncated, wrong-version and same-size corrupted OBB; readable error
  and successful recovery after installing the matching file and relaunching.
- Interrupted store download, restart, low disk space, headset removal and system
  overlay during verification; no input leaks or unresponsive head tracking.

Account/AppID/entitlement integration, privacy/reporting and gameplay/performance
VRCs remain separate launch gates.

References: [Meta APK/expansion delivery](https://developers.meta.com/horizon/resources/publish-apk/),
[Godot Android API integration](https://docs.godotengine.org/en/4.5/tutorials/platform/android/javaclasswrapper_and_androidruntimeplugin.html).
