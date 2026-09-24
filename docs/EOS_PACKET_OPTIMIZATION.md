# Network packet optimization for EOS

Measured 2026-09-25 on `experimental/eos-meta`, production networking protocol 17,
Godot 4.7.2, EOSG 2.3.1. Investigation and benchmark only: no production packet
formats, replication rates, gameplay or avatar transfer behavior were changed.

## Findings

The existing traffic cannot be attached directly to EOSG. Oversized messages
include routine poses, BBQ state, competition state, avatar chunks and rankings.
The largest avoidable payload is the fishing leaderboard, which copies entire
records into each of five ranking categories, including nested golf history.

EOS permits **1,170 bytes per P2P send**. The inspected EOSG wrapper adds a
**6-byte header**, so its actual maximum Godot packet is **1,164 bytes**, even
though `get_max_packet_size()` advertises 1,170. Its send path checks the size
again after adding the header. Godot RPC headers/arguments consume part of those
1,164 bytes too. Fix or wrap that advertised limit during transport integration.

Use a conservative **1,000-byte total EOS packet target** and test final encoded
size, including cold node-path negotiation. Do not allocate the entire 1,170
bytes to an application payload.

Sources: [EOS packet limit](https://github.com/EOS-Contrib/eos_plugin_for_unity/blob/stable/lib/NativeCode/third_party/eos_sdk/include/eos_p2p_types.h),
[pinned EOSG peer implementation](https://github.com/3ddelano/epic-online-services-godot/blob/56238973e2cd7ac9ac99ca14f88934465f0a8997/src/eosg_multiplayer_peer.cpp),
[EOSG header](https://github.com/3ddelano/epic-online-services-godot/blob/56238973e2cd7ac9ac99ca14f88934465f0a8997/src/eosg_multiplayer_peer.h).

## Measured serialization sizes

The audit uses real Godot RPC serialization over two local ENet peers. It builds
deterministic, nonzero player fixtures validated against `State.valid()`, real
BBQ/course-session snapshots and populated ranking fixtures. RPC signatures
match production argument types. It warms the node-path cache first. The final
column adds EOSG's six bytes; it is calculated, not captured EOS traffic. UDP,
IP, encryption and relay protocol overhead are additional.

| Message / fixture | Godot RPC bytes | With EOSG header | Fits EOS? |
| --- | ---: | ---: | --- |
| Controller-only player update | 1,164 | 1,170 | Exactly, no margin |
| Same update relayed with player ID | 1,169 | 1,175 | No |
| Hips/chest/feet, curls and face | 1,725 | 1,731 | No |
| Ten body transforms, curls and face | 2,157 | 2,163 | No |
| Golf full-body player update | 2,165 | 2,171 | No |
| Stocked BBQ station, ten items | 3,136 | 3,142 | No |
| BBQ with extra pose fields on all items, stress fixture | 4,416 | 4,422 | No |
| Eight-player competition, empty ranking | 1,752 | 1,758 | No |
| Competition plus 50 records per each of six catalog courses | 47,496 | 47,502 | No |
| Fishing rankings, 50 players with golf records | 234,188 | 234,194 | No |
| Same, including 20 history entries/course | 2,064,188 | 2,064,194 | No |
| Existing 32 KiB avatar chunk | 32,857 | 32,863 | No |
| 1,024-byte avatar data chunk | 1,113 | 1,119 | Yes, limited spare room |
| 900-byte avatar data chunk | 989 | 995 | Yes |
| 768-byte avatar data chunk | 857 | 863 | Yes |
| Largest allowed voice packet, 400-byte codec payload | 423 | 429 | Yes |

These are representative and populated stress fixtures, not a measurement of
the current users' records, nor a complete maximum-size proof. Longer strings,
late-round scorecards, late-join synchronization and cold RPC paths need their
own budget checks. The BBQ stress row adds optional fields generously; it is
not claimed to be a naturally occurring station state.

Reproduce without VR, game assets or EOS login:

```sh
XDG_DATA_HOME=/tmp/ubs-packet-audit XDG_CONFIG_HOME=/tmp/ubs-packet-config \
  godot --headless --xr-mode off --path . --script tests/network_packet_audit.gd
```

It uses loopback port 25097 and writes `test-results/eos-meta/packet-audit.json`.
The expected ENet warning about an oversized unreliable packet corroborates
the MTU issue. The existing one-instance ObjectDB shutdown warning also occurs.

## Recommended implementation order

### 1. Remove repeated leaderboard data and separate rankings from gameplay

`scripts/network/leaderboard.gd:snapshot()` duplicates all record fields into
five categories. Return only the fields each category displays: player reference,
name, category value and relevant fish detail. Keep golf history server-side.
Where useful, send a player table once and category lists of player references.

`addons/golfminus/scripts/golf/network_service.gd:publish()` sends a full ranking
with every published round view. Publish ranking changes separately, with a
revision. Fetch bounded pages when the leaderboard UI opens; invalidate/update
the displayed page after a record changes. Keep join/turn/stroke/retirement
messages small and independent of rankings. Fragment or page initial round
views: even an eight-player view with no rankings exceeds EOS's limit.

This also fixes a pre-existing ENet scaling concern: a roughly 2 MB ranking sent
to seven clients creates about 14 MB of application traffic in one broadcast.
The worker has an 8 MiB outgoing queue cap. Whether it overflows depends on
concurrent draining; the current code provides no scheduling guarantee here.

### 2. Pack player state; retain 20 Hz initially

`scripts/network/state.gd` sends 35 named fields, including five full transforms,
seven vectors, and nested tracking dictionaries. `session.gd` sends at 20 Hz and
relays every player's state to every other client.

Use a versioned binary schema with presence masks, compact numeric IDs for
location/equipment/state, and explicit optional body/face blocks. Preserve all
needed data and reconstruct the validated in-memory schema if that minimizes
gameplay changes. Preserve tracking validity and explicit removal of stale
optional trackers. Start with independently decodable snapshots, not a chain
of unreliable deltas that needs previous packets to survive.

Suggested layout budget, **design estimate, not an implemented codec**:

- Five poses: float32 world positions + four signed-16 quaternion components,
  about 100 bytes instead of full bases. Normalize decoded quaternions.
- Seven world-space vectors: float32, 84 bytes. Do not encode all world positions
  as millimetre int16; courses and casts exceed that range.
- Up to ten body-local transforms: bounded half-millimetre positions plus
  quantized quaternions, about 140 bytes.
- Curls, face weights and visemes: byte weights with separate masks; scalar
  metadata and sequence/world identifiers in a small fixed header.

Target roughly **400–500 bytes for a complete full-tracking packet**, with a
hard size assertion. Validate position/angular error against long clubs/rods,
avatar IK, and server BBQ reach checks; quantization affects those checks too.
Any lower-frequency cosmetic stream must not delay the head and hand stream.

Replacing only the outer Dictionary with an Array is insufficient: measured
full-tracking Variant serialization falls from 2,148 to 1,592 bytes. Zstd on
that nonzero fixture yields 1,362 bytes before RPC/EOSG overhead, still too
large. Compression ratios are input-dependent; compression alone cannot
establish a packet bound. It may help bounded reliable pages later.

For eight players in one world, an ad-hoc host sends 49 pose copies per tick:
seven copies of its own pose plus six copies for each of seven remote players.
At 20 Hz that is **980 packets/s**. With the measured 2,163-byte full pose,
this is about **17 Mbit/s host upload for poses alone**, excluding lower-layer
overhead. At 450 bytes it would be about **3.5 Mbit/s**, a ~79% reduction.
These are calculated traffic budgets, not a measured eight-player session.

### 3. Preserve unreliable delivery and add queue priorities

EOSG converts `unreliable_ordered` to reliable. Send poses as plain unreliable
and keep the existing serial-based stale rejection. Add an explicit world/
tracking epoch and wrap-safe sequence policy when versioning the codec.

Separate reliable equipment/state changes from the current practice of sending
an entire pose reliably whenever `event_key()` changes. Use revision references
or include a small durable-state subset in periodic snapshots so racing channels
cannot resurrect stale gear or lose an important catch transition.

Use separate channels/queues for control, latest poses, voice and bulk data.
Channels alone do not reserve bandwidth. Coalesce superseded unsent poses,
expire late voice, cap both queued bytes and queue age, and prioritize small
control commands. Expose outgoing queue age/bytes, message type, packet-size
histograms, rejected oversize messages, RTT and stale-pose drops. Current
`threaded_peer.gd:diagnostics()` omits outgoing bytes and per-message sizes.
Keep EOS SDK ticking on the required thread; the existing ENet worker is not
automatically a valid EOS worker.

### 4. Replace full BBQ broadcasts with changes and time anchors

`scripts/bbq/network.gd` sends complete station state reliably every 250 ms,
as well as immediately after accepted actions. Even empty station state is
sent repeatedly. Stocked state alone costs about 12.6 KB/s per recipient.

Send initial state once, then changed item IDs/fields and ownership/flip events.
Derive fixed kind/home/slot data from the shared definitions. Replicate cooking
start/time/rate anchors and interpolate the display locally, while preserving
host authority over cooking and eating outcomes. Version state and provide a
bounded resynchronization path on late join or missed revisions. Held objects
already reuse controller poses; do not add a redundant high-frequency stream.

### 5. Give avatars a separate bulk-transfer design

Changing `CHUNK` from 32,768 to 900 makes the measured chunk fit, but also reduces
`WINDOW = CHUNK * 8` from 256 KiB to 7,200 bytes. At 50 ms RTT that permits only
about 144 KB/s before overhead/disk delays: a 25 MB avatar takes at least ~174 s.
At the present 2 MiB/s upload target, 900-byte chunks would require about 2,330
data messages/s plus acknowledgements. Smaller packets also turn each current
per-chunk disk job into much more scheduler work.

For the first EOS integration, use explicitly bounded 768–900-byte content
fragments with a transfer ID rather than repeating the 64-character hash in
every fragment. Keep the hash in the manifest/final verification. Decouple the
window size from chunk size, batch disk writes and cumulative acknowledgements,
and give bulk data a lower-priority aggregate bandwidth budget. Tune a starting
32–64 KiB per-transfer window against RTT, with a global cap; measure fairness
across simultaneous uploads before increasing throughput. Review queue and
inactivity timeouts at the chosen rate, and preserve cancellation, size/hash
validation and cache reuse. The 90-second request timeout is not a hard active
download timeout: active transfers currently use a 30-second inactivity check.

Longer term, content-addressed HTTPS downloads are a better candidate for large
user avatars: the multiplayer channel carries manifests/selection, while a
validated upload/download service handles files. That needs backend storage,
admission/quotas and operating-cost decisions; it is not supplied by EOS P2P.

### 6. Filter recipients, then optimize secondary rates

The remote renderer already hides players in other worlds, but `session._accept`
still relays their full poses. Filter at the host using the existing
`host_locations.same_world()` semantics, not strict hole equality: connected
golf courses intentionally share a world. Keep roster/location/leaderboard
metadata global and send a fresh snapshot when players enter relevance. The
host still needs client state for validation even when no observer needs it.

Voice already uses 24 kbit/s mono Opus with 20 ms frames and unreliable delivery.
The tone fixture produced 55–91-byte codec packets; the currently allowed
400-byte maximum is still well within EOS. Leave the codec/rate alone initially.
Preserve all-waters radio behavior; proximity voice already filters by world.
Avoid batching that adds speaking latency just to reduce packet counts.

## Before attaching the game to EOS

1. Budget every message family, including connection/path setup, full rankings,
   late joins, avatars and unusually long names. Gate final encoded packet sizes.
2. Bounded reliable pages/fragments need per-peer memory caps, deadlines,
   transfer/revision IDs, duplicate rejection and explicit failure/retry paths.
   Never deserialize objects from network data.
3. Validate codec round trips at world-coordinate extremes, all activity/rig
   combinations, full tracking, tracker removal, equipment changes and sequence
   wrap. Preserve location/permission checks and server authority.
4. Run eight-player loss/jitter/reordering tests while uploading avatars and
   sending voice, with forced relay. Measure tracking age and control latency,
   not merely successful delivery or average throughput.
5. Keep ENet available and version the new protocol. The successful EOS lab
   used tiny probes; it does not demonstrate that today's gameplay packets fit.

The first implementation should cover leaderboard projection/paging, the
binary pose codec, delivery semantics and bounded control/bulk framing together.
Replacing only the transport or reducing only the update rate is insufficient.
