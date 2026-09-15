"""Blender: rebuild Lakeside/Gray Pier rope barriers, retaining other source scenes.
Run with --background --factory-startup -noaudio --python tools/rebuild_natural_barriers.py.
Then bake each location with tools/bake_foregrounds.py.
"""
import sys,json
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_foregrounds as fg
locations=['lakeside','gray_pier']
manifest=ROOT/'assets/models/locations/manifest.json'
records=json.loads(manifest.read_text())
for location in locations:
    scene=fg.build(location)
    original=[{k:v for k,v in proxy.items() if k!='enabled'} for proxy in records[location]['colliders']]
    assert original==fg.RECORDS[location]['colliders'], 'Movement boundaries changed: '+location
    fg.RECORDS[location]['colliders']=records[location]['colliders'] # Preserve disabled seat proxies.
    assert records[location]['spawn']==fg.RECORDS[location]['spawn'], 'Arrival changed: '+location
    rope=next(ob for ob in scene.objects if ob.name.endswith('_rope'))
    assert sum(v.co.z>.4 for v in rope.data.vertices)>200, 'Missing raised rope spans'
    print('PASS rope barrier, original collision and arrival:',location,flush=True)
library=ROOT/'source/foregrounds.blend'
with bpy.data.libraries.load(str(library)) as (src,dst):
    dst.scenes=[name for name in src.scenes if name.split('.')[0] not in ['Foreground_'+id for id in locations]]
# Keep retained source texture paths portable when saving the combined library.
for image in bpy.data.images:
    local=ROOT/'source/textures/foreground'/Path(image.filepath).name
    if local.is_file():image.filepath=str(local)
bpy.data.libraries.write(str(library),set(fg.SCENES+list(dst.scenes)),path_remap='RELATIVE',fake_user=True,compress=True)
records.update(fg.RECORDS)
manifest.write_text(json.dumps(records,indent=2)+'\n')
