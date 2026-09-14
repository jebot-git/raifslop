#!/usr/bin/env python3
"""Remove an empty duplicate Blink_L declaration; preserve geometry/textures."""
from pathlib import Path
import gzip,json,struct,hashlib
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'source/avatars/sharkperson_original.vrm.gz'
raw=gzip.decompress(source.read_bytes());length=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+length]);master=doc['extensions']['VRM']['blendShapeMaster'];groups=master['blendShapeGroups']
filled={g.get('presetName',g.get('name')) for g in groups if g.get('binds') or g.get('materialValues')}
master['blendShapeGroups']=[g for g in groups if g.get('binds') or g.get('materialValues') or g.get('presetName',g.get('name')) not in filled]
header=json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode();header+=b' '*((-len(header))%4)
payload=struct.pack('<II',len(header),0x4e4f534a)+header+raw[20+length:]
result=struct.pack('<III',0x46546c67,2,len(payload)+12)+payload
(ROOT/'assets/avatars/sharkperson.vrm').write_bytes(result)
p=ROOT/'docs/sharkperson_source.json';meta=json.loads(p.read_text());meta['bundled_sha256']=hashlib.sha256(result).hexdigest();meta['change']='Removed the final empty duplicate blink_l declaration, which masked the valid left blink. Geometry, textures, authored weights and license unchanged.';p.write_text(json.dumps(meta,indent=2)+'\n')
