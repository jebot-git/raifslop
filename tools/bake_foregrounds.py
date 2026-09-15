"""Bake local static foreground irradiance and AO in Blender Cycles (CPU).
Run: blender --background --python tools/bake_foregrounds.py -- lakeside
Original authored source and collision manifest are preserved.
"""
import bpy,sys,math,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ID=sys.argv[sys.argv.index('--')+1]
OUT=ROOT/'assets/models/locations/lit';OUT.mkdir(parents=True,exist_ok=True)
TEX=ROOT/'source/textures/foreground'
BAKE=ROOT/'assets/textures/lighting';BAKE.mkdir(parents=True,exist_ok=True)
PROFILES={'lakeside':(.55,.42,(-35,-40,0),(1,.95,.87)), 'lake_pier':(.3,.35,(-12,-20,0),(1,.96,.9)), 'gray_pier':(.08,.48,(-50,-40,0),(.9,.95,1)), 'bell_park_pier':(.4,.38,(-28,40,0),(1,.97,.9))}
bpy.ops.wm.read_factory_settings(use_empty=True)
PROFILES.update({'simons_town_rocks':(.5,.4,(-38,-65,0),(1,.97,.9)), 'blouberg_sunrise_2':(.16,.4,(-8,95,0),(1,.85,.72))})
library='coastal_foregrounds.blend' if ID in ['simons_town_rocks','blouberg_sunrise_2'] else 'foregrounds.blend'
with bpy.data.libraries.load(str(ROOT/'source'/library)) as (src,dst):dst.scenes=[next(n for n in src.scenes if n.split('.')[0]=='Foreground_'+ID)]
s=dst.scenes[0];bpy.context.window.scene=s
# Separate far terrain, so bake texels concentrate on the reachable foreground.
near=[]
for ob in list(s.objects):
 if ob.type!='MESH':continue
 # Thin rope uses a uniform runtime material instead of undersized atlas islands.
 if ob.name.split('.')[0].endswith(('_grass','_reed','_rope')):continue
 if max(ob.dimensions)>60:
  keep=[];far=[]
  for p in ob.data.polygons:
   center=sum((ob.data.vertices[i].co for i in p.vertices),start=__import__('mathutils').Vector())/len(p.vertices)
   (keep if abs(center.x)<22 and abs(center.y)<25 else far).append(p.index)
  def subset(indices,name):
   mesh=bpy.data.meshes.new(name);verts=[];faces=[];uvs=[]
   for idx in indices:
    p=ob.data.polygons[idx];start=len(verts);verts.extend(ob.data.vertices[i].co[:] for i in p.vertices);faces.append(tuple(range(start,len(verts))));uvs.extend(ob.data.uv_layers[0].data[i].uv[:] for i in p.loop_indices)
   mesh.from_pydata(verts,[],faces);mesh.update();uv=mesh.uv_layers.new(name='UVMap')
   for i,v in enumerate(uvs):uv.data[i].uv=v
   n=bpy.data.objects.new(name,mesh);s.collection.objects.link(n)
   for m in ob.data.materials:n.data.materials.append(m)
   return n
  near.append(subset(keep,ob.name+'_near'));subset(far,ob.name+'_distant');bpy.data.objects.remove(ob,do_unlink=True)
 else:near.append(ob)
# Missing weathered maps reuse the source timber's photographed surface detail.
for m in bpy.data.materials:
 if not m.use_nodes:continue
 bs=m.node_tree.nodes.get('Principled BSDF')
 if not bs:continue
 bs.inputs['Specular IOR Level'].default_value=.28
 if m.name.startswith('FG_steel'):bs.inputs['Roughness'].default_value=.68;bs.inputs['Metallic'].default_value=.7
 if m.name.startswith('FG_paint'):bs.inputs['Roughness'].default_value=.78;bs.inputs['Metallic'].default_value=0
 if m.name.startswith('FG_weathered'):
  for suffix,socket in [('Rough','Roughness'),('nor_gl','Normal')]:
   n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=bpy.data.images.load(str(TEX/('brown_planks_03_'+suffix+'.jpg')),check_existing=True);n.image.colorspace_settings.name='Non-Color'
   if socket=='Normal':
    nm=m.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.28;m.node_tree.links.new(n.outputs['Color'],nm.inputs['Color']);m.node_tree.links.new(nm.outputs['Normal'],bs.inputs[socket])
   else:m.node_tree.links.new(n.outputs['Color'],bs.inputs[socket])
 for n in m.node_tree.nodes:
  if n.type=='NORMAL_MAP':n.inputs['Strength'].default_value=.28
# Join only for an atlas; material slots and tiling UV0 are retained.
bpy.ops.object.select_all(action='DESELECT')
for ob in near:ob.select_set(True)
bpy.context.view_layer.objects.active=near[0];bpy.ops.object.join();ob=bpy.context.object;ob.name=ID+'_BakedForeground'
ob.data.uv_layers.new(name='BakedUV');ob.data.uv_layers.active_index=1;ob.data.uv_layers['BakedUV'].active_render=True
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.003);bpy.ops.object.mode_set(mode='OBJECT')
# Existing tiling textures must always use UV0, independently of the bake target.
for m in ob.data.materials:
 uv=m.node_tree.nodes.new('ShaderNodeUVMap');uv.uv_map='UVMap'
 for n in list(m.node_tree.nodes):
  if n.type=='TEX_IMAGE':m.node_tree.links.new(uv.outputs['UV'],n.inputs['Vector'])
s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=48
s.cycles.use_denoising=True;s.render.bake.margin=8
sun_energy,ambient,rot,color=PROFILES[ID]
world=bpy.data.worlds.new('Soft overcast fill');world.use_nodes=True;world.node_tree.nodes['Background'].inputs['Color'].default_value=(.8,.86,.93,1);world.node_tree.nodes['Background'].inputs['Strength'].default_value=ambient;s.world=world
light=bpy.data.lights.new('Broad soft sun','SUN');light.energy=sun_energy;light.color=color;light.angle=math.radians(12 if ID!='gray_pier' else 25)
sun=bpy.data.objects.new('Broad soft sun',light);s.collection.objects.link(sun);sun.hide_render=True # Sun remains dynamic in Godot; bake diffuse sky fill only.
# Convert Godot's -Z light ray to Blender's -Z ray (Y-up to Z-up).
from mathutils import Euler,Matrix
basis=Euler(tuple(math.radians(v) for v in rot),'YXZ').to_matrix();convert=Matrix(((1,0,0),(0,0,-1),(0,1,0)));sun.rotation_euler=(convert@basis).to_euler()
images={}
for kind in ['sky','irradiance','ao']:
 sun.hide_render=kind!='irradiance'
 img=bpy.data.images.new(ID+'_'+kind,1024,1024,alpha=False,float_buffer=kind!='ao');img.colorspace_settings.name='Non-Color';images[kind]=img
 for m in ob.data.materials:
  n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=img;m.node_tree.nodes.active=n
 if kind!='ao':
  original=[]
  for m in ob.data.materials:
   bs=m.node_tree.nodes.get('Principled BSDF');original.append((bs,bs.inputs['Metallic'].default_value));bs.inputs['Metallic'].default_value=0
  s.render.bake.use_pass_direct=True;s.render.bake.use_pass_indirect=True;s.render.bake.use_pass_color=False
  bpy.ops.object.bake(type='DIFFUSE',uv_layer='BakedUV')
  for bs,v in original:bs.inputs['Metallic'].default_value=v
 else:bpy.ops.object.bake(type='AO',uv_layer='BakedUV')
 s.render.image_settings.color_depth='16'
 img.filepath_raw=str(BAKE/(ID+'_'+kind+('.exr' if kind!='ao' else '.png')));img.file_format='OPEN_EXR' if kind!='ao' else 'PNG';
 if kind!='ao':
  s.render.image_settings.file_format='OPEN_EXR';s.render.image_settings.color_mode='RGB';s.render.image_settings.color_depth='16';s.render.image_settings.exr_codec='ZIP';img.save_render(img.filepath_raw,scene=s)
 else:img.save()
 print('BAKED',ID,kind,flush=True)
# Only source PBR maps belong in GLB; baked atlases are loaded by the game shader.
for m in ob.data.materials:
 for n in list(m.node_tree.nodes):
  if n.type=='TEX_IMAGE' and n.image in images.values():m.node_tree.nodes.remove(n)
ob.data.uv_layers.active_index=0;ob.data.uv_layers['UVMap'].active_render=True
bpy.ops.export_scene.gltf(filepath=str(OUT/(ID+'.glb')),export_format='GLB',use_active_scene=True,export_yup=True,export_apply=True,export_lights=False)
bpy.data.libraries.write(str(ROOT/'source/locations'/(ID+'_lighting.blend')),set([s]),path_remap='RELATIVE',fake_user=True,compress=True)
manifest=ROOT/'assets/models/locations/manifest.json'
records=json.loads(manifest.read_text())
records[ID]['triangles']=sum(sum(len(p.vertices)-2 for p in obj.data.polygons) for obj in s.objects if obj.type=='MESH')
records[ID]['bytes']=(OUT/(ID+'.glb')).stat().st_size
manifest.write_text(json.dumps(records,indent=2)+'\n')
print('LIGHTING_DONE',ID,flush=True)
