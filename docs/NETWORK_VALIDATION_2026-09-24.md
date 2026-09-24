# Dedicated server network validation — 2026-09-24

Tested the current working tree (including uncommitted changes) using Godot 4.7.2, a freshly exported Linux dedicated server, and separate headless client processes over real ENet loopback connections. Base commit: `b61e1a38154ae9fcd76398d61e590cff09caf79f`.

Server: `builds/NetworkValidation-20260924/UltimateBoomerSimulatorServer.x86_64`

SHA-256: `31968efc6459f41580a1356a0e031a55b7dcdc08c16c933f60e4515ad05d671b`

## Results

- **PASS — dedicated golf:** client A 74/74, client B 76/76, restart verifier 3/3. Two identities join a competition, clubhouse proximity is enforced, course visibility and poses replicate, malformed commands are rejected, both players complete 18 holes, retirement works, and rankings persist exactly once across restart.
- **PASS — networked golf cosmetics:** all four tackle tiers across driver, iron and putter traverse the dedicated server in both directions. Received tier and club fields match; production material styling produces the expected shaft colours; tier-only changes reuse the club model. These headless checks inspect material properties, not rendered headset appearance.
- **PASS — clubhouse BBQ:** the exported server resolves terrain-backed stations and grants tongs ownership for a valid tracked hand pose.
- **PASS — fishing multiplayer:** dedicated sender, observer and late joiner; additional ad-hoc host and observer regression. Casting, catches, release, movement, avatar transfer, body/finger/face/viseme state, tackle, feeder and lure replication; remote catches do not modify the local Fish Guide. Real Opus fixture packets decode, mute works, and location filtering controls visibility and voice.
- **PASS — fishing leaderboard persistence:** two clients, records, duplicate rejection, server restart, renamed reconnect and client-only identity storage.

## Test changes and observations

Extended `tests/golf_dedicated_client.gd` with 12 acknowledged cosmetic phases per client. The initial run exposed a stale BBQ fixture: its generic hand pose was at head height, outside the server grab radius. Corrected the fixture to submit a tracked hand at the tongs before requesting ownership, using the same reliable channel to preserve order. Production reach validation was unchanged; the rerun passed.

The multiplayer suite emitted ENet warnings for unreliable packets of 1432 and 1459 bytes exceeding its 1392-byte MTU. No integration assertions failed, but packet sizing deserves follow-up before Wi-Fi acceptance testing; loopback does not establish loss tolerance.

These tests use Linux headless clients and XR fixtures. They do not validate physical Quest controllers, live microphone capture, headset rendering/performance, WAN/NAT connectivity, or adverse network conditions. Golf completion uses scripted shot/settled events to test multiplayer turn flow and persistence, rather than physical swings or ball trajectories.

## Reproduction

```sh
python3 tools/build_server.py --output builds/NetworkValidation-20260924
python3 tools/test_golf_dedicated.py --server builds/NetworkValidation-20260924/UltimateBoomerSimulatorServer.x86_64
FISHING_SERVER_BIN="$PWD/builds/NetworkValidation-20260924/UltimateBoomerSimulatorServer.x86_64" python3 tools/test_multiplayer.py
python3 tools/test_server_leaderboard.py --server builds/NetworkValidation-20260924/UltimateBoomerSimulatorServer.x86_64
```

Logs: `test-results/golf-dedicated-run.log`, `test-results/golf-dedicated/`, `test-results/multiplayer-dedicated-run.log`, `test-results/server-leaderboard-run.log`, and `test-results/server-leaderboard/`.
