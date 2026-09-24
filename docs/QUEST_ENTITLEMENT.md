# Quest store entitlement

The owner-supplied AppID is **3428825797290213**. Public build configuration is
in `config/quest_store.json`; `META_QUEST_APP_ID` can override it in a trusted
release environment. This numeric ID is not an app secret. Never embed account
passwords, access tokens or app secrets.

Quest store builds include pinned Godot Meta Toolkit 1.0.3-stable and inject
`quest_store.json` into the signed APK. Startup initializes the Platform SDK
asynchronously, checks initialization status, requests viewer entitlement and
allows game loading only after a successful result. The check runs before OBB
hashing, with a ten-second deadline covering initialization and entitlement.
Errors, null requests, denial and late callbacks cannot start gameplay. The
headset displays recovery instructions; close through the system menu and
relaunch after resolving the account/network issue. The application delegates
offline entitlement decisions to Meta's SDK; it does not invent a local bypass.

Desktop and dedicated server startup are unchanged. Non-store Quest exports
remain development/sideload builds. The store stager rejects APKs without the
required entitlement metadata, matching AppID and both native SDK libraries.
The SDK's convenience export overrides are disabled to preserve target API 34;
its Android library hook still includes the AAR. Desktop exports exclude the
add-on. Upstream binaries, licenses and SHA256 provenance are retained under
`addons/godot_meta_toolkit/`.

## Validation commands

```bash
python3 -m unittest discover -s tests -p test_quest_platform.py
GODOT_BIN=/path/to/godot python3 tools/test_quest_entitlement.py
python3 tools/store_release.py quest --check-config
python3 tools/build_release.py --target Quest --store-release
python3 tools/store_release.py quest
```

The isolated `tools/test_quest_platform_export.py` additionally exports a tiny
Android fixture and a Linux fixture to check SDK inclusion/exclusion. It uses
the installed toolchains and Godot signing environment, never an AppID or a
store upload. Its APK uses a separate test package and is not a candidate.

## Account owner and headset steps

1. In the Meta developer dashboard, confirm AppID 3428825797290213 belongs to
   Ultimate Boomer Simulator and targets Quest. Preserve Android package
   `org.jebot.raifslop.quest` and the established signing certificate.
2. Complete organization verification and the applicable Data Use Checkup.
   Request only the platform features actually used. Configure the free listing,
   internal release channel and authorized test users; testers must accept their
   invitations/access before testing. Free pricing still requires app entitlement.
3. Upload the staged APK with its exact matching OBB through Meta Platform CLI.
   Version code is now 18; increment it before any subsequent uploaded revision.
   No upload credentials are stored in this repository.
4. Install through the internal channel on Quest. Verify successful startup for
   an entitled account, denial for an account without access, offline SDK
   behavior, loss of network during initialization, timeout/relaunch, system
   overlays, headset removal and OBB verification after entitlement success.
5. Capture device/OS, account test role (no tokens), commit, file hashes and
   timing. Inspect logs for SDK initialization/entitlement errors without logging
   account profiles or raw platform payloads.

Unit tests and APK inspection cannot establish dashboard ownership, tester
entitlement, SDK service availability or VRC acceptance. Those require the
actual device/account setup. No account authentication, channel upload or live
entitlement result is implied by a local build.

Sources: [Meta entitlement checks](https://developers.meta.com/horizon/documentation/native/ps-entitlement-check/),
[Toolkit setup and API](https://godot-sdk-integrations.github.io/godot-meta-toolkit/manual/platform_sdk/getting_started.html).
