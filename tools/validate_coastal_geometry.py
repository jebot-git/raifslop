"""Blender: check rock/barrier clearance and the beach's continuous sand geometry."""
import bpy,bmesh,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
with bpy.data.libraries.load(str(ROOT/'source/coastal_foregrounds.blend')) as (src,dst):
    dst.scenes=src.scenes
manifest=json.loads((ROOT/'assets/models/locations/manifest.json').read_text())
def audit_stone(mesh):
    bmesh.ops.remove_doubles(mesh,verts=list(mesh.verts),dist=.00001)
    remaining=set(mesh.verts);rocks=0
    while remaining:
        component={remaining.pop()};todo=list(component)
        while todo:
            for edge in todo.pop().link_edges:
                for vertex in edge.verts:
                    if vertex in remaining:
                        remaining.remove(vertex);component.add(vertex);todo.append(vertex)
        points=[(v.co.x,v.co.z,-v.co.y) for v in component]
        lo=[min(p[i] for p in points) for i in range(3)]
        hi=[max(p[i] for p in points) for i in range(3)]
        if hi[0]-lo[0]>8:continue # The single solid terrace.
        rocks+=1
        assert lo[1]<-.8,("Rock does not reach below water",lo,hi)
        for rail in manifest['simons_town_rocks']['colliders']:
            if rail['role']!='barrier':continue
            size=rail['size'][:]
            if abs(rail.get('yaw',0))>1:size[0],size[2]=size[2],size[0]
            a=[rail['position'][i]-size[i]/2 for i in range(3)]
            b=[rail['position'][i]+size[i]/2 for i in range(3)]
            clearance=max(max(a[i]-hi[i],lo[i]-b[i]) for i in range(3))
            assert clearance>.04,('Rock intersects barrier envelope',lo,hi,rail,clearance)
    assert rocks>=16
    print('PASS',rocks,'submerged rocks clear all barrier envelopes')
    mesh.free()

for scene in dst.scenes:
    if scene.name.startswith('Foreground_simons_town_rocks'):
        stone=next(ob for ob in scene.objects if ob.name.endswith('_stone'))
        assert any(ob.name.endswith('_weathered') for ob in scene.objects), 'Missing weathered barrier posts'
        rope=next(ob for ob in scene.objects if ob.name.endswith('_rope'))
        assert sum(v.co.z>.4 for v in rope.data.vertices)>200, 'Missing elevated rope spans'
        print('PASS weathered posts and elevated sagging rope barrier')
        mesh=bmesh.new();mesh.from_mesh(stone.data)
        audit_stone(mesh)
    else:
        assert all(ob.name.endswith(('_sand','_grass')) for ob in scene.objects)
        sand=next(ob for ob in scene.objects if ob.name.endswith('_sand'))
        assert min(v.co.z for v in sand.data.vertices)<-.7
        for v in sand.data.vertices:
            x,y,z=v.co.x,v.co.z,-v.co.y
            if abs(x)<=9 and -3<=z<=12:assert abs(y)<.0001
        print('PASS continuous sand shore, submerged margin, no pier or railing meshes')

# Audit the exported, baked runtime geometry as well as the editable source.
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/locations/lit/simons_town_rocks.glb'))
mesh=bmesh.new()
for ob in bpy.context.scene.objects:
    if ob.type!='MESH':continue
    for polygon in ob.data.polygons:
        if not ob.data.materials[polygon.material_index].name.startswith('FG_stone'):continue
        vertices=[mesh.verts.new(ob.matrix_world@ob.data.vertices[i].co) for i in polygon.vertices]
        mesh.faces.new(vertices)
audit_stone(mesh)
print('PASS exported GLB rock depths and rope-barrier clearance')
