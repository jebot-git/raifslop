# Achievements and activity destinations

The Achievements tab shows six persistent local milestones: a first catch, ten
catches, an exceptional catch, a clean 18-hole round, a birdie or better, and visits
to three different waters or courses. Fishing uses the dedicated leaderboard's
exceptional-catch rule. Forfeited golf holes cannot earn a birdie or a clean round.

`user://achievements.json` stores local progress. Invalid files are preserved and
reported in the menu. A milestone earned during an authenticated EOS lobby is
also queued in an account-scoped unlock outbox. EOS and Meta acknowledgements
are independent; failed unlocks retry without counting the milestone twice.
Meta writes recheck the logged-in viewer and attempt at most two unlocks per
minute with fair rotation. Session changes invalidate late acknowledgements.
Offline progress is not bulk-imported into another account.

Provision the exact IDs, English text and PNG icons in
[ACHIEVEMENTS.example.json](ACHIEVEMENTS.example.json). EOS achievements use
manual client unlocks, with the client policy granting achievement unlocks for
the local user. Meta definitions use SIMPLE achievements. `[achievements]
enabled=true` enables the online outbox (also the default); setting it false
keeps local milestones available without online submissions.

[DESTINATIONS.example.json](DESTINATIONS.example.json) specifies twelve waters
and the four playable named courses. These names are allowlisted by the game.
Current activity is published through Meta group presence, and shared activity
links use that destination. Cold destination-only launches travel directly when
the player is idle. Warm launch requests appear in the Achievements tab with an
explicit travel action. Lobby invitations retain the existing join confirmation;
after joining, the pending destination is applied. A cast or enrolled online golf
round prevents travel until the player can safely leave it. Unknown destination
names are ignored. The existing `eos_game` destination remains compatible.

Portal definitions and a rebuilt Quest application are both required for live
acceptance. Offline validation covers progress persistence, unlock retries,
account cancellation, destination allowlisting and lobby intent routing:

```sh
godot --headless --xr-mode off --path . --script tests/progress.gd
godot --headless --xr-mode off --path . --script tests/meta_lobby_invites.gd
```

On Quest, verify a new catch and a new milestone, EOS/Meta unlock read-back,
restart/retry, destination-only cold launch, and an accepted water/course lobby
invite. Headset acceptance is separate from these offline contract checks.

## Quest build 24 acceptance (2026-09-26)

The release-signed `0.1.18-eos.3` update was installed over ALPHA build 23
without clearing app data. The connected-headset retest confirmed EOS hosting
and motion-controlled fly casting both work. At that point Meta friends and
chat destination invites were unavailable while destination provisioning was
still pending. Repeat those checks after the portal definitions are active and
the lobby is hosted again.

## Portal provisioning (2026-09-26)

All six achievement definitions are saved in EOS Live and published in Meta app
3428825797290213, with the generated artwork described in
[ACHIEVEMENT_ART.md](ACHIEVEMENT_ART.md). Meta uses SIMPLE, client-authoritative,
non-secret achievements. The EOS `UBS` client policy is now Custom with User
required; every original Peer2Peer grant was preserved and read back, adding
only `achievements:unlockAchievementForLocalUser`. Unlocking other users remains
disabled.

Destination images are actual 2560×1440 RGB game captures in
`test-results/destination-art/`, with exact portal metadata recorded in
[DESTINATIONS.example.json](DESTINATIONS.example.json). Optional group-launch
capacity is unset: shared lobby invitations carry an existing lobby ID, while
standalone destination links travel to the selected activity.

All sixteen destinations were submitted and immediately published by Meta; the
final table confirms both submission and publish states are Published, audience
Everyone, and deeplinks enabled. No external review remains pending. The native
EOS SDK also read back all six achievement definitions without unlocking any.
The Meta invite-panel and chat-link headset retest follows rehosting the lobby
so group presence is republished with the new definitions.
