# Fishing and minigolf leaderboards

The active catalog has **53 definitions**: five fishing categories and four fields for each of twelve minigolf courses. `docs/EOS_LEADERBOARDS.example.json` is the exact provider specification; `scripts/network/leaderboards/catalog.gd` supplies the same IDs at runtime.

| Activity | Fields | Aggregation |
|---|---|---|
| Fishing | Heaviest (grams), longest (millimetres) | MAX |
| Fishing | Catches, earnings, exceptional catches | MAX absolute totals |
| Minigolf, per water | Best complete 18-hole score | MIN strokes |
| Minigolf, per water | Latest complete score | LATEST strokes |
| Minigolf, per water | Completed rounds, forfeits | MAX absolute totals |

Minigolf uses separate `ubs_v3_minigolf_<water>_<field>` IDs. Blouberg and Simon's Town use shortened slugs to fit Meta's 40-character API-name limit. Existing fishing IDs are unchanged. The old six full-golf courses and their scores are retained as historical provider data but are absent from the active game catalog. Minigolf has no handicap leaderboard; raw strokes determine its scores.

Completed, non-forfeited 18-hole cards contribute scores. Counters rebase against remote absolute totals before retrying, avoiding double-counted retries. The dedicated server owns multiplayer round membership and records, retains archived full-golf data, and exposes only the twelve current courses. The internal zero handicap field remains solely for legacy wire compatibility and is not displayed as a minigolf metric.

Meta boards remain hidden with friend-surpassed notifications disabled, as in the existing application setup. Best scores use KEEP_BEST; latest scores use force-update in the provider adapter. EOS uses the existing start timestamp 1790330760 with no end time. Achievements retain their existing IDs and earned unlocks; first round and birdie descriptions now explicitly refer to minigolf.

## Validation

`tools/test_minigolf.py` checks provider definition parity, outbox retries, archived-score migration, round validation and guide/ranking integration. `tools/test_minigolf_network.py` checks three independent activity clients and completed server-scored minigolf. The asset-free server is built with `tools/build_server.py`; `tools/test_server_leaderboard.py` checks persisted records, duplicate rejection and identity continuity after restart.

Live portal provisioning results are recorded separately in `test-results/minigolf-providers/` after readback. Creating definitions does not submit player scores. Native EOS/Meta login and achievement unlock behavior remain subject to the platform's configured client policies.
