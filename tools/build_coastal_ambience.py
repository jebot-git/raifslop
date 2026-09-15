#!/usr/bin/env python3
"""Assemble quiet coastal beds from two CC0 recorded surf excerpts (ffmpeg, numpy).
Run with Blender --background --python tools/build_coastal_ambience.py, or Python + NumPy."""
from pathlib import Path
import hashlib, json, random, subprocess
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
SR=44100
def build():
    waves=[]
    for index in ['01','04']:
        raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(ROOT/f'source/audio/coastal_wave_{index}.flac'),
            '-af','highpass=f=85,lowpass=f=5500','-ar',str(SR),'-ac','2','-f','f32le','-'])
        samples=np.frombuffer(raw,dtype='<f4').copy().reshape(-1,2)
        fade=min(int(SR*.3),len(samples)//2)
        samples[:fade]*=np.linspace(0,1,fade)[:,None]
        samples[-fade:]*=np.linspace(1,0,fade)[:,None]
        waves.append(samples)
    for name,seed,gain,spacing in [('simons_town_rocks',741,.035,(2.3,4.2)),('blouberg_sunrise_2',931,.045,(3.5,5.5))]:
        rng=random.Random(seed);out=np.zeros((SR*128,2),dtype=np.float32)
        # Wrap each recorded wave through the buffer boundary for a continuous loop.
        cursor=0.0
        while cursor<128:
            clip=waves[rng.randrange(len(waves))]*rng.uniform(.65,1)
            positions=(np.arange(len(clip))+int(cursor*SR))%len(out)
            out[positions]+=clip
            cursor+=rng.uniform(*spacing)
        out*=gain/max(.001,float(np.max(np.abs(out))))
        path=ROOT/f'assets/audio/ambience/{name}.ogg'
        subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(SR),'-ac','2','-i','-',
            '-c:a','libvorbis','-q:a','4',str(path)],input=out.astype('<f4').tobytes(),check=True)
    records=[{'file':str(p.relative_to(ROOT)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
             for p in sorted((ROOT/'assets/audio/ambience').glob('*.ogg'))]
    (ROOT/'docs/ambience_assets.json').write_text(json.dumps(records,indent=2)+'\n')
if __name__=='__main__':build()
