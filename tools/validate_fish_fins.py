"""Blender audit of repaired runtime fin roots, dorsal silhouettes and bounds.
Run: blender --background --python tools/validate_fish_fins.py
"""
import bpy, bmesh, json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
names=['roach','tench',*json.loads((ROOT/'source/fish_references/anatomy.json').read_text())]
names += list(json.loads((ROOT/'source/fish_references/marine/anatomy.json').read_text()))
names += list(json.loads((ROOT/'source/fish_references/predators/anatomy.json').read_text()))
names += list(json.loads((ROOT/'source/fish_references/marine_expansion/anatomy.json').read_text()))
report={}
for name in names:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/fish'/(name+'.glb')))
    obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
    bm=bmesh.new();bm.from_mesh(obj.data)
    weld=list(bm.verts)
    if name not in ['roach','tench']:
        weld=list({v for f in bm.faces if 'fin membranes' in obj.data.materials[f.material_index].name for v in f.verts})
    bmesh.ops.remove_doubles(bm,verts=weld,dist=1e-6)
    unseen=set(bm.verts);parts=[]
    while unseen:
        todo=[unseen.pop()];group=[]
        while todo:
            v=todo.pop();group.append(v)
            for edge in v.link_edges:
                other=edge.other_vert(v)
                if other in unseen:unseen.remove(other);todo.append(other)
        lo=Vector(tuple(min(v.co[k] for v in group) for k in range(3)))
        hi=Vector(tuple(max(v.co[k] for v in group) for k in range(3)))
        parts.append((group,lo,hi))
    body,lo,hi=max(parts,key=lambda p:(p[2]-p[1]).x*(p[2]-p[1]).y*(p[2]-p[1]).z)
    indices={v:i for i,v in enumerate(body)}
    faces=[f for f in bm.faces if f.verts[0] in indices]
    tree=BVHTree.FromPolygons([v.co for v in body],[[indices[v] for v in f.verts] for f in faces])
    gaps=[];dorsal=False
    for group,part_lo,part_hi in parts:
        if group is body:continue
        faces=set(f for v in group for f in v.link_faces)
        if name not in ['roach','tench']:
            if not all('fin membranes' in obj.data.materials[f.material_index].name for f in faces):continue
        elif len(group)==27:continue # Retained tench sensory barbels.
        gaps.append(min(tree.find_nearest(v.co)[3] for v in group))
        dorsal=dorsal or part_hi.z>hi.z+.015
    overall=Vector(tuple(max(v.co[k] for v in bm.verts)-min(v.co[k] for v in bm.verts) for k in range(3)))
    assert .95<overall.x<1.05 and overall.y<overall.x and overall.z<overall.x,(name,overall)
    assert gaps and max(gaps)<.002,(name,'unattached fin',gaps)
    assert dorsal,(name,'missing dorsal silhouette')
    report[name]={'fin_components':len(gaps),'maximum_root_gap_m':max(gaps),'bounds_m':list(overall),'dorsal_present':dorsal}
    bm.free()
path=ROOT/'test-results/fish-fins';path.mkdir(parents=True,exist_ok=True)
(path/'audit.json').write_text(json.dumps(report,indent=2)+'\n')
print('FISH_FINS_RESULT',len(report),'species passed',flush=True)
