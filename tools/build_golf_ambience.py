"""Build course-only park/trees beds from the retained CC0 park recording.

No lake, river or surf recording is mixed into these tracks. Requires FFmpeg.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile
import wave

from build_ambience import loop

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio/ambience'


def main():
    with tempfile.TemporaryDirectory(prefix='golf-ambience-') as folder:
        bed = Path(folder) / 'park.wav'
        loop(ROOT / 'source/audio/park_birds.flac', bed)
        with wave.open(str(bed)) as source:
            loop_frames = source.getnframes()
        # Woodland: closer birds and leaves. Links: open-air low rustle with
        # fewer, more distant high-frequency bird calls. Offset a seamless
        # 32-second source loop; render four full periods for clean boundaries.
        for name, offset, low, high, gain in [
            ('golf_woodland', 9, 350, 6500, .32),
            ('golf_links', 23, 90, 2200, .38),
        ]:
            subprocess.run([
                'ffmpeg', '-v', 'error', '-y',
                '-i', str(bed), '-af',
                f'aloop=loop=-1:size={loop_frames},atrim=start={offset}:duration=128,'
                f'asetpts=N/SR/TB,highpass=f={low},lowpass=f={high},volume={gain},alimiter=limit=0.75:level=false',
                '-t', '128', '-ar', '44100', '-ac', '2', '-c:a', 'libvorbis', '-q:a', '4',
                str(OUT / (name + '.ogg')),
            ], check=True)
    records = [
        {'file': str(p.relative_to(ROOT)), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest(),
         'bytes': p.stat().st_size}
        for p in sorted(OUT.glob('*.ogg'))
    ]
    (ROOT / 'docs/ambience_assets.json').write_text(json.dumps(records, indent=2) + '\n')


if __name__ == '__main__':
    main()
