# Water/golf ambience and Cedar Creek deadwood — 24 September 2026

Returning from golf left the water ambience node's internal processing disabled,
so its newly started bed stayed at -80 dB. Location selection now restores the
processor and timber detail, including interrupted same-water playback. Stopping
releases player nodes; golf's restore loop checks freed references before casting
them to Node. User mute and volume remain authoritative.

All twelve waters retain their own existing lake, river or coastal bed. Golf uses
two new park-recording mixes: woodland for Spyglass/Poppy and links for
Pebble/Cypress. Gain/mute applies before playback begins. The shared selector's
actual trigger is disabled for enrolled rounds; the former OptionButton property
aborted resumed-course activation before its ambience was created.

Cedar's three flat-colored log prototypes are replaced with the established shore
deadwood mesh, wood texture, fibre normal detail and vertex AO. Each rigid trunk
aligns to the bank plane and settles against its actual lower geometry with 3.5 cm
of soil overlap at its supports. Curved/tapered ends need not touch the ground.

Validation:
- `tests/ambience_lifecycle.gd`: actual timed processing over three suspend/resume
  cycles, mute preservation, interrupted playback, all twelve waters, separate golf beds.
- `tests/golf_social.gd`: 41 checks, including an audible fishing return and resumed
  enrolled-course ambience. `tests/shark_ambience_menu.gd`: all checks pass.
- `tests/cedar_deadwood.gd`: 121 checks; independent physical-bank rays confirm
  multiple supports per log. Sample clearance spans -3.5 cm to +13.4 cm at curved ends.
- `tests/fly_expansion.gd`: 37 checks pass across Cedar Creek and Glacier Run.
- Both new Oggs decode to exactly 128 seconds without clipping. RMS is -38.45 dBFS
  (links), -41.09 dBFS (woodland); they remain deliberately quiet background layers.
- Before/after desktop renders of all three sites were inspected in
  `test-results/cedar-fix/`; audio and transition logs are in
  `test-results/ambience-fix/`. No headset test or new release was launched.
- Godot reports shutdown ObjectDB warnings; the standalone lifecycle fixture also
  reports retained script resources on exit. No runtime script errors occurred
  in the final hosted transition or scenery regressions.

Rebuild the golf tracks with `python3 tools/build_golf_ambience.py`, then import in
Godot. The release asset audit now requires both golf recordings.
