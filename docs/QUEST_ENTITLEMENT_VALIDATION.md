# Quest entitlement validation — 2026-09-24

AppID: **3428825797290213**, supplied by the owner.
Source: integrated `6d6a66aefc94eb805dcf3834298d12034fa5c45f`, merged into stores
with shared code identical. This local build retains integrated provenance;
a subsequent stores CI build must record its own commit.
Package: `org.jebot.raifslop.quest`, version code **18**.

| File | Bytes | SHA256 |
| --- | ---: | --- |
| UltimateBoomerSimulator.apk | 214,140,346 | `63907c4147a4202bbd9aef2f93697cd7dd3cdef57bb2de7914ad4745524ee8f3` |
| main.18.org.jebot.raifslop.quest.obb | 2,656,032,500 | `c401ce0c9579682ff1b8de8b7dff387533f06d3a738c34312530e5b8af3789d4` |

## Passed

- Eighteen runtime assertions across success, denied access, initialization
  errors/result failures, missing configuration/SDK/request/message, timeout and
  late callbacks. Tests use the production gate and mock platform responses.
- Thirteen Python release/expansion/platform tests and the isolated Godot
  expansion runtime test.
- Pinned SDK archive/file hashes verified; required native methods confirmed
  against the real extension's registered API.
- An isolated Android export bundled both SDK libraries and targeted API 34.
  The Linux fixture excluded the SDK/extension registration and launched.
- Full Quest release build passed with the established signing certificate,
  v1/v2/v3 signatures and 16 KiB ZIP alignment.
- Actual APK contains the expected AppID, mandatory entitlement configuration,
  native libraries, Godot extension registration and Android plugin metadata.
- Store manifest, current-commit provenance and combined APK/OBB asset audits
  passed. The OBB has exactly the same bytes as version 17.
- Godot loaded the exported bootstrap and OBB panorama at 8192×4096; the
  unchanged icon loaded at 512×512.
- Candidate staged successfully at
  `builds/store/quest/6d6a66aefc94eb805dcf3834298d12034fa5c45f/` in the integrated
  worktree. Uploaded to the ALPHA internal channel on 2026-09-24; see
  [QUEST_INTERNAL_UPLOAD.md](QUEST_INTERNAL_UPLOAD.md). No public release performed.

Evidence: `test-results/quest-entitlement-candidate.log`,
`test-results/quest-exported-resources.log`,
`test-results/quest-platform-fixture-{android,linux,linux-run}.log`, build
manifest and the staged candidate's signature/manifest/checksum reports.
The initial isolated fixture import crashed in Godot's editor layout startup;
a repeat import and subsequent exports passed. Direct export is used by the
fixture runner. Toolkit-enabled editor shutdown also reports one retained
ObjectDB instance; no continuing runtime leak has been established.

## Pending live acceptance

No Quest was attached. This does **not** verify dashboard ownership, test-user
entitlement, real service responses, offline caching, initialization timing,
Android startup, or headset recovery UI. Confirm app/package/channel setup and
install the candidate through an internal channel. Run the entitled, denied,
offline, timeout, relaunch and upgrade checks in
[QUEST_ENTITLEMENT.md](QUEST_ENTITLEMENT.md). Retain startup timing/device logs.
Privacy/reporting, lifecycle and performance VRCs remain separate launch work.
