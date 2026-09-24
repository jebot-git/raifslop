# Photon versus EOS with Meta social services

Assessed 2026-09-24 for UBS production `main` (`555e9fc`), Godot 4.7.2,
Quest standalone and PC VR. This extends [the EOS assessment](EOS_META_MULTIPLAYER_FEASIBILITY.md).
Research only: no Photon SDK, account configuration or headset installation was performed.

## Recommendation for this game

**Keep EOS + Meta as the first transport prototype. Treat Photon Realtime as
an alternative transport, and Photon Fusion for Godot as a separate replication
prototype.** Photon is viable on Quest and has an official Godot integration,
but that integration is currently a development preview explicitly unsuitable
for production. The decision should not be based on Unity-only Photon samples.

EOS is the closer fit when the priority is preserving our gameplay/RPC
architecture and avoiding recurring multiplayer service fees. Photon Fusion
becomes attractive if we want to replace more of our replication with managed
state distribution, interest filtering, late-join state and ownership handling.
It is a larger migration with a preview dependency and usage-based cloud costs.
These are project-specific engineering judgments, not measured integration times.

## Available Photon routes

| Route | Fit for UBS | Main limitation |
|---|---|---|
| Photon Realtime through a native Godot adapter | Can preserve game rules and carry encoded packets/events | We must implement/validate the Godot peer mapping, routing, channels, lifecycle and diagnostics |
| Photon Fusion 3 for Godot | Official GDExtension, GDScript support, replication and ownership framework | Development preview; requires migration of replication and RPC patterns |
| Photon Fusion 2 Unity | Established Quest/XR examples demonstrate platform viability | The Unity integration and samples do not establish compatibility with this Godot project |
| Photon Quantum | Deterministic simulation and rollback | Would require a much larger simulation redesign; not justified for the current game |
| Photon Voice | Optional managed voice service | Separate integration/plan assessment; retain current Opus path for the first transport test |

Photon's Fusion Godot download currently lists **3.0.0 Preview Build 555**, for
Godot 4.6+ and Android/desktop targets. The new Realtime Core native SDK also
lists a **6.0.0 Preview** build, released September 23. Its Android arm64 C/C++
route is useful for a GDExtension, but should not be described as a mature,
ready-made Godot transport. Confirm a supported stable native SDK option if
avoiding all preview dependencies is a release requirement.
[Fusion Godot download](https://doc.photonengine.com/fusion-godot/v3-shared-authority/getting-started/sdk-download),
[Realtime Core download](https://doc.photonengine.com/realtime-core/v6/getting-started/sdk-download).

## Comparison

| Concern | EOS + Meta | Photon + Meta |
|---|---|---|
| Quest identity | EOS Connect accepts Meta user ID and proof nonce | Photon has a documented Oculus authentication provider using user ID and nonce |
| Quest invitations | Meta presence and join-intent bridge required | Same Meta bridge required, resolving Photon room/region/version instead of an EOS lobby |
| Networking | EOS P2P direct connection with relay fallback | Realtime room events route through Photon; Fusion 3 Godot distributes state through cloud rooms |
| Godot integration | Community adapters inspected; known fixes needed | Official Fusion GDExtension, but preview; Realtime needs an adapter |
| Reuse of current RPC/game rules | Relatively good after transport adaptation | Realtime: relatively good; Fusion: significant networking rewrite |
| Simulation hosting | Player host or separately hosted dedicated server | Realtime/Fusion Client-Host still run game logic on a player; dedicated game process is separate |
| Host disappears | Explicit migration/recovery or session termination needed | Realtime master election alone is insufficient; Fusion Shared provides stronger ownership/state facilities, requiring us to use them correctly |
| Service expense | Epic advertises game services without royalty/hosting fees | Peak CCU plus traffic allowances/overages; different Realtime and Fusion plans |

Photon's Realtime Core also documents optional direct messaging with relay
fallback. That is distinct from ordinary cloud room events and from Fusion 3
Godot's documented cloud-state path; evaluate it separately rather than assuming
every Photon mode has the same topology.
[Realtime Core features](https://doc.photonengine.com/realtime-core/v1/realtime-core-intro).

Photon's **Fusion 3 Godot** topology documentation says the cloud room caches
and distributes state in all its topologies. Shared-Authority distributes
simulation ownership among players; Client-Host centralizes it on one player;
Dedicated requires a separately hosted simulation process. Shared mode could
reduce dependence on one headset, but migrating our central golf/BBQ rules,
timers and persistence requires explicit design. Cloud state caching is not
cloud execution of our GDScript game logic.
[Fusion Godot topologies](https://doc.photonengine.com/fusion-godot/v3-shared-authority/getting-started/choose-topology).

For Realtime, Photon automatically chooses a new master client on disconnect,
but explicitly does not transfer all old-master application state. Our host-ID-1
assumption, pending commands, golf epochs, BBQ ownership and leaderboard writes
must be handled. Neither changing a transport nor merely selecting a new master
fixes those issues. [Realtime host migration](https://doc.photonengine.com/realtime/v5/gameplay/hostmigration).

## Identity and Meta invitations

Photon has a straightforward documented Meta authentication path: configure the
Meta app ID/secret in the Photon dashboard, then send the numeric user ID and
fresh nonce from the client using its Oculus auth provider. The app secret must
stay out of the APK. Our existing Meta toolkit can obtain those client values.
Players need not create Photon accounts.
[Photon Meta authentication](https://doc.photonengine.com/realtime/v5/connection-and-authentication/authentication/oculus-auth).

For either provider, keep Meta entitlement, native invites and presence.
A Photon invite/deep-link reference must include enough information to select
**the same region and application version** as the host before joining its room.
A room name alone is insufficient if independently chosen regions differ.
Validate room access/capacity and cold/warm launch behavior. A Meta invitation
does not automatically authorize private-room access on either backend.

## Bandwidth is a practical discriminator

Our recent Quest test showed a 1434-byte unreliable pose packet, while avatar
transfer uses 32 KiB chunks. EOS's inspected packet limit is 1170 bytes, and the
two reviewed Godot adapters reject oversize messages and convert
unreliable-ordered traffic to reliable. Those need specific adapter/protocol work.

Photon permits larger messages through fragmentation, but its guidance still
recommends **under 1 KB for frequent updates**, small occasional messages, and a
separate backend for large files. It documents a 500 KB per-client server buffer.
Moving our existing avatar transfer unchanged would be risky and expensive.
Both options benefit from compact poses, separate reliable events and bounded
bulk transfers. [Photon traffic guidance](https://doc.photonengine.com/realtime/v5/troubleshooting/faq).

Illustrative estimate, not measured Photon usage: eight players each broadcasting
one 1434-byte update at 20 Hz to the other seven create 160 incoming plus 1120
outgoing message deliveries per second. Counting the same payload for each gives
about **6.6 GB per room-hour**, before extra protocol overhead, voice, avatar
files, retries or any extra application-host forwarding. This assumes no batching,
compression, interest filtering or direct messaging. It shows why a CCU-only cost
comparison is insufficient. Photon counts cloud incoming and outgoing traffic.

Do not treat Photon's documented recommendation of fewer than 500 room messages
per second as a hard capacity limit; its FAQ calls this a fair-use recommendation.
Our actual usage must be measured with the selected SDK/topology and payloads.

## Pricing snapshot

USD, public gaming prices read 2026-09-24. CCU means simultaneous connected
users across the application, not players allowed in one room.

| Plan | Photon Realtime | Photon Fusion |
|---|---|---|
| Development | 20 CCU free, development only; 60 GB/month | Same |
| Small launch | 100 CCU: $95 once for 12 months; 0.3 TB/month | Free 100 CCU for one game app per customer; 0.3 TB/month |
| 500 CCU | $95/month; 1.5 TB/month | $125/month; 1.5 TB/month |
| 1,000 CCU | $185/month; 3 TB/month | $250/month; 3 TB/month |

Eligible paid-plan excess traffic is listed at $0.05 or $0.10/GB depending on
region. Free/capped plan handling and Fusion 3 preview availability should be
confirmed in the dashboard before launch. Do not assume Fusion's free 100-CCU
offer applies to a plain Realtime adapter. Photon sums regional CCU peaks for
billing. Additional services and dedicated simulation hosting are separate.
[Realtime pricing](https://www.photonengine.com/realtime/pricing),
[Fusion pricing](https://www.photonengine.com/fusion/pricing).
Epic currently advertises its game services without royalty or hosting fees;
a custom backend/dedicated game process still has operating costs.
[Epic licensing](https://onlineservices.epicgames.com/licensing).

## What to prototype before choosing

1. **EOS transport:** preserve the current rules, fix packet size/delivery
   semantics and run the existing network suite across two Internet connections,
   including forced relay and Quest-to-PC.
2. **Photon Realtime alternative:** carry the same test commands over an adapter,
   validate the host/peer-ID/channel mapping, region-aware Meta joins and actual
   eight-player traffic. Confirm a suitable native SDK release first.
3. **Photon Fusion contender:** a separate small Godot scene with two tracked
   hands, one ball and one shared BBQ item. Validate Android export, ownership
   transfer, late joining, headset suspension and remote physics smoothing.
   Measure the migration burden before replacing production scenes.

If preserving the current production architecture and minimizing recurring
service expense remain the priorities, choose EOS first. If managed state
replication and resilience to individual player departures are worth a larger
rewrite and cloud costs, Fusion for Godot deserves evaluation once its preview
risks are acceptable. Realtime is a viable commercial alternative when a
managed room service is preferred over EOS lobby/P2P plumbing.
