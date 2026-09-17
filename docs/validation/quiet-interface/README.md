# Quiet interface validation

All 16 pictograms were checked for transparent margins, antialiasing, 128px texture imports and mipmaps, and rendered in both simulated OpenXR eyes. The pictogram suite passed 93 checks including all rod notices, fight-state mappings, the Controls toggle, saved preference reload and preservation of bait text. Radio tests additionally verify that hiding its symbol does not interrupt transmission and that re-enabling restores it.

- [All pictograms, left eye](pictograms_eye0.png)
- [All pictograms, right eye](pictograms_eye1.png)
- [Rod notice](rod-symbol_eye1.png)
- [Server leaderboard](leaderboard_eye0.png)

Names beneath symbols appear only on the diagnostic sheet. Gameplay uses symbols alone. The quiet-interface suite passed 22 checks, including menu/guide visibility and both-eye captures. These captures use simulated Monado OpenXR; physical headset comfort and performance remain unmeasured. Monado teardown reports the existing session-stop / interaction-profile cleanup warnings after successful captures.
