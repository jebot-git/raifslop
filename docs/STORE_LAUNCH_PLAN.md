# Ultimate Boomer Simulator — Steam and Quest launch plan

Prepared 2026-09-24 using the existing [store workflow](STORE_RELEASE.md),
[candidate builder](../tools/store_release.py), and
[manual CI workflow](../.github/workflows/store-candidate.yml).
This is preparation for store submission, not a submission or certification.
The game remains free, with no real-money purchases. Retain the existing icon.

## Branch and synchronization

`stores` starts at integrated commit `937232ecdae4a923c124a5deca461d4e7c1d1f03`
(0.1.15), and now includes integrated Steam fixes through `c2b2270`.
Its only differences from that integrated revision are store preparation documents. Game code,
assets, export settings, tests and build tools match `integration/golf-fishing`.
The integrated checkout remains on its original branch; a separate worktree
holds `stores`.

Before each candidate, run these commands in the stores checkout:

```bash
git status --short
git fetch origin
git merge origin/integration/golf-fishing
git merge-base --is-ancestor origin/integration/golf-fishing HEAD
git diff --exit-code origin/integration/golf-fishing HEAD -- . ':(exclude)docs/**'
python3 -m unittest discover -s tests -p 'test_store_release.py'
```

Start with a clean tree, resolve any documentation conflicts, and commit before
building. The last diff must be empty. Implement game, packaging and shared
workflow fixes on the integrated branch first, then merge them into `stores`.
Do not restore the whole integrated tree over store documents or rewrite history.
Record the exact resulting stores commit for each candidate.

Build fresh from that clean stores commit. The released 0.1.15 manifests identify
`937232e`, so the existing stager correctly rejects them at a later stores commit.
Do not edit manifests to relabel old binaries. Existing hash-keyed texture caches
may be reused; binaries and manifests must be regenerated together.

## Current evidence and release gates

| Item | Current evidence | Required next action |
| --- | --- | --- |
| Integrated release | Linux, Windows, Quest and server exported; package audits passed | Build store candidates from the synchronized stores commit |
| Gameplay/network | Headless package and dedicated-client checks passed | Run the physical-device/platform acceptance checklist |
| Quest APK | 1,952,432,894 bytes; version code 16; ARM64; target SDK 34 | Resolve store packaging gates below |
| Quest identity | `org.jebot.raifslop.quest`; existing certificate preserved | Reuse that identity and securely provision the existing key |
| Steam identifiers | No assigned AppID/depot IDs supplied to this preparation | Publisher provides AppID and separate Windows/Linux depot IDs |
| CI registration | Store workflow exists here; its path returns 404 on remote `main` | Register the workflow on the default branch before dispatch, or build locally |
| Store accounts/listings | Not inspected or configured by this task | Publisher completes account, listing and dashboard setup |

The published Quest artifact's SHA-256 is
`e5f0b97ec4266329e78dba96c23b45712e8252fa05a93910fcb90697d973a6f2`.
Its signing-certificate SHA-256 is
`15f604964c24bd8edc02a2cde8407293c2fdc3b87939c4164ea317e929a9d380`.
These identify the reference release, not an approved store candidate.

Running the existing Quest checks against that APK produced four failures:

1. It exceeds the repository's conservative 1,000,000,000-byte APK budget.
2. Head tracking is not declared required.
3. The Godot activity is not excluded from recents.
4. It is validly v3-signed, but does not satisfy the stager's explicit v2 check.

The size threshold and v2 requirement above describe this repository's current
checker; they are not a new assertion about every accepted Meta upload format.
Do not waive the checker simply because sideloading succeeds.

## Quest: ordered preparation and submission

1. **Resolve package delivery on the integrated branch.** Decide whether to bring
   the APK under the existing budget without removing promised content, or
   implement supported expansion-asset delivery. For expansion delivery, include
   download/install, offline access, updates, checksums and failure recovery;
   extend staging and tests before treating an oversized APK as eligible.
2. **Resolve signing in the shared builder.** Preserve the existing certificate;
   explicitly enable v2 signing during final APK re-signing so the current stager
   passes, retaining newer signing where supported. Add a meaningful regression
   check. Android documents the `--v2-signing-enabled` option in
   [apksigner](https://developer.android.com/tools/apksigner).
3. **Apply and verify the existing store manifest path.** Build with
   `--store-release`, which calls `quest_store_manifest.py`. It sets required
   head tracking, excludes the activity from recents and disables debugging.
   Validate the final merged APK, not just the template. Confirm the supported
   device list against devices actually tested. Meta documents these manifest
   requirements in its [release manifest specification](https://developers.meta.com/horizon/resources/publish-mobile-manifest/).
4. **Prepare the publisher inputs.** Confirm the Meta app, organization access,
   app/package association and test-channel users. Obtain the existing keystore
   through the secure local environment or CI secrets. Check the highest uploaded
   version code; allocate a higher unused code in the integrated source before
   building an update. Code 16 is the reference release, not a reserved next code.
5. **Synchronize, commit, build and stage.** After steps 1–4, merge integrated
   changes into `stores`, run the synchronization checks above, then run:

   ```bash
   export PATH="$JAVA_HOME/bin:$PATH"
   python3 tools/build_release.py --target Quest --store-release
   python3 tools/store_release.py quest
   ```

   Supply `GODOT_BIN`, `JAVA_HOME`, `ANDROID_SDK_ROOT`, `STORE_KEYSTORE`,
   `STORE_KEYSTORE_ALIAS` and `STORE_KEYSTORE_PASSWORD` as described in
   [the existing workflow](STORE_RELEASE.md#quest). Do not put passwords in Git
   or command-line literals. The release build needed a 1536 MiB Gradle heap and
   one worker on this 16 GiB host after a daemon exit; provision sufficient runner
   memory or apply the same local generated-build tuning if needed.
6. **Check the candidate.** Preserve `builds/store/quest/<commit>/`, including
   manifest/signature inspection, notices and checksums. Run `sha256sum -c
   SHA256SUMS` inside that directory. Record the certificate, package ID, version
   code, APK SHA-256 and any expansion artifact hashes. A failed staging command
   is not a candidate; do not upload the old GitHub APK as a substitute.
7. **Complete the listing and test the installed channel build.** Set Free with
   no IAP. Supply gameplay captures, description, privacy/support URLs, ratings,
   AI-asset disclosures where requested and the reporting/data-use information
   described in the workflow. Upload to an internal channel through the app's
   dashboard/MQDH. Test clean install and signed upgrade on every advertised
   device, including saved progress, permissions, overlays and suspend/resume.
   Work through [Meta's current VRCs](https://developers.meta.com/horizon/resources/publish-quest-req/)
   and attach evidence to the acceptance record.
8. **Submit and release.** Submit the matching build and listing for review only
   after packaging and hardware gates pass. Resolve review feedback, verify the
   reviewed version/channel, then perform the public release in the dashboard.

## Steam: ordered preparation and submission

Start with [Steam onboarding and current blocker status](STEAM_ONBOARDING.md).
The account owner has confirmed AppID/depot IDs are not yet assigned. Desktop
storage migration, missing-XR feedback and staging/preflight checks are now
implemented and tested; a fresh full store candidate remains pending IDs.

1. **Provision Steamworks.** Complete publisher onboarding and obtain the real
   AppID plus distinct Windows and Linux depot IDs. Configure each depot for its
   OS and include both in the app's package. Configure free acquisition and no
   paid DLC/IAP. Keep build-account credentials outside the repository.
2. **Prepare the page early.** Use the Ultimate Boomer Simulator branding and
   existing icon; produce the required capsule/library formats and genuine
   gameplay screenshots. Complete ratings and the AI-content survey using
   `ASSET_CREDITS.md`. State VR required, supported OpenXR/controller setups,
   fishing/golf/BBQ and direct-UDP multiplayer accurately. Do not claim Steam
   achievements, Cloud, invites or Workshop. Confirm privacy/support information.
3. **Build and stage from the synchronized stores commit.** Export toolchains
   and actual IDs through the environment, then run the established commands:

   ```bash
   python3 tools/store_release.py steam --check-config
   python3 tools/build_release.py --target Windows
   python3 tools/build_release.py --target Linux
   python3 tools/store_release.py steam \
     --app-id "$STEAM_APP_ID" \
     --windows-depot "$STEAM_WINDOWS_DEPOT" \
     --linux-depot "$STEAM_LINUX_DEPOT"
   ```

   Preserve `builds/store/steam/<commit>/`. Verify its `SHA256SUMS` from that
   directory. The generated `app_build.vdf` uses relative paths, separates the
   two client depots, and contains no automatic `SetLive` promotion. Dedicated
   server distribution is separate; it is not staged into these client depots.
4. **Upload privately.** Follow the interactive SteamCMD commands in
   [the workflow](STORE_RELEASE.md#steam), using the candidate's absolute VDF
   path. Record the returned Steam BuildID and assign it to a private test branch.
   Follow [SteamPipe's upload procedure](https://partner.steamgames.com/doc/sdk/uploading).
5. **Validate the Steam-installed build.** Configure Windows launch executable
   `UltimateBoomerSimulator.exe` and Linux `UltimateBoomerSimulator.x86_64`, with
   `--xr-mode on --rendering-driver vulkan`. Keep adjacent PCK/native libraries.
   Test installation, updates, saves, missing-runtime feedback and actual VR
   play on the OS/runtime/controller combinations advertised. Check writable
   avatar storage and needed redistributables on clean machines. Physical
   Windows VR and Linux headset acceptance remain outstanding.
6. **Review and schedule release.** Submit the page and near-final build through
   Steamworks. Budget at least seven business days for review and possible
   corrections per [Valve's review guidance](https://partner.steamgames.com/doc/store/review_process).
   Check the applicable fee waiting period and Coming Soon requirement in
   [Steam onboarding](https://partner.steamgames.com/doc/gettingstarted/onboarding)
   before promising a date. After approval and acceptance, select the reviewed
   BuildID for the public branch and complete Steamworks release controls.

## CI path and account configuration

The existing `.github/workflows/store-candidate.yml` only builds/stages; it does
not upload to Steam/Meta. Provision the dedicated `store-release` runner and
GitHub environment, restrict it to trusted release refs including `stores`, and
configure the variables/secrets listed in [STORE_RELEASE.md](STORE_RELEASE.md#github-actions).

Manual dispatch also requires the workflow on the repository's default branch,
according to [GitHub's dispatch documentation](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow).
The default-branch workflow was absent when checked. Bootstrap its reviewed
workflow file on `main` before trying these commands; that separate repository
change is prepared in [draft PR #1](https://github.com/jebot-git/raifslop/pull/1),
which is not merged. No self-hosted runner is registered yet. Local builds above are usable
without CI registration. Once registered and provisioned:

```bash
gh workflow run store-candidate.yml --ref stores -f store=steam
gh workflow run store-candidate.yml --ref stores -f store=quest
```

Use the workflow's selected commit SHA when retrieving artifacts, extract the
candidate tar to preserve Linux executable permissions, and verify checksums.
Do not run Quest staging until its prerequisites pass. Never use placeholder
Steam IDs for a submission. Rebuilding at a later commit requires a new candidate.

## Acceptance and release record

Create one record per platform candidate using the full acceptance checklist in
[STORE_RELEASE.md](STORE_RELEASE.md#acceptance-record-complete-per-candidate).
Record at least:

| Field | Value to enter |
| --- | --- |
| Source | Stores commit and merged integrated commit |
| Artifact | Filename, SHA-256, candidate manifest location |
| Platform | Steam BuildID/test branch, or Quest app/channel/version code |
| Hardware | Headset, controllers, OS/runtime/GPU, test date and tester |
| Results | Install/upgrade/saves, all activities, input/overlays, network/voice, performance |
| Evidence | Logs, captures, measured frame timing, failures and follow-up issue links |
| Listing | Free/no-IAP, supported devices, privacy/support, ratings, attribution/AI disclosure |
| Review/release | Review result, approved artifact identity, release operator and date |

The remaining game-readiness work already recorded in the workflow includes
focus/input behavior, permission minimization, reporting/privacy handling,
controller support and physical performance. The 0.1.15 network report also
records oversized unreliable pose packets; test Wi-Fi loss and reconnect behavior
before signing off multiplayer. Keep missing evidence explicitly pending.
