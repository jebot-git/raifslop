# Ambience source excerpts

- `water_birds.flac`: TimBahrij, **ambient water and birds**, Freesound #234917, CC0 1.0. https://freesound.org/people/TimBahrij/sounds/234917/ . Excerpt 1–37 seconds of the public 192 kb/s preview at https://cdn.freesound.org/previews/234/234917_3463736-hq.mp3 . The first portion avoids the stronger wind interference described by the author. Resampled to stereo 44.1 kHz FLAC.
- `park_birds.flac`: Thimras, **Park ambiences / park_ambience_birds.wav**, OpenGameArt, CC0 1.0. https://opengameart.org/content/park-ambiences . Original https://opengameart.org/sites/default/files/park_ambience_birds.wav . Excerpt 20–66 seconds, resampled to stereo 44.1 kHz FLAC. The author identifies the recording as a public park in Adelaide, South Australia.

License: https://creativecommons.org/publicdomain/zero/1.0/

These are curated background recordings, not recordings of the photographed game locations. `tools/build_ambience.py` joins overlapping sections, filters and mixes the two recordings into quiet 128-second Ogg Vorbis beds. Lakeside emphasizes park birds; Lake Pier emphasizes low, muffled recorded water; Gray Pier uses only the airy high-frequency park recording; Bell Park mixes recorded water with sparse distant birds. There are no synthesized wave/wind layers in the final mix. The occasional timber detail is synthesized by the script and dedicated to CC0 1.0. There is no music or intelligible voice intentionally included.
