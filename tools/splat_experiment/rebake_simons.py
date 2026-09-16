"""Rebake existing UV2 from the oriented site panorama; isolated outputs only.
Blender --background --python tools/splat_experiment/rebake_simons.py
"""
from pathlib import Path
import bpy, math, json, numpy as np
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/splat-experiment/viewer'
bpy.ops.wm.read_factory_settings(use_empty=True)
with bpy.data.libraries.load(str(ROOT/'source/locations/simons_town_rocks_lighting.blend')) as (src,dst):
    dst.scenes=[src.scenes[0]]
s=dst.scenes[0];bpy.context.window.scene=s
for ob in s.objects:
    if ob.type=='LIGHT':ob.hide_render=True
ob=next(o for o in s.objects if 'BakedForeground' in o.name)
bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
# Original HDR retains the sun's energy, lost in the tone-mapped input PNG.
# Simons has zero longitude roll in prepare_location_panos.py.
world=bpy.data.worlds.new('Simons photographic environment');world.use_nodes=True;s.world=world
nodes=world.node_tree.nodes;links=world.node_tree.links
tex=nodes.new('ShaderNodeTexEnvironment');tex.image=bpy.data.images.load(str(ROOT/'assets/environment/locations/simons_town_rocks_8k.hdr'))
coord=nodes.new('ShaderNodeTexCoord');
# Cycles u=.5-atan2(y,x)/TAU. Rotate Blender +Y (Godot -Z) to +X.
rotate=nodes.new('ShaderNodeVectorRotate');rotate.rotation_type='AXIS_ANGLE';rotate.inputs['Axis'].default_value=(0,0,1);rotate.inputs['Angle'].default_value=-math.pi/2
links.new(coord.outputs['Generated'],rotate.inputs['Vector']);links.new(rotate.outputs['Vector'],tex.inputs['Vector'])
links.new(tex.outputs['Color'],nodes['Background'].inputs['Color']);nodes['Background'].inputs['Strength'].default_value=1.0
s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=48;s.cycles.use_denoising=True;s.render.bake.margin=8
s.view_settings.view_transform='Standard'
img=bpy.data.images.new('simons_panorama_irradiance',1024,1024,alpha=False,float_buffer=True);img.colorspace_settings.name='Non-Color'
for m in ob.data.materials:
    bs=m.node_tree.nodes.get('Principled BSDF')
    if bs:bs.inputs['Metallic'].default_value=0
    n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=img;m.node_tree.nodes.active=n
s.render.bake.use_pass_direct=True;s.render.bake.use_pass_indirect=True;s.render.bake.use_pass_color=False
bpy.ops.object.bake(type='DIFFUSE',uv_layer='BakedUV')
img.filepath_raw=str(OUT/'simons_panorama_irradiance.exr');img.file_format='OPEN_EXR';img.save()
pixels=np.empty(1024*1024*4,dtype=np.float32);img.pixels.foreach_get(pixels)
(OUT/'simons_rebake.json').write_text(json.dumps({'source':'simons_town_rocks_8k.hdr','samples':48,'resolution':1024,'uv':'existing BakedUV','environment_rotation_degrees':-90,'mean_rgb':pixels.reshape(-1,4)[:,:3].mean(axis=0).tolist()},indent=2))
print('SIMONS_REBAKE_DONE',flush=True)
