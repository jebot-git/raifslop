"""Blender: refine only the three shores called out in the gameplay recording.
Run before bake_foregrounds.py for lake_pier, simons_town_rocks and blouberg_sunrise_2.
Other waters' scene data and collision records are retained.
"""
import bpy, bmesh, importlib.util, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
# Rebuild the harbour head from its maintained authoring function.
with bpy.data.libraries.load(str(ROOT/'source/foregrounds.blend')) as (src,dst):
    dst.scenes=[n for n in src.scenes if n.split('.')[0]!='Foreground_lake_pier']
retained=list(dst.scenes)
spec=importlib.util.spec_from_file_location('foreground_builder',ROOT/'tools/build_foregrounds.py')
builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
pier=builder.build('lake_pier')
records=json.loads((ROOT/'assets/models/locations/manifest.json').read_text())
records['lake_pier']=builder.RECORDS['lake_pier']
(ROOT/'assets/models/locations/manifest.json').write_text(json.dumps(records,indent=2)+'\n')
bpy.data.libraries.write(str(ROOT/'source/foregrounds.blend'),set(retained+[pier]),path_remap='RELATIVE',fake_user=True,compress=True)
# Reuse the CC0 scan already retained in fishing_assets.blend. Its UV atlas and
# measured bounding boxes are preserved; a shared low-detail mesh limits VR cost.
with bpy.data.libraries.load(str(ROOT/'source/coastal_foregrounds.blend')) as (src,dst):dst.scenes=src.scenes
coasts=list(dst.scenes);coast=next(s for s in coasts if s.name.startswith('Foreground_simons_town_rocks'))
bpy.context.window.scene=coast
stone=next(o for o in coast.objects if o.name.startswith('simons_town_rocks_stone'))
if len(stone.data.polygons)>6:
    polygons=list(stone.data.polygons)
    assert len(polygons)==294, 'Unexpected coastal source geometry; refusing to guess rock groups'
    footprints=[]
    for first in range(6,len(polygons),16):
        vertices=[stone.data.vertices[i].co.copy() for p in polygons[first:first+16] for i in p.vertices]
        lo=Vector(tuple(min(v[a] for v in vertices) for a in range(3)))
        hi=Vector(tuple(max(v[a] for v in vertices) for a in range(3)))
        footprints.append((lo,hi))
    # Keep the six terrace faces, including the submerged foundation.
    verts=[];faces=[];uvs=[]
    for poly in polygons[:6]:
        start=len(verts);verts.extend(stone.data.vertices[i].co[:] for i in poly.vertices)
        faces.append(tuple(range(start,len(verts))))
        uvs.extend(stone.data.uv_layers[0].data[i].uv[:] for i in poly.loop_indices)
    mesh=bpy.data.meshes.new('CoastalTerrace');mesh.from_pydata(verts,[],faces);mesh.update()
    mesh.materials.append(stone.data.materials[0]);uv=mesh.uv_layers.new(name='UVMap')
    for index,value in enumerate(uvs):uv.data[index].uv=value
    stone.data=mesh
    with bpy.data.libraries.load(str(ROOT/'source/fishing_assets.blend')) as (src,dst):dst.objects=['boulder_01']
    scan=dst.objects[0];coast.collection.objects.link(scan)
    for mat in scan.data.materials:
        mat.name='FG_stone_scan'
        for node in mat.node_tree.nodes:
            if node.type=='TEX_IMAGE' and node.image:
                for suffix in ['diff','nor_gl','arm']:
                    if suffix in node.image.name+' '+node.image.filepath:
                        node.image=bpy.data.images.load(str(ROOT/'source/textures/original'/('boulder_01_'+suffix+'_1k.jpg')),check_existing=True)
                        node.image.colorspace_settings.name='sRGB' if suffix=='diff' else 'Non-Color';break
    bpy.ops.object.select_all(action='DESELECT');scan.select_set(True);bpy.context.view_layer.objects.active=scan
    modifier=scan.modifiers.new('VR geometry budget','DECIMATE');modifier.ratio=.055
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    lo=Vector(tuple(min(v.co[a] for v in scan.data.vertices) for a in range(3)))
    hi=Vector(tuple(max(v.co[a] for v in scan.data.vertices) for a in range(3)))
    extent=hi-lo
    for vertex in scan.data.vertices:
        vertex.co=Vector(tuple((vertex.co[a]-lo[a])/extent[a] for a in range(3)))
    for index,(low,high) in enumerate(footprints):
        rock=scan.copy();rock.data=scan.data;rock.name='CoastalScannedRock_%02d'%index
        coast.collection.objects.link(rock);rock.location=low;rock.scale=high-low
    bpy.data.objects.remove(scan,do_unlink=True)
    coast['coastal_scan_faces']=len(rock.data.polygons)
    print('Replaced',len(footprints),'angular boulders with shared scanned geometry',flush=True)
scans=[o for o in coast.objects if o.name.startswith('CoastalScannedRock_')]
if scans and len(scans[0].data.polygons)>2500:
    template=scans[0];template.data=template.data.copy()
    # The original glTF split vertices along UV/normal seams. Weld geometry
    # before decimation, preserving per-corner UVs, or nearly every edge is locked.
    bm=bmesh.new();bm.from_mesh(template.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0001)
    bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(template.data);bm.free()
    bpy.ops.object.select_all(action='DESELECT');template.select_set(True);bpy.context.view_layer.objects.active=template
    modifier=template.modifiers.new('Shared VR rock budget','DECIMATE')
    modifier.ratio=min(1.0,1500/max(1,len(template.data.polygons)))
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    # This scan also contains disconnected near-coincident sheets. Coarsen
    # those first; an edge-only decimator cannot collapse isolated triangles.
    for distance in [.01,.02,.035,.05,.08]:
        if len(template.data.polygons)<=2500:break
        bm=bmesh.new();bm.from_mesh(template.data)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=distance)
        bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.00001)
        bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(template.data);bm.free()
        print('Coastal scan weld',distance,len(template.data.polygons),flush=True)
    assert len(template.data.polygons)<=2500, 'Scanned rock exceeded VR budget'
    for poly in template.data.polygons:poly.use_smooth=True
    for rock in scans:rock.data=template.data
    coast['coastal_scan_faces']=len(template.data.polygons)
    print('Shared coastal rock budget:',len(template.data.polygons),'faces',flush=True)
for rock in coast.objects:
    if not rock.name.startswith('CoastalScannedRock_'):continue
    for mat in rock.data.materials:
        for node in mat.node_tree.nodes:
            if node.type=='TEX_IMAGE' and node.image:
                for suffix in ['diff','nor_gl','arm']:
                    if suffix in node.image.name+' '+node.image.filepath:
                        node.image=bpy.data.images.load(str(ROOT/'source/textures/original'/('boulder_01_'+suffix+'_1k.jpg')),check_existing=True)
                        node.image.colorspace_settings.name='sRGB' if suffix=='diff' else 'Non-Color';break
beach=next(s for s in coasts if s.name.startswith('Foreground_blouberg_sunrise_2'))
if not beach.get('curved_side_shore',False):
    for ob in beach.objects:
        if not ob.name.startswith('blouberg_sunrise_2_sand'):continue
        for vertex in ob.data.vertices:
            # Blender +Y is Godot -Z. Preserve the central waterline and rear.
            x,y,z=vertex.co
            if y>0:vertex.co.y+=max(0,abs(x)-3.5)*.45*min(1,y/3)
    beach['curved_side_shore']=True
records['simons_town_rocks']['triangles']=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in coast.objects if o.type=='MESH')
(ROOT/'assets/models/locations/manifest.json').write_text(json.dumps(records,indent=2)+'\n')
bpy.data.libraries.write(str(ROOT/'source/coastal_foregrounds.blend'),set(coasts),path_remap='RELATIVE',fake_user=True,compress=True)
print('RECORDED_SHORES_AUTHORED',flush=True)
