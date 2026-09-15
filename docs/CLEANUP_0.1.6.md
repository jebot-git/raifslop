# Release cleanup — 0.1.6

Godot model dependency inspection found six candidate texture files. River code dynamically uses Gray Pier's gravel diffuse and normal maps, so those remain. The three unused Lakeside gravel maps and unused Gray Pier gravel roughness map, plus their import sidecars, were removed. Editable source maps remain under `source/textures/foreground/`.

Folded rod generation now removes accessors and buffer views belonging to the original unfolded mesh after producing folded sections. Referenced vertex, normal, UV and image payloads are copied unchanged. This removes about 4.1 MB from the eight authored folded GLBs; Godot's runtime geometry is unchanged.

Selected model texture imports use high-quality GPU compression (BC7/BPTC on desktop, ASTC on Android) with original dimensions and mipmaps. Textures whose compressed download would grow on either platform retain their existing lossless import. VRM files remain intact. Existing export-time hashing deduplicates identical final texture payloads while respecting target formats. Native 8K panorama data and the existing desktop BC6H / Android RGBE formats are preserved.

A lossless compressed ImageTexture alternative for Android HDR was measured and rejected: two representative 8K textures occupied 125.8/137.6 MB compared with 116.6/124.9 MB using the current level-9 APK deflate path. Replacing the established path would have increased downloads.

Release targets build into fresh directories, and packaging uses temporary staging. Runtime pack audits reject orphan texture payloads, dangling remaps, missing dynamically loaded models, documentation, tests, tools, editor configuration, player data and signing files. Credits and third-party notices remain packaged.
