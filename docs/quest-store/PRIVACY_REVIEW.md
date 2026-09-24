# Privacy policy evidence and publication handoff

[PRIVACY_POLICY.md](PRIVACY_POLICY.md) is a substantive draft, not an active
notice. Publisher identity and privacy contact were explicitly not ready at the
last owner check. Do not invent these values or mark the listing URL complete.
The policy covers the current game behavior, not hypothetical future analytics.

## Publication blockers

1. Fill legal publisher identity, postal address, effective date and an actual
   monitored privacy/deletion contact. Give everyone a usable deletion route.
2. Confirm whether the publisher runs any servers, support system or website;
   name actual processors, hosting countries, transfer safeguards and retention
   periods. Independent-server behavior must not be presented as publisher control.
3. Confirm applicable legal bases with qualified privacy/legal advice, including
   optional tracking and voice. No consent mechanism or encryption was added by
   writing this document. Do not turn suggested legal grounds into unsupported
   assertions or claim that a permission prompt is sufficient legal consent.
4. Implement and test the operational deletion process: locate server identity,
   remove fishing and golf records, handle cached VRMs and backups, document
   necessary retention. Do not request raw player tokens through support.
5. Confirm publisher-wide no-sale/no-advertising statements and actual platform
   and service-provider behavior. Complete Meta data-handling answers against
   the same inventory; do not claim the app processes no personal data.
6. Publish the completed policy at a stable HTTPS URL without login, supply it in
   the Meta listing and provide access from the game before affected processing.
   This task creates a document; no public hosting or in-game link is configured.
7. Keep previous effective versions and review the notice when SDKs, server
   operations, tracking, voice defaults or retention change.

## Code evidence reviewed, 2026-09-24

| Behavior | Source |
| --- | --- |
| Random local token, saved display name/address; raw token sent to chosen host | `scripts/network/session.gd`, `load_preferences`, `_hello` |
| Hashed identity and persistent fishing results | `scripts/network/leaderboard.gd` |
| Golf results and server persistence | `addons/golfminus/scripts/golf/network_service.gd`, `server_records.gd` |
| Local settings, journal and rewards | `scripts/main.gd`, `scripts/tackle.gd`, `scripts/locations.gd` |
| Voice activation default; listen-only and PTT choices | `scripts/voice/preferences.gd`, `scripts/voice/chat.gd` |
| Voice packets relayed, not written as recordings | `scripts/voice/chat.gd`, `scripts/voice/microphone.gd` |
| Body/hand/eye/face permissions; saved measured height | `scripts/voice/permissions.gd`, `scripts/tracking/manager.gd` |
| Tracking/expressions in multiplayer state | `scripts/network/state.gd`, `docs/MULTIPLAYER.md` |
| Persistent VRM files; size cap is not expiry | `scripts/network/avatar_library.gd`, `reserve_cache`; `scripts/network/avatars.gd` |
| Local asset migration preserves old copies | `scripts/data_paths.gd` |
| Photos saved to shared Pictures folder on Android | `scripts/guide_camera.gd`, `scripts/android_photos.gd` |
| Meta SDK init and entitlement result only in startup gate | `scripts/quest_entitlement.gd`, `scripts/quest_bootstrap.gd` |
| Direct ENet connection without configured encryption | `scripts/network/threaded_peer.gd` |

Do not describe deletion as “uninstall and everything is gone”: photos, legacy
avatar folders, backup copies and independent server/client caches can remain.
The server receives a stable raw token before hashing it for storage. Hashing
that token does not anonymize records or encrypt network traffic. The game
has no automatic central collection of every player's journal or server board.
Runtime SDK/platform diagnostics are not fully described by a scan of game scripts;
verify those against provider disclosures before final Dashboard declarations.

## References checked

[Meta privacy-policy requirements](https://developers.meta.com/horizon/policy/privacy-policy/)
require a public, current notice describing data, purposes and a specific deletion
path. [Meta’s deletion VRC](https://developers.meta.com/horizon/resources/vrc-quest-privacy-4/)
also calls for explaining exceptions to deletion.

[ICO privacy-information guidance](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/individual-rights/the-right-to-be-informed/what-privacy-information-should-we-provide/)
covers controller identity, purposes, lawful grounds, recipients, retention,
transfers and rights. Applicability and legal grounds depend on the actual
publisher and operations; this draft is not a compliance certification.
