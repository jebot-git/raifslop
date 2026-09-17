# Release source cleanup — 14 September 2026

Removed obsolete 2K skies, the unused River Alcove reference download, duplicate
4K originals, legacy boulder/ground runtime assets, superseded unlit foreground
exports, procedural fish builders/scenes/skin textures, Blender backups, raw XR
test captures and documentation image import sidecars. The detailed file audit
is [cleanup_manifest.json](cleanup_manifest.json).

Moved rebuild-only fish and foreground textures into `source/textures/`, outside
Godot's importer. Current runtime GLBs and their extracted material textures stay
under `assets/models/`. Current editable source scenes, reference artwork,
recordings and attribution are retained. Older asset manifests and screenshots
remain historical provenance; their hashes do not describe the replacement
photographic fish or baked scenery. Dynamic catalogues and embedded GLB image
names were checked before removing assets.

The location manifest now selects baked foregrounds directly. The original
foreground builder writes intermediate unlit GLBs under `source/models/locations/`
and collision metadata under `assets/models/locations/manifest.json`; follow it
with the four lighting bakes to produce playable GLBs. The photographic fish
builder is the generator for the thirteen replacement species. The earlier
four-fish builder and packed original perch source remain available.

`tools/prepare_locations.py` creates previews from the current native 4K HDRs
without generating obsolete 2K copies. Three XR test scripts now write raw
EXRs to ignored `test-results/xr/`; reviewed PNG evidence remains in `docs/`.
`docs/.gdignore` prevents document images from entering Godot's import cache.

Public source and release archives exclude `.release-signing/`, player data,
build output and development caches. Third-party addon libraries and their
licenses are retained together. Current validation and build provenance are
recorded in [VALIDATION.md](VALIDATION.md) and the release build manifest.

## 0.1.7 release preparation — 16 September 2026

The authored Lake Pier additions share its existing GLB and bake atlases. Korean
lettering is retained as SVG outlines, avoiding a bundled CJK font and separate
runtime labels. Rebuild artwork and compact Blender lighting scenes remain under
`source/`; original 8K HDRs stay canonical. Review captures remain under `docs/`.

Exports include the measured lighting JSON and exclude source scenes, authoring
tools, tests, screenshots and caches. The release builder replaces each target's
old output directory, deduplicates final texture payloads, compresses desktop HDR
with BC6H, preserves Android HDR, and recompresses packages at level 9. Pack audits
check the new billboard, rear mesh shader and all six lighting profiles.

## 0.1.11 release preparation

Retained editable fish scenes, original generated references and normal-map outputs
under `source/`; these are excluded from imports and packages. Reviewed captures
are in `docs/validation/release-0.1.11/`, also excluded. Per-target output is rebuilt
from clean directories; packaging uses fresh staging and replaces stale release
artifacts. Quest/Pico APKs are prohibited by the publisher. No saves or private
signing files are deleted. The separate Linux server packages only its embedded
script binary, launcher and attribution. Runtime HDR compression and imported
texture deduplication remain enabled; ZIPs use level-9 deflate.
