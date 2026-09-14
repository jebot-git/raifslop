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
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;s=m.node_tree.nodes.get('Principled BSDF');s.inputs['Base Color'].default_value=(*color,1);s.inputs['Metallic'].default_value=metal;s.inputs['Roughness'].default_value=rough;return m
carbon=material('Satin graphite',(.022,.028,.03),.25,.36);rubber=material('Matte EVA',(.025,.026,.026),0,.78);steel=material('Brushed stainless',(.38,.41,.42),.85,.3);ceramic=material('Ceramic guide inserts',(.055,.06,.06),.12,.26);line=material('Wound nylon',(.26,.29,.23),0,.55)
cork=material('Natural cork',(.5,.33,.18),0,.78)
rng=np.random.default_rng(124);a=rng.random((512,1024));grain=(a>.987).astype(float)
for _ in range(3):grain=np.maximum(grain,np.roll(grain,1,axis=1)*.85)
c=np.zeros((512,1024,4),np.float32);base=np.array([.52,.35,.19]);c[:,:,:3]=base[None,None,:]*(.88+a[:,:,None]*.24-grain[:,:,None]*.5);c[:,:,3]=1
im=bpy.data.images.new('Cork grain',width=1024,height=512);im.pixels.foreach_set(c.ravel());im.pack();t=cork.node_tree.nodes.new('ShaderNodeTexImage');t.image=im;cork.node_tree.links.new(t.outputs['Color'],cork.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
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
for index,name in enumerate(['willow','reed','heron','kingfisher']):
 scene=bpy.data.scenes.new('Rod_'+name);scenes.append(scene);bpy.context.window.scene=scene
 accent=material(name+' wraps',[(.16,.22,.13),(.13,.2,.21),(.26,.22,.13),(.06,.19,.23)][index],.35,.4)
 grip=cork if index in [0,2] else rubber
 # One continuous tapered carbon blank rather than thick segmented sticks.
 cylinder('Tapered carbon blank',(0,0,.19),(0,0,-1.68),.0065,carbon,.0009)
 cylinder('Rear grip',(0,0,.21),(0,0,.055),.017,grip,.0185)
 cylinder('Butt cap',(0,0,.217),(0,0,.203),.0185,rubber)
 cylinder('Reel seat',(0,0,.052),(0,0,-.082),.012,carbon)
 for z in [.04,.03,-.07,-.08]:cylinder('Machined seat ring',(0,0,z+.003),(0,0,z-.003),.014,steel)
 cylinder('Foregrip',(0,0,-.09),(0,0,-.16),.018,grip,.014)
 for z in [-.16,-.19,-.24]:cylinder('Thread binding',(0,0,z+.009),(0,0,z-.009),.007,accent)
 # Diminishing ceramic line guides under the spinning rod.
 for i,z in enumerate([-.31,-.55,-.8,-1.02,-1.22,-1.4,-1.55,-1.678]):
  r=.018*(1-i/9)+.0015;y=-r-.007
  torus('Line guide',(0,y,z),r,.0012,steel);torus('Ceramic ring',(0,y,z),r-.0014,.001,ceramic)
  tube('Guide support',[(0,-.004,z+.024),(0,y-r*.7,z),(0,-.004,z-.019)],.0013,steel)
  cylinder('Guide wrap',(0,0,z+.026),(0,0,z+.008),max(.002,.0055*(1-i/10)),accent)
 # Reel foot, neck, gear housing and forward-facing spool.
 tube('Reel stem',[(0,-.008,.012),(0,-.047,.006),(0,-.071,.041)],.008,carbon)
 cylinder('Reel mounting foot',(0,-.012,-.055),(0,-.012,.052),.0045,steel)
 ellipsoid('Gear housing',(0,-.081,.042),(.025,.032,.042),carbon)
 cylinder('Spool axle',(0,-.081,.018),(0,-.081,-.074),.006,steel)
 cylinder('Spool',(0,-.081,-.035),(0,-.081,-.071),.024,steel)
 cylinder('Wound fishing line',(0,-.081,-.039),(0,-.081,-.066),.023,line)
 for z in [-.035,-.071]:torus('Spool lip',(0,-.081,z),.025,.002,steel)
 cylinder('Drag adjustment',(0,-.081,-.074),(0,-.081,-.08),.012,rubber)
 bail=[]
 for j in range(25):
  a=math.pi*j/24;bail.append((.034*math.cos(a),-.081+.035*math.sin(a),-.066-.023*math.sin(a)))
 tube('Bail wire',bail,.0015,steel)
 for side in [-1,1]:tube('Rotor arm',[(side*.022,-.08,.007),(side*.034,-.081,-.066)],.004,accent)
 cylinder('Crank spindle',(-.085,-.075,.04),(0,-.075,.04),.004,steel)
 export(scene,name)
scene=bpy.data.scenes.new('Reel_handle');scenes.append(scene);bpy.context.window.scene=scene
# Local pivot matches the existing controller reeling gesture: rotate around local X.
tube('Cranked metal arm',[(0,0,0),(-.008,.037,0),(-.014,.08,0)],.004,steel)
cylinder('Knob spindle',(-.014,.08,0),(-.039,.08,0),.003,steel)
ellipsoid('Reel paddle',(-.035,.08,0),(.014,.023,.014),rubber)
export(scene,'handle')
bpy.data.libraries.write(str(ROOT/'source/rods.blend'),set(scenes),path_remap='RELATIVE',fake_user=True,compress=True)
print('RODS_COMPLETE')
