# Shared waterside BBQ

Open **Menu → BBQ → Start BBQ & visit**. Everyone at that location shares one grill, six portions, two pairs of tongs and two cans. Starting again visits the same station. **Return to fishing spot** restores your position; cooking continues for the other players. Finish your cast before visiting.

The station uses the new grill, prep board, cooler, hinged lid, cans and animated spring tongs. Fish burgers have rounded brioche buns, layered filling, ruffled lettuce and sesame seeds. Burgers, sausages, corn and mushrooms replenish freely, without changing catches, bait or the journal.

## Controls

- **VR:** grip near a prop to take it; release grip to return it. With tongs, trigger near food to grill, flip, then serve. A/X moves grilling food to a cooler free grate position. Each side cooks separately and eventually chars.
- **Food:** take a serving and trigger near your mouth to eat. Other players can take food you serve or put down.
- **Cooler:** trigger near the lid to open or close it. Grip a can, trigger to open, then trigger near your mouth to sip. Cooler state is shared.
- **Desktop:** H visits; B visits or returns. Click a prop to take it, then click food while holding tongs to grill, flip or serve. Right-click returns the held prop. C toggles the cooler; F moves food to a cooler grate position. Middle-mouse drag looks around.
- **Camera:** the guide remains available during BBQ use. Opening it returns held BBQ props and gives its camera the controls; shared cooking continues.

World prompts use the same outlined mint pictograms as fishing and radio prompts. They show the relevant grip, tool, cooking, serving or drinking action, respect the guiding-icon setting, and are excluded from guide photos. There are no floating textual instructions or title signs.

## Multiplayer and assets

The host owns cooking, item claims, handoffs, consumption, cooler state and replenishment. Clients receive the current station on arrival or late join. Disconnects, travel and tracking loss return owned props; an unattended station packs away after three minutes. Protocol 11 requires matching clients and server.

`tools/build_bbq.py` and `tools/build_bbq_tongs.py` retain the station and tool sources in `source/bbq_quality.blend`. All four foods are authored through Blender MCP using `tools/build_bbq_food.py`, with editable procedural source and a review scene in `source/bbq_food.blend`. Run this script in Blender after rebuilding the station kit. It exports one material and at most 18,000 triangles per portion, with baked colour, normal and roughness textures (2K burger; 1K sausage, corn and mushroom). The cooking shader preserves these maps while applying browning and grill marks. Source textures are retained in `source/textures/bbq_food/`; the runtime GLBs embed them. Sounds come from `assets/audio/bbq/`.

## Verification

Run `python3 tools/test_vr_fixes.py bbq_model bbq_controllers bbq_food_art bbq_scene bbq_visit rod_holster menu_controls guide_camera network_guards` and `python3 tools/test_bbq_network.py`. These exercise ownership contention, two cooks, serving and eating, late joins on dedicated and player hosts, guide-camera access, synthetic controller interactions, replenishment, cleanup and supporting ground at all ten locations. Rendered inspection and synthetic input do not replace physical headset acceptance.
