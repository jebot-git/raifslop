"""Blender: bake the retained CC0 rock scan onto a closed convex VR proxy.
Run after refine_recorded_shores.py, then bake_foregrounds.py for Coastal Rocks.
"""
import bpy,bmesh,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
with bpy.data.libraries.load(str(ROOT/'source/fishing_assets.blend')) as (src,dst):dst.objects=['boulder_01']
scan=dst.objects[0];scene.collection.objects.link(scan)
scan.modifiers.clear()
for mat in scan.data.materials:
    for node in mat.node_tree.nodes:
        if node.type=='TEX_IMAGE' and node.image:
            for suffix in ['diff','nor_gl','arm']:
                if suffix in node.image.name+' '+node.image.filepath:
                    node.image=bpy.data.images.load(str(ROOT/'source/textures/original'/('boulder_01_'+suffix+'_1k.jpg')),check_existing=True)
                    node.image.colorspace_settings.name='sRGB' if suffix=='diff' else 'Non-Color';break
bm=bmesh.new()
for vertex in scan.data.vertices:bm.verts.new(vertex.co)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.001)
hull=bmesh.ops.convex_hull(bm,input=list(bm.verts),use_existing_faces=False)
bmesh.ops.delete(bm,geom=list(set(hull['geom_interior']+hull['geom_unused'])),context='VERTS')
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
bmesh.ops.triangulate(bm,faces=list(bm.faces))
assert all(edge.is_manifold for edge in bm.edges), 'Coastal proxy must be watertight'
mesh=bpy.data.meshes.new('ClosedCoastalRock');bm.to_mesh(mesh);bm.free()
proxy=bpy.data.objects.new('ClosedCoastalRock',mesh);scene.collection.objects.link(proxy)
for poly in mesh.polygons:poly.use_smooth=True
bpy.ops.object.select_all(action='DESELECT');proxy.select_set(True);bpy.context.view_layer.objects.active=proxy
mesh.uv_layers.new(name='UVMap')
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(70),island_margin=.01);bpy.ops.object.mode_set(mode='OBJECT')
mat=bpy.data.materials.new('FG_stone_scan');mat.use_nodes=True;mesh.materials.append(mat)
image=bpy.data.images.new('CoastalGraniteBake',1024,1024,alpha=False)
image.generated_color=(.4,.36,.3,1)
node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=image;mat.node_tree.nodes.active=node
scene.render.engine='CYCLES';scene.cycles.samples=8;scene.cycles.device='CPU'
scene.render.bake.use_selected_to_active=True;scene.render.bake.cage_extrusion=.03;scene.render.bake.max_ray_distance=1.0
scene.render.bake.use_pass_direct=False;scene.render.bake.use_pass_indirect=False;scene.render.bake.use_pass_color=True
scene.render.bake.margin=8
scan.select_set(True)
bpy.ops.object.bake(type='DIFFUSE',uv_layer='UVMap')
path=ROOT/'source/textures/foreground/coastal_granite_base.png'
image.filepath_raw=str(path);image.file_format='PNG';image.save()
bs=mat.node_tree.nodes.get('Principled BSDF');mat.node_tree.links.new(node.outputs['Color'],bs.inputs['Base Color']);bs.inputs['Roughness'].default_value=.9
lo=Vector(tuple(min(v.co[a] for v in mesh.vertices) for a in range(3)))
hi=Vector(tuple(max(v.co[a] for v in mesh.vertices) for a in range(3)))
for vertex in mesh.vertices:vertex.co=Vector(tuple((vertex.co[a]-lo[a])/(hi[a]-lo[a]) for a in range(3)))
with bpy.data.libraries.load(str(ROOT/'source/coastal_foregrounds.blend')) as (src,dst):dst.scenes=src.scenes
coasts=list(dst.scenes);coast=next(s for s in coasts if s.name.startswith('Foreground_simons_town_rocks'))
for rock in coast.objects:
    if rock.name.startswith('CoastalScannedRock_'):rock.data=mesh
coast['coastal_scan_faces']=len(mesh.polygons)
bpy.data.libraries.write(str(ROOT/'source/coastal_foregrounds.blend'),set(coasts),path_remap='RELATIVE',fake_user=True,compress=True)
print('CLOSED_COASTAL_ROCK',len(mesh.polygons),'faces',flush=True)
