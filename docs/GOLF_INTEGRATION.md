# Fishing and golf integration

Based on Fishing `b13646980ccdea259acef06a55a4878473e70d7c`, with GolfMinus `851fa6c` vendored under `addons/golfminus`. The integration branch retains the Fishing project and its existing player, networking, avatar, radio and BBQ systems.

The Golf menu joins Spyglass Hill or Pebble Beach and swaps the rod for a club. Fishing, golf and clubhouse BBQ share the player session. Radio remains available across locations. The leaderboard page selects golf rankings on golfing courses, stored alongside fishing records. Golf includes turn notifications, retirement and a five-minute absence deadline that forfeits the current hole. Connected course worlds show other golfers across holes.

## Dedicated server

Matching protocol-13 clients and servers are required. The server owns course enrollment, turn order, deadlines, scorecards and persistence. Ball flight remains simulated by the owning client; this is not server-side trajectory verification.

Run `python3 tools/build_server.py`. The staged server contains the script dependency closure and course JSON, height and lie data needed for shared-world and clubhouse placement. It excludes client rendering assets and native extensions. The tested export contains nine course-data files (13,238,716 bytes), zero visual assets and zero native extensions.

Validate the actual exported binary:

```sh
python3 tools/test_golf_dedicated.py --godot /path/to/godot
python3 tools/test_server_leaderboard.py
/path/to/godot --headless --path . --xr-mode off --script tests/golf_social.gd
```

The golf test starts two clients, tests cross-hole presence and clubhouse BBQ, rejects malformed commands, completes 18-hole rounds, retires players, then restarts the server and checks persisted rankings (22 checks). The existing fishing test verifies catch records, duplicate rejection and persistence after reconnect/restart. The merged-scene social test covers 25 menu, equipment, turn, radio/avatar identity, BBQ and retirement checks.

## Desktop builds

Linux and Windows exports are available locally under `builds/Integration`; they are excluded from Git. Use `run-test.sh` or `run-test.cmd` for verbose logging. Linux was smoke-tested locally; the Windows runtime has not been tested on Windows.
