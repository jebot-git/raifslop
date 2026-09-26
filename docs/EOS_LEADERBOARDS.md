# EOS and dedicated-server stat parity

The game tracks the same fishing categories and golf fields for dedicated-server
records and EOS sessions. The rankings panel reads server records during ENet
play and EOS rankings during an EOS lobby. Server history remains server-local;
new EOS play contributes to the authenticated account's online totals.

| Activity | Fields | EOS representation |
| --- | --- | --- |
| Fishing | Catches, catch earnings before spending, exceptional catches | Absolute MAX counters |
| Fishing | Heaviest catch, longest catch | MAX grams / millimetres |
| Golf, per course | Best completed score | MIN strokes |
| Golf, per course | Completed rounds, forfeited holes | Absolute MAX counters |
| Golf, per course | Latest completed score, current handicap | LATEST strokes / tenths plus one |

There are 35 stat/board definitions: five fishing categories and five fields for
each of six courses. Existing `ubs_v1_*` personal-best IDs are retained. Added
fields use `ubs_v2_*`. Destinations expose the four currently playable named golf
courses; records also retain support for the two legacy fictional courses.

Fishing uses the same cast/fight/landing collector and reward/exceptional rules
as the dedicated server. It consumes each landing once. Golf deduplicates
finished cards and forfeited holes by the authority's round ID, persists that
progress across restarts, and derives handicap using the existing rolling-history
calculator. Capped timeout holes count as forfeits and completed cards follow the
same rules as server records. Retired/incomplete cards do not become best scores.

## Persistence and synchronization

Account files are isolated by product, sandbox, deployment, EOS user, Meta app and
Meta user. No server balances or journal histories are imported. New counter
increments are saved locally, reconciled with a fresh EOS read, then converted
into an absolute target and saved before ingestion. Retrying after an ambiguous
acknowledgement sends that same MAX target instead of repeating a SUM increment.
A subsequent EOS read confirms delivery. Corrupt outboxes are preserved.

MIN/MAX fields keep best values. LATEST fields compare for equality and replace
Meta entries only after an EOS read; other Meta entries use keep-best writes.
Handicap zero is stored as 1, with a scale of 10 and offset of 1, to distinguish
zero handicap from an unset stat. The UI decodes it before display. Only the
currently authenticated Meta viewer's entry can be written.

These are client-attested records. Absolute counters support one active writer
per account; concurrent play from multiple devices can lose increments, and
rolling handicap history is local to that account on this installation. A trusted
transactional event service is required for cross-device concurrent aggregation
or competitive anti-cheat. Server records retain their existing authority model.

Synchronization is bounded to one batched ingest and read per minute, plus a
baseline read when new counters need reconciliation. At most two Meta writes run
per cycle, with fair rotation and backoff. Ranking pages contain ten rows, stop
at the top 50, use a one-minute cache and never expose PUIDs. Leaving a session
invalidates late callbacks.

## Provisioning

Use [EOS_LEADERBOARDS.example.json](EOS_LEADERBOARDS.example.json) as the exact
35-definition specification. All 35 definitions were provisioned and read back on 2026-09-26.
A live desktop SDK probe verified every EOS ID, stat, aggregation and time window,
plus personal stat and ranking queries; it submitted no scores. Meta read-back
verified all IDs, sorting, hidden visibility and disabled notifications. This file is a specification, not an automatic portal importer.

1. Create EOS stats with the specified aggregation, then matching leaderboards
   with the same IDs/stat names and aggregation. Keep start `1790330760` and end
   `-1` for the non-expiring windows. v1 best scores use MIN/MAX; v2 last/handicap
   explicitly use LATEST. Do not change an existing stat's meaning.
2. Give the client policy self-stat ingest, stat reads, and leaderboard queries.
   The native adapter verifies every board definition before use. Check the
   underlying stat aggregation in the portal as well.
3. Create matching Meta numeric, client-authoritative boards with the exact
   sort/update policy in the JSON. Keep public display and friend notifications
   disabled during ALPHA testing. The game never needs the Meta app secret.
4. Set `[leaderboards] enabled=true` in the private EOS config. It is false when
   absent, and the Android exporter preserves this boolean.
5. Verify a catch and completed round on an entitled Quest account, EOS read-back,
   Meta mirrors, reconnect, interrupted uploads, account switching and a forfeit.

Offline checks:

```sh
godot --headless --xr-mode off --path . --script tests/online_leaderboards.gd
godot --headless --xr-mode off --path . --script tests/leaderboard.gd
godot --headless --xr-mode off --path . --script tests/ranking_pages.gd
```

Achievements and activity destinations are described in
[ONLINE_PROGRESS.md](ONLINE_PROGRESS.md).

## Prior portal setup, 2026-09-25 (original eight boards only)

Configured through official Playwright MCP 0.0.82 attached to an isolated Vivaldi
profile, with interactive developer authentication.

- EOS product `eecd2ee94fed409886609b4cf4fd627d`, sandbox
  `a9fbe66fd8ea474a9d77b9fa3d51a809`, deployment
  `c72d48d53f314430a5905ebca435ed02` (Live Deployment): all eight stats and
  [leaderboards](https://dev.epicgames.com/portal/pldot/products/ubs/epic-online-services/leaderboards/Live/c72d48d53f314430a5905ebca435ed02)
  created and read back with the specified names, aggregations and time window.
- Existing UBS Peer2Peer client policy already grants `findLeaderboardDefinitions`,
  `findLeaderboardEntries`, stats reads (including `findStatsForAnyUser`) and
  `ingestForLocalUser`. No policy changes were needed.
- Live desktop SDK probe verified all eight definitions, a personal stats query
  and a ranking query. Both score results were empty; no scores were written.
- Meta application `3428825797290213` (Ultimate Boomer Simulator): all eight
  [mirror boards](https://developers.meta.com/horizon/manage/applications/3428825797290213/platform-services/leaderboards/)
  created. Read-back confirms numeric Point scores, Client Authoritative writes,
  the matching application and Higher/Lower is Better sorting. All have zero
  entries; User facing and friend notifications are off.
- Version `0.1.18-eos.2` (23) opts into synchronization in the local ALPHA export
  configuration for Quest testing. The checked-in default stays disabled.
  Quest score submission, Meta mirroring and account-switch acceptance remain
  unverified on hardware; these are experimental client-attested scores.

## Validation

`tests/online_leaderboards.gd` covers encoding, MIN/MAX retries, delayed EOS
visibility, Meta-only retries, account isolation, corruption, bounded/fair writes,
cache limits, cancellation, completed golf cards, fishing collection and native
API shapes. `tests/test_eos_android_export.py` checks the opt-in export setting.
Existing server leaderboard, ranking-page, EOS lifecycle and dedicated-server
restart/reconnect tests protect the independent server path.

`tests/online_leaderboards_live.gd` is an explicit live, read-only leaderboard
probe. It authenticates a desktop test device (creating its EOS identity if needed)
but never creates a lobby, ingests a score or calls Meta. Run with an isolated
`XDG_DATA_HOME`, `--headless --xr-mode off --path . --script
tests/online_leaderboards_live.gd -- --eos-device-test --eos-config <local cfg>
--result <report.json>`. Keep the configuration and SDK logs private.

## SDK references

- [Epic Stats interface](https://dev.epicgames.com/docs/epic-online-services/player-and-game-data/stats-interface)
- [Epic Leaderboards interface](https://dev.epicgames.com/docs/epic-online-services/player-and-game-data/leaderboards-interface)
- [Pinned EOSG stats binding](https://github.com/3ddelano/epic-online-services-godot/blob/56238973e2cd7ac9ac99ca14f88934465f0a8997/src/stats_interface.cpp)
- [Pinned Meta toolkit leaderboard methods](https://github.com/godot-sdk-integrations/godot-meta-toolkit/blob/7fc223fa4b9a1b43552a53bf287a720c4719ea76/doc_classes/MetaPlatformSDK.xml)
