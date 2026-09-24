# Privacy operations — PLdot development team

Owner: Juzuv Jebot. Monitored inbox: jewzuv@gmail.com.
Scope: support messages and the Cloudzy testing VPS in Frankfurt, Germany.
This procedure implements the commitments described by the
[policy](PRIVACY_POLICY.md); it is not evidence of a live server deletion test.
No VPS or mailbox settings were changed by publishing the policy.

## Retention routine

| Data under our control | Maximum retention | Operator action |
| --- | --- | --- |
| Support messages and attachments, including downloaded copies | 90 days after resolution | Record the resolution date; delete the thread, sent replies and downloaded attachments by its deadline; empty the relevant trash |
| Testing-server fishing/golf records and received avatars | End of each test, at most 30 days from collection | Stop the server and clear the testing records and received-avatar cache at test end; for longer tests, rotate the entire dataset at least every 28 days |
| Basic functional server logs | Seven days | Rotate and delete logs, including service-manager/stdout captures, within seven days; do not rely on size-only rotation |
| Operator-maintained backups and VPS snapshots, if any | 30 days | Check Cloudzy snapshots and all local/remote copies; expire each within 30 days and avoid copying old snapshots to restart the clock |

Use a calendar or a verified scheduler. Review resolved support threads at
least weekly with enough margin to meet the 90-day deadline. Provider-managed
retention is separate; ask Cloudzy about infrastructure backups rather than
assuming the VPS has none. Do not put player data or deletion requests in public
GitHub issues or commit them to this repository.

The scoreboard has no reliable first-seen timestamp for every player. Golf's
round timestamps are not a complete age record. A full test-dataset rotation
avoids inventing per-record expiry from modification times or player names.
Account for records already present before the policy became effective.

## Handle a deletion request

1. Record receipt and a response deadline within 30 days (or a shorter legal
   deadline). Deletion is free for everyone, regardless of location. Ask for
   only the display name, server and approximate participation dates initially.
   Do not ask for the raw token from `multiplayer.cfg`, account passwords or an
   identity-document scan by default.
2. Search the support inbox and privately inspect the testing records. Names
   are not unique and may have changed. Use proportionate verification, such as
   the existing support conversation and privately supplied session details.
   If a particular scoreboard row cannot safely be identified, explain the
   issue; clearing the entire testing board at test end is also an option.
   Never publish a list of matching players or their identifiers to a requester.
3. Stop the server before editing persistent data. Its in-memory board is saved
   every few seconds and on shutdown; editing a live file can resurrect data.
   Resolve the actual `--leaderboard-path`, `--asset-root`, service account's
   `user://` directory and log destinations from the launch configuration.
4. The scoreboard is JSON shaped as `{"version":1,"players":{...}}`.
   Remove the verified player's entire entry under `players`, keyed by the
   SHA-256 hash of their private token. This removes both fishing records and
   the nested `golf` results/history. Do not search only the top-50 visible
   rankings. Write valid JSON atomically and check any residual `.tmp` copy.
   Avoid retaining an indefinite "safety copy" of deleted records.
5. Avatars are content-addressed, not indexed permanently by player identity.
   Identify the requested files if possible; otherwise clear the testing
   server's received-avatar cache while stopped. Check `<asset-root>/vrm/`,
   legacy `user://avatars/`, `user://network_avatars/` and any migrated copies.
   Do not claim to delete independent clients' cached copies.
6. Delete matching support messages, sent copies, trash and downloaded
   attachments as requested. Remove identifiable entries from our functional
   logs where feasible or expire the entire affected test log. Check operator
   snapshots and other backups. Delete accessible backup copies promptly;
   any remaining scheduled expiry must be within 30 days. Keep them out of
   normal use and reapply outstanding deletions before a restore serves players.
7. Restart the server, verify that the removed entry is absent from disk and
   the board, then stop/restart once more to check persistence. Use a synthetic
   test profile to rehearse this before accepting real participants. Rejoining
   later may create a new record; that does not justify retaining the old one.
8. Reply with what was deleted, what was never held by us, any pending backup
   expiry and specific exceptions. A legal-retention exception needs an actual
   reason, scope and review date. Explain separately that Meta, independent
   hosts and other players control their own copies. Retain the request/reply
   only under the support schedule unless a specific legal need applies.

## Before the next testing session

Provide the public policy with the server invitation; explain voice activation
and sharing of avatars/poses. Record the next dataset-clear date and configure
log retention. Check the inbox is monitored. Rehearse the steps above with a
synthetic profile, including a fishing record, a golf result and a test avatar.
This document does not claim that rehearsal or the VPS configuration is done.

## Provider and release checks

Cloudzy, Gmail and GitHub disclosures are linked in the policy. Check applicable
processor and transfer arrangements with providers; their public privacy pages
are not proof that the publisher has signed particular contracts. Keep data-use
answers in Meta's Dashboard consistent with voice, tracking, avatars, identity
and server records. Do not declare that the app processes no personal data.
Add/check in-game policy access in the release build separately from publishing
the web page. Preserve previous effective notices in Git history.
