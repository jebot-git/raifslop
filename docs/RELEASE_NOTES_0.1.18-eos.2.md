# 0.1.18-eos.2 — Meta ALPHA leaderboard testing

Android version code 23. This ALPHA export enables experimental EOS personal-best
leaderboards and mirrors confirmed EOS scores to the signed-in Quest player's
Meta entries. The checked-in default remains disabled.

- Fishing: heaviest catch in grams and longest catch in millimetres.
- Golf: lowest completed 18-hole score for each course; forfeits are excluded.
- Account-scoped persistent retries, bounded background requests, and matching
  non-expiring EOS/Meta definitions. Meta's public leaderboard display and friend
  notifications remain off during testing.
- Dedicated-server rankings and historical records remain independent. The
  existing rankings panel still displays server rankings; the online reader is
  prepared for a subsequent UI update.

All eight EOS definitions and live stats/ranking reads passed verification, as
did 60 leaderboard checks, Android configuration tests, and the existing server,
golf and EOS regressions. Quest score writes and Meta mirroring still need device
acceptance. Scores are client-attested, not a trusted competitive ranking system.

Test while playing in an EOS lobby: land a new personal best or complete a golf
card, allow background synchronization, then compare the EOS and Meta entries.
Also test interrupted uploads, reconnects and account changes. Dedicated-server
play must not submit cloud scores. See [setup and validation](EOS_LEADERBOARDS.md).
