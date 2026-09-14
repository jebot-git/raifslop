#!/usr/bin/env python3
"""Build loopable location beds from attributed CC0 excerpts; requires ffmpeg."""
from pathlib import Path
import subprocess, tempfile, wave, math, random, struct, json, hashlib
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/audio/ambience'
def run(args): subprocess.run(['ffmpeg','-v','error','-y',*map(str,args)],check=True)
def loop(source,dest):
    graph='[0:a]highpass=f=65,asplit=3[a][b][c];[a]atrim=start=4:end=32,asetpts=PTS-STARTPTS[mid];[b]atrim=start=32:end=36,asetpts=PTS-STARTPTS[tail];[c]atrim=start=0:end=4,asetpts=PTS-STARTPTS[head];[tail][head]acrossfade=d=4:c1=tri:c2=tri[seam];[mid][seam]concat=n=2:v=0:a=1,loudnorm=I=-26:TP=-6:LRA=10[out]'
    run(['-i',source,'-filter_complex',graph,'-map','[out]','-ar','44100',dest])
def main():
    OUT.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='fishing-ambience-') as d:
        d=Path(d);loop(ROOT/'source/audio/water_birds.flac',d/'water.wav');loop(ROOT/'source/audio/park_birds.flac',d/'birds.wav')
        profiles={'lakeside':(0.85,0.36,0.06,6500,0),'lake_pier':(0.95,0.10,0.035,5200,7),'gray_pier':(0.48,0.55,0.045,3900,13),'bell_park_pier':(0.8,0.25,0.10,6000,21)}
        for name,(water,birds,wind,cutoff,offset) in profiles.items():
            graph=f'[0:a]volume={water},lowpass=f={cutoff}[water];[1:a]volume={birds},highpass=f=180[birds];anoisesrc=color=pink:sample_rate=44100:duration=128:seed=120,highpass=f=100,lowpass=f=850,volume={wind}[wind];[water][birds][wind]amix=inputs=3:normalize=0,alimiter=limit=0.75:level=false,afade=t=in:d=0.1,afade=t=out:st=127.9:d=0.1[out]'
            run(['-stream_loop','-1','-i',d/'water.wav','-stream_loop','-1','-ss',offset,'-i',d/'birds.wav','-filter_complex',graph,'-map','[out]','-t','128','-ar','44100','-ac','2','-c:a','libvorbis','-q:a','4',OUT/(name+'.ogg')])
        rng=random.Random(128);sr=22050;duration=5;raw=bytearray();noise=0.
        for i in range(sr*duration):
            t=i/sr;noise=.94*noise+.06*rng.uniform(-1,1)
            env=math.sin(math.pi*min(1,t/1.8))**2 if t<1.8 else .65*math.sin(math.pi*min(1,(t-2.2)/1.6))**2 if 2.2<t<3.8 else 0
            phase=2*math.pi*(125*t+18*t*t+2*math.sin(5*t))
            sample=env*(.08*math.sin(phase)+.025*math.sin(phase*2.9)+noise*.1)
            raw.extend(struct.pack('<h',round(max(-1,min(1,sample))*32767)))
        with wave.open(str(d/'timber.wav'),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(sr);w.writeframes(raw)
        run(['-i',d/'timber.wav','-c:a','libvorbis','-q:a','3',OUT/'timber.ogg'])
    entries=[]
    for p in sorted(OUT.glob('*.ogg')):entries.append({'file':str(p.relative_to(ROOT)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size})
    (ROOT/'docs/ambience_assets.json').write_text(json.dumps(entries,indent=2)+'\n')
if __name__=='__main__':main()
