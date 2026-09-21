"""BBQ food authoring through Blender MCP. Metres, Z up; glTF exports Y up.
Build() creates a separate scene. bake_asset() retains editable procedural originals
and exports a single PBR material per portion. No external textures are required.
"""
import bpy, math, random
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models/bbq'; TEX=ROOT/'source/textures/bbq_food'
R=random.Random(1747)
assets={}; originals={}; scene=None

def linear(hex):
 c=[int(hex[i:i+2],16)/255 for i in (0,2,4)]
 return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c)+(1,)

def material(name, dark, light, scale=90, rough=.55, grain=1600, bump=.00025):
 m=bpy.data.materials.new('Food • '+name);m.use_nodes=True
 n=m.node_tree.nodes;l=m.node_tree.links;p=next(n for n in n if n.type=='BSDF_PRINCIPLED')
 p.inputs['Base Color'].default_value=linear(light);m.diffuse_color=linear(light)
 p.inputs['Roughness'].default_value=rough
 noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=scale;noise.inputs['Detail'].default_value=3
 coord=n.new('ShaderNodeTexCoord');l.new(coord.outputs['Object'],noise.inputs['Vector'])
 ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.24;ramp.color_ramp.elements[0].color=linear(dark)
 ramp.color_ramp.elements[1].position=.78;ramp.color_ramp.elements[1].color=linear(light)
 l.new(noise.outputs['Factor'],ramp.inputs['Factor']);l.new(ramp.outputs['Color'],p.inputs['Base Color'])
 micro=n.new('ShaderNodeTexNoise');micro.inputs['Scale'].default_value=grain;micro.inputs['Detail'].default_value=2.5;l.new(coord.outputs['Object'],micro.inputs['Vector'])
 b=n.new('ShaderNodeBump');b.inputs['Strength'].default_value=.4;b.inputs['Distance'].default_value=bump;l.new(micro.outputs['Factor'],b.inputs['Height']);l.new(b.outputs['Normal'],p.inputs['Normal'])
 rr=n.new('ShaderNodeValToRGB');rr.color_ramp.elements[0].color=(max(.1,rough-.16),)*3+(1,);rr.color_ramp.elements[1].color=(min(.95,rough+.12),)*3+(1,)
 l.new(micro.outputs['Factor'],rr.inputs['Factor']);l.new(rr.outputs['Color'],p.inputs['Roughness'])
 return m

def mesh(name,verts,faces,mat):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);scene.collection.objects.link(o);o.data.materials.append(mat)
 for p in me.polygons:p.use_smooth=True
 return o

def lathe(name,profile,mat,segments=96,warp=0):
 # Cubic profiles give buns/caps rolled edges rather than stacked cylinders.
 points=[]
 for i in range(len(profile)-1):
  a,b,c,d=[Vector(profile[k]) for k in (max(i-1,0),i,i+1,min(i+2,len(profile)-1))]
  for j in range(5):
   t=j/5;v=.5*(2*b+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t);points.append((max(0,v.x),v.y))
 points.append(profile[-1]);verts=[];faces=[]
 for r,z in points:
  for j in range(segments):
   a=j*math.tau/segments
   w=warp*(.55*math.sin(a*7+z*63)+.3*math.sin(a*13-z*77)+.15*math.sin(a*23))
   rr=max(0,r+w*(min(1,r/.02)))
   verts.append((rr*math.cos(a),rr*math.sin(a),z+w*.25))
 for i in range(len(points)-1):
  for j in range(segments):
   a=i*segments+j;b=i*segments+(j+1)%segments;faces.append((a,b,b+segments,a+segments))
 return mesh(name,verts,faces,mat)

def ellipsoid(name,at,size,mat,segments=16,rings=8):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=at)
 o=bpy.context.object;o.name=name;o.scale=size;o.data.materials.append(mat)
 for p in o.data.polygons:p.use_smooth=True
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return o

def tube(name,points,radius,mat,sides=8):
 verts=[];faces=[]
 for i,p in enumerate(points):
  at=Vector(p);t=(Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])).normalized();u=t.cross(Vector((0,0,1)))
  if u.length<.01:u=t.cross(Vector((1,0,0)))
  u.normalize();v=t.cross(u).normalized()
  for j in range(sides):verts.append(at+radius*(math.cos(j*math.tau/sides)*u+math.sin(j*math.tau/sides)*v))
 for i in range(len(points)-1):
  for j in range(sides):a=i*sides+j;b=i*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
 faces.extend([tuple(reversed(range(sides))),tuple((len(points)-1)*sides+j for j in range(sides))]);return mesh(name,verts,faces,mat)

def remember(kind,before):
 objects=[o for o in scene.objects if o.type=='MESH' and o.name not in before]
 originals[kind]=objects
 # Isolate per-asset authoring collections without changing original objects.
 collection=bpy.data.collections.new('Editable • '+kind);scene.collection.children.link(collection)
 for o in objects:
  for col in list(o.users_collection):col.objects.unlink(o)
  collection.objects.link(o)
 return objects

def build():
 global scene
 scene=bpy.data.scenes.new('BBQ Food • Authoring');bpy.context.window.scene=scene
 R.seed(1747)
 bun=material('brioche crust','78330f','ce8431',80,.42,2100,.00016)
 edge=material('soft bread edge','c18549','edca8f',210,.74,3100,.00025)
 fish=material('crisp fish coating','945019','e2a854',430,.68,3100,.00055)
 whitefish=material('flaked white fish','c6b78f','eee4be',280,.61,1800,.00015)
 lettuce=material('butter lettuce','244514','759542',125,.49,2100,.00012)
 vein=material('leaf veins','557331','a5b56d',100,.52,1600,.00006)
 sauce=material('tartar sauce','d7cca5','f4e9c9',180,.32,2400,.00007)
 tomato=material('tomato flesh','8e2414','d74622',160,.35,2400,.00010)
 seeds=material('sesame','bb955f','f4d9a3',500,.62,2000,.00008)
 herb=material('herbs','27402a','566d32',200,.7,2000,.00003)
 before=set(o.name for o in scene.objects)
 heel=lathe('Bun • soft heel',[(0,-.044),(.043,-.044),(.063,-.040),(.069,-.031),(.069,-.021),(.063,-.017),(0,-.017)],edge,96,.0008)
 heel.data.materials.append(bun)
 for poly in heel.data.polygons:
  if sum(heel.data.vertices[v].co.z for v in poly.vertices)/len(poly.vertices)<-.027:poly.material_index=1
 fillet=lathe('Breaded fish fillet',[(0,-.016),(.050,-.016),(.064,-.014),(.072,-.006),(.070,.007),(.061,.014),(0,.014)],fish,96,.0020)
 fillet.scale.y=.86;fillet.rotation_euler.z=.17
 # Individual crust crumbs break the patty silhouette without geometric noise everywhere.
 for i in range(115):
  a=R.random()*math.tau;r=R.uniform(.060,.070);z=R.uniform(-.012,.011)
  o=ellipsoid('Crisp crumb',(math.cos(a)*r,math.sin(a)*r*.86,z),(R.uniform(.0006,.0015),R.uniform(.0007,.0018),R.uniform(.0005,.0015)),fish,8,4);o.rotation_euler=(R.random(),R.random(),R.random())
 for i in range(9):
  a=2.9+i*.085;o=ellipsoid('Fish flake',(math.cos(a)*.068,math.sin(a)*.058,.002),(.005,.0015,.002),whitefish,12,6);o.rotation_euler.z=a+math.pi/2
 lathe('Tartar filling',[(0,.012),(.048,.012),(.064,.015),(.062,.019),(0,.019)],sauce,80,.0018)
 for i in range(11):
  a=R.random()*math.tau;r=R.uniform(.044,.065)
  ellipsoid('Tartar drip',(math.cos(a)*r,math.sin(a)*r,.015),(.004,.005,.003),sauce,12,6)
 for k in range(7):
  angle=k*math.tau/7+.25;verts=[];faces=[]
  for i in range(17):
   t=i/16;r=.021+.061*t;width=.025*math.sin(math.pi*t)**.6
   for j in range(9):
    s=j/4-1;a=angle+s*width/max(r,.01)
    z=.022+.005*t+.004*math.sin(t*9+k)*s*s+.0025*math.sin(t*24+k)*abs(s)**3
    verts.append((math.cos(a)*r,math.sin(a)*r,z))
  for i in range(16):
   for j in range(8):a=i*9+j;faces.append((a,a+1,a+10,a+9))
  mesh('Curled lettuce leaf',verts,faces,lettuce)
  tube('Leaf midrib',[(math.cos(angle)*(.025+.052*t),math.sin(angle)*(.025+.052*t),.023+.005*t) for t in [i/12 for i in range(13)]],.00028,vein,6)
 for x,y in [(-.022,.007),(.020,-.009)]:
  o=lathe('Tomato slice',[(0,.027),(.032,.027),(.038,.030),(.037,.033),(0,.033)],tomato,64,.0007);o.location.x=x;o.location.y=y
 crown=lathe('Brioche crown',[(0,.032),(.052,.032),(.067,.034),(.070,.040),(.068,.051),(.058,.064),(.041,.075),(.020,.081),(0,.082)],bun,128,.00065)
 lathe('Crown • pale cut edge',[(0,.031),(.055,.031),(.068,.033),(.069,.036),(.067,.038),(0,.038)],edge,96,.0004)
 for i in range(78):
  a=R.random()*math.tau;r=.063*math.sqrt(R.random());z=.083-.046*(r/.07)**2
  hit,point,normal,_=crown.ray_cast(Vector((math.cos(a)*r,math.sin(a)*r,.2)),Vector((0,0,-1)))
  if not hit:continue
  p=point+normal*.0005
  o=ellipsoid('Sesame seed',p,(R.uniform(.001,.0014),R.uniform(.0019,.0026),.0007),seeds,12,6)
  o.rotation_mode='QUATERNION';o.rotation_quaternion=normal.to_track_quat('Z','Y')
  from mathutils import Quaternion
  o.rotation_quaternion @= Quaternion(Vector((0,0,1)),R.random()*math.tau)
 for i in range(14):
  a=R.random()*math.tau;ellipsoid('Herb fleck',(math.cos(a)*.062,math.sin(a)*.06,.019),(.0006,.001,.0003),herb,8,4)
 for o in remember('fish_burger',before):
  # Apply seed/object rotation before compressing the assembled burger.
  bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
  o.location.z*=.82
  for v in o.data.vertices:v.co.z*=.82
 build_sausage();build_corn();build_mushroom()
 print('FOOD_BUILT', {k:len(v) for k,v in originals.items()})
 return scene

def build_sausage():
 before=set(o.name for o in scene.objects)
 skin=material('sausage casing','8f381f','c98650',170,.37,2400,.00018)
 score=material('sausage cut','c29571','e0b493',260,.66,1900,.00016)
 spice=material('sausage seasoning','6b3623','9b4e31',200,.62,1800,.00008)
 verts=[];faces=[];ns=64;nr=49
 for i in range(nr):
  t=i/(nr-1);y=(t-.5)*.174;bend=.013*(1-(2*t-1)**2)
  end=min(1,math.sin(math.pi*t)*4);radius=.0205*math.sqrt(max(0,end))
  for j in range(ns):
   a=j*math.tau/ns;wav=1+.017*math.sin(a*11+t*48)
   # Fine diagonal scoring indents the casing rather than floating on it.
   cut=0
   for c in [.27,.46,.65,.81]:cut=max(cut,math.exp(-((t-c-.045*math.cos(a))/.015)**2)*max(0,math.sin(a))**8)
   rad=radius*wav-.0014*cut
   verts.append((bend+rad*math.cos(a),y,.001+rad*math.sin(a)))
 for i in range(nr-1):
  for j in range(ns):a=i*ns+j;b=i*ns+(j+1)%ns;faces.append((a,a+ns,b+ns,b))
 mesh('Gently curved sausage',verts,faces,skin)
 for t in [.27,.46,.65,.81]:
  pts=[]
  for j in range(13):
   a=.30+math.pi*j/18;tt=t+.045*math.cos(a);pts.append((.013*(1-(2*tt-1)**2)+.019*math.cos(a),(tt-.5)*.174,.001+.0188*math.sin(a)))
  tube('Casing score',pts,.00045,score,6)
 for y in [-.088,.088]:ellipsoid('Twisted casing end',(0,y,.001),(.006,.003,.005),skin,16,8)
 for i in range(32):
  t=R.uniform(.14,.86);a=R.uniform(.1,3.04);r=.0206
  ellipsoid('Pepper fleck',(.013*(1-(2*t-1)**2)+r*math.cos(a),(t-.5)*.174,.001+r*math.sin(a)),(.0005,.0006,.0003),spice,8,4)
 remember('sausage',before)

def build_corn():
 before=set(o.name for o in scene.objects)
 gold=[material('corn kernel '+str(i),*pair,scale=220,rough=.39,grain=1900,bump=.00012) for i,pair in enumerate([('d19928','f1cb63'),('cf8d20','edbc44'),('d9a83c','f2d57e')])]
 core=material('corn pith','c7a774','e6cf97',260,.8,2100,.00024)
 ellipsoid('Corn cob core',(0,0,0),(.021,.081,.021),core,32,16)
 for row in range(14):
  a=row*math.tau/14
  for k in range(17):
   y=-.074+k*.0091+(row%2)*.0010;t=y/.083;r=.021*math.sqrt(max(.35,1-t*t*.36))
   aa=a+R.uniform(-.022,.022)
   p=(math.cos(aa)*r,y,math.sin(aa)*r)
   o=ellipsoid('Rounded corn kernel',p,(.0055,.00465,.0059),gold[(k+row)%3],12,8)
   o.rotation_euler.y=math.pi/2-aa
 for y in [-.079,.080]:
  ellipsoid('Cut cob end',(0,y,0),(.016,.002,.016),core,24,12)
 remember('corn',before)

def build_mushroom():
 before=set(o.name for o in scene.objects)
 cap=material('chestnut mushroom skin','795037','b69472',110,.52,1900,.0003)
 rim=material('mushroom rim','b29574','dbc5a0',240,.67,2000,.00013)
 stem=material('mushroom stem','c0a783','e7d4af',220,.73,2300,.0002)
 gill=material('mushroom gills','5b4234','9f7960',340,.85,1800,.00009)
 lathe('Chestnut cap',[(0,.020),(.037,.020),(.054,.021),(.060,.027),(.057,.041),(.043,.055),(.020,.062),(0,.064)],cap,112,.0012)
 lathe('Rolled cap rim',[(.047,.019),(.055,.019),(.060,.023),(.059,.027),(.054,.025),(.047,.022)],rim,96,.0005)
 stalk=lathe('Tapered stalk',[(0,-.029),(.015,-.029),(.017,-.024),(.012,.003),(.017,.022),(0,.026)],stem,64,.0006);stalk.rotation_euler.y=.08
 verts=[];faces=[]
 for j in range(80):
  a=j*math.tau/80;start=len(verts)
  for k in range(8):
   t=k/7;r=.014+t*.044;z=.019-.004*math.sin(t*math.pi)
   for offset in [-.0004,.0004]:verts.append((math.cos(a)*r-math.sin(a)*offset,math.sin(a)*r+math.cos(a)*offset,z))
  for k in range(7):n=start+k*2;faces.append((n,n+1,n+3,n+2))
 mesh('Radial mushroom gills',verts,faces,gill)
 remember('mushroom',before)

def preview():
 view=bpy.data.scenes.new('BBQ Food • Review');bpy.context.window.scene=view
 offsets={'fish_burger':(-.13,0,0),'sausage':(.055,-.06,0),'corn':(.075,.07,0),'mushroom':(.19,.01,0)}
 for kind,objects in originals.items():
  for o in objects:
   dup=o.copy();view.collection.objects.link(dup);dup.location+=Vector(offsets[kind])
 world=bpy.data.worlds.new('Food review softbox');view.world=world;world.use_nodes=True
 bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs[0].default_value=(.18,.18,.18,1);bg.inputs[1].default_value=.4
 for name,at,energy,size in [('Key',(-.2,-.25,.5),8,.4),('Fill',(.25,.1,.35),4,.3)]:
  data=bpy.data.lights.new(name,type='AREA');data.energy=energy;data.shape='DISK';data.size=size
  lamp=bpy.data.objects.new(name,data);view.collection.objects.link(lamp);lamp.location=at;lamp.rotation_euler=(Vector((0,0,.02))-lamp.location).to_track_quat('-Z','Y').to_euler()
 cam=bpy.data.cameras.new('Food review camera');ob=bpy.data.objects.new('Food review camera',cam);view.collection.objects.link(ob);ob.location=(.38,-.68,.48);ob.rotation_euler=(Vector((.025,0,.015))-ob.location).to_track_quat('-Z','Y').to_euler();cam.type='ORTHO';cam.ortho_scale=.54;view.camera=ob
 view.render.resolution_x=1500;view.render.resolution_y=1100;view.render.resolution_percentage=100
 for screen in bpy.data.screens:
  for area in screen.areas:
   if area.type=='VIEW_3D':
    space=area.spaces.active;space.shading.type='MATERIAL';space.overlay.show_overlays=False
    space.region_3d.view_perspective='CAMERA'
 return view

def bake_asset(kind):
 """Bake procedural colour, grain normals and roughness; one draw per portion."""
 bake=bpy.data.scenes.new('Export • '+kind);bpy.context.window.scene=bake
 copies=[]
 for original in originals[kind]:
  o=original.copy();o.data=original.data.copy();bake.collection.objects.link(o);copies.append(o)
 bpy.ops.object.select_all(action='DESELECT')
 for o in copies:o.select_set(True)
 bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join();o=copies[0];o.name=kind
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 bake.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
 triangles=sum(len(f.vertices)-2 for f in o.data.polygons)
 if triangles>18000:
  mod=o.modifiers.new('Mobile triangle budget','DECIMATE');mod.ratio=18000/triangles;bpy.ops.object.modifier_apply(modifier=mod.name)
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.003,margin_method='FRACTION',scale_to_bounds=True);bpy.ops.object.mode_set(mode='OBJECT')
 try:bake.render.engine='CYCLES'
 except TypeError as e:raise RuntimeError('Cycles required for food texture bake: '+str(e))
 bake.cycles.samples=4;bake.render.bake.margin=3;bake.render.bake.use_selected_to_active=False
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
 bpy.context.view_layer.update()

 # Fail before export if any island would fall outside the baked atlas.
 assert all(-1e-5<=c<=1.00001 for loop in o.data.uv_layers.active.data for c in loop.uv), 'UV island outside atlas'
 mats=list(o.data.materials);baked={};size=2048 if kind=='fish_burger' else 1024
 for label,pass_type in [('albedo','DIFFUSE'),('normal','NORMAL'),('roughness','ROUGHNESS')]:
  im=bpy.data.images.new(kind+'_'+label,width=size,height=size,alpha=False)
  if label!='albedo':im.colorspace_settings.name='Non-Color'
  for mat in mats:
   n=mat.node_tree.nodes.new('ShaderNodeTexImage');n.image=im;mat.node_tree.nodes.active=n
  if label=='albedo':bpy.ops.object.bake(type=pass_type,pass_filter={'COLOR'},use_clear=True)
  else:bpy.ops.object.bake(type=pass_type,use_clear=True)
  if label=='albedo':
   import numpy as np
   pixels=np.asarray(im.pixels[:],dtype=np.float32).reshape(-1,4)
   assert np.isfinite(pixels).all() and np.mean(pixels[:,:3].max(axis=1)>.03)>.05, 'Empty food colour bake'
  im.filepath_raw=str(TEX/(kind+'_'+label+'.png'));im.file_format='PNG';im.save();im.pack();baked[label]=im
 m=bpy.data.materials.new(kind+' • baked PBR');m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;p=next(x for x in n if x.type=='BSDF_PRINCIPLED')
 for label in ['albedo','roughness']:
  t=n.new('ShaderNodeTexImage');t.image=baked[label];l.new(t.outputs['Color'],p.inputs['Base Color' if label=='albedo' else 'Roughness'])
 t=n.new('ShaderNodeTexImage');t.image=baked['normal'];normal=n.new('ShaderNodeNormalMap');l.new(t.outputs['Color'],normal.inputs['Color']);l.new(normal.outputs['Normal'],p.inputs['Normal'])
 o.data.materials.clear();o.data.materials.append(m)
 for poly in o.data.polygons:poly.material_index=0
 bpy.ops.export_scene.gltf(filepath=str(OUT/(kind+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,export_materials='EXPORT',export_image_format='AUTO',export_yup=True)
 assets[kind]=o
 stats={'triangles':sum(len(f.vertices)-2 for f in o.data.polygons),'materials':len(o.data.materials),'texture_size':size}
 print('FOOD_EXPORTED',kind,stats)
 return stats

def save_source(review):
 # Remove disconnected bake targets from the editable procedural materials.
 for objects in originals.values():
  for o in objects:
   for mat in o.data.materials:
    for node in list(mat.node_tree.nodes):
     if node.type=='TEX_IMAGE' and not any(link.from_node==node for link in mat.node_tree.links):mat.node_tree.nodes.remove(node)
 # Save only authored food scenes, keeping any pre-existing Blender work out.
 datablocks={scene,review}
 datablocks.update(o.users_scene[0] for o in assets.values())
 bpy.data.libraries.write(str(ROOT/'source/bbq_food.blend'),datablocks,compress=True)

if __name__=='__main__':
 build()
 for kind in ['fish_burger','sausage','corn','mushroom']:bake_asset(kind)
 review=preview();save_source(review)
