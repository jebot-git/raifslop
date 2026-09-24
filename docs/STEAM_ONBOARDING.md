# Steam application and launch workflow

Status: publisher onboarding and AppID/depot allocation are pending. No Steam
application has been created or submitted by the repository tooling. Checked
2026-09-24. This runbook uses the existing free/no-IAP store candidate workflow.

## Account owner: apply through Steam Direct

1. Open [Steam Direct](https://partner.steamgames.com/steamdirect) and sign in with
   the Steam account that will own the publisher relationship. Complete the
   agreements yourself; keep Steam Guard and credentials in your own session.
2. Prepare your legal individual/company name, address, matching bank-account
   details and tax information. Enter these directly into Steamworks, not in Git
   or chat. Valve permits individual onboarding; follow its
   [onboarding instructions](https://partner.steamgames.com/doc/gettingstarted/onboarding).
3. Pay the **US$100 per-app fee (or local equivalent)** when the account flow
   requests it. A free game still has this onboarding fee. Review the charge in
   Steam before payment. See [Steam Direct fee](https://partner.steamgames.com/doc/gettingstarted/appfee).
4. Complete verification and create the app for **Ultimate Boomer Simulator**.
   Record its assigned AppID. Configure free acquisition, with no paid DLC,
   subscriptions or real-money in-game purchases.
5. In the app's SteamPipe configuration, create/confirm separate Windows and
   Linux depots, filter each by OS and add both to the app's package. Record the
   actual depot IDs. The tools require all three IDs to be distinct and numeric.
6. Provide only the AppID and two depot IDs for build configuration. Also select
   a public support contact and privacy-policy URL. Do not share passwords,
   Steam Guard codes, bank details or tax documents with build tooling.

Do not promise a release date yet. Valve documents an applicable 30-day wait
from fee payment and at least two weeks of public Coming Soon visibility for
initial releases. Plan review time as well; follow the dashboard's eligibility
and [review process](https://partner.steamgames.com/doc/store/review_process).

## Repository work completed

- Desktop imported/downloaded avatars default to writable `user://data/vrm`,
  independent of Steam's install directory. Existing install-folder avatars are
  copied without deleting originals; filename conflicts preserve both models.
  Existing `--asset-root` portable/server overrides still work. Editor and
  Android default paths are unchanged.
- A graphical desktop launch without OpenXR shows setup instructions before
  exiting. Headless launches still exit promptly with a diagnostic; no desktop
  gameplay mode is introduced.
- `store_release.py steam --check-config` rejects missing/invalid/duplicate IDs
  before exports. It validates syntax only; Steamworks controls ownership.
- Steam staging checks the executable, PCK, XR and voice libraries, Linux execute
  permission, and accidental extra depot files. A candidate includes
  `steam-launch.json` with the executable/arguments for each OS.
- The manual candidate CI workflow only runs from `stores`, preflights Steam
  IDs before exporting and supplies the Android signing password only for Quest.

Validation: seven Python store tests pass. An isolated Godot release export
passes 18 storage checks against a read-only installation (default user directory
and explicit portable root), plus the missing-XR headless exit check. This does
not establish Windows or physical-headset acceptance.

## Local candidate workflow after IDs are assigned

Use a clean, committed `stores` checkout synchronized with the integrated branch.
Set real values for `STEAM_APP_ID`, `STEAM_WINDOWS_DEPOT`, `STEAM_LINUX_DEPOT` and
`GODOT_BIN` in the environment. No account login is needed for local packaging.

```bash
python3 tools/store_release.py steam --check-config
python3 -m unittest discover -s tests -p 'test_store_release.py'
python3 tools/build_release.py --target Windows
python3 tools/build_release.py --target Linux
python3 tools/store_release.py steam
```

The output is `builds/store/steam/<full-commit>/`. From that directory run
`sha256sum -c SHA256SUMS`. Retain the manifest, notices, VDF and launch settings.
Builds from older commits cannot be relabelled; rebuild after source changes.
No placeholder AppIDs, ownership bypass, Steam SDK integration or public branch
promotion are required to prepare the current direct-UDP game.

Install the Steamworks SDK's SteamCMD after account access is granted. In its
interactive console, authenticate with a build account and Steam Guard, then:

```text
login YOUR_BUILD_ACCOUNT
run_app_build /absolute/path/to/candidate/app_build.vdf
quit
```

Record the returned Steam BuildID and assign it to a private test branch.
The VDF intentionally omits `SetLive`. Upload and install using Valve's
[SteamPipe instructions](https://partner.steamgames.com/doc/sdk/uploading).

## Steamworks launch and listing configuration

Configure OS-filtered launch entries under Installation > General. Set the VR
options and list tested OpenXR devices/controller configurations in the store
page's Basic Info. Follow [Valve's VR setup documentation](https://partner.steamgames.com/doc/features/steamvr/settings).

| OS | Executable | Arguments |
| --- | --- | --- |
| Windows | `UltimateBoomerSimulator.exe` | `--xr-mode on --rendering-driver vulkan` |
| Linux | `UltimateBoomerSimulator.x86_64` | `--xr-mode on --rendering-driver vulkan` |

Keep each executable beside its PCK and native libraries. Use VR required and
tracked-controller input. Do not advertise Steam Deck, Steam Frame standalone,
unsupported controller profiles, Cloud, achievements, Workshop or Steam invites.
Maintain the existing icon. Prepare required capsule/library artwork separately.

Draft short description for publisher review:

> Cast a line, play a round of golf, and meet friends at the grill. Ultimate
> Boomer Simulator brings fishing, golf and shared BBQ activities together in
> a free VR game with direct-server multiplayer.

Complete the AI-content survey from ASSET_CREDITS: the project includes generated
artwork/textures; current gameplay does not call a live generative-AI service.
Use actual gameplay screenshots and approved rights/attributions. Enter measured
system requirements after platform tests, not guessed minimum specifications.

A privacy page needs the publisher's identity/contact and actual server-operator
arrangements. Review local saves, player names/identity tokens, avatar exchange,
voice/tracking transmission and server-held records; establish retention and
handling of deletion/report requests. This document is a data-review checklist,
not a published privacy policy or a claim of legal compliance.

## Remaining launch gates

| Gate | Status / next step |
| --- | --- |
| Steam account, AppID and depot IDs | Account owner follows application steps above |
| Support/privacy URLs and listing artwork | Publisher supplies/reviews these |
| Windows and Linux headset tests | Install private Steam build; test clean install, upgrade, saves, controllers, overlays, recenter, reconnect and all activities |
| Performance/system requirements | Record physical headset frame timing and hardware/runtime versions |
| Multiplayer | Test Wi-Fi/WAN and oversized-pose-packet loss; loopback alone is insufficient |
| CI availability | No repository self-hosted runner registered at last check; use local workflow or provision trusted `store-release` runner/environment |
| CI registration | Default branch must contain the manual workflow; bootstrap PR can register it without moving gameplay branches |
| Public release | Only after approved page/build, eligibility dates and acceptance evidence |

The application, payment, agreements and dashboard submission require the account
owner. No payment, onboarding agreement, Steam upload or public release was made
as part of these local changes.
