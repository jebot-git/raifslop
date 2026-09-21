"""Deterministic original sound design; no third-party recordings."""
from pathlib import Path
import math, random, struct, wave
OUT=Path(__file__).resolve().parents[1]/'assets/audio/bbq'
OUT.mkdir(parents=True,exist_ok=True)
rng=random.Random(318)
rate=44100

def save(name,seconds,sample):
    with wave.open(str(OUT/name),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate)
        f.writeframes(b''.join(struct.pack('<h',int(max(-1,min(1,sample(i/rate)))*28000)) for i in range(int(rate*seconds))))

def opening(t):
    # Aluminium tab click, scored seal snap, then escaping carbonation.
    click=math.sin(2*math.pi*2600*t)*math.exp(-t*95)*.45
    snap=0 if t<.095 else (rng.uniform(-1,1)*.65+math.sin(t*19000)*.2)*math.exp(-(t-.095)*70)
    hiss=0 if t<.12 else rng.uniform(-1,1)*.28*math.exp(-(t-.12)*5)*(1-math.exp(-(t-.12)*90))
    return click+snap+hiss
save('can_open.wav',1.15,opening)
save('grill_sizzle.wav',3.0,lambda t: rng.uniform(-1,1)*(.15+.03*math.sin(t*91)) + (.18*math.sin(t*15000) if rng.random()<.004 else 0))
