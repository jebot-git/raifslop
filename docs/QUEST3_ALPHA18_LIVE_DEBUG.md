# Quest 3 ALPHA build 18 live debugging — 2026-09-24

The startup crash was reproduced on physical Quest 3 after installation through
the Meta ALPHA library. Version 0.1.15 / Android version code 18 was installed by
`com.oculus.ocms`. The app launched successfully, initialized OpenXR, and crashed
before reaching gameplay. Source checkout: `stores` at `160b83f`.

## Artifact identity

Both artifacts were pulled from the headset into the ignored local directory
`builds/quest3-alpha18-device/`. Their SHA256 hashes match the uploaded candidate
recorded in [QUEST_INTERNAL_UPLOAD.md](QUEST_INTERNAL_UPLOAD.md):

- APK: `63907c4147a4202bbd9aef2f93697cd7dd3cdef57bb2de7914ad4745524ee8f3`
- OBB: `c401ce0c9579682ff1b8de8b7dff387533f06d3a738c34312530e5b8af3789d4`
- OBB size: 2,656,032,500 bytes.

This rules out a damaged or incomplete expansion download in this reproduction.
The uploaded candidate records integrated source `6d6a66a`; pulling it from the
headset does not change that provenance.

## Timeline and diagnostics

Device: Quest 3, Android 14 / API 34; Godot 4.7.2, Vulkan Mobile renderer,
Adreno 740, Oculus OpenXR runtime 207.218.0.

| Device local time | Observation |
| --- | --- |
| 16:15:31.447 | Cold launch requested; Android activity reports 313 ms launch time. |
| 16:15:32.050 | OpenXR instance initialized. |
| 16:15:34.549 | Godot main loop started. |
| 16:15:51.000 | First texture failure: APK sparse-pack entry points at a missing texture payload. |
| 16:15:52.624–52.694 | Rod textures/scenes fail; null `add_child` errors follow. |
| 16:15:52.702 | Native SIGSEGV on `VkThread`, null pointer dereference at address `0x408`. |
| 16:15:53.611 | Android exit history records signal 11 for version 0.1.15. |

Time from launch request to fatal signal: **21.255 seconds**. The stack is in
`libgodot_android.so`, build ID `270121fef88100c19643517c328b5868e01d345c`.
The exact native function at the fault address is not symbolicated.

The highest five-second memory sample was **719.64 MiB PSS / 837.10 MiB RSS**;
this is not an exact peak. Seventeen app-PID VR frame-rate samples had a median
of **72 FPS** (range 1–73 including initial startup). These describe the loading
screen only, not gameplay performance. Thermal status after capture was 0.
The evidence records a native signal, not a low-memory kill.

## Confirmed resource-mount defect

The signed APK includes `assets/assets.sparsepck`, whose directory still lists
textures removed from the APK by `tools/quest_expansion.py` and placed in the
OBB. `scripts/quest_bootstrap.gd` mounts that OBB using
`ProjectSettings.load_resource_pack(expansion_path, false)`.

Godot's `PackedData::add_path` retains an existing entry when replacement is
false. The stale sparse entry therefore continues to win over the actual OBB
payload. `FileAccessPack` attempts to read the removed APK asset using
`SKIP_PACK`, producing the observed sparse-pack errors and misleading
"Compressed texture file is corrupt (Bad header)" messages. Model loading then
fails immediately before the native crash.

An isolated desktop probe using the **actual captured sparse pack and OBB**
reproduced the inaccessible texture with replacement disabled. Mounting the
same verified OBB with replacement enabled produced a valid `GST2` header and
loaded the affected texture as `CompressedTexture2D`, 1024×1024. Expected missing
APK-support-file errors also appear because the isolated probe mounts only its
index and OBB; it is not a complete Android application launch.

This confirms the mounting defect. A corrected APK must still be tested on the
headset to establish that the native crash is fully resolved.

## Recommended changes

1. Mount the checksum-verified expansion with replacement enabled so its real
   payloads replace the APK's stale sparse entries.
2. Add a regression test with an existing sparse-pack entry for a moved texture.
   The current isolated expansion test starts without that conflicting entry,
   so it passes despite this Android packaging problem.
3. Show separate verification, mount, and scene-loading status, with timestamps
   in logs. The current “Checking game download” message spans these phases.
4. Handle missing model resources before dereferencing/attaching them. Preserve
   useful diagnostics and fail gracefully if a resource cannot load.

No runtime source changes, replacement APK installation, signing bypass, or app
data clearing were performed during this capture.

## Local evidence

All raw captures remain local under the ignored directory
`test-results/quest3-store-2026-09-24/`:

- `launch-161531/logcat.txt`: complete 120-second all-buffer logcat.
- `launch-161531/crash-excerpt.txt`: resource errors and native backtrace.
- `launch-161531/analytics.json`, `vr-metrics.txt`, `samples.jsonl`, and
  `memory-*.txt`: metrics and sampling evidence.
- `launch-161531/package.txt`, `launch.txt`, `exit-info.txt`, `thermal.txt`,
  `battery.txt`, `gfxinfo.txt`, and `screen-startup.png`.
- `artifact-sha256.txt`, `obb-sha256.txt`, `assets.sparsepck`.
- `mount-probe/probe.gd` and `mount-probe.log`: isolated reproduction.

Raw logs may contain device/account identifiers and are not committed.
