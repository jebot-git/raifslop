# Fishing sound, wakes and tension

Implemented 14 September 2026.

- Accepted casts play a positional swish at the rod tip. Rejected casts do not make a sound.
- Actual crank input during a fight drives a looping ratchet at the reel, with pitch following crank speed. Stopping, opening menus, viewing the Guide or losing VR tracking stops the loop.
- Float entry, hook set and fighting create positional splashes. Landing produces one separate, longer splash at the last surface position and an expanding ring; inspecting a held catch never repeats it.
- A lightweight 8 m shader plane shows expanding crests and a diverging wake. The float moves toward the escape direction. A left counter means a rightward escape, a right counter means leftward escape, and a lift counters an outward escape. Left/right directions use the same player-origin basis as the VR gesture detector, including after turning. Existing HUD counter prompts remain.
- Line color now transitions from blue at low tension through pale neutral to red at high tension. Line sag also decreases with tension.

Cast, float impact, fight splashes and landing now use real recordings. A gentle fly-rod excerpt excludes the line-stop clack; a river plop marks float entry; three small-trout excerpts alternate during fights, and a separate short splash marks landing. [Recording credits and licenses](../source/audio/fishing/CREDITS.md). The reel synthesis is unchanged. Rebuild with `python3 tools/build_fishing_audio.py` (ffmpeg required).

The electronic landing-success tone is removed. Recordings are softly filtered and faded, with peaks capped between −23 and −26 dBFS and no more than 8 dB of source boost. Cast and splash players cap close-range gain at −8 dB; water effects use a 2 m attenuation reference instead of 5 m. Fight clips avoid immediate repetition, use only ±2% pitch variation, and recur at irregular 1–1.5 second intervals during a run or 2–2.8 seconds while calm. Directional cues still trigger feedback. Three splash players and one wake mesh remain the fixed resource budget. Dedicated servers do not instantiate effects. These are local-angler sounds; no new effect RPCs are introduced.


## Comparison with Real VR Fishing

The project already had a simplified tension mechanic in `scripts/fishing_session.gd`; this change does not replace its balance or claim to reproduce proprietary game code.

| Existing mechanic | Project behavior |
| --- | --- |
| Reeling | Adds tension, particularly during a run |
| Easing off | Relieves tension; prolonged slack can lose the hook |
| Excess tension | At or above 0.98 for more than 1.4 seconds, the line snaps |
| Slack | At or below 0.02 for more than 1.4 seconds, the hook slips |
| Correct directional counter | Sustained input drains resistance over `2 + power × 0.6` seconds; proportionally relieves 0.16 tension and 0.19 stamina, adjusted for rod/species |
| Missed counter | Adds 0.18 tension |
| Fish runs | Periodic 3.5-second runs within a 9-second cycle, modulated by remaining stamina and species power |

Real VR Fishing's [official difficulty documentation](https://devsunitedgameshelp.zendesk.com/hc/en-us/articles/6127412904207-Difficulty-Levels) confirms guided fights on Normal and fewer/no guides on higher difficulties. Its public help pages do not specify numerical tension formulas. [Community descriptions of line colors](https://www.reddit.com/r/RealVRFishing/comments/1cqm9kl) describe blue slack, neutral white and red excessive tension; [player advice](https://www.reddit.com/r/RealVRFishing/comments/1vvq2dx/new_to_the_game_and_looking_for_advice_from_the/) describes stopping reeling during a rage/run and using counters to relieve tension. These reports support broad behavioral similarity, not an exact verified reproduction. Difficulty-specific rules, rod/reel drag settings and the original game's exact rage/counter logic are not reproduced here.

## Checks

- `tests/fishing_feedback.gd`: 26 checks covering recorded float entry, close-range gain caps, non-repeating fight clips, event timing, reel speed/stop/pause, turned-player counter/wake directions, line colors, landing position/one-shot behavior, bounded sound pool, both line failure paths, runs and counter relief.
- Existing fishing simulation: 118 checks passed.
- Native Monado simulated OpenXR casting/catch regression: 49 checks passed. The existing runtime shutdown/spatial-signal/profile-RID diagnostics remain; this is not physical-headset validation.
- Desktop Vulkan render captured in [fishing_wake.png](fishing_wake.png); no shader errors. `tests/fishing_feedback_render.gd` reproduces it.

See the [tester feedback update](TESTER_FEEDBACK.md) for the sustained resistance mechanic, line haptics, guide status and current live validation.
