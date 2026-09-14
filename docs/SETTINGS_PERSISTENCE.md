# Settings persistence audit — 14 September 2026

Menu quit, gameplay Escape and window-close now use the same save-and-shutdown path. Menu Escape still closes the menu, and Guide Escape still docks the Guide. Settings also save when changed through their controls. Write failures are reported in the runtime log.

| Choice | Store |
|---|---|
| Smooth turning, selected bait | `user://player.cfg` |
| Avatar | `user://avatar.cfg` |
| Location | `user://location.cfg` |
| Earned shekels, owned/equipped rods | `user://tackle.json` |
| Catch history | `user://journal.json` |
| Ambience volume and mute | `user://sound.cfg` |
| Shadow mode | `user://graphics.cfg` |
| Body tracking, seated mode, expressions, tracked-leg animation; OSC preference | `user://tracking.cfg` |
| Voice mode, mute-all, input device, voice threshold | `user://voice.cfg` |
| Multiplayer name, host address and port | `user://multiplayer.cfg` |

The audit fixed missing turn-mode, bait and connection preference persistence, restored the turn checkbox from the saved motor setting, and unified normal exit paths. Existing preference stores remain compatible. Restoring connection fields does not join a server automatically.

Body calibration and recenter transforms depend on the current XR origin and tracker session, so they are recalibrated each session. Individual peer mutes use connection-local peer IDs and end with that connection. Open menu/guide pages, camera activation, rod stashing and an unfinished cast are transient interaction state. Tutorial instructions are menu-only, with no saved popup state.

`python3 tools/test_settings_persistence.py` starts six fresh processes with isolated temporary user data: write/exit and read/verify for menu quit, Escape and window-close. It checks restored control, bait, ambience, tracking, shadows, voice, multiplayer, avatar, location and tackle choices; no player saves are modified by this test. Existing journal tests cover catch history.
