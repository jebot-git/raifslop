# Fishing together

Open the avatar menu (**V** on desktop; the existing menu control in VR), then **Together**. Enter a name and use **Host**, or enter the host's IP/hostname and use **Join**. The limit is eight players: eight clients on a dedicated server, or the host plus seven guests for ad-hoc hosting. Everyone can travel independently; choose the same location in the Locations page to see and hear one another. The player list shows each angler's location. Fish Guide entries and personal records stay on each device.

For a dedicated server, run the project with Godot 4.7.2 and its imported assets:

```bash
./run.sh --server --port 24567 --bind 0.0.0.0
```

It runs headless without loading the environment, player rig or decoded avatar models. It relays fishing state, verified avatar files and compressed voice. The default bind address is `*`; default port is UDP 24567. Stop with Ctrl+C. The Linux and Windows release archives include headless server launchers using the same executable.

Command-line desktop hosting/joining also works:

```bash
./run.sh --desktop -- --host --port 24567 --name Alex
./run.sh --desktop -- --join 192.168.1.10 --port 24567 --name Sam
```

For XR, omit `--desktop`. On a LAN, use the host's LAN address. Internet hosting requires the chosen UDP port through the host's firewall/router, or a reachable dedicated server. There is no matchmaking, discovery, relay service, automatic NAT traversal, password system, or host migration. If the host disconnects, clients return to offline fishing and keep their local records.

## Voice

FPSloppa's TwoVoIP integration supplies 48 kHz mono Opus, 20 ms frames, RNNoise input denoising and positional playback. New profiles default to **Voice activation**. Existing saved voice modes are preserved; **Listen only** and **Push to talk** remain available. Push to talk uses **T** on desktop or **left thumbstick click** in VR; the left grip remains available for fish and Guide inspection. Select the microphone in the multiplayer menu. Select a player to mute/unmute them, or use Mute all. Voice is relayed only between participants at the same location and attenuates with distance (60 m maximum).

Android microphone capture requests `android.permission.RECORD_AUDIO` when enabled. The Quest and Pico release APKs declare RECORD_AUDIO and INTERNET and include TwoVoIP's ARM64 native library. Optional avatar tracking now uses the shared Quest/Pico tracking permission queue; see [tracking setup](AVATAR_TRACKING.md). Eye tracking never affects cast aim. Synthetic tests use generated tones, never the microphone.

## Replication and reuse

The host relays owner-simulated fishing and locomotion. Twenty updates per second carry head/hand transforms and tracking availability, calibrated body joints, finger curls, cosmetic eye/face expressions and visemes, feet and movement, rod/line/bobber, casting state and target, bait, caught species and size, fish orientation and hand inspection. Event changes use reliable delivery; a shared sequence prevents older poses overwriting newer events. New arrivals receive current states and avatar choices. Remote avatars use the existing fishing IK and full-body VRM meshes, with interpolated poses.

This is cooperative replication, not an authoritative competitive simulation: bounds, types, membership, sequences and rate limits are validated, but clients can still falsify catches or movement. Remote players do not physically collide or affect another player's fish. Whole saved journals are never transmitted.

Custom avatars use FPSloppa's server-mediated SHA-256 protocol: self-contained VRM validation, 25 MB maximum per file, 32 KiB chunks, eight-chunk windows, 2 MiB/s aggregate upload per transfer service, worker-thread disk operations, timeouts, and a 1 GB cache cap. Downloads are stored under `user://network_avatars/`; local imports and avatar selection retain their existing storage. A simple angler appears while a model downloads. Imported avatars selected for play are shared with session participants.

Source provenance is recorded in [FPSLOPPA_REUSE.md](FPSLOPPA_REUSE.md). ENet lifecycle/20 Hz replication conventions, voice capture/relay/playback, permissions/preferences, avatar verification/transfer and disk-worker code are reused or adapted; FPS combat, inventory and map systems are omitted.

## Validation

```bash
python3 tools/test_multiplayer.py
XDG_DATA_HOME=/tmp/fishing-network-guards ./run.sh --desktop --headless --script res://tests/network_guards.gd
```

The integration runner starts real independent ENet processes in isolated save directories: dedicated server plus sender, observer and late joiner; then ad-hoc host plus observer. It checks custom avatar transfer/loading, casts, catch size, hand inspection, release, moving poses, same-location visibility/voice, per-player mute, real Opus decoding and local Guide isolation. Guards additionally exercise malformed poses/species, sequence ordering, voice replay/flood prevention and invalid connection parameters. These are local synthetic tests, not an Internet or physical-headset acceptance test.

Native stereo/controller integration: `python3 tools/test_multiplayer_xr.py` runs a simulated Monado HMD host and a separate Vulkan desktop client. See [stereo captures and known shutdown diagnostics](VALIDATION.md#multiplayer-and-fpsloppa-reuse-2026-09-14).
