"""Original seeded river noise beds, matching the existing river audio pipeline."""
import subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
for ident,amp,seed,high,low in [('cedar_creek',.12,1223,160,5300),('glacier_run',.24,1447,70,7200)]:
 subprocess.run(['ffmpeg','-v','error','-y','-f','lavfi','-i',f'anoisesrc=color=pink:amplitude={amp}:sample_rate=24000:duration=30:seed={seed}','-af',f'highpass=f={high},lowpass=f={low},afade=t=in:d=0.1,afade=t=out:st=29.9:d=0.1','-c:a','libvorbis','-q:a','4',str(root/'assets/audio/ambience'/f'{ident}.ogg')],check=True)
