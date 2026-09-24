# Fly waters and menu navigation

Two fictional waters extend the existing fly system:

| Water | Character | Fish |
|---|---|---|
| Cedar Creek | Forest HDR, crossed-card cedar grove, fallen timber, gentle current and gravel margins | Cutthroat trout, rainbow trout, brook trout |
| Glacier Run | Alpine HDR, snow blended into banks, textured river-granite rocks, faster current and sheltered boulder pockets | Arctic char, brown trout, grayling |

Cutthroat trout and Arctic char are appended at species IDs 40 and 41, preserving old save/journal indices. Both have textured volumetric GLBs, authored fins and eyes, fight profiles, journal descriptions, dry-fly/nymph preferences and lure eligibility. Every new water has ambience, a preview, dry-ground collision and a picnic spawn.

Waters opens a category page: Lakes & reservoirs, Rivers & streams, Coasts & estuaries. Each category opens its filtered list and a visible Water types back button. Fish here emits the selected water's stable ID, rather than the filtered row's catalog position. Travel remains disabled during a cast.

All scrollable menus now share drag ownership and joystick routing, including avatar/import lists, multiplayer, golf pages, the clubhouse roster and in-canvas selectors. Either stick can scroll. The open selector takes priority, followed by the list under the pointer, then the active page. Scrollbars show position but ignore pointer input and focus. A deliberate drag beginning over an action or toggle scrolls without activating it; sliders/text fields keep their normal input. Small trigger jitter still permits selection. Fractional stick movement accumulates instead of being rounded away.

Assets were created/procured using Blender MCP, Krita MCP, Poly Haven capabilities and builtin imagegen. Full image-generation prompts and mode are in `source/fish_references/fly_expansion/prompts.json` and `source/vegetation/fly_expansion/prompt.json`; source credits, download links and hashes are in `ASSET_CREDITS.md` and `source/locations/fly_expansion_sources.json`. Fish habitat references: [USFWS cutthroat trout](https://www.fws.gov/species/cutthroat-trout-oncorhynchus-clarkii) and [Alaska ADFG Arctic char](https://www.adfg.alaska.gov/index.cfm?adfg=arcticchar.printerfriendly). These waters are gameplay settings, not surveyed habitats.

Validation:

- Fish model/journal integration: 291 checks, no failures.
- Location/species/bait reachability: 280 checks, no failures. The fly reachability assertion uses the fly pool; Meadow Bend also has species specific to other fishing methods.
- Location traversal: 1,268 checks, no failures; includes HDR sizes and physical ground. Audio import errors discovered during the first traversal were fixed with new ambience assets.
- Fly expansion integration: 37 checks, no failures; both waters, real casting, current pockets, categories and stable selection IDs.
- Shared scroll consistency: 11 checks, no failures; button/toggle drag, inert bars, popup priority, selection jitter, fractional motion and both stick axes.
- Existing menu controls, fly fishing and golf attachment regression suites pass. The GPU clubhouse test also passes its synthetic tracked-pointer selection check.
- Mipmap audit checks actual imported mip chains as well as settings: 485 texture imports and 115 models, no failures. Fifteen icon/menu-preview exceptions are intentionally UI-only. Cached test-avatar imports also receive the existing mipmap post-import script; runtime avatar loading already requests mip generation.
- Cardboard trees use the same alpha-tested, mipmapped, crossed planes as existing rivers; no camera-facing rotation is applied per eye. Glacial rocks share the established river boulder UVs and shading.
- Godot GPU captures: `docs/fly_expansion/`. A live OpenXR check could not initialize the local runtime (XR error -51); physical-headset verification remains outstanding.

Rebuild original fish with `tools/build_fly_expansion_fish.py` in Blender, the retained prototype scenery with `tools/build_fly_expansion_props.py` (live Cedar logs now share `tools/build_shore_dressing.py` geometry and materials), and ambience with `python3 tools/build_fly_expansion_audio.py`. Reimport in Godot afterwards.
