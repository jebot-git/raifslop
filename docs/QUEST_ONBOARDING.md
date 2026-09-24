# Quest Store blockers and launch sequence

Status checked 2026-09-24. Ultimate Boomer Simulator remains free with no
real-money IAP. Keep the current icon and Android package
`org.jebot.raifslop.quest`. This is a launch worklist, not a submission or
certification claim.

## Measured blockers

The existing v0.1.15 APK (version code 16, commit `937232e`) is
1,952,432,894 bytes. Its SHA256 is
`e5f0b97ec4266329e78dba96c23b45712e8252fa05a93910fcb90697d973a6f2`.
It exceeds the 1 GB APK limit, declares optional head tracking, includes the
activity in recents. ARM64, target API 34, v1/v2 signatures and
16 KiB ZIP alignment pass. The previous verifier falsely rejected v2 because
its default Android-version range selected v3; explicit verification from API
21 exercises all required schemes. This older artifact is not a stores candidate.

Changes to release tooling explicitly enable v1/v2/v3 signing and verify the
established signing certificate before importing/exporting. Store manifest
overrides already set required head tracking and exclude the Godot activity
from recents. These overrides still need verification in a freshly exported
APK. Do not treat a template test as a merged-manifest/device test.

The signing certificate SHA256 is
`15f604964c24bd8edc02a2cde8407293c2fdc3b87939c4164ea317e929a9d380`.
Keep the existing private key and credentials in the owner's secret storage.
The public digest is deliberately pinned in preflight to protect upgrades.

## Account owner actions

1. Open the [Meta Developer Dashboard](https://developers.meta.com/horizon/manage/),
   create/select your developer organization and complete
   [organization verification](https://developers.meta.com/horizon/resources/publish-organization-verification/).
   Identity/business evidence and legal agreements require the account owner.
2. Create the Quest app named **Ultimate Boomer Simulator** and record its
   numeric AppID. Preserve the existing Android package identity. AppID and
   package name are different identifiers. Choose Free pricing; create no paid
   products or subscriptions.
3. Assign developer roles and internal testers, and prepare an internal release
   channel. Keep upload tokens and app secrets outside the repository; only the
   AppID and public support/privacy URLs are needed for source configuration.
4. Supply a public support contact, privacy policy and deletion-request route.
   Review microphone voice chat, network identity, avatars, persistence and
   leaderboards against actual server data handling. Complete applicable data-use,
   age/content and user-reporting requirements in the dashboard.

No account enrollment, AppID assignment or dashboard configuration has been
performed by these repository changes.

## Engineering work before a candidate

1. **Expansion delivery:** retain the existing texture quality and content while
   splitting the APK below 1,000,000,000 bytes. Meta allows one OBB up to 4 GB,
   named `main.<versionCode>.org.jebot.raifslop.quest.obb`, or required asset files.
   Evaluate a Godot resource pack mounted before loading game resources. Implement
   missing/corrupt/wrong-version handling and audit the combined APK/expansion
   resource graph. Include both files in provenance and staging. Merely moving
   textures outside the APK will break resource loading; no expansion delivery
   exists in the current workflow. Test channel install, offline startup, upgrade
   and interrupted download before accepting this solution.
2. **Platform entitlement:** integrate Meta Platform SDK with the assigned AppID
   and implement the entitlement result/error path. The source audit found no
   application entitlement implementation. OpenXR vendor extensions alone do not
   supply this integration. Validate entitled/non-entitled users and network
   failures using the official platform behavior.
3. **Lifecycle and permissions:** test overlay focus, hidden hands, input
   suppression, recenter, headset removal and suspend/resume in all activities.
   Review microphone and optional tracking permissions, including denied access.
4. **Hardware acceptance:** measure startup, frame timing, memory and thermal
   behavior on Quest 3 through fishing, golf, BBQ and multiplayer sessions.
   Keep Mobile rendering until device measurements justify a change. The current
   advertised device list also includes Quest 2/Pro/3S; validate or narrow it.
5. Bump Android version code above every uploaded build. For expansion delivery,
   update the APK and expansion together with matching version codes.

## Local checks and launch order

Use `stores` synchronized with `integration/golf-fishing`; keep shared source
changes on integrated and merge them into stores. Provision the existing
`STORE_KEYSTORE`, `STORE_KEYSTORE_ALIAS`, `STORE_KEYSTORE_PASSWORD`, `JAVA_HOME`,
`ANDROID_SDK_ROOT` and `GODOT_BIN` as described in [STORE_RELEASE.md](STORE_RELEASE.md).

```bash
export PATH="$JAVA_HOME/bin:$PATH"
python3 -m unittest discover -s tests -p test_store_release.py
python3 tools/store_release.py quest --check-config
# Diagnostic only: can inspect a previous APK without presenting it as current.
python3 tools/store_release.py quest --inspect-apk builds/Quest/UltimateBoomerSimulator.apk
# After engineering blockers above are resolved, from a clean committed checkout:
python3 tools/build_release.py --target Quest --store-release
python3 tools/store_release.py quest
```

Diagnostic output is JSON and returns nonzero on packaging failures. It does
not bypass candidate provenance checks. The current oversized artifact fails
staging by design. Signing preflight neither verifies Meta account access nor
asserts entitlement integration.

The prepared CI workflow uses a trusted `store-release` runner/environment.
Register the workflow on the default branch before manual dispatch; provision
the runner/toolchains and signing secret. CI only prepares a candidate.

After packaging passes, verify candidate hashes, upload to an internal release
channel and install through that channel. Expansion builds require Meta's
Platform CLI; the present APK-only stager must be extended before using it.
Check the installed CLI's upload help for its current expansion options, and
supply authentication through private configuration. Do not upload the old
oversized APK as a release candidate.

Record the exact commit, hashes, devices, OS versions and VRC results. Complete
listing screenshots/trailer, supported-device claims, free pricing, ratings,
privacy/reporting and attribution, then submit build and listing for review.
Release after acceptance and perform a store-install smoke test. Preserve the
previous candidate and signing identity; a corrective update needs a higher
version code, not reuse of the old version.

## Official requirements checked

- [APK sizes and expansion delivery](https://developers.meta.com/horizon/resources/publish-apk/)
- [Required v1/v2 signing and certificate continuity](https://developers.meta.com/horizon/documentation/native/android/mobile-application-signing/)
- [Release manifest](https://developers.meta.com/horizon/resources/publish-mobile-manifest/)
- [AppID and entitlement](https://developers.meta.com/horizon/resources/publish-overview-appID/)
- [Quest requirements](https://developers.meta.com/horizon/resources/publish-quest-req/)
- [Submission](https://developers.meta.com/horizon/resources/publish-submit/)
