"""Rebuild the Shore BBQ kit in Blender; metres in Godot coordinates.
Run through Blender MCP or: blender --background --python tools/build_bbq.py.
Poly Haven metal_plate (CC0); remaining geometry/materials authored here.
"""
import bpy, math, json, shutil
from pathlib import Path
from mathutils import Vector, Quaternion
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models/bbq';OUT.mkdir(parents=True,exist_ok=True)
TEX=ROOT/'source/textures/bbq';TEX.mkdir(parents=True,exist_ok=True)
for suffix in ['Diffuse','Rough']:
 name='metal_plate_'+suffix+'.jpg';path=TEX/name
 if not path.exists():
  image=next((im for im in bpy.data.images if im.name==name),None)
  if image:
   image.filepath_raw=str(path);image.save()

def p(v):return Vector((v[0],-v[2],v[1]))
def mat(name,color,metal=0,rough=.65):
 m=bpy.data.materials.new('BBQ_'+name);m.diffuse_color=(*color,1);m.use_nodes=True
 s=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 s.inputs['Base Color'].default_value=(*color,1);s.inputs['Metallic'].default_value=metal;s.inputs['Roughness'].default_value=rough
 return m
steel=mat('steel',(.32,.35,.34),.72,.43)
for suffix,socket in [('Diffuse','Base Color'),('Rough','Roughness')]:
 path=TEX/('metal_plate_'+suffix+'.jpg')
 if path.exists():
  im=bpy.data.images.load(str(path),check_existing=True)
  tex=steel.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im
  steel.node_tree.links.new(tex.outputs['Color'],next(n for n in steel.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs[socket])
enamel=mat('teal_enamel',(.025,.105,.087),.28,.32)
black=mat('charcoal',(.035,.026,.019),0,.94)
wood=mat('warm_timber',(.27,.15,.062),0,.7)
white=mat('cream_enamel',(.78,.75,.60),.1,.25)
orange=mat('ember',(.45,.065,.008),0,.8)
node=next(n for n in orange.node_tree.nodes if n.type=='BSDF_PRINCIPLED');node.inputs['Emission Color'].default_value=(.7,.09,.01,1);node.inputs['Emission Strength'].default_value=.7
rubber=mat('rubber',(.02,.025,.026),0,.8)
sausage=mat('sausage',(.65,.28,.14));corn=mat('corn',(.91,.66,.075));mushroom=mat('mushroom',(.63,.50,.35))
for old in list(bpy.data.scenes):
 if old.name.startswith('BBQ_'):bpy.data.scenes.remove(old)
scenes=[];stats={}
def scene(name):
 s=bpy.data.scenes.new('BBQ_'+name);bpy.context.window.scene=s;scenes.append(s);return s

def finish(o,name,m):
 o.name=name;o.data.materials.append(m)
 return o

def box(name,at,size,m,bevel=.008):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p(at));o=bpy.context.object;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 finish(o,name,m)
 if bevel:
  mod=o.modifiers.new('Soft manufactured edges','BEVEL');mod.width=bevel;mod.segments=2
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 return o

def sphere(name,at,size,m,segments=16,rings=8):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=p(at));o=bpy.context.object;o.scale=(size[0],size[2],size[1]);finish(o,name,m)
 for f in o.data.polygons:f.use_smooth=True
 return o

def tube(name,a,b,r,m):
 a,b=p(a),p(b);d=b-a
 bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=r,depth=d.length,location=(a+b)/2)
 o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=d.to_track_quat('Z','Y');return finish(o,name,m)

def disk(name,at,r,h,m):return tube(name,(at[0],at[1]-h/2,at[2]),(at[0],at[1]+h/2,at[2]),r,m)
def export(s,name):
 # Join material groups to bound draw calls while retaining shared surfaces.
 for m in list(bpy.data.materials):
  objects=[o for o in s.objects if o.type=='MESH' and o.data.materials and o.data.materials[0]==m]
  if not objects:continue
  bpy.ops.object.select_all(action='DESELECT')
  for o in objects:o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0]
  if len(objects)>1:bpy.ops.object.join()
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
  # Export origins must remain the authored origin, not the last joined part.
  s.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
 stats[name]={'triangles':sum(len(p.vertices)-2 for o in s.objects if o.type=='MESH' for p in o.data.polygons),'batches':len([o for o in s.objects if o.type=='MESH'])}
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_active_scene=True,export_animations=False)

s=scene('station')
box('Firebox',(0,.79,0),(.93,.27,.64),enamel,.035)
box('Coal bed',(0,.925,0),(.83,.016,.55),black,.015)
for x in range(7):
 for z in range(4):
  at=(-.34+x*.115,.922,-.21+z*.14)
  sphere('Coal',at,(.058,.023,.062),black,8,4)
  tube('Glowing coal seam',(at[0]-.035,at[1]+.023,at[2]),(at[0]+.025,at[1]+.023,at[2]+.015),.003,orange)
for x in range(15):tube('Grill grate',(-.4+x*.057,.948,-.28),(-.4+x*.057,.948,.28),.004,steel)
for z in [-.27,.27]:tube('Grate rail',(-.43,.945,z),(.43,.945,z),.007,steel)
for x in [-.36,.36]:
 for z in [-.23,.23]:tube('Stand',(x,.02,z),(x,.69,z),.023,steel)
box('Lower shelf',(0,.23,0),(.8,.035,.5),enamel)
for x in [-.49,.49]:tube('Carry handle',(x,.82,-.11),(x,.82,.11),.016,wood)
for x in [-.86,.94]:
 box('Prep shelf',(x,.86,0),(.63,.055,.9),wood)
 for z in [-.32,.32]:tube('Shelf support',(x,.02,z),(x,.83,z),.021,steel)
box('Pantry tray',(-.85,.898,-.01),(.51,.018,.71),steel)
for i in range(6):
 x=.81+(i%2)*.26;z=-.22+(i//2)*.30
 disk('Serving plate',(x,.90,z),.117,.016,white)
box('Cooler',(1.02,.27,.66),(.42,.54,.36),enamel,.035)
box('Cooler lid',(1.02,.55,.66),(.45,.05,.39),white,.02)
box('Cooler handle',(1.02,.60,.66),(.18,.045,.05),steel)
# Vents, controls and cream enamel badge give the small grill readable detail.
for x in range(6):box('Front vent',(-.25+x*.10,.79,.323),(.044,.018,.008),black,.004)
box('Badge',(0,.87,.331),(.24,.045,.008),white,.004)
for x in [-.36,.36,-.86,.94]:
 for z in ([-.23,.23] if abs(x)<.5 else [-.32,.32]):disk('Foot',(x,.02,z),.032,.04,rubber)
export(s,'station')

s=scene('tongs')
for side in [-1,1]:
 tube('Spring arm',(0,0,.045),(side*.021,0,-.19),.006,steel)
 box('Scalloped jaw',(side*.023,-.003,-.235),(.025,.013,.08),steel,.009)
 box('Wood grip',(side*.01,.002,-.05),(.013,.017,.12),wood,.006)
export(s,'tongs')
s=scene('sausage');sphere('Sausage',(0,.025,0),(.035,.028,.105),sausage)
for z in [-.075,-.025,.025,.075]:box('Scoring',(0,.047,z),(.035,.003,.007),wood,.002)
export(s,'sausage')
s=scene('corn');sphere('Cob',(0,.026,0),(.034,.030,.105),corn)
for ring in range(10):
 for j in range(8):
  a=j*math.tau/8;at=(math.cos(a)*.031,.031+math.sin(a)*.029,-.089+ring*.0195)
  sphere('Kernel',at,(.009,.009,.0085),corn,8,4)
export(s,'corn')
s=scene('mushroom');tube('Stem',(0,.005,0),(0,.037,0),.018,white);sphere('Cap',(0,.045,0),(.064,.029,.058),mushroom);export(s,'mushroom')
s=scene('drink');tube('Can',(0,-.057,0),(0,.057,0),.033,enamel)
for y in [-.058,.058]:disk('Rim',(0,y,0),.034,.004,steel)
box('Cream label',(0,0,.033),(.035,.067,.002),white,.004)
box('Pull tab',(0,.062,0),(.013,.003,.024),steel,.003);export(s,'drink')
# Keep a composed scene for editable source and visual review.
s=scene('kit_preview')
for index,src in enumerate(scenes[:-1]):
 for o in src.objects:
  dup=o.copy();dup.data=o.data;s.collection.objects.link(dup)
  if src.name!='BBQ_station':dup.location+=p((-.86+(index-1)*.36,1.04,.10))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source/bbq.blend'))
(ROOT/'docs/bbq_assets.json').write_text(json.dumps({'source':'Blender-authored Shore BBQ kit','material':{'asset':'metal_plate','url':'https://polyhaven.com/a/metal_plate','license':'CC0','author':'Rob Tuytel','license_url':'https://polyhaven.com/license'},'models':stats},indent=2)+'\n')
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  area.spaces.active.region_3d.view_distance=3.8
  area.spaces.active.region_3d.view_location=p((0,.65,0))
  area.spaces.active.region_3d.view_rotation=Quaternion((1,0,0),math.radians(62))
print('BBQ_ASSETS',stats)
