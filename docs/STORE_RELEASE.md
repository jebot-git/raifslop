# Free Quest and Steam release workflow

Release policy: the integrated fishing, golf and BBQ game is **free to acquire,
with no real-money in-app purchases, subscriptions or paid currency** on both
stores. Earned gameplay progression/tackle purchases remain ordinary gameplay;
do not describe them as IAP. This document and candidate metadata record that
policy; they do not change pricing in either developer dashboard.

## Prepare candidates

Use a clean committed checkout of the intended release revision. Requirements:
Godot 4.7.2 and matching Windows/Linux/Android export templates, Python 3.11+,
Java 17 and Android SDK/build-tools 36.1.0 for Quest. Install the native export
libraries already tracked by this project. Hardware tests and store account
setup are separate from packaging success.

### Quest

Start with [Quest onboarding and measured blockers](QUEST_ONBOARDING.md).

Provision the **existing** signing keystore outside the checkout. Preserve its
password and certificate identity; changing keys can break upgrades. Set
`GODOT_BIN`, `JAVA_HOME`, `ANDROID_SDK_ROOT`, `STORE_KEYSTORE` (absolute path),
`STORE_KEYSTORE_ALIAS` (normally `fishing`) and `STORE_KEYSTORE_PASSWORD` through
your local secret environment. Do not put passwords in shell history, source,
artifacts or documentation. Use the existing JDK installation, not an assumed path.

```bash
export PATH="$JAVA_HOME/bin:$PATH"
python3 tools/store_release.py quest --check-config
python3 tools/build_release.py --target Quest --store-release
python3 tools/store_release.py quest
```

The Store build refuses to invent a signing identity. It applies idempotent
head-tracking/recents/release overrides to Godot's generated Android manifest.
The Quest export explicitly targets Android API 34. This is distinct from the
Android compile SDK and Horizon OS version. The stager checks current-commit
hashes, packaged assets, target SDK, ARM64, release flags, launch categories,
v1/v2 signatures, 16 KiB ZIP alignment and a conservative **1,000,000,000-byte APK
budget**. Store exports now move texture payloads unchanged into a Godot resource
pack carried as `main.<versionCode>.<package>.obb` (under 4 GB). The signed APK
binds its size and SHA256; the bootstrap verifies and mounts it before game load.
Audits validate the combined resource graph and original HDR bytes. The older
monolithic APK remains over budget and is not a current candidate.
See [expansion delivery](QUEST_EXPANSION.md) for installation and acceptance.

Output: `builds/store/quest/<commit>/`, including APK, matching OBB, manifest inspection,
signature report, notices, candidate metadata and SHA256SUMS. A failure produces
no new staged candidate. Re-running an already staged revision refuses to
replace it. Increment Android version code before an update upload.

In Meta Developer Dashboard:

1. Complete organization verification, create/choose the app, and set pricing to
   **Free**. Create no IAP products or subscriptions. Confirm multiplayer/co-op,
   controller input and the actual supported device list.
2. Supply privacy policy, support contact, age rating/self-certification and
   accurate descriptions/artwork. Configure User Reporting Service and an inbox
   and moderation process for multiplayer/avatars/leaderboards. Complete required
   data-use review; mixed-age targeting requires the age-category integration.
3. Upload the exact staged APK and matching OBB to an internal testing release
   channel using Meta Platform CLI (expansion uploads require the CLI). Check
   dashboard validation and install from that channel.
4. Record physical-device acceptance below against this commit and APK hash.
5. Submit the build and metadata for Store review; release publicly only after
   acceptance and review of the final free/no-IAP listing.

Packaging success is not VRC certification. Remaining product work from the
September 2026 audit: consistent focus/input suppression and hidden hands under
system overlays; permission minimization; privacy/deletion support; reporting
configuration; current integrated-game performance and startup tests. Plugin
metadata currently advertises Quest 2/Pro/3/3S: narrow the device list to those
actually validated or test all of them before claiming support.

### Steam

Create an AppID and separate Windows/Linux depot IDs in Steamworks first.
Configure each depot for its OS and include both depots in the appropriate
package. The repository has no publisher account credentials or assigned IDs.

```bash
python3 tools/build_release.py --target Windows
python3 tools/build_release.py --target Linux
python3 tools/store_release.py steam \
  --app-id "$STEAM_APP_ID" \
  --windows-depot "$STEAM_WINDOWS_DEPOT" \
  --linux-depot "$STEAM_LINUX_DEPOT"
```

Output: `builds/store/steam/<commit>/`, including `app_build.vdf`, separate
`content/Windows` and `content/Linux` trees, notices, metadata and hashes. The
VDF uses relative paths and contains **no SetLive directive**. It uploads a
build without promoting it to the default or public branch. Verify the downloaded
candidate with `sha256sum -c SHA256SUMS` from its directory before upload.

Using Steamworks SDK's SteamCMD and a build account authenticated with Steam
Guard (enter credentials interactively, never in a checked-in command):

```text
login YOUR_BUILD_ACCOUNT
run_app_build /absolute/path/to/candidate/app_build.vdf
quit
```

1. In Steamworks select the **Free to Play** distribution/pricing configuration;
   explain the entire game is free with no IAP. Do not enable paid DLC,
   subscriptions, microtransactions or external purchase links. The Steam Direct
   app fee/onboarding still applies to a free game.
2. Configure OS-specific VR launch options: `UltimateBoomerSimulator.exe` on Windows and
   `UltimateBoomerSimulator.x86_64` on Linux, arguments
   `--xr-mode on --rendering-driver vulkan`. Declare **VR required**, OpenXR,
   tracked-controller input and tested headsets/play-area requirements.
3. Select actual required redistributables after clean-machine testing. Assign
   the uploaded build to a private test branch and test installation via Steam.
   Keep all PCK/native libraries next to their respective executable.
4. Complete ratings/content survey and disclose **pre-generated AI artwork and
   textures** documented in ASSET_CREDITS. Current gameplay has no live generative
   AI service. Supply representative screenshots, capsule/library artwork,
   support details, requirements and privacy information. Do not advertise
   achievements, Cloud, Workshop or Steam invites until implemented.
5. Submit Store page and near-final build for review. Meet the applicable
   30-day fee waiting period and two-week Coming Soon period. Set the reviewed
   build live and release through Steamworks only after acceptance.

Steamworks SDK, DRM, achievements, Cloud, Steam networking and platform
leaderboards are not required for this free release. Existing direct-UDP servers
and shared persistence can remain. If dedicated server delivery through Steam is
wanted, configure a separate Tool app/depot; this workflow stages client depots
only. Existing server build tooling remains available separately.

Recommended product follow-ups: migrate writable avatar storage from the install
folder into user data; improve missing-OpenXR feedback; validate Touch and Index
and implement additional controller profiles before advertising them. Windows
runtime testing is still outstanding. Do not infer Steam/Linux headset acceptance
from native simulated Monado tests or successful export.

## GitHub Actions

`.github/workflows/store-candidate.yml` provides a manual Quest/Steam selector.
It builds and stages candidates, never uploads to either Store or publishes.
Provision a dedicated Linux x64 self-hosted runner labelled `store-release`, with
matching Godot templates, SDK, Java and enough disk for imports/exports. Run only
trusted release branches on this runner; never attach it to untrusted PR jobs.
Create a GitHub environment `store-release`, restrict its deployment branches,
and configure variables:

- `GODOT_BIN`: absolute Godot 4.7.2 executable path.
- `JAVA_HOME`, `ANDROID_SDK_ROOT`: installed Quest toolchains.
- `STORE_KEYSTORE`, `STORE_KEYSTORE_ALIAS`: existing key outside checkout.
- `STEAM_APP_ID`, `STEAM_WINDOWS_DEPOT`, `STEAM_LINUX_DEPOT`: actual numeric IDs.
- Secret `STORE_KEYSTORE_PASSWORD`: existing Android key/store password.

The workflow serializes use of the runner and uploads a tar candidate that
preserves Linux executable permissions. Download and extract before using it.
The runner/environment and Store accounts must be provisioned by their owner;
no account setup or external publication is claimed by this repository.

## Acceptance record (complete per candidate)

Record commit, artifact SHA256, device/controllers, OS/runtime/GPU versions,
tester/date, results and log locations. Outstanding items stay outstanding.

- Clean install, upgrade, saved progression, account/user switching and recovery.
- VR launch from the platform library; recenter, controller disconnect/reconnect,
  system overlay, headset removal and suspend/resume. Solo pauses appropriately;
  multiplayer turn timers and server simulation remain authoritative.
- Fishing methods, all courses, clubhouse travel, competition, timeout/forfeit,
  radio across activities, BBQ, guide camera, avatar loading and mirrored view.
- Denied microphone/tracking access, offline play, failed network connection,
  reporting flow, privacy/deletion contact and supported input modes.
- Physical Quest performance/startup tests and VRCs on every listed device;
  clean Windows/SteamVR and advertised Linux/OpenXR configurations for Steam.
- Free acquisition, no real-money checkout/paywall/IAP, accurate Store features.
- Packaged commercial redistribution rights, attribution, course references and
  AI-content disclosures checked. Privacy text matches actual network behavior.

## Official references (checked September 2026)

- [Meta manifest requirements](https://developers.meta.com/horizon/resources/publish-mobile-manifest/)
- [Meta VRCs](https://developers.meta.com/horizon/resources/publish-quest-req/)
- [Meta submission](https://developers.meta.com/horizon/resources/publish-submit/)
- [Meta reporting](https://developers.meta.com/horizon/resources/reporting-service/)
- [SteamPipe](https://partner.steamgames.com/doc/sdk/uploading)
- [Steam VR setup](https://partner.steamgames.com/doc/features/steamvr/settings)
- [Steam review](https://partner.steamgames.com/doc/store/review_process)
- [Steam content survey](https://partner.steamgames.com/doc/gettingstarted/contentsurvey)
- [Steam onboarding](https://partner.steamgames.com/doc/gettingstarted/onboarding)
- [Steam API optionality](https://partner.steamgames.com/doc/sdk/api)
