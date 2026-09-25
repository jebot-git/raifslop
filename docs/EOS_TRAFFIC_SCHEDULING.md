# EOS preparation: traffic scheduling

Implemented 2026-09-25 on `experimental/eos-meta`, following packet-size enforcement.
Gameplay still uses ENet. The isolated EOS–Meta lab and store releases are unchanged.
Wire schemas remain protocol 18; the scheduler metadata is local and never sent.

## Delivery policy

`packet_scheduler.gd` owns bounded queues of serialized Godot packets. The framed
ENet worker admits broadcasts atomically and charges each destination separately.
It sends at most 32 fragments before servicing incoming traffic and releasing its
lock. Reliable messages retain order within each recipient/channel stream. Other
classes and recipients can run between fragments; a later reliable command cannot
overtake a partially sent message on its own stream.

The class cycle reserves four opportunities for control, two each for poses/voice,
and one for bulk. Empty or rate-limited classes are skipped. Each class rotates
among eligible streams; avatar channel 4 has one ordered stream per recipient.
This also keeps avatar begin/chunk/ack/cancel ordering intact. Avatar control
messages still share that bulk channel, rather than racing data on another channel.

| Class | Aggregate wire budget | Burst | Queue lifetime |
| --- | ---: | ---: | --- |
| Control / other channels | 256 KiB/s | 8 KiB | 60 s; fail connection on expiry |
| Unreliable poses, channel 1 | 640 KiB/s | 8 KiB | 150 ms; superseded poses replaced |
| Unreliable voice, channel 6 | 384 KiB/s | 8 KiB | 100 ms; stale audio discarded |
| Avatar traffic, channel 4 | 256 KiB/s | 4 KiB | 60 s; fail connection on expiry |

Budgets count the frame and six reserved EOSG bytes per destination, but not UDP,
DTLS, retransmission or relay overhead. These are project tuning values, not Epic
service quotas or reservations. The pose/voice budgets accommodate the measured
full-pose and normal Opus fixtures across eight players; simultaneous maximum-size
voice packets can still exceed the voice budget and expire. Normal codecs/rates
are unchanged.

Only an explicit pose-origin hint enables replacement. `session._send_pose()` tags
an unreliable RPC with its originating player ID and resets the hint immediately.
The queue keys include recipient and origin, so relayed players never replace one
another. Untagged packets and reliable transition snapshots are not coalesced.

## Bounds and backpressure

- Full queued payloads remain charged until their final fragment succeeds: 8 MiB
  total, 2 MiB per destination and 4 MiB of bulk. Bulk may occupy at most 2,048 of
  the 4,096 message slots, leaving a separate reserve for other traffic.
- Each frame remains at most 994 bytes before the EOSG header. The framing helper
  constructs only the next fragment, avoiding a whole-message fragment array.
- Native `ERR_BUSY` / `ERR_OUT_OF_MEMORY` retain the exact frame and token credit.
  That stream is skipped for the rest of the pump, allowing other peers to run.
  Retrying commits the offset only after a successful send.
- Sustained reliable queue expiry, permanent send failure, or reliable admission
  overflow disconnects the affected recipient(s). SceneMultiplayer has no generic
  RPC retry mechanism, so accepted control messages are not silently discarded.
  An overflowing broadcast is not partially admitted.
- Framing retains the 1 MiB message limit and bounded reassembly reservations.
  Its absolute assembly deadline increases from 10 to 60 seconds so paced maximum
  messages can finish across eight destinations. Disconnect/reset frees queues.

These bounds cover the project scheduler. ENet's native retransmit queue and the
future EOS SDK outgoing queue require separate measurement. The EOS adapter must
use its native queue feedback and SDK thread rules; it must not transplant the
ENet worker thread or treat these local budget numbers as measured WAN capacity.

## Avatar disk admission

`bulk_read_budget.gd` admits at most 192 KiB/s of content across all transfers,
with at most 64 KiB of idle credit. Ready destinations rotate, receiving one
32 KiB disk read per grant (or the remaining short tail). The acknowledgement
window is independently 64 KiB per transfer. Pending reads reserve credit, failed
job admission refunds it, and reset clears credit/fairness state. Chunk hashes,
validation, caching, cancellation and inactivity recovery remain in the existing
transfer service.

The content rate leaves framing headroom under the 256 KiB/s bulk wire rate.
Large models intentionally take longer: a 25 MB file requires at least about
127 seconds of exclusive content service, before validation/relay/other transfers.
The existing 14 MB full-scene multiplayer harness now derives its transfer
deadlines from the fixture size and configured content rate, accounting for upload
plus two server-mediated downloads; it is intentionally a longer-running test. Active downloads retain
the existing 30-second inactivity timeout, not a 30-second total deadline.

## Validation

Use Godot 4.7.2, isolated writable user data, and loopback permission for network
fixtures. New focused tests:

```sh
godot --headless --xr-mode off --path . --script tests/packet_scheduler.gd
godot --headless --xr-mode off --path . --script tests/network_scheduler_stress.gd
godot --headless --xr-mode off --path . --script tests/framed_network.gd
godot --headless --xr-mode off --path . --script tests/avatar_pacing.gd -- --asset-root /tmp/ubs-avatar-pacing
godot --headless --xr-mode off --path . --script tests/network_packet_audit.gd -- --framed
```

Measured results (local fixtures, not live EOS or headset acceptance):

- Seven continuously queued bulk recipients differ by at most one sent packet in
  the deterministic fairness fixture. Aggregate bytes respect rate plus burst.
- Eight destinations with seven pose/voice origins each, four simulated seconds,
  and a 120 ms send refusal for one peer: healthy control queue age 0 ms, healthy
  realtime queue age at most 32 ms, peak queued payloads 298,944 bytes. Fourteen
  stale voice messages expired and fourteen superseded poses were replaced.
  Reliable fragment offsets stayed ordered and all eight bulk recipients advanced.
- Actual framed ENet loopback: a full pose arrived after 10 ms while 800 KB of bulk
  was queued; the first 200 KB bulk message completed after 769 ms. All data was
  reconstructed and malformed-peer isolation passed.
- Two concurrent 393,229-byte avatar transfers through real RPCs and asynchronous
  disk jobs finished in about 4.0 seconds; control probes peaked at 9 ms and
  unacknowledged content at 32,781 bytes. Reconstructed SHA256 and short final
  chunks matched. This fixture substitutes synthetic content for model decoding.
- All 17 framed packet-audit fixtures retained the 1,000-byte bound including
  reserved EOSG overhead. Golf, BBQ (including late joins), radio and raw ENet
  compatibility, leaderboard restart/reconnect and avatar recovery regressions passed. The dedicated server builds with the new
  scheduler dependencies. The existing single ObjectDB shutdown warning remains.

Next: demand-paged rankings and BBQ deltas/time anchors, then live EOS adapter
integration and eight-player forced-relay/loss/jitter acceptance.
