"""Blender-authored compact spinning tackle. Dimensions are game-space metres.
Generic construction reference: Shimano Sienna spinning cork rods and spinning reel schematics;
no branding, proprietary CAD or external artwork is copied.
"""
import bpy, math, numpy as np
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/models/rods';OUT.mkdir(parents=True,exist_ok=True)
scenes=[]
def p(v):return Vector((v[0],-v[2],v[1]))
def material(name,color,metal=0,rough=.4):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;s=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');s.inputs['Base Color'].default_value=(*color,1);s.inputs['Metallic'].default_value=metal;s.inputs['Roughness'].default_value=rough;return m
carbon=material('Satin graphite',(.022,.028,.03),.25,.36);rubber=material('Matte EVA',(.025,.026,.026),0,.78);steel=material('Brushed stainless',(.38,.41,.42),.85,.3);ceramic=material('Ceramic guide inserts',(.055,.06,.06),.12,.26);line=material('Wound nylon',(.26,.29,.23),0,.55)
cork=material('Natural cork',(.5,.33,.18),0,.78)
rng=np.random.default_rng(124);a=rng.random((512,1024));grain=(a>.987).astype(float)
for _ in range(3):grain=np.maximum(grain,np.roll(grain,1,axis=1)*.85)
c=np.zeros((512,1024,4),np.float32);base=np.array([.52,.35,.19]);c[:,:,:3]=base[None,None,:]*(.88+a[:,:,None]*.24-grain[:,:,None]*.5);c[:,:,3]=1
im=bpy.data.images.new('Cork grain',width=1024,height=512);im.pixels.foreach_set(c.ravel());im.pack();t=cork.node_tree.nodes.new('ShaderNodeTexImage');t.image=im;cork.node_tree.links.new(t.outputs['Color'],next(n for n in cork.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Base Color'])
def finish(o,name,mat):
 o.name=name;o.data.materials.append(mat)
 for f in o.data.polygons:f.use_smooth=True
 return o
def cylinder(name,a,b,r,mat,r2=None):
 va,vb=p(a),p(b);delta=vb-va
 bpy.ops.mesh.primitive_cone_add(vertices=24,radius1=r,radius2=r if r2 is None else r2,depth=delta.length,location=(va+vb)/2)
 o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=delta.to_track_quat('Z','Y');return finish(o,name,mat)
def torus(name,center,r,tube,mat,axis=(0,0,1)):
 bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=8,location=p(center),major_radius=r,minor_radius=tube)
 o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=p(axis).to_track_quat('Z','Y');return finish(o,name,mat)
def ellipsoid(name,center,scale,mat):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=p(center));o=bpy.context.object;o.scale=p((scale[0],scale[1],-scale[2]));return finish(o,name,mat)
def tube(name,points,r,mat):
 for i in range(len(points)-1):cylinder(name,points[i],points[i+1],r,mat)
def export(scene,name):
 bpy.ops.object.select_all(action='DESELECT');obs=[o for o in scene.objects if o.type=='MESH']
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_active_scene=True,export_animations=False)
for variant in range(12):
 index=variant%4;fly=4<=variant<8;feeder=variant>=8
 name=['willow','reed','heron','kingfisher'][index]+('_fly' if fly else '_feeder' if feeder else '')
 scene=bpy.data.scenes.new('Rod_'+name);scenes.append(scene);bpy.context.window.scene=scene
 accent=material(name+' wraps',[(.18,.25,.10),(.48,.53,.56),(.65,.35,.075),(.025,.52,.66)][index],.5,.3)
 carbon=material(name+' blank',[(.028,.055,.018),(.025,.045,.075),(.20,.018,.03),(.01,.16,.23)][index],.4,.3)
 reel_metal=material(name+' reel finish',[(.07,.09,.05),(.38,.43,.47),(.45,.21,.055),(.04,.32,.43)][index],.75,.3)
 grip=cork if index in [0,2] else rubber
 # One continuous tapered carbon blank rather than thick segmented sticks.
 cylinder('Tapered carbon blank',(0,0,.19),(0,0,-1.40 if feeder else -1.68),.0065,carbon,.0018 if feeder else .0009)
 if index in [1,3]:
  cylinder('Split grip butt',(0,0,.21),(0,0,.155),.019,grip,.015)
  cylinder('Exposed split seat',(0,0,.155),(0,0,.095),.009,carbon)
  cylinder('Split grip palm',(0,0,.095),(0,0,.055),.015,grip,.019)
 else:cylinder('Rear grip',(0,0,.21),(0,0,.055),.017 if index==0 else .022,grip,.0185)
 cylinder('Butt cap',(0,0,.217),(0,0,.203),.0185,rubber)
 cylinder('Reel seat',(0,0,.052),(0,0,-.082),.012,carbon)
 for z in [.04,.03,-.07,-.08]:cylinder('Machined seat ring',(0,0,z+.003),(0,0,z-.003),.014,steel)
 cylinder('Foregrip',(0,0,-.09),(0,0,-.16),.018 if index<2 else .024,grip,.014)
 if index>=2:
  for z in [-.095,-.15,.065,.20]:cylinder('Premium grip collar',(0,0,z+.005),(0,0,z-.005),.023 if z<0 else .022,accent)
 if index==3:
  for z in [-.105,-.12,-.135]:torus('Ribbed EVA grip',(0,0,z),.022,.002,accent)
 for z in [-.21,-.27]:cylinder('Tier colour band',(0,0,z+.015),(0,0,z-.015),.0075,accent)
 for z in [-.16,-.19,-.24]:cylinder('Thread binding',(0,0,z+.009),(0,0,z-.009),.007,accent)
 # Diminishing ceramic line guides under the spinning rod.
 for i,z in enumerate([-.31,-.55,-.8,-1.02,-1.22,-1.4,-1.55,-1.678]):
  if feeder and z< -1.4:continue
  r=.018*(1-i/9)+.0015;y=-r-.007
  torus('Line guide',(0,y,z),r,.0012,steel);torus('Ceramic ring',(0,y,z),r-.0014,.001,ceramic)
  tube('Guide support',[(0,-.004,z+.024),(0,y-r*.7,z),(0,-.004,z-.019)],.0013,steel)
  cylinder('Guide wrap',(0,0,z+.026),(0,0,z+.008),max(.002,.0055*(1-i/10)),accent)
 # Fly reels have a transverse open-arbor drum and a short direct crank.
 # Spinning reels retain their forward spool, rotor and bail.
 tube('Reel stem',[(0,-.008,.012),(0,-.047,.006),(0,-.071,.041)],.008,reel_metal)
 cylinder('Reel mounting foot',(0,-.012,-.055),(0,-.012,.052),.0045,steel)
 if fly:
  for x in [-.03,.03]:
   torus('Fly reel open rim',(x,-.075,.04),.053,.004,reel_metal,axis=(1,0,0))
   for j in range(8+index*2):
    a=j*math.tau/(8+index*2)
    cylinder('Fly spool spoke',(x,-.075+math.cos(a)*.017,.04+math.sin(a)*.017),(x,-.075+math.cos(a)*.05,.04+math.sin(a)*.05),.0028,accent)
  cylinder('Fly reel arbor',(-.033,-.075,.04),(.033,-.075,.04),.018,reel_metal)
  cylinder('Fly line backing',(-.023,-.075,.04),(.023,-.075,.04),.036,line)
  cylinder('Fly drag dial',(.031,-.075,.04),(.039,-.075,.04),.014,rubber)
 else:
  scale=1.0+index*.09
  ellipsoid('Gear housing',(0,-.081,.042),(.025*scale,.032*scale,.042),reel_metal)
  cylinder('Spool axle',(0,-.081,.018),(0,-.081,-.074),.006,steel)
  cylinder('Spool',(0,-.081,-.035),(0,-.081,-.071),.024*scale,reel_metal)
  cylinder('Wound fishing line',(0,-.081,-.039),(0,-.081,-.066),.023*scale,line)
  for z in [-.035,-.071]:torus('Spool lip',(0,-.081,z),.025*scale,.002,accent)
  cylinder('Drag adjustment',(0,-.081,-.074),(0,-.081,-.08),.012,rubber)
  bail=[]
  for j in range(25):
   a=math.pi*j/24;bail.append((.043*math.cos(a),-.081+.043*math.sin(a),-.066-.023*math.sin(a)))
  tube('Bail wire',bail,.0015,steel)
  for side in [-1,1]:tube('Rotor arm',[(side*.022,-.08,.007),(side*.043,-.081,-.066)],.004,accent)
 if not fly:cylinder('Crank spindle',(-.085,-.075,.04),(0,-.075,.04),.004,steel)
 export(scene,name)
scene=bpy.data.scenes.new('Reel_handle');scenes.append(scene);bpy.context.window.scene=scene
# Local pivot matches the existing controller reeling gesture: rotate around local X.
tube('Cranked metal arm',[(0,0,0),(-.008,.037,0),(-.014,.08,0)],.004,steel)
cylinder('Knob spindle',(-.014,.08,0),(-.039,.08,0),.003,steel)
ellipsoid('Reel paddle',(-.035,.08,0),(.014,.023,.014),rubber)
export(scene,'handle')
scene=bpy.data.scenes.new('Fly_reel_handle');scenes.append(scene);bpy.context.window.scene=scene
# Short crank lies against the left spool face, using the existing X-axis pivot.
tube('Fly direct crank',[(0,0,0),(0,.039,0)],.003,steel)
cylinder('Fly crank knob',(0,.039,0),(-.021,.039,0),.007,rubber)
export(scene,'fly_handle')
bpy.data.libraries.write(str(ROOT/'source/rods.blend'),set(scenes),path_remap='RELATIVE',fake_user=True,compress=True)
print('RODS_COMPLETE')
