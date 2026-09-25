# Fishing together

Open the avatar menu (**right B**), then **Together**. Enter a name and use **Host**, or enter the host's IP/hostname and use **Join**. The limit is eight players: eight clients on a dedicated server, or the host plus seven guests for ad-hoc hosting. Everyone can travel independently; choose the same location in the Locations page to see one another and hear nearby speech. The radio reaches anglers in every water. The player list shows each angler's location. Fish Guide entries and personal records stay on each device.

For a dedicated server, run the project with Godot 4.7.2 and its imported assets:

```bash
./run.sh --server --port 24567 --bind 0.0.0.0
```

It runs headless without loading the environment, player rig or decoded avatar models. It relays fishing state, verified avatar files and compressed voice. The default bind address is `*`; default port is UDP 24567. Stop with Ctrl+C. The Linux and Windows release archives include headless server launchers using the same executable.

Command-line PC VR hosting/joining also works:

```bash
./run.sh -- --host --port 24567 --name Alex
./run.sh -- --join 192.168.1.10 --port 24567 --name Sam
```

On a LAN, use the host's LAN address. Internet hosting requires the chosen UDP port through the host's firewall/router, or a reachable dedicated server. There is no matchmaking, discovery, relay service, automatic NAT traversal, password system, or host migration. If the host disconnects, clients return to offline fishing and keep their local records.

## Voice

FPSloppa's TwoVoIP integration supplies 48 kHz mono Opus, 20 ms frames, RNNoise input denoising and positional playback. New profiles default to **Voice activation**. Existing saved voice modes are preserved; **Listen only** and **Push to talk** remain available. Push to talk uses **left thumbstick click**; the left grip remains available for fish and Guide inspection. Select the microphone in the multiplayer menu. Select a player to mute/unmute them, or use Mute all. Nearby voice is relayed only between participants at the same location and attenuates with distance (60 m maximum).

FPSloppa’s shoulder radio supplies a second channel to **all anglers on the server**, regardless of water or distance. Reach to the **left shoulder**, squeeze grip to take the radio, and hold the **left trigger** to transmit. Release trigger to stop talking; release grip to dock it. While the radio is held, voice activation cannot leak speech onto the nearby channel. The rod remains in the right hand. Radio playback uses FPSloppa’s narrow-band filtering and on/off click cues; existing player mute, Mute all, Listen only, and host voice policy apply. Opening the menu, losing focus or controller tracking releases the radio.

This development build uses **protocol 19**, including shared BBQ ownership/cooking/cooler deltas and time anchors, explicit terminal-tackle visibility/positions, server accomplishments and classic/feeder/lure rig selection. Update clients and server together; older clients cannot join. Avatar offer acknowledgements and transfer cancellation/recovery are retained.

Android microphone capture requests `android.permission.RECORD_AUDIO` when enabled. The retained Quest development preset declares RECORD_AUDIO and INTERNET and includes TwoVoIP's ARM64 native library. Optional avatar tracking uses a shared vendor permission queue; retained Pico permission handling does not imply a maintained Pico build. Pico OS 6 support is a future goal only; see [tracking setup](AVATAR_TRACKING.md). Eye tracking never affects cast aim. Synthetic tests use generated tones, never the microphone.

## Replication and reuse

The host relays owner-simulated fishing and locomotion. Twenty updates per second carry head/hand transforms and tracking availability, calibrated body joints, finger curls, cosmetic eye/face expressions and visemes, feet and movement, rod/line/bobber, casting state and target, bait, caught species and size, fish orientation and hand inspection. Event changes use reliable delivery; a shared sequence prevents older poses overwriting newer events. New arrivals receive current states and avatar choices. Remote avatars use the existing fishing IK and full-body VRM meshes, with interpolated poses.

This is cooperative replication, not an authoritative competitive simulation: bounds, types, membership, sequences and rate limits are validated, but clients can still falsify catches or movement. Remote players do not physically collide or affect another player's fish. Whole saved journals are never transmitted.

Custom avatars use FPSloppa's server-mediated SHA-256 protocol: self-contained VRM validation, 25 MB maximum per file, 32 KiB disk chunks, independent 64 KiB acknowledgement windows, fair 192 KiB/s aggregate content upload per transfer service, worker-thread disk operations, timeouts, and a 1 GB cache cap. Downloads and local imports share the external `data/vrm/` folder. Legacy caches are copied over without removing originals. A simple angler appears while a model downloads. Imported avatars selected for play are shared with session participants.

Source provenance is recorded in [FPSLOPPA_REUSE.md](FPSLOPPA_REUSE.md). ENet lifecycle/20 Hz replication conventions, voice capture/relay/playback, permissions/preferences, avatar verification/transfer and disk-worker code are reused or adapted; FPS combat, inventory and map systems are omitted.

## Validation

```bash
python3 tools/test_multiplayer.py
XDG_DATA_HOME=/tmp/fishing-network-guards godot --path . --xr-mode off --headless --script res://tests/network_guards.gd -- --xr-test
```

The integration runner starts real independent ENet processes in isolated save directories: dedicated server plus sender, observer and late joiner; then ad-hoc host plus observer. It checks custom avatar transfer/loading, casts, catch size, hand inspection, release, moving poses, same-location visibility/voice, per-player mute, real Opus decoding and local Guide isolation. Guards additionally exercise malformed poses/species, sequence ordering, voice replay/flood prevention and invalid connection parameters. These are local synthetic tests, not an Internet or physical-headset acceptance test.

Native stereo/controller integration: `python3 tools/test_multiplayer_xr.py` runs a simulated Monado HMD host and a separate Vulkan desktop client. See [stereo captures and known shutdown diagnostics](VALIDATION.md#multiplayer-and-fpsloppa-reuse-2026-09-14).


### EOS packet budget (experimental branch)

Protocol 19 retains compact tracking introduced in protocol 18 and packs tracked poses into independently decodable binary snapshots
(up to 468 bytes for current full tracking), uses plain unreliable pose delivery
with wrap-safe serial rejection, and projects fishing rankings without duplicating
other categories or golf history. Golf rankings are sent separately on change or
join, rather than with every round update.

The ENet worker exercises transport-independent framing below Godot RPCs: each
send is at most 994 bytes, reserving six bytes for EOSG. Large reliable messages
are reassembled with bounded sizes, reservations and deadlines; oversized
unreliable messages fail explicitly. Avatar disk chunks stay at 32 KiB while the acknowledgement window is 64 KiB; framing subdivides chunks on the wire. The application scheduler paces traffic classes, coalesces superseded poses, and expires stale voice. See [traffic budgets and validation](EOS_TRAFFIC_SCHEDULING.md). These bounds are not a WAN latency guarantee. The game still uses ENet;
live EOS gameplay integration and relay stress testing remain pending.
See [implementation and measured sizes](EOS_PACKET_OPTIMIZATION.md).

### Transport threading

`threaded_peer.gd` gives each ENet connection one socket-owning worker. Native ENet polling, acknowledgements and packet receipt continue through main-thread stalls. Bounded packet/event queues deliver to SceneMultiplayer on the main thread; game state, RPCs, avatar scene instantiation and voice dispatch stay there. This does not make gameplay simulation or microphone capture independent of frame stalls. Closing/leaving joins the worker. The seven logical channels remain. Gameplay sessions now opt into bounded packet framing; both endpoints must run protocol 19. Standalone unframed transport users retain stock ENet compatibility. Fishing’s application handshake is protocol 19; protocol 3 added radio, protocol 4 added avatar offer/cancel/recovery messages, and protocol 5 adds visible tackle state.

FPSloppa checkout `8898d03a33f42e6eec472506fccce6d68dad83d1` threads disk jobs rather than its ENet peer. Its immutable-job/main-thread-completion pattern is retained here; the socket worker is a local addition. Its decoded-VRM cache pattern is also applied so repeated remote models reuse a decoded PackedScene.

Cross-water radio integration: `python3 tools/test_radio.py` launches a dedicated server with three clients, then an ad-hoc host with two clients. Synthetic Opus packets verify nearby → radio → nearby transitions, cross-water reach, no sender echo, actual decoding and host reception. `tests/radio.gd` covers VR grip/trigger controls, VAD isolation, mute/policy handling and reordered channel packets.

For authorized remote test servers, pass `--remote SERVER_IP --port PORT` to `tools/test_radio.py`; `tools/test_remote_reconnect.py SERVER_IP --port PORT` checks silence/stall recovery and two same-process reconnect cycles. Launch builds with `-- --network-metrics` to log bounded counters and worker-side RTT/throttle snapshots without audio payloads.

### Avatar recovery and diagnostics (0.1.10)

Latest accepted avatar selection wins. Superseded transfers are cancelled; rejected/throttled offers receive a response. Model requests retry at most three times with 2/4/8-second backoff, a 10-second response timeout, a 90-second queue deadline, and a separate 30-second download-progress timeout. A disconnected owner can be replaced by another pending owner of the same hash. Reselecting an avatar starts a fresh offer. Per-asset errors clear on retry, success, cancellation or leaving the session; unrelated errors remain visible.

`--client-metrics` enables per-frame monotonic wall-clock interval aggregates and stage durations for validation, glTF/image parsing, scene generation, rig configuration, location changes and remote fish construction. It also emits discrete fishing-state transitions. `--network-metrics` enables these plus accepted state arrival ages/gaps and detailed voice counters. Existing aggregate counters remain available. FEC counts are **attempts**, because the native decoder does not expose whether FEC or concealment produced that frame; `empty_playback_queue` counts observed transitions, not sample-accurate audio underruns. Neither counter proves audible quality. No microphone recordings or controller poses are saved by these diagnostics. Headset compositor/Virtual Desktop timings still require their own capture.

`AVATAR_TRANSFER` records peer/hash, request ID, phase and timing at transfer transitions, and progress on timeout/completion. Import failures retain filename/hash/image-index context. Remote fish meshes are instantiated only for a visible landed catch; scene resources retain Godot's normal resource cache.

## Server accomplishments and separate binary

Protocol 6 added persistent player identities and host-owned accomplishment rankings; 7 added feeder rigs and 8 added lure rigs; 9 expands the shared species roster to 38. See [dedicated server and leaderboard details](DEDICATED_SERVER.md). The menu header now opens Leaderboard; controls are in the [HTML manual](MANUAL.html).

### Requested standings and BBQ replication (protocol 19)

The leaderboard panel fetches ten rows for its selected fishing category or golf
course, with Previous/Next controls across the existing top 50. It refreshes every
two seconds while visible; joining and playing with the panel closed send no
ranking rows. The server accepts two requests/second with a four-request burst
per admitted player. Request IDs prevent old selections from replacing new ones.

BBQ state starts with a reliable baseline at the player's location. Later messages
carry changed items, cooler/revision metadata, and cooking time anchors. Cooking
renders locally between five-second anchor corrections; ownership, reset timers
and station expiry remain server-authoritative. Empty stations are sent once,
and missing baselines trigger a rate-limited full resync. State is cleared on leave.

### Online EOS lobbies

The multiplayer menu now includes Host online, Join online, Copy invite, Invite
friends and Accept invite. EOS initialization is opt-in and requires local
configuration plus the optional pinned native extension. Use
`--eos-config /absolute/path/eos.cfg`; existing IP host/join continues through ENet.
See [EOS gameplay transport setup and validation](EOS_GAMEPLAY_TRANSPORT.md).
Linux desktop direct/forced-relay checks passed. Quest Android bootstrap and
entitled-account acceptance remain required before a headset EOS release.

### Named online lobbies

In **Together**, choose **Host a lobby**, enter its name, and optionally enable
**Password protect**. **Open lobby** creates a listed EOS room for eight players,
including the host. **Browse lobbies** shows names, occupancy and lock status;
select a room, enter its password if required, and join. New rooms can take a
moment to appear; use Refresh. Leaving as host ends the session.

Use **Invite Meta friends** in the current lobby to open Meta's native invite
panel. **Copy Meta invitation link + join code** prepares text to paste into a
message: the Meta destination link opens the app, then the recipient selects
the lobby in Together or pastes its join code. Send passwords separately.
Pending Meta invitations require explicit acceptance, including a password for
locked rooms. This experimental branch still requires the Android EOS package
and real-headset acceptance checks in [EOS gameplay transport](EOS_GAMEPLAY_TRANSPORT.md).
