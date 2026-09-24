# Quest expansion validation — 2026-09-24

Validated source: integrated commit `953cc565b07298fd34355157dbbd865830491dab`.
Shared code is merged into `stores`; only release documentation differs. This
local validation build retains its original integrated commit provenance. A CI
candidate built from `stores` must carry that branch's actual commit; do not
relabel this build's manifest.

| File | Bytes | SHA256 |
| --- | ---: | --- |
| UltimateBoomerSimulator.apk | 210,834,085 | `f2a09b1706ea5fea272aa9108e388b2624dd3c09006d85032d941114245efe58` |
| main.17.org.jebot.raifslop.quest.obb | 2,656,032,500 | `c401ce0c9579682ff1b8de8b7dff387533f06d3a738c34312530e5b8af3789d4` |

The APK is below the conservative 1 GB limit and the expansion below 4 GB.
Version code 17, existing package/certificate and icon are preserved as specified
(the version code increases from the previous release's 16).

## Passed locally

- Nine release-tool regression tests and two expansion regression tests.
- Isolated Godot runtime verification: invalid/missing/mismatched downloads
  rejected, PCK mounted and resource loaded successfully.
- Full release export, explicit v1/v2/v3 signature verification, original
  signing certificate and 16 KiB ZIP alignment.
- Actual APK manifest checks: target API 34, ARM64 only, required head tracking
  version 1, Godot activity excluded from recents, no debug flag, launch/VR
  categories, supported-devices metadata, auto install location and no billing.
- Combined APK/OBB resource audit: remaps, required game assets, texture hashes,
  original HDR bytes and matching expansion metadata/provenance.
- Godot loaded the exported bootstrap scene and an OBB panorama at 8192×4096;
  the APK icon loaded at 512×512. The exported project includes the Quest
  bootstrap feature override.
- Candidate staging completed from the exact source revision without upload.

The real export exposed two pre-existing manifest problems that are now fixed:
AGP lint rejected hardcoded `debuggable=false`, so release tooling controls it;
the generated release manifest overrode the template's recents flag, so the
Quest export preset now explicitly excludes the activity from recents.

Local evidence is retained in the integrated worktree:
`test-results/quest-expanded-candidate.log`,
`test-results/quest-exported-resources.log`, `builds/manifest-Quest.json`,
`builds/verify-Quest.log`, `builds/align-Quest.log`, and the staged candidate at
`builds/store/quest/953cc565b07298fd34355157dbbd865830491dab/`.

## Still pending

No Quest was attached. AndroidRuntime OBB-path access, channel delivery, startup
verification time, VR loading/error readability, clean install, signed upgrade,
offline startup and damaged/interrupted-download recovery need physical-device
acceptance. See [QUEST_EXPANSION.md](QUEST_EXPANSION.md).

Meta account/AppID and entitlement integration, privacy/reporting and performance
VRCs remain open. No store upload, submission, certification or public release
was performed. The next engineering blocker is Platform SDK/AppID/entitlement
integration; account-owner onboarding can proceed using
[QUEST_ONBOARDING.md](QUEST_ONBOARDING.md).
