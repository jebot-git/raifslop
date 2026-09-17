"""Verify shipped held/folded GLBs retain each tier's shared material palette."""
import json,struct
from pathlib import Path
from rod_styles import ROD_STYLES
ROOT=Path(__file__).resolve().parents[1]
checks=0
for style in ROD_STYLES:
 for rig in ['', '_fly','_feeder','_lure']:
  for folded in ['', '_folded']:
   path=ROOT/'assets/models/rods'/(style['name']+rig+folded+'.glb')
   data=path.read_bytes();doc=json.loads(data[20:20+struct.unpack_from('<I',data,12)[0]])
   materials=doc['materials']
   for field,label in [('blank','casting carbon' if rig=='_lure' else 'blank'),('trim','casting trim' if rig=='_lure' else 'wraps'),('reel','low profile reel' if rig=='_lure' else 'reel finish')]:
    material=next(m for m in materials if label in m['name'])
    actual=material['pbrMetallicRoughness']['baseColorFactor'][:3]
    assert all(abs(a-b)<1e-6 for a,b in zip(actual,style[field])),(path,field,actual)
    checks+=1
   grip=next(m for m in materials if ('Natural cork' if style['cork'] else 'Fine EVA grain' if rig=='_lure' else 'Matte EVA') in m['name'])
   if style['cork'] or rig=='_lure':
    assert 'baseColorTexture' in grip['pbrMetallicRoughness'],path
   checks+=1
print(f'ROD_STYLE_RESULT {checks} checks across 32 held/folded models')
