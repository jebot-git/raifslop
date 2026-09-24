# Ultimate Boomer Simulator — store media

Open [index.html](index.html) to review the images, lettering and trailer, or
open the updated [listing preview](../index.html). Created 24 September 2026
from the `stores` checkout, game version 0.1.15, base commit `71d768e`.

## Deliverables

| Files | Purpose / specification |
| --- | --- |
| `screenshot-01` through `screenshot-06` | Six unbranded in-game vistas, 2560 × 1440, 24-bit RGB PNG |
| `promo-tackle.png` | Production Willow spinning, Heron fly and Kingfisher lure tackle; blurred harbour backdrop; 2560 × 1440 RGB PNG |
| `promo-clubs.png` | Production driver, 7-iron and putter with matching tackle finishes; blurred harbour backdrop; 2560 × 1440 RGB PNG |
| `trailer.mp4` | 36 seconds, 1920 × 1080, 30 fps, H.264 / AAC, web fast-start |
| `trailer-cover.png` | Harbour vista, 2560 × 1440, RGB PNG |
| `trailer-title.png` | 1920 × 1080 opening/closing card using the full listing name |
| `logo-mark.svg`, `logo-mark.png` | Existing game icon; SVG copied unchanged, PNG preserves transparency |
| `logo-lockup.png`, `logo-ubs.png` | Transparent short-title / UBS lettering with the unchanged icon |
| `logo.png` | Full-title transparent submission logo, 1800 × 700 RGBA PNG |
| `hero.png`, `cover-landscape.png`, `cover-square.png`, `cover-portrait.png`, `mini-landscape.png` | 3000 × 900, 2560 × 1440, 1440 × 1440, 1008 × 1440, 1080 × 360 RGB PNG; consistent full-title art |
| `icon.png` | 512 × 512 opaque store icon; existing teal fills only the transparent outer corners |
| `lettering-specimen.png`, `fonts/` | Almonte and Blue Highway Regular; original OTFs and author-issued CC0 licence |
| `manifest.json`, `trailer-probe.json` | Asset sizes, hashes, capture provenance and encoded-media checks |

## Capture provenance

All environment imagery comes from the running game's production scene and
location-loading functions, including its animated water and wildlife. These
are desktop Godot 4.7.2 editorial-camera captures using the Mobile renderer,
with a debug XR fixture and an isolated save directory. They are not footage
recorded on a Quest headset and do not establish headset performance or visual
parity. No external players, network session or live microphone recording was
used. Camera motion is a slow yaw from −14° to +14° at a fixed standing viewpoint.

The trailer is a conventional 16:9 video of panoramic camera moves, not a 360°
equirectangular video. Its 900 environmental frames were rendered from the game
at fixed 30 fps, without frame interpolation. The five six-second shots are
Harbour/Lake Pier, Gray Pier, Cedar Creek, Glacier Run and Blouberg, preceded by
a two-second title and followed by a four-second closing card. Natural ambience
uses the corresponding game audio beds with fades and a final −20 LUFS
normalization target (−2 dB true-peak ceiling). Source credits:
[ambience](../../../source/audio/CREDITS.md) and
[game assets](../../../ASSET_CREDITS.md). No stock video, generated replacement
scenery, external music or gameplay-action claims were added.

The two equipment images are **staged promotional renders**, not normal player
POV screenshots. They use the game's existing meshes, materials, tackle palettes
and physical golf heads, with editorial placement, Forward+ depth of field,
4× MSAA and two soft fill lights affecting only equipment. Backgrounds remain
the game harbour. Geometry and game materials were not redesigned. Keep these
as promotional/detail artwork; use the unbranded vistas for screenshot slots.

The title-font licence and original source are recorded in [fonts/README.md](fonts/README.md).
The requested short title and UBS are lettering variants; the full store title
remains Ultimate Boomer Simulator. No font is installed globally.

## Reproduce

Use the Godot 4.7.2 editor binary with an imported project and a Vulkan-capable
display. Set `GODOT_BIN` to its path. Set `XDG_DATA_HOME`, `XDG_CONFIG_HOME` and
`XDG_CACHE_HOME` to dedicated temporary capture directories so user saves and
editor preferences are not touched. Run commands from the repository root.

```sh
"$GODOT_BIN" --path . --xr-mode off --rendering-method mobile --rendering-driver vulkan --display-driver x11 --script tools/capture_store_media.gd -- --xr-test --mode stills --output res://docs/quest-store/media
"$GODOT_BIN" --path . --xr-mode off --rendering-method forward_plus --rendering-driver vulkan --display-driver x11 --script tools/capture_store_media.gd -- --xr-test --mode equipment --output res://docs/quest-store/media
"$GODOT_BIN" --path . --xr-mode off --rendering-method gl_compatibility --display-driver x11 --script tools/render_store_branding.gd
"$GODOT_BIN" --path . --xr-mode off --rendering-method mobile --rendering-driver vulkan --display-driver x11 --fixed-fps 30 --script tools/capture_store_media.gd -- --xr-test --mode video --output /tmp/ubs-trailer-frames
python3 tools/build_store_trailer.py --frames /tmp/ubs-trailer-frames
python3 docs/quest-store/render.py
```

`--mode survey` renders smaller location-selection views; `--shot lake_pier`
can restrict a video capture to one of the five scenes. Raw frame sequences and
intermediate encoded clips stay outside the distributable asset directory.
The `.gdignore` prevents these marketing assets from entering game imports.

## Store handoff

The screenshot dimensions and trailer format follow
[Meta's asset guidelines](https://developers.meta.com/horizon/resources/asset-guidelines/),
checked 24 September 2026. Choose five distinct vistas from the six exports.
Screenshots contain no marketing text or logos. Review the rendered images
against the Quest build before submission; the effects in the staged equipment
shots are intentionally editorial. This package does not claim to complete
headset gameplay captures or store submission. All five cover formats are included.

The official safe-area PSD links redirected to a Facebook login and could not
be inspected. Cover compositions reserve generous margins (design bounds within
the central 74% of each dimension); check the official overlays in Dashboard
before submission. This is not a claim of verified template-safe placement.
