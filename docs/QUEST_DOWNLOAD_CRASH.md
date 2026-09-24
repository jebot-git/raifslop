# Download-verification crash investigation — 2026-09-24

Reported: testers see a crash around the game download-verification screen.
The tester confirmed Quest 3, build 18. Quest OS, elapsed time, exact screen text
and a failing headset log are still unknown.
No crash was reproduced and no production fix or replacement build was made.

## Simulator / device availability

This workstation runs Linux. No Meta XR Simulator installation was found, and
`adb devices -l` returned no connected devices. Meta supplies its simulator for
Windows/macOS. More importantly, it is an OpenXR API runtime with **no Android
layer or device OS image**, so it cannot execute the store APK or reproduce its
Android OBB, package-manager or store-service behavior. A desktop game build in
that runtime would not test this startup path.

Source: [Meta XR Simulator overview](https://developers.meta.com/horizon/documentation/native/xrsim-intro/),
checked 2026-09-24.

## Exact uploaded candidate tested locally

- Version 0.1.15, Android version code 18, ALPHA build ID 3428857920620334.
- Candidate source commit: `6d6a66aefc94eb805dcf3834298d12034fa5c45f`.
- APK SHA256: `63907c4147a4202bbd9aef2f93697cd7dd3cdef57bb2de7914ad4745524ee8f3`.
- OBB: `main.18.org.jebot.raifslop.quest.obb`, 2,656,032,500 bytes, 402 entries.
- OBB SHA256: `c401ce0c9579682ff1b8de8b7dff387533f06d3a738c34312530e5b8af3789d4`.

The production `Expansion.verify_file` ran on a Godot Thread against this exact
OBB in an isolated desktop project. SHA256/length verification passed in 15,775
ms while the main loop continued (2,289 process ticks). The real pack mounted,
and Godot loaded a CompressedTexture2D at offset 2,442,303,616, beyond the 2 GiB
boundary. Whole-process peak resident memory was 102,528 KiB; exit status 0.
These are desktop measurements, not Quest performance or memory results.

Also passed: two Python expansion tests and 18 entitlement-gate assertions with
mock responses. Evidence is in local `test-results/quest-download-desktop-probe.log`,
`quest-expansion-unit.log` and `quest-entitlement-probe.log`.
The isolated probe and metadata are retained at `/tmp/ubs-quest-crash-probe/`.

## What the screen establishes

`quest_bootstrap.gd` switches to “Checking game download…” after entitlement
success. It then calls the Android package/storage APIs, verifies the OBB on a
worker, mounts it, and synchronously changes to the main scene. There is no
separate message between checksum completion, pack mount and main-scene load.
The same text is also briefly set while the loading UI is initially constructed.
Thus the last visible text alone cannot identify the failing operation or prove
entitlement succeeded. Local tests do not cover Android bridge calls, device
storage, native crashes, real account responses or main-scene GPU/memory use.

## Capture a failing headset launch

Use an authorized tester account with the ALPHA build installed through the
library. Connect the headset by USB and authorize USB debugging. Do not clear
app data, reinstall or replace the APK/OBB before collecting the first failure.
Commands below use `adb` from Android SDK platform-tools; with multiple devices,
add `-s DEVICE_SERIAL` immediately after `adb` to every command.

```sh
adb devices -l
adb shell getprop ro.product.model
adb shell getprop ro.build.fingerprint
adb shell dumpsys package org.jebot.raifslop.quest > quest-package.txt
adb shell ls -l /sdcard/Android/obb/org.jebot.raifslop.quest > quest-obb.txt
adb logcat -b all -v threadtime -T 1 > quest-startup-logcat.txt
```

Leave the last command running. Launch the game from the headset library and
reproduce the crash. Wait five seconds, then stop logcat with Ctrl+C. Afterwards:

```sh
adb shell dumpsys activity exit-info org.jebot.raifslop.quest > quest-exit-info.txt
```

Retain the complete startup log, including the system crash/low-memory messages;
a PID-only filter can lose them after the app exits. Record the exact visible
text and seconds from launch to crash, whether it exits to Home or stays frozen,
and whether this was a clean install or upgrade. The `ls` path above is for the
primary Android user; runtime code obtains the actual user's path from Android.
Logs may include device/account identifiers: share privately and redact those
before posting publicly. No tester logs have been obtained during this session.

## Follow-up: physical Quest reproduction

The ALPHA build 18 crash was reproduced on Quest 3 on 2026-09-24. Both installed
artifact hashes match the uploaded candidate. Captured logs and an isolated
probe identify stale APK sparse-pack entries taking precedence over OBB
textures. See [the live debugging report](QUEST3_ALPHA18_LIVE_DEBUG.md) for the
crash timeline, metrics, evidence, and proposed correction. The earlier
no-device/no-reproduction statements above describe the initial investigation.
