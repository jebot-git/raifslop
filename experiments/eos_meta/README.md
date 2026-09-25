# EOS + Meta experimental workflow

Branch: `experimental/eos-meta`, based on production `main` at `555e9fc`.
This is an isolated Godot project, not a replacement for the game's ENet peer.
The parent `.gdignore` keeps its SDKs and scripts out of production imports.

## Implemented

- Optional native EOSG bindings; missing dependencies/configuration fail clearly.
- Quest Meta initialization, entitlement, logged-in user and fresh proof nonce.
- EOS Connect `OculusUseridNonce` authentication (`UserID|Nonce`), first-use
  user creation and a follow-up login to initialize EOSG's peer mediator.
- Explicit desktop-only device identity that reuses an existing device ID.
- Eight-member public test lobbies, host/join/leave, fixed host authority and
  membership checks before accepting P2P connections.
- A deployment/protocol-scoped join reference, Meta presence and native invite
  panel. Cold/warm join intents are queued through authentication. An invite
  received while already in a lobby waits for the user to leave and accept it.
- Tiny, unreliable P2P ping/echo probes, RTT and direct/relay network-type data.
  `relay="force"` tests relay use; `auto` allows direct connections and relays.
- Fresh Meta proofs on EOS authentication expiry, callback correlation,
  bounded request timeouts, cleanup of late successful lobby operations,
  host-loss handling and full-lobby presence updates.
- Phase-only logs; credentials, Meta proofs and account IDs are not printed
  by the lab. Normal game save/leaderboard identities are untouched.

## Install and run locally

From the repository root:

```sh
python3 tools/eos/setup_lab.py --platform linux
mkdir -p experiments/eos_meta/private
cp experiments/eos_meta/config.example.cfg experiments/eos_meta/private/eos.cfg
chmod 600 experiments/eos_meta/private/eos.cfg
godot --headless --path experiments/eos_meta --editor --import --quit
godot --path experiments/eos_meta --xr-mode off
```

Do not overwrite an already populated `private/eos.cfg`. The `private/` and
`addons/` directories are Git-ignored. Windows and Android dependencies can be
installed with additional `--platform windows` / `--platform android` arguments.
The installer validates pinned release SHA256 values before extracting and
copies the project's existing Meta toolkit. It installs only the native EOSG
surface; no upstream HEOS autoloads or production editor settings are needed.

Preflight is read-only and does not authenticate:

```sh
godot --headless --path experiments/eos_meta -- --preflight
```

Exit 2 means the SDK/config is missing. `--config /absolute/path/eos.cfg` selects
another local configuration. For two Linux desktop clients, use separate
`XDG_DATA_HOME` directories and `provider="device"`; otherwise both processes
would share the same EOS device identity. Device identity is for the lab only,
not durable cross-platform accounts. Start the lab in each process, Connect,
Host on one, Copy current reference, and Join reference on the other.

## Developer portal setup

Portal configuration was supplied manually by the user and the configured
EOS deployment has passed the desktop checks below. This branch does not
automatically create or modify portal resources.

1. In the [Epic Developer Portal](https://dev.epicgames.com/portal/), select the
   correct organization and the existing **Ultimate Boomer Simulator** product,
   or create that product if none exists. Use a development sandbox and a
   separate deployment named **ubs-eos-lab**. Keep experiments out of a live
   deployment. Record product ID, sandbox ID and deployment ID in `private/eos.cfg`.
2. Create a game-client policy and client for **ubs-eos-lab**. Enable the Connect,
   Lobbies and P2P permissions needed by player clients to authenticate, create,
   join/read/leave their lobbies and exchange packets. Use player-scoped
   permissions, not a trusted-server/admin policy. Record the client ID and
   client secret locally. This client credential is distributed with an app;
   it must not grant server/admin powers.
3. Configure the **Oculus/Meta identity provider** for the same product/sandbox
   using the real Meta app identity. Put any Meta app secret into the provider's
   server-side portal configuration, never the APK, this repository or chat.
   Ensure test accounts can access the development sandbox.
4. Meta DUC for **User ID, User profile, Friends and Invites** was confirmed
   granted by the application owner on **2026-09-25**. Configure a destination
   API name **eos_lab** in the Meta developer dashboard.
   Enable the appropriate joinability/invite behavior and eight-player group
   capacity. Use entitled test accounts and a channel/package/signing setup
   matching that Meta app. Set `app_id` and `destination` in the local config.
5. First validate two desktop device identities in the same deployment. Then
   validate a real Meta identity and its EOS Product User ID, followed by a
   second entitled Meta account and Quest/PC crossplay.

The lab intentionally uses **public test lobbies** with join-by-ID enabled for
native-platform invitations. A join reference is a locator, not an access
credential. P2P admission additionally checks actual EOS lobby membership.
Private-lobby tickets/admission and Meta party-created group sessions need a
separate design and acceptance test before production use.

## Android / Quest packaging gate

The Meta adapter and EOS Android binaries are provided, but this lab currently
has a desktop control panel. It is **not yet a headset-ready VR test build**.
No APK was installed or headset session launched.

Before a Quest build, prepare an isolated Gradle export and VR control panel:

- Include the installed EOS AAR and the Meta toolkit AAR, OpenXR vendor plugin,
  and arm64 native libraries; preserve current production target/min SDK choices.
- Bootstrap `com.epicgames.mobile.eossdk.EOSSDK` on Android's activity thread,
  loading `EOSSDK` and calling `EOSSDK.init(activity)` before Godot initializes
  the native EOS platform. Copying `.so` files alone is insufficient.
- Apply the EOS AAR's manifest/dependency requirements, the client-specific
  `eos_login_protocol_scheme`, network permissions and lifecycle integration.
- Export a separate test package using the real entitled Meta test-app setup;
  do not replace the installed ALPHA build. Inspect arm64 dependencies and
  16 KiB alignment before installation.
- Provision local configuration explicitly. Do not blindly include the whole
  `private/` directory in release exports.

The [EOSG Android initialization instructions](https://3ddelano.github.io/epic-online-services-godot/docs/topics/initialization)
describe the required Java/AAR bootstrap. Their example targets an older Godot
template; adapt it to this project's Godot 4.7.2 activity rather than replacing
the activity file wholesale. `EOS_Android_InitializeOptions` is still marked TODO
in the inspected wrapper; do not infer Android readiness from the Linux check.

## Tests and acceptance

```sh
python3 tools/eos/test_lab.py
```

The runner checks a clean SDK-free copy, missing-configuration preflight, and
the installed native SDK when present. It isolates test user data under `/tmp`
and writes reports to `test-results/eos-meta/`. It never uses the real config
to authenticate. To run just the GDScript assertions, use `godot --headless
--path experiments/eos_meta --script res://test_workflow.gd`.

Verified locally: **83 assertions, zero failures**, including actual Linux EOS
SDK initialization/shutdown and native API registration. Login, Meta proof,
lobby and failure flows use deterministic fake service responses. The test
does not contact EOS or claim a successful real account login.

Godot reports one ObjectDB instance at exit with the native dependencies loaded;
this also occurs in configuration-only preflight. Investigate before release.

### Live desktop results, 2026-09-24

Configuration preflight passed. Two separate persistent desktop device identities
authenticated, created/joined an eight-member test lobby, exchanged ten P2P
ping/echo probes, and both left successfully in each run:

| Mode | EOS-reported network type | Replies | Median RTT | Cleanup |
| --- | --- | --- | --- | --- |
| Auto | Direct (`1`) | 10/10 | 7 ms | Host and client successful |
| Forced relay | Relayed (`2`) | 10/10 | 41.5 ms | Host and client successful |

Both processes ran on this workstation. The forced-relay check traverses EOS's
relay, but these results do **not** establish cross-network NAT behavior,
eight-player performance, Quest identity or Meta invitations. Both runs reported
zero rejected requests/packets and empty incoming/outgoing queues at completion.
Reports are in `test-results/eos-meta/live-20260924-235218-auto/` and
`test-results/eos-meta/live-20260924-235259-force/`. Logs/configuration are private
local files and are not committed.

A further forced-relay run verified the runner's network-type assertion and
median calculation: 10 replies, 35 ms median, both clients cleaned up
(`test-results/eos-meta/live-20260924-235441-force/`).

To repeat explicitly (this contacts EOS and creates temporary public lab lobbies):

```sh
python3 tools/eos/test_live.py --relay auto
python3 tools/eos/test_live.py --relay force
```

The live runner overrides identity to **device only in process memory**; the
user's `provider="meta"` configuration remains intact. Test identities persist
under `builds/eos-live-identities/host` and `client`. It checks actual reported
transport type, bounds execution time, records RTT/queue diagnostics, and attempts
lobby cleanup. No headset is installed or launched. An externally killed process
may leave lobby membership until the service expires it.

Still required after provisioning:

| Gate | Evidence to collect |
| --- | --- |
| Real Connect login | Existing and new Meta user succeed; entitlement denial blocks login |
| WAN P2P | Two independent Internet connections; direct/forced relay; repeated probes and queue sizes |
| Admission | Nonmember cannot open peer; full, wrong-deployment and wrong-protocol joins fail |
| Meta invitations | Cold/warm launches, full lobby, leave intent, expired reference and friend account |
| Lifecycle | Fresh nonce on expiry; network loss, Quest sleep/resume, host departure, retry after timeout |
| Android export | Java bootstrap, AAR/native dependency audit, ABI/alignment, real entitlement |

Local logs: `user://logs/eos-meta-lab.log`. RTT counters are visible in the lab;
`eos_backend.diagnostics()` also exposes queue sizes. The join reference is
copied only through the explicit UI action. No generic SDK log callback dumps
tokens or arbitrary platform payloads.

## Gameplay integration status

The game now has a transport factory and bounded main-thread EOSG adapter, plus
online lobby/menu integration. The lab remains a separate protocol-1 probe;
its raw peer is not attached directly to gameplay. See
[EOS gameplay transport](../../docs/EOS_GAMEPLAY_TRANSPORT.md) for setup,
actual queue/channel handling, desktop direct/forced-relay results and remaining
Quest gates. Protocol 19 retains compact tracking, framing, scheduling, requested
ranking pages and BBQ deltas/time anchors.

Pinned dependency: EOSG **2.3.1**, source commit
`56238973e2cd7ac9ac99ca14f88934465f0a8997`; Meta toolkit **1.0.3-stable** from
the existing repository. The feasibility report inspected a newer EOSG source
commit; this implementation uses the published release for reproducibility.
See [EOSG release](https://github.com/3ddelano/epic-online-services-godot/releases/tag/2.3.1),
[Connect native interface](https://github.com/3ddelano/epic-online-services-godot/blob/56238973e2cd7ac9ac99ca14f88934465f0a8997/src/connect_interface.cpp),
[Meta toolkit](https://github.com/godot-sdk-integrations/godot-meta-toolkit/tree/7fc223fa4b9a1b43552a53bf287a720c4719ea76),
and [Meta destinations](https://developers.meta.com/horizon/documentation/native/ps-destinations-implementation/).
