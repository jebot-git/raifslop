"""Bake static course irradiance into unique UV2 atlases from exact runtime meshes.

Blender --background --python tools/bake_minigolf_lighting.py -- location [size]
The retained, sun-separated location lighting scenes supply the illumination.
"""
import bpy
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'source/minigolf/lighting'
OUTPUT = ROOT / 'assets/minigolf/lighting'
OUTPUT.mkdir(parents=True, exist_ok=True)


def lighting(location):
    path = ROOT / 'source/locations' / (location + '_lighting.blend')
    if not path.exists():
        path = ROOT / 'source' / (location + '_lighting.blend')
    if path.exists():
        with bpy.data.libraries.load(str(path)) as (src, dst):
            dst.scenes = [src.scenes[0]]
        scene = dst.scenes[0]
        bpy.context.window.scene = scene
        for obj in list(scene.objects):
            if obj.type != 'LIGHT':
                for collection in list(obj.users_collection):collection.objects.unlink(obj)
        return scene, str(path.relative_to(ROOT))
    # These newer river panoramas have no retained foreground lighting scene.
    # Integrate the full HDR once, without adding a second solar contribution.
    scene = bpy.data.scenes.new('MinigolfBake_' + location)
    bpy.context.window.scene = scene
    world = bpy.data.worlds.new(location + '_HDR');world.use_nodes = True;scene.world = world
    nodes = world.node_tree.nodes
    background = next(n for n in nodes if n.type == 'BACKGROUND')
    texture = nodes.new('ShaderNodeTexEnvironment')
    texture.image = bpy.data.images.load(str(ROOT / 'assets/environment/locations' / (location + '_4k.hdr')))
    texture.image.scale(1024,512);texture.image.pack()
    # World direction in Blender: (game X, -game Z, game Y).
    coords = nodes.new('ShaderNodeTexCoord');mapping = nodes.new('ShaderNodeMapping')
    mapping.inputs['Rotation'].default_value[2] = math.pi / 2
    world.node_tree.links.new(coords.outputs['Generated'],mapping.inputs['Vector'])
    world.node_tree.links.new(mapping.outputs['Vector'],texture.inputs['Vector'])
    world.node_tree.links.new(texture.outputs['Color'],background.inputs['Color'])
    background.inputs['Strength'].default_value = .6 if location == 'cedar_creek' else .7
    return scene, location + '_4k.hdr (full HDR, single solar contribution)'


def bake(location, resolution=2048):
    scene, illumination = lighting(location)
    scene.name = 'MinigolfBake_' + location
    records = json.loads((SOURCE / (location + '-geometry.json')).read_text())
    vertices=[];faces=[];ranges=[];colors=[]
    for record in records:
        # Weld only within a surface so coplanar triangles share UV islands.
        lookup={};mapping=[]
        for point in record['vertices']:
            key=tuple(round(v,6) for v in point)
            if key not in lookup:
                lookup[key]=len(vertices);vertices.append(point)
            mapping.append(lookup[key])
        start=len(faces)
        faces.extend(tuple(mapping[v] for v in face) for face in record['faces'])
        ranges.append((record['path'],record['surface'],start,len(faces)))
        colors.append(record['color'])
    mesh=bpy.data.meshes.new(location+'_StaticCourse');mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new(location+'_StaticCourse',mesh);scene.collection.objects.link(obj)
    mats={}
    for record_index,(_,_,start,end) in enumerate(ranges):
        color=tuple(colors[record_index])
        if color not in mats:
            mat=bpy.data.materials.new('BakeDiffuse');mat.use_nodes=True
            bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
            bs.inputs['Base Color'].default_value=tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in color[:3])+(1,)
            bs.inputs['Roughness'].default_value=.9
            mats[color]=len(mesh.materials);mesh.materials.append(mat)
        for face in range(start,end):mesh.polygons[face].material_index=mats[color]
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    uv=mesh.uv_layers.new(name='LightmapUV')
    atlas=json.loads((SOURCE/(location+'-uv2.json')).read_text())
    assert len(atlas)==len(ranges)
    for record,(_,_,start,end) in zip(atlas,ranges):
        assert len(record['uv2'])==(end-start)*3
        for face in range(start,end):
            for corner,loop in enumerate(reversed(list(mesh.polygons[face].loop_indices))):
                value=record['uv2'][(face-start)*3+corner]
                uv.data[loop].uv=(value[0],1-value[1])
    print('MINIGOLF_UV_READY',location,len(faces),flush=True)
    scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=24
    scene.render.threads_mode='FIXED';scene.render.threads=4
    scene.render.bake.margin=4;scene.render.bake.use_pass_direct=True;scene.render.bake.use_pass_indirect=True;scene.render.bake.use_pass_color=False
    scene.render.bake.use_selected_to_active=False
    for kind in ['irradiance','ao']:
        image=bpy.data.images.new(location+'_'+kind,resolution,resolution,alpha=False,float_buffer=kind=='irradiance')
        image.colorspace_settings.name='Non-Color'
        for mat in mesh.materials:
            node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=image;mat.node_tree.nodes.active=node
        bpy.ops.object.bake(type='DIFFUSE' if kind=='irradiance' else 'AO',uv_layer='LightmapUV')
        image.filepath_raw=str(OUTPUT/(location+'_'+kind+('.exr' if kind=='irradiance' else '.png')))
        image.file_format='OPEN_EXR' if kind=='irradiance' else 'PNG'
        if kind=='irradiance':
            scene.render.image_settings.file_format='OPEN_EXR';scene.render.image_settings.color_mode='RGB';scene.render.image_settings.color_depth='16';scene.render.image_settings.exr_codec='ZIP'
            image.save_render(image.filepath_raw,scene=scene)
        else:image.save()
        print('MINIGOLF_LIGHT_BAKED',location,kind,flush=True)
        for mat in mesh.materials:
            for node in list(mat.node_tree.nodes):
                if node.type=='TEX_IMAGE' and node.image==image:mat.node_tree.nodes.remove(node)
    bpy.data.libraries.write(str(SOURCE/(location+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    (OUTPUT/(location+'.json')).write_text(json.dumps({'location':location,'resolution':resolution,'samples':24,'lighting_source':illumination,'surfaces':len(records),'triangles':len(faces),'uv_set':'UV2','passes':['direct + indirect diffuse irradiance (without albedo)','ambient occlusion']},indent=2)+'\n')
    print('MINIGOLF_BAKE_COMPLETE',location,flush=True)

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:];bake(args[0],int(args[1]) if len(args)>1 else 2048)
