# Fishing and golf integration

Based on Fishing `b13646980ccdea259acef06a55a4878473e70d7c`, with GolfMinus `851fa6c` vendored under `addons/golfminus`. The integration branch retains the Fishing project and its existing player, networking, avatar, radio and BBQ systems.

The Golf menu joins Spyglass Hill or Pebble Beach and swaps the rod for a club. Fishing, golf and clubhouse BBQ share the player session. Radio remains available across locations. The leaderboard page selects golf rankings on golfing courses, stored alongside fishing records. Golf includes turn notifications, retirement and a five-minute absence deadline that forfeits the current hole. Connected course worlds show other golfers across holes.

## Dedicated server

Matching protocol-14 clients and servers are required. The server owns course enrollment, turn order, deadlines, scorecards and persistence. Ball flight remains simulated by the owning client; this is not server-side trajectory verification.

Run `python3 tools/build_server.py`. The staged server contains the script dependency closure and course JSON, height and lie data needed for shared-world and clubhouse placement. It excludes client rendering assets and native extensions. The tested export contains nine course-data files (13,238,716 bytes), zero visual assets and zero native extensions.

Validate the actual exported binary:

```sh
python3 tools/test_golf_dedicated.py --godot /path/to/godot
python3 tools/test_server_leaderboard.py
/path/to/godot --headless --path . --xr-mode off --script tests/golf_social.gd
```

The golf test starts two clients, tests cross-hole presence and clubhouse BBQ, rejects malformed commands, completes 18-hole rounds, retires players, then restarts the server and checks persisted rankings (22 checks). The existing fishing test verifies catch records, duplicate rejection and persistence after reconnect/restart. The merged-scene social test covers 25 menu, equipment, turn, radio/avatar identity, BBQ and retirement checks.

## Desktop builds

Linux and Windows exports are available locally under `builds/Integration`; they are excluded from Git. Use `run-test.sh` or `run-test.cmd` for verbose logging. Linux was smoke-tested locally with a successful exit; forced headless shutdown reports a retained Fishing lake ambience Ogg resource. No script errors were observed. The Windows runtime has not been tested on Windows.

## Clubhouse and handicap update

Course selection visits the clubhouse without entering a round. The fixed wall panel offers solo play, competition enrollment and an organiser-only start once at least two players are gathered within 15 metres of the clubhouse. Enrollment closes when the competition starts. Competition progresses holes as a group; only competition has return notifications and the five-minute timeout. A timeout writes the player's net-double-bogey score, not a negative forfeit placeholder. Solo rounds remain resumable while fishing or at BBQ without deadlines.

The existing BBQ and Waters menu entries cover activity changes. Golf retains Return to course, Visit clubhouse and Retire; duplicate BBQ, fishing, stash and avatar actions are removed. Returning to course works from Fishing both offline and online. Club geometry follows the resolved avatar palm locally and remotely. Both maps use the complete shared course, and the current-hole beacon follows the guiding toggle. Tree canopy collision remains invisible. Golf reuses the Fishing ambience controls, stereo birds and insects, adding windblown leaves and cosmetic ground squirrels.

Handicap is an **in-game estimate**, not an official WHS Handicap Index: these reconstructed courses use par as rating, slope 113 and length-ranked stroke allocation unless authored stroke indices are available. Saved rounds retain recent differentials, with the best-eight-of-twenty method and reduced-record adjustments; old best scores seed legacy profiles. New profiles receive provisional handicap 54. Net double bogey is par + 2 + allocated handicap strokes. The guide and competition board show handicap; the board also shows net totals. Offline and server records retain handicap history in their existing persistence files. Reference: https://www.usga.org/content/usga/home-page/handicapping/world-handicap-system/world-handicap-system-usga-golf-faqs/faqs---what-is-the-maximum-hole-score-.html

Validation for this update: `tests/golf_clubhouse_rules.gd` covers scoring/lobby rules; `tests/golf_social.gd` covers scene transitions, map bounds, guiding, equipment and solo caps; `tools/test_golf_network.py` exercises three-process ENet turns, timeout, reconnect and radio; `tools/test_golf_dedicated.py` tests the exported server through complete rounds and restart. `tests/golf_clubhouse_visual.gd` captures the mounted panel and tests its desktop pointing interaction.

## Guide camera and VR desktop mirror

The golf guide retains Fishing’s photo preview, shutter, selfie lens, extension and 1920×1080 PNG saving, including at the clubhouse. The course map remains its first page. In VR, the guide-hand trigger switches between camera and tracker; the free-hand trigger takes a photo and A/X switches the selfie lens. Desktop controls are C for camera, Space for shutter, F for selfie and arrow keys for extension. Golf photos use the shared photo directory with a `golf_` filename prefix.

PC VR keeps the third-person desktop mirror and separate tracked headset viewport when entering golf, opening menus and returning to Fishing. Godview continues hiding the avatar. `tests/golf_camera.gd` checks the integrated camera; pass `-- --native-xr` with a simulated OpenXR runtime to also check mirror ownership and Godview visibility.
