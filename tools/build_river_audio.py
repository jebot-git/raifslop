"""Rebuild the original synthetic river beds (FFmpeg required)."""
import subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
for ident, amplitude in [('meadow_bend', '.14'), ('boulder_run', '.22')]:
    subprocess.run([
        'ffmpeg', '-v', 'error', '-y', '-f', 'lavfi', '-i',
        f'anoisesrc=color=pink:amplitude={amplitude}:sample_rate=24000:duration=30:seed=771',
        '-af', 'highpass=f=100,lowpass=f=6500,afade=t=in:d=0.1,afade=t=out:st=29.9:d=0.1',
        '-c:a', 'libvorbis', '-q:a', '4', str(ROOT / 'assets/audio/ambience' / f'{ident}.ogg')
    ], check=True)
