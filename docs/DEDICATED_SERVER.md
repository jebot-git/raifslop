# Dedicated server and accomplishments

Build the independent Linux x86-64 server with:

```sh
python3 tools/build_server.py
builds/Server/UltimateBoomerSimulatorServer.x86_64 -- --port 24567 --bind 0.0.0.0 \
  --leaderboard-path /absolute/writable/server/leaderboard.json \
  --asset-root /absolute/writable/server/assets
```

`--godot /path/to/godot` and `--output /path/to/output` select the engine and
output folder. The engine needs its matching Linux release export template.
The generated project is under `builds/Server/project`; `manifest.json` lists
every bundled script and the executable's checksum. This server starts in
headless mode automatically. It uses protocol 11: update clients and server together.

The build copies only the transitive `preload` dependencies of the minimal server
entry point. It shares the client's actual session, state validation, avatar
transfer and voice relay RPC scripts, preserving their node paths and protocol.
Rendering, avatar instantiation and voice codecs are loaded only by clients.
There are no bundled panoramas, meshes, sounds, default avatars, XR plugins,
VRM renderer or Opus extensions. The build is about 70.2 MiB,
with about 141 KiB added to the standard engine template. It still contains the
standard Godot engine's compiled modules; it is not a custom stripped engine build.

Received avatars are validated and cached at runtime for relay. `--asset-root`
controls that separate cache; it is not a dependency bundled in the executable.
The leaderboard defaults to the server application's `user://server/leaderboard.json`.
Use an explicit absolute path for a stable deployment and backups. Existing
`./run.sh --server --port 24567` hosting remains supported, as does ad-hoc hosting
from Together; those hosts also own their leaderboard file. No leaderboard is
saved by joining clients.

## What the board records

The server observes an accepted cast → fight → landed sequence, validates the
location/species and current 0.85–1.15 size range, derives weight from the species'
length/weight relation, and computes the reward itself. Repeated landed poses,
reconnecting while holding a fish, invalid lengths and imported local journals do
not count. Purchases do not reduce lifetime earnings. Exceptional catches are
specimens at least 1.12 times typical length or rarity-4+ species (currently rare
predators). Rankings include catch count, earnings, heaviest, longest and the
number of exceptional catches, with a noteworthy specimen per angler.

All connected identities, including anglers without catches, are retained after
disconnection. Clients hold only a bounded in-memory top-50 view for each category.
Each profile creates a random private token in `user://multiplayer.cfg`; the
server persists its hash, never sends it in public rankings, and uses it to keep
records through display-name changes. A new/deleted profile is a new identity.
Simultaneous use of one identity is rejected. There is no account-recovery service.

Fishing remains owner-simulated. These records are validated session achievements,
not a cheat-proof competitive service: a modified client could fabricate an
otherwise plausible state sequence. Full competitive authority would require
moving catch selection, timing and fight simulation onto the server.

Updates are broadcast and atomically saved at most every two seconds, and on
normal leave/scene shutdown. A forced process kill can lose the last two seconds.
A corrupt store is left intact for operator recovery instead of being overwritten.
Back up the file while the server is stopped. Clients never upload saved balances
or journal histories to the board.

## Validation

```sh
# Pure records: deduplication, invalid catches, reconnect, restart, bounded views.
godot --headless --xr-mode off --path . --script res://tests/leaderboard.gd
# Actual built server + two clients, restart and renamed returning identity.
python3 tools/test_server_leaderboard.py
# Existing ad-hoc/dedicated voice, avatar and tackle transport regression.
FISHING_SERVER_BIN="$PWD/builds/Server/UltimateBoomerSimulatorServer.x86_64" python3 tools/test_multiplayer.py
```

The build approach avoids the client dependency graph entirely. Godot also
supports resource stripping for conventional server presets:
[official dedicated-server export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html).
