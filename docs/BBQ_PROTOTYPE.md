# Shore BBQ prototype — 0.1.9-bbq.1

Branch: `prototype/shore-bbq`. Includes the newly authored **Secluded Cove** (`secluded_beach`) and **Tidal Strand** (`fish_hoek_beach`), their HDR lighting, ambience and associated maritime expansion. This is a prototype, not a new public release.

## Try it

Run `./run.sh --desktop` or `./run.sh` for OpenXR. Open **V / right B → BBQ → Start BBQ & visit**, or press **H** on desktop. Finish the active cast before visiting. Visiting stows the rod and retains ready bait, fades the view in stereo, and puts you facing the grill. **Return to fishing spot** restores the departure position and direction. Pick up the rod normally to resume fishing.

Anyone can start the shared station at their current water. Repeated starts use the existing kit. Walk over to watch, or take a free utensil/serving to participate. There is no host-only permission or party membership. Existing same-location positional voice works normally. Up to eight players share two pairs of tongs, six food portions and two replenishing drinks.

| Action | VR | Desktop |
|---|---|---|
| Take tongs, served food or drink | Hold grip near it | Click the prop |
| Put pantry food on grill | Hold tongs; trigger near food | Hold tongs; click food |
| Turn / then serve | Trigger near grilling food | Click grilling food |
| Move to an available cooler grill slot | A with tongs near food | C with tongs aimed at food |
| Return held prop | Release grip | Right-click |
| Eat | Trigger with held food near mouth | Click while holding food |
| Drink | Trigger to open; trigger near mouth to sip | Click to open, then click to sip |

The centre heats faster than the edges. Each side takes about 42 seconds in the centre or 62 seconds on an edge. Browning, a small nearby label, sizzling and sparse smoke provide feedback. Food can char; ingredients are always free. Eating replenishes that portion after three seconds. A serving left on its plate returns to the pantry after 90 seconds. Stations pack away after three minutes without anyone nearby. Opening a menu does not stop shared cooking.

## Locations and access

Every location has an authored anchor in `scripts/bbq/sites.gd`. Lakeside uses the inland cove; Lake Pier uses a side of its quay; Gray Pier uses its wider landward bank; the rocky coast uses the rear terrace; all three beaches use dry sand; the two rivers use the inland bank. Eight arrival positions per location have floor-support checks.

Bell Park's boat is too narrow for a gathering. A supported, railed, timber picnic deck sits alongside its modeled mooring. The explicit fade transition reaches it in the same multiplayer location; it is visible from the fishing area. Return uses the original departure position. The prototype does not open a new scene or move other players.

## Functional limits

- Tongs use assisted placement and a three-step trigger interaction (grill, flip, serve). They are not a free rigid-body cooking simulation. Flipping animates visibly; broad grab and interaction volumes avoid precision gestures.
- Serving plates are fixed to the shelf. Food is held individually and shared via the communal plates, rather than by carrying loaded plates or grabbing objects out of another player's hand.
- Drinks are generic leisure props. There are no cigarettes, alcohol effects, eating buffs, hunger, cooking scores, costs or rewards. No caught fish are consumed. BBQ state has no access to fishing rewards or populations.
- The local hand must be free of the Guide or radio. Menu/focus/tracking loss returns held props; a fresh grip is needed afterward. Moving more than six metres away, travelling, or disconnecting returns utensils. Players can keep fishing while others cook.
- No new shadow-casting lights are used. The existing scene HDR bake is unchanged. BBQ props have no dynamic shadows. Sparse smoke and bounded props limit rendering/network load.

## Multiplayer

Prototype clients and servers use **protocol 4**. The host validates membership, location, reach, state, finite coordinates, command shape and a bounded request rate. It owns utensil claims, food heat, serving, consumption and cleanup. Reliable snapshots at four per second go to peers at the matching location; controller/hand transforms reuse the existing avatar replication. Late arrivals receive the current kit and cooking state. A dedicated server runs the model without loading foregrounds or prop meshes. A departing initiator does not end the BBQ while others remain. Ad-hoc host migration retains the existing game's limitation: loss of the host ends that network session.

## Assets and rebuild

`tools/build_bbq.py` authored six reusable GLBs via Blender MCP and the Poly Haven asset integration. `source/bbq.blend` retains the editable kit. The grill is about 6.1k triangles in seven material groups; the entire active food/tool kit stays bounded. Texture aliases use the existing release export deduplication. See [asset provenance](bbq_assets.json) and [credits](../ASSET_CREDITS.md).

Build a local Linux/PC-VR package with `python3 tools/build_bbq_prototype.py`. It exports into `builds/BBQ-Prototype/` and leaves public release packages separate.

## Validation

`python3 tools/test_vr_fixes.py` includes the model, tracked-controller controls, visit/return and all-location support suites alongside the fishing regressions. `python3 tools/test_bbq_network.py` runs real ENet dedicated and ad-hoc sessions, a second cook and a late joiner, including ownership contention, cooking, serving, consumption, menu independence and cleanup. Vulkan scene captures are in `test-results/bbq-*.png`; `bbq-sites.json` records support heights.

Standalone Quest/Pico performance and physical multiplayer cooking remain hardware acceptance checks. The prototype uses the same scene/interaction code for desktop and OpenXR.
