# 0.1.18-eos.4 — Meta ALPHA hand interactions and online progress

Android version code 25, for Meta ALPHA. Update the APK and matching expansion
file together using the existing release signing identity.

- Fix Quest EOS login error 10 when hosting a lobby.
- Keep motion-controlled fly casts within reachable water along the cast's
  measured direction.
- Match EOS/Meta leaderboard statistics to the dedicated-server catalog, with
  35 board definitions and provider-aware rankings. Historical records remain
  scoped to their original provider.
- Add six persistent achievements with generated artwork, independent EOS/Meta
  unlock retries, and sixteen water/course destinations with invitation routing.
- Add optical hand controls for menus, casting, reeling, fly stripping and golf
  strikes. Tracking interruptions cancel pending actions; controller pickup
  restores controller calibration. Quest requests high-frequency hand tracking.
  No hand gestures provide locomotion; move physically or use controllers.

See [hand gestures](HAND_INTERACTIONS.md), [online progress](ONLINE_PROGRESS.md)
and [leaderboards](EOS_LEADERBOARDS.md) for controls and configuration.

Automated hand/controller regressions passed 310 checks. EOS login, leaderboard,
achievement, destination and invitation tests also passed during implementation.
The signed build 24 headset retest confirmed hosting and motion fly casting.
Hand-tracking comfort/accuracy and the Meta friends/chat destination invite
retest remain pending; headset testing was deferred by the owner. This ALPHA
release does not claim complete hardware or store certification acceptance.
