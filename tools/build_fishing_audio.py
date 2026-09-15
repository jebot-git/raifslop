#!/usr/bin/env python3
"""Prepare quiet recorded fishing foley; synthesize only the unchanged reel loop.
Requires ffmpeg. See source/audio/fishing/CREDITS.md for licenses and excerpts.
"""
import argparse,array,hashlib,json,math,random,struct,subprocess,wave
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/audio/fishing';OUT.mkdir(parents=True,exist_ok=True)
SOURCE=ROOT/'source/audio/fishing'
# Start/duration in the complete public HQ previews. Keep the fly-line stop/clack out.
CUTS={
 'cast':('fly_rod_cast',.28,.59,-23,4200),
 'impact':('river_plop',.48,.76,-25,4300),
 'splash':('trout_splashes',.12,.95,-25,4300),
 'splash_2':('trout_splashes',1.24,.60,-26,4300),
 'splash_3':('trout_splashes',2.53,.54,-26,4300),
 'land':('trout_splashes',3.10,.91,-24,4000),
 'ripple':('river_plop',.70,.70,-30,2200),
}
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--only',choices=list(CUTS),help='Rebuild one recorded effect')
args=parser.parse_args()
manifest_path=ROOT/'docs/fishing_audio_assets.json'
manifest=json.loads(manifest_path.read_text()) if args.only else []
if args.only: manifest=[entry for entry in manifest if entry['file']!=f'assets/audio/fishing/{args.only}.wav']
for name,(source,start,duration,peak_db,cutoff) in CUTS.items():
 if args.only and name!=args.only:continue
 filters=f'highpass=f=120,lowpass=f={cutoff},acompressor=threshold=0.045:ratio=2.5:attack=15:release=100:makeup=1,afade=t=in:d=0.025,afade=t=out:st={duration-.15}:d=0.15'
 raw=subprocess.run(['ffmpeg','-v','error','-ss',str(start),'-i',str(SOURCE/(source+'.mp3')),'-t',str(duration),'-af',filters,'-ar','44100','-ac','1','-f','f32le','-'],check=True,capture_output=True).stdout
 samples=array.array('f');samples.frombytes(raw)
 peak=max(abs(v) for v in samples);gain=min(10**(8/20),10**(peak_db/20)/max(peak,1e-8))
 pcm=b''.join(struct.pack('<h',round(max(-1,min(1,v*gain))*32767)) for v in samples)
 path=OUT/(name+'.wav')
 with wave.open(str(path),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(44100);w.writeframes(pcm)
 manifest.append({'file':str(path.relative_to(ROOT)),'source':str((SOURCE/(source+'.mp3')).relative_to(ROOT)),'start':start,'duration':duration,'peak_dbfs':round(20*math.log10(peak*gain),2),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
if args.only:
 manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
 raise SystemExit(0)
# Existing reel sound is deliberately unchanged by this pass.
rng=random.Random(705);data=bytearray();low=0.;sr=22050;duration=1.
for i in range(sr):
 t=i/sr;x=rng.uniform(-1,1);low=.87*low+.13*x;high=x-low
 u=t%(1/24);env=math.exp(-u*480)
 sample=(.15*env*(math.sin(2*math.pi*2300*u)+.35*high)+.014*low)*min(1,t/.006,(duration-t)/.012)
 data.extend(struct.pack('<h',round(max(-.95,min(.95,sample))*32767)))
with wave.open(str(OUT/'reel.wav'),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(sr);w.writeframes(data)
(ROOT/'docs/fishing_audio_assets.json').write_text(json.dumps(manifest,indent=2)+'\n')
