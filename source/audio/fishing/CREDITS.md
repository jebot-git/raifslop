# Recorded fishing foley

Downloaded 14 September 2026 from the public high-quality MP3 previews. Original downloaded preview bytes are retained here. These replace the procedural cast/splash/landing synthesis.

| Source file | Recording / creator | License | Public source / preview |
| --- | --- | --- | --- |
| `fly_rod_cast.mp3` | **Fly Rod Casting.wav**, paulprit | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | [Freesound 529665](https://freesound.org/people/paulprit/sounds/529665/), [HQ preview](https://cdn.freesound.org/previews/529/529665_8682843-hq.mp3) |
| `river_plop.mp3` | **Rock In Water Splash-Plop 1.aif**, jc144940 | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | [Freesound 178735](https://freesound.org/people/jc144940/sounds/178735/), [HQ preview](https://cdn.freesound.org/previews/178/178735_2596329-hq.mp3) |
| `trout_splashes.mp3` | **Trout splashing after being caught**, TheFlyFishingFilmmaker | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | [Freesound 592784](https://freesound.org/people/TheFlyFishingFilmmaker/sounds/592784/), [HQ preview](https://cdn.freesound.org/previews/592/592784_6501596-hq.mp3) |

The trout recording is described by its author as a roughly 14-inch trout being reeled in. The river recording captures a rock entering calm water. The rod excerpt excludes the prominent end-of-line stop/clack near the end of the recording.

Changes: selected short excerpts, mono downmix at 44.1 kHz, 120 Hz high-pass and 4–4.3 kHz low-pass filtering, mild transient compression, 25 ms onset and 150 ms tail fades, conservative peak level matching. The resulting `splash.wav`, `splash_2.wav`, `splash_3.wav` and `land.wav` are adaptations of the trout recording under CC BY 4.0; retain its title, creator, source, license and this modification notice with distributed builds. `cast.wav` and `impact.wav` derive from the CC0 recordings. No endorsement is implied.

Exact excerpt times, output levels and SHA-256 hashes: [fishing_audio_assets.json](../../../docs/fishing_audio_assets.json). Reproduce with `python3 tools/build_fishing_audio.py` (requires ffmpeg). `reel.wav` retains its prior authored CC0 synthesis.
