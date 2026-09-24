# Quest build 19 startup fix — 2026-09-24

Implemented the resource-mount correction identified in
[the live Quest 3 investigation](QUEST3_ALPHA18_LIVE_DEBUG.md).

- Shared fix commit: `534a958` on `integration/golf-fishing`.
- Merged into `stores`: `1b0c87aba0e375ac84aee0ad2f7f356212049c08`.
- Quest version remains 0.1.15; Android version code increases from 18 to 19.
- The checksum-verified expansion replaces stale APK sparse-pack entries.
- The runtime regression test exercises the production bootstrap with and without
  a conflicting sparse entry. Reverting only the mount flag makes it fail.

## Validation completed

- Both expansion runtime cases pass.
- Thirteen Python Quest/platform/release-tool tests pass.
- Eighteen entitlement-gate assertions pass.
- Full project import and unsigned Android release export complete.
- Exported bootstrap matches the fixed source byte for byte.
- APK declares build 19, target API 34, ARM64, and Platform SDK registration.
- Expansion checksum/metadata, combined asset audit, and 16 KiB alignment pass.
- The new OBB is byte-identical to build 18's verified payload; its filename is
  correctly changed to `main.19.org.jebot.raifslop.quest.obb`.

The local Gradle build required increasing its heap from 4536 MiB to 12 GiB with
2 workers after asset compression exhausted the initial heap. This affects only
ignored local build configuration. Godot reports its previously observed one
ObjectDB-instance shutdown warning; no script/export error remained.

## Unsigned handoff; no Meta upload yet

Prepared locally at `builds/quest19-unsigned/` from stores merge `1b0c87a`.
The only temporary export-preset change was disabling signing; the tracked
preset was restored. This is not a signed or staged store candidate.

| Artifact | SHA256 |
| --- | --- |
| UltimateBoomerSimulator.unsigned.apk | `ecd553868a8c672ce6a2d9d1437849dbbf262bb67d0ab33f3e8b5ef061593b9e` |
| main.19.org.jebot.raifslop.quest.obb | `c401ce0c9579682ff1b8de8b7dff387533f06d3a738c34312530e5b8af3789d4` |

The owner confirmed the original signing key is not on this machine. The
available project key has a different certificate. The pinned certificate check
has not been changed. Signing must use the original identity:
`15f604964c24bd8edc02a2cde8407293c2fdc3b87939c4164ea317e929a9d380`.
Meta upload authentication is also not provisioned here.

Meta requires subsequent versions to retain the same certificate; see
[Packaging.2](https://developers.meta.com/horizon/resources/vrc-quest-packaging-2/).
Sign and validate using the original key, then upload the APK and matching OBB
to the existing ALPHA channel with audience `TEENS_AND_ADULTS`. Verify the
channel's version and install it through the library before declaring the
store-release headset crash resolved. The unsigned store artifact has not been
run on the headset; the separate diagnostic variant has, as documented below.

Local evidence: `test-results/quest19-fix/`, plus package manifest, asset audit,
and hashes beside the unsigned APK. No credentials are included.

## Local test variant

At the owner's request, a separately signed debug variant was prepared under
`builds/quest19-localtest/` with package
`org.jebot.raifslop.quest.localtest` and label **UBS Startup Test 19**. The original
ALPHA package and data are separate. This diagnostic build skips Meta entitlement
under both a debug and test-only feature check, while retaining the production
expansion verification and fixed mount path. The temporary source/preset changes
were restored after export. Its artifact manifest records these differences.
This package must not be uploaded as an ALPHA update.

The first local test reached the fishing scene and remained running throughout
a two-minute capture with no sparse-texture failures or native crash. Captured
body-tracking initialization errors remain a separate diagnostic issue. The
owner then requested a hands-on headset suite; the test APK was re-signed with
controller/metrics capture enabled, retaining its separate package identity.
Automated negative-download and lifecycle evidence is under
`test-results/quest19-device-suite/`. Meta upload is still pending the original
signing key and authentication.

## Completed headset pass

See [Quest 19 headset results](QUEST19_HEADSET_RESULTS.md). The diagnostic
startup checks pass, but gameplay acceptance fails on the initial club-head
orientation and persistent ball rolling. These gameplay faults are not fixed
by the resource-mount change.
