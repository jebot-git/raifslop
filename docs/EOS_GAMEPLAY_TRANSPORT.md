# EOS gameplay transport integration

Implemented on `experimental/eos-meta`, 2026-09-25. Gameplay remains protocol 19.
The isolated protocol-1 lab remains separate. ENet stays available for IP hosting
and the asset-free dedicated server.

## Implemented

- `transport_factory.gd` creates framed ENet peers or the new `eos_peer.gd` adapter.
  `session.gd` attaches either transport to the same gameplay, golf, BBQ, voice,
  avatar and ranking RPCs. Host authority remains peer 1.
- `scripts/network/eos/` promotes the lab's configuration, callback correlation,
  Meta identity/proofs, EOS Connect login and lobby workflow into the game.
  Runtime cancellation prevents late authentication/lobby completions from
  attaching a peer after leaving. Failed/expired identity and host loss leave
  the game session; explicit reconnect preserves the authenticated record key.
- EOS records use a deployment-scoped hash of the native peer's EOS Product User
  ID. Clients cannot choose an installation token for the EOS record. Existing
  ENet identities/saves remain intact; account linking/import is not implemented.
- Together has a hosting submenu with a required name, eight-player capacity
  (host included), optional password, and a browser showing names, occupancy and
  locks. Direct IP controls remain available in a separate expandable section.
  Search uses public `ubs_bucket`, `ubs_protocol`, `ubs_name` and `ubs_locked`
  attributes, with a maximum of 50 results and a two-second refresh interval.
  New lobby indexing is eventually consistent; Refresh retries an empty search.
- Lobby admission runs through SceneMultiplayer authentication before hello,
  roster, record creation or gameplay RPCs. The host challenges each connection
  with a random nonce and verifies HMAC-SHA256 using a salted password-derived
  key. Neither passwords nor their verifier are published in EOS attributes,
  presence, invitations, preferences or logs. Wrong-password peers are kicked
  from EOS membership and may retry; admission expires after 12 seconds.
  Passwords protect gameplay access, not initial EOS lobby membership: joining
  the public EOS lobby temporarily occupies a slot before admission completes.
  This does not replace the native sender-binding acceptance gate below.
- Named/admitted rooms use bucket `ubs-eos-game-v19-lobbies1`, separate from the
  earlier EOS prototype. Gameplay RPC protocol remains 19. The host leaving
  ends the lobby; host migration is disabled.
- Hosts can open the native Meta friends invite panel. Group presence carries
  the existing EOS lobby ID and a deployment/protocol-scoped join reference.
  Incoming intents use the deeplink message, or the native lobby session ID
  when no message is supplied, and wait for explicit acceptance. Locked lobbies
  still need a password. Clients publish joinable presence only after admission.
- **Copy Meta invitation link + join code** copies shareable text with the
  documented `https://oculus.com/vr/<app_id>/<destination>` URL, lobby name and
  join code. Paste it into a message outside the game. This is a destination
  link: recipients select the named lobby in Together or paste the code.
  It is not an automatically generated, room-specific Meta Invite Link.
  Meta's mobile-app Invite Link feature has its own platform-generated lobby
  session ID; no unsupported URL parameters or client-side app secret are used.
  See [Meta destinations](https://developers.meta.com/horizon/documentation/native/ps-destinations-implementation/)
  and [Meta Invite Links](https://developers.meta.com/horizon/documentation/native/ps-invite-link/).
  The configured destination must exist in Meta's dashboard; DUC approval alone
  does not create it. Opening Together initializes services to receive intents.

## SDK ownership, queues and channels

Initialization, callbacks, tick, native poll and sends stay on the main thread,
matching EOSG's process-frame packet mediator. ENet's worker is not reused for
EOS. EOS gameplay networking therefore still pauses during main-thread stalls.

The adapter shares the bounded framing and class scheduler with ENet. Native
application payloads are at most 994 bytes, leaving six bytes for EOSG's header.
The SDK queues are configured to 2 MiB incoming / 256 KiB outgoing; mediator
admission is bounded to 2,048 packets. The adapter checks actual native queue
telemetry before each send, limits its contribution to a 64 KiB high-water mark,
and reserves 16 KiB for control. Failed telemetry pauses sends. Application
incoming messages are capped at 8 MiB / 4,096 packets. Fragment deadlines and
reliable queue failures disconnect affected peers.

Pinned EOSG 2.3.1 maps `EOS_LimitExceeded` to Godot `FAILED`. Since this adapter
has already enforced packet size, it retains that exact fragment/offset and
retries under scheduling deadlines, including `ERR_BUSY`/`ERR_OUT_OF_MEMORY`.
Broadcasts become individual sends, avoiding partially successful broadcast
retries. Poses expire/coalesce and voice expires in the application queue.
Native accepted packets cannot be retracted by those application deadlines.

EOSG returns physical receive channels: 0/1 for default reliable/unreliable,
then logical channel + 1. The adapter normalizes these before reassembly and
SceneMultiplayer dispatch. Plain unreliable remains plain unreliable.
These details were verified against the [pinned native peer source](https://github.com/3ddelano/epic-online-services-godot/blob/56238973e2cd7ac9ac99ca14f88934465f0a8997/src/eosg_multiplayer_peer.cpp),
[queue API](https://github.com/3ddelano/epic-online-services-godot/blob/56238973e2cd7ac9ac99ca14f88934465f0a8997/src/p2p_interface.cpp), and
[main-thread mediator](https://github.com/3ddelano/epic-online-services-godot/blob/56238973e2cd7ac9ac99ca14f88934465f0a8997/src/eosg_packet_peer_mediator.cpp).

Diagnostics expose scheduler counters, native queue snapshots/high-water,
packet counts/maximum, reassembly reservations and malformed-frame counts.
They omit credentials, proofs and account identifiers.

## Local setup

```sh
python3 tools/eos/setup_lab.py --game --platform linux
# Fill a private local copy of docs/EOS_GAME_CONFIG.example.cfg.
godot --path . -- --eos-config /absolute/path/eos.cfg
```

This workspace has a private ignored config at `builds/eos/eos.cfg`, prepared
with the application owner. Do not commit it or the optional SDK binaries.
The runtime also accepts `user://eos.cfg`. Configure the Meta destination
(default `eos_game`) and matching EOS Oculus provider separately. Never put a
Meta app secret in the game config; EOS client credentials must have only the
intended client policy permissions.

Use the online menu or `--eos-host` / `--eos-join '<reference>'`. Desktop device
identity is explicitly test-only: it requires both `provider="device"` in the
config and `--eos-device-test`. Quest always requires `provider="meta"`.
The live test runner makes a private temporary desktop/relay override; it does
not change the owner's real configuration.

## Validation

```sh
godot --headless --xr-mode off --path . --script tests/eos_peer.gd
godot --headless --xr-mode off --path . --script tests/eos_session.gd
godot --headless --xr-mode off --path . --script tests/eos_runtime.gd -- --eos-device-test
godot --headless --xr-mode off --path . --script tests/eos_native.gd
godot --headless --xr-mode off --path . --script tests/eos_lobbies.gd
godot --headless --xr-mode off --path . --script tests/meta_lobby_invites.gd
python3 tools/eos/test_game.py --relay auto
python3 tools/eos/test_game.py --relay force
python3 tools/eos/test_game.py --relay auto --lobby-check
python3 tools/eos/test_game.py --relay force --lobby-check
```

Offline adapter tests exercise physical channel normalization, native
backpressure/error retry, control reserve, byte-exact reassembly, queue telemetry
failure and malformed-peer cleanup. Two SceneMultiplayer instances exercise the
actual gameplay handshake, PUID record binding, requested rankings, compact
poses and concurrent 200 KB transfers alongside voice-sized packets. Lifecycle
checks cover startup, queued invites, cancellation, leave, reconnect and loss.
The native API load check does not authenticate.

Live Linux desktop tests passed with direct (`network_type=1`) and forced relay
(`network_type=2`) routing. Each run used a host and a client that disconnected
and reconnected with the same device identity; one player record was retained.
Each client connection sent two 200 KB reliable payloads and received exact
echoes while compact poses and 400-byte unreliable voice fixtures continued.
Native application payloads reached 994 bytes maximum. Both sides acknowledged
lobby cleanup. These are transport fixtures, not microphone/audio-quality or
avatar-disk-transfer acceptance tests.

Successful named/password runs are `game-20260925-102211-auto` and
`game-20260925-102337-force`.

The lobby fixture additionally verifies public discovery of a named, locked
8-slot room, wrong-password rejection with zero gameplay packets, then a
correct-password join and reconnect using the same EOS account. Offline tests
cover open/protected admission, admission cleanup, UI name/password/full-room
validation, browsing without leaving a session, and Meta intent routing.

Reports are local under `test-results/eos-meta/game-<timestamp>-auto|force/`.
The test runner removes private temporary config and lobby handoff files.

## Emulated live-view check

`tools/eos/test_xr.py --relay force` runs two complete gameplay clients: a
headless desktop fixture and a visible OpenXR client using the installed Monado
simulated HMD. Start `SIMULATED_ENABLE=1 XRT_COMPOSITOR_FORCE_XCB=1 monado-service`
in a terminal first. The runner selects the Monado manifest for its own process
and uses private temporary device-identity configuration and isolated user data.
It does not change WiVRn or the system's active OpenXR runtime.

The XR process explicitly selects the project’s Mobile renderer; specifying
only `--rendering-driver vulkan` selected Forward+ in this local Godot launch.
The fixture discovers a named password-protected eight-slot lobby, joins via
the Together menu action (programmatic button activation), loads the remote avatar,
captures both stereo eyes and the
menu panel, exchanges two 200 KB payloads per connection alongside normal pose
replication and voice-sized packets, then reconnects and checks record identity.
Hand poses are explicitly injected test poses; the head and stereo views come
from Monado. Reports and captures go to `test-results/eos-meta/xr-<timestamp>-force/`.
This verifies Linux simulated-XR/desktop interoperability. It does not emulate
Android, Meta identity/invites, a native Quest client, physical controller input,
real microphone audio, or WiVRn streaming.

### Emulated results — 2026-09-25

The final Mobile/Vulkan runs passed on Intel ADL-N with Monado 25.1.0:

| Run | EOS route | XR-observed remote pose changes | Reliable echoes | Voice-sized echoes | Sampled XR FPS |
| --- | --- | ---: | ---: | ---: | --- |
| `xr-20260925-103716-auto` | Direct (`1`) | 259 | 4 × 200 KB | 296 | 10–28 |
| `xr-20260925-103828-force` | Relay (`2`) | 259 | 4 × 200 KB | 296 | 11–28 |

Both runs discovered and joined the listed locked lobby, rendered the remote
avatar in stereo, reconnected with two retained records, stayed within 994-byte
native application packets, and acknowledged EOS cleanup. The desktop host
observed the XR flag and both simulated hands. Captures include the lobby
browser, connected Together panel and world view, each with both eyes.

These are functional passes, not VR performance acceptance. The earlier Mobile
forced-relay run `xr-20260925-103449-force` timed out before gameplay admission;
its cause remains unresolved and the later pass does not establish reliable
cold-start joining. The first Forward+ run completed gameplay but failed the
fixture's pose-count assertion because optional network metrics were disabled;
the fixture now counts observed remote serial changes independently. Synthetic
haptic calls were disabled because injected trackers have no native haptic
endpoint. Final logs retain only the previously known OpenXR shutdown errors.
The test clients and separately started Monado service were stopped; WiVRn was
left running unchanged.

## Remaining acceptance gates

Before opening this experimental transport to untrusted players, harden the
pinned native peer's sender binding: its `EVENT_STORE_PACKET` path looks up the
peer ID from the packet header without comparing that ID's stored EOS PUID to
`packet_data.get_sender()`. The GDScript adapter cannot recover the discarded
native sender metadata. Lobby membership admission and server-derived record
keys are implemented, but the live tests use cooperating members and do not
establish resistance to a member spoofing another member's header ID. Fix and
verify that comparison in the native EOSG builds for every shipped platform.


No headset was attached during this work. Real Meta entitlement, user proof
refresh, profile/friends access, cold/warm invite intents, Quest/PC crossplay and
headset disconnect/reconnect have not been validated by the desktop tests.
Meta DUC for User ID, User profile, Friends and Invites is granted, as confirmed
by the application owner.

The experimental Quest export now integrates the EOS AAR, ARM64 libraries,
activity bootstrap and login intent resource. See [Android export](EOS_ANDROID_EXPORT.md).
Hardware validation remains required before treating it as a production release.

Next validate that Android bootstrap/package with entitled Quest accounts,
then run eight-player WAN loss/jitter/reordering tests with actual voice and
large avatar transfers. Tune frame-time, pose age and control latency on hardware.
