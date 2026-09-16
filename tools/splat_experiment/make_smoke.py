"""A deterministic colored wall/floor fixture, NOT an AI-generated environment."""
import json
import math
from pathlib import Path
import struct

out = Path(__file__).resolve().parents[2] / 'test-results/splat-experiment/viewer'
rows = []
for iy in range(70):
    for ix in range(100):
        x, y = (ix-50)*0.06, (iy-35)*0.06
        color = (0.25 + ix/180, 0.3 + iy/140, 0.45)
        rows.append([x, y, -4, *[(c-0.5)/0.28209479177387814 for c in color],
                     4.0, math.log(0.045), math.log(0.045), math.log(0.01), 1,0,0,0])
props = ['x','y','z','f_dc_0','f_dc_1','f_dc_2','opacity','scale_0','scale_1','scale_2','rot_0','rot_1','rot_2','rot_3']
header = ['ply','format binary_little_endian 1.0',f'element vertex {len(rows)}']
header += ['property float '+p for p in props] + ['end_header','']
with (out/'smoke.ply').open('wb') as stream:
    stream.write('\n'.join(header).encode())
    for row in rows: stream.write(struct.pack('<14f',*row))
path = out/'placement.json'
data = json.loads(path.read_text()) if path.exists() else {}
data['smoke.ply'] = {'center':[sum(r[j] for r in rows)/len(rows) for j in range(3)]}
path.write_text(json.dumps(data,indent=2)+'\n')
print('Created synthetic 7000-splat renderer fixture')
