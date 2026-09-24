# Quest standalone hosting and Meta invites

Tested 2026-09-24 against production source `4c43563` (protocol 17), after
promoting integration to `main` and merging the BBQ fixes into `stores`.
Previous `main` is preserved at `archive/main-pre-integration-2026-09-24`
(`b136469`).

## Physical Quest result

**Quest 3 successfully hosted the full standalone game with two simultaneous
PC clients over Wi-Fi LAN.** This was native Android/OpenXR execution, not
WiVRn streaming. The host rendered the fishing scene while processing commands.

The separate locally signed debug package was
`org.jebot.raifslop.quest.hosttest`, version code 22, labelled **UBS Quest Hosting
Test**. Its embedded arguments automatically host UDP 28673 and enable network
metrics. It does not exercise Meta entitlement or overwrite the store package.
APK SHA256: `94c002cd8512220a8f6281081583aaa5021414ef4c8b8b4d47902a8733a758f3`.

- First run: **21/21 checks passed**.
- Repeat run: **23/23 checks passed**, with an additional two-client readiness
  exchange to verify a change from the food's initial side, including when
  reusing an existing station.
- Verified handshake, host roster entry, live host poses, client-to-client
  relay, authoritative tongs ownership, clamping, wrist-based flipping,
  cooking and observer replication, solo golf enrollment, turn permission,
  stroke acknowledgement/settling, retirement and same-identity reconnect.
- Sampled client RTT: 8–14 ms on the first run and 9–10 ms on the repeat.
  No transport worker failure or remaining outgoing queue at completion.
- Startup/joins/first activity use were not smooth throughout: maximum sampled
  state gaps were **1491 ms** on the first run and **807 ms** on the repeat.
  First-use BBQ model loads and shader cache misses overlap the first stall.
  This suggests main-thread resource/scene work, rather than socket-worker
  starvation; further profiling is needed to separate each contributor.
- ENet warned about an **unreliable 1434-byte packet exceeding its 1392-byte
  MTU**. Fragmentation can amplify loss, especially on weaker Wi-Fi/WAN links.
- Post-probe VrApi samples showed approximately 72 FPS at the 72 Hz target;
  these are not a frame-time acceptance test during every operation. Memory
  after the first probe was about 1.38 GiB PSS (1,449,023 KiB).
- No script errors or fatal crash were captured on the host. Hardware texture
  format conversion warnings remain. Headless probes report the existing
  ObjectDB shutdown warning.

The PC clients supplied synthetic controller poses and game commands. This
validates host networking and authority, not physical swing quality, voice,
full eight-player load, thermal endurance, Internet reachability, host headset
sleep/suspend, or a second physical Quest client. The host did not load a golf
course itself during these checks; it processed remote golf commands while in
fishing. Host course transitions under multiplayer load still need testing.

Evidence remains local under `test-results/quest-host/`: `device/` and `warm/`
contain per-client logs/results; `device/launch-logcat.log` contains the host
startup and network capture, alongside memory/package/VrApi snapshots.
`summary.json` summarizes both runs. APK and provenance are under
`builds/QuestHostTest-2026-09-24/`.

## Repeat the LAN probe

Install a matching-protocol standalone build. After prompting the tester,
launch it and select Host, or use the prepared test APK which auto-hosts on
28673. Keep the headset awake and in the application, then run:

```sh
python3 tools/test_quest_host.py QUEST_LAN_IP --port 28673 \
  --output test-results/quest-host/repeat
```

The runner only connects clients; it never installs or launches headset apps.
For normal builds use the selected host port (default 24567). The probe uses a
lakeside BBQ and disposable test identities; run it in a test session. Its
fixture runs the actual session/BBQ/golf RPC scripts with the same node paths as
the game. It does not simulate a server or substitute loopback for the Quest.

## Meta invite feasibility

**Viable as the invitation/join layer, but not implemented in the game yet.**
Meta's current flow combines Destinations, Group Presence and invites. The
receiving app handles launch details or a join intent to enter the intended
session. Meta's multiplayer examples separately associate that session with
the game's networking service.

The already bundled Godot Meta Toolkit **1.0.3-stable**, pinned to
`7fc223fa4b9a1b43552a53bf287a720c4719ea76`, exposes the needed native bindings:

- `group_presence_set_async`, `group_presence_clear_async` and setters for
  destination, joinability, lobby session and match session.
- `group_presence_launch_invite_panel_async` and `group_presence_send_invites_async`.
- `application_lifecycle_get_launch_details` and launch-intent notifications.
- `MESSAGE_NOTIFICATION_GROUP_PRESENCE_JOIN_INTENT_RECEIVED` and leave intents.

No replacement engine/plugin is necessary just to expose those functions.
The app currently uses the SDK for entitlement only; it has no presence,
invite button, session directory or invite-to-ENet join bridge. Actual Meta
invitation delivery has **not** been tested with two entitled accounts or a
store-channel build; the separate local test package cannot establish that.

Recommended implementation sequence:

1. Keep the existing ENet/game-authority protocol. For reliable Internet play,
   prefer a reachable dedicated server; alternatively design a relay/NAT
   traversal solution if player-hosted WAN sessions are a requirement.
2. Configure an immersive-app Destination in the Meta dashboard. Publish
   joinable Group Presence only when the session is ready and has capacity;
   use an opaque lobby ID rather than publishing a private LAN address.
3. Add an Invite action using the existing toolkit, and a session lookup that
   maps that lobby ID to a reachable endpoint and validated join information.
4. Handle cold and warm launch/join intents after platform initialization;
   queue the intent through loading, leave the old session deliberately, and
   join the resolved session. Clear presence when leaving/closing/full.
5. Validate between two entitled accounts: host/invite/accept, cold launch,
   already-running app, full session, host departure, stale invite, and suspend.

A Meta invitation does not by itself make a private-IP ENet host reachable
outside its LAN. Godot documents UDP port forwarding for ordinary Internet
hosting. The deprecated Oculus Rooms/Matchmaking/P2P APIs are not a suitable
new integration.

## Follow-up engineering priorities

1. Profile and preload shared BBQ/remote equipment resources before making the
   session joinable; spread safe scene instantiation across frames and warm
   shader pipelines. The socket worker already continues separately, but
   gameplay/RPC application remains on the main thread.
2. Compact pose packets (quantized transforms or a packed pose schema, with
   infrequent state sent separately) to fit below the effective MTU. Measure
   packet sizes including RPC overhead and retest under loss; do not simply
   switch every pose to reliable delivery.
3. Test host golf transitions and overlay/suspend with connected peers, then
   eight-player and long-duration load. Prefer dedicated hosting for sessions
   that must survive the host removing their headset.
4. Add Meta invites on top of the chosen reachable-session service.

Primary references, checked 2026-09-24:

- [Meta Multiplayer Overview](https://developers.meta.com/horizon/documentation/native/ps-multiplayer-overview/)
- [Meta Destinations and Group Presence implementation](https://developers.meta.com/horizon/documentation/native/ps-destinations-implementation/)
- [Pinned Godot Meta SDK API definitions](https://github.com/godot-sdk-integrations/godot-meta-toolkit/blob/7fc223fa4b9a1b43552a53bf287a720c4719ea76/doc_classes/MetaPlatformSDK.xml)
- [Godot hosting considerations and Android permission](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html#hosting-considerations)
- [Meta Rooms/P2P deprecation](https://developers.meta.com/horizon/blog/deprecating-oculus-rooms-api-in-march-2023/)
