"""Location-specific minigolf scenery. Run through Blender MCP; leaves existing art intact."""
import bpy, math, random
from pathlib import Path
from mathutils import Vector
ROOT=Path('/home/blux/Documents/Real AI Fishing')
OUT=ROOT/'assets/minigolf/models'
name='Minigolf Location Art v2'
collection=bpy.data.collections.get(name)
if collection is None:
 collection=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(collection)
# Regenerate only this tool's dedicated collection.
for previous in list(collection.objects):
 if previous.name.startswith('MG2 '):bpy.data.objects.remove(previous,do_unlink=True)
def mat(name,hexcolor,metal=0):
 m=bpy.data.materials.get('MG2 '+name) or bpy.data.materials.new('MG2 '+name);m.use_nodes=True
 srgb=tuple(int(hexcolor[i:i+2],16)/255 for i in (0,2,4))
 color=tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in srgb)
 node=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 node.inputs['Base Color'].default_value=(*color,1);node.inputs['Roughness'].default_value=.83;node.inputs['Metallic'].default_value=metal
 m.diffuse_color=(*color,1);m.use_backface_culling=False
 return m
stone=mat('Stone warm','8c826e');granite=mat('Stone granite','979d99');darkrock=mat('Stone wet','535f56');snow=mat('Snow','e3e9e2')
wood=mat('Wood cedar','69503b');bleached=mat('Wood driftwood','aea58b');moss=mat('Moss','586b39');green=mat('Leaves','456345');dry=mat('Dry grass','a49b67');reed=mat('Reed stalk','8e8a53');seed=mat('Seed heads','70583c');rope=mat('Rope','b1a07d');metal=mat('Metal iron','364b4f',.6);red=mat('Paint red','b75d42');cream=mat('Shell','d9cdb3');yellow=mat('Petals','d9c476')
def register(o,label,m):
 o.name='MG2 '+label
 for c in list(o.users_collection):c.objects.unlink(o)
 collection.objects.link(o);o.data.materials.append(m);return o
def rock(loc,scale,m,seedval=0):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=loc)
 o=register(bpy.context.object,'weathered rock',m);o.scale=scale
 rng=random.Random(seedval)
 for v in o.data.vertices:v.co*=rng.uniform(.91,1.09)
 return o
def stem(a,b,r,m,r2=None):
 a=Vector(a);b=Vector(b);delta=b-a
 bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=r,radius2=r if r2 is None else r2,depth=delta.length,location=(a+b)/2)
 o=register(bpy.context.object,'stem',m);o.rotation_euler=delta.to_track_quat('Z','Y').to_euler();return o
def leaf(a,b,width,m):
 a=Vector(a);b=Vector(b);d=b-a;side=Vector((-d.y,d.x,0)).normalized()*width
 middle=a+d*.52+Vector((0,0,.06));verts=[a,middle-side,b,middle+side,middle+Vector((0,0,.025))]
 mesh=bpy.data.meshes.new('folded leaf');mesh.from_pydata(verts,[],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)])
 o=bpy.data.objects.new('MG2 leaf',mesh);collection.objects.link(o);mesh.materials.append(m)
def grass(m=green,flower=False):
 for i in range(16):
  angle=i*2.4;r=.06+(i%3)*.027;height=.25+(i%5)*.065
  a=(math.cos(angle)*r,math.sin(angle)*r,.025);b=(math.cos(angle)*.24,math.sin(angle)*.24,height)
  leaf(a,b,.018+(i%2)*.008,m)
  if flower and i%4==0:
   stem(a,b,.006,green)
   rock(b,(.026,.026,.018),yellow,i)
def pebbles():
 for i,(x,y,r) in enumerate([(-.12,.04,.14),(.1,.08,.13),(.04,-.12,.11),(-.12,-.12,.08)]):rock((x,y,r*.4),(r,r*.82,r*.55),stone,i)
 grass(dry)
def outcrop():
 rock((-.07,0,.19),(.20,.23,.23),granite,2);rock((.15,.02,.1),(.13,.18,.13),granite,3)
 for i in range(4):rock((-.19+i*.09,-.12,.12),(.06,.05,.025),moss,i)
def driftwood():
 stem((-.23,0,.06),(.23,.02,.12),.075,bleached,.045)
 stem((-.04,0,.085),(.12,.17,.26),.032,bleached,.011)
 stem((.07,0,.09),(.19,-.14,.18),.027,bleached,.007)
 for i in range(3):rock((-.15+i*.11,-.10,.045),(.055,.043,.035),cream,i)
def cattails():
 for i in range(9):
  a=i*2.4;x=math.cos(a)*.15;y=math.sin(a)*.15;h=.43+(i%4)*.09
  stem((x,y,0),(x+.025,y,h),.008,reed)
  stem((x+.025,y,h-.08),(x+.025,y,h+.045),.022,seed)
  leaf((x,y,.04),(x+math.cos(a)*.11,y+math.sin(a)*.11,h*.67),.02,dry)
def fern():
 for i in range(7):
  angle=i*math.tau/7;d=Vector((math.cos(angle),math.sin(angle),0));end=d*.26+Vector((0,0,.30))
  stem((0,0,.025),end,.007,green)
  for k in range(1,6):
   t=k/6;at=end*t;side=Vector((-d.y,d.x,0))*(.12*(1-t)+.02)
   for sign in [-1,1]:leaf(at,at+side*sign+d*.035,.018,green)
def cedar():
 stem((-.07,0,0),(-.03,0,.45),.15,wood,.115)
 for i in range(4):
  a=i*1.57;stem((0,0,.09),(math.cos(a)*.23,math.sin(a)*.23,.015),.05,wood,.012)
 rock((-.08,-.02,.45),(.11,.1,.018),moss,3)
 fern()
def alpine():
 rock((-.04,0,.17),(.23,.22,.23),granite,5)
 rock((-.055,.025,.325),(.21,.18,.05),snow,6)
 rock((.15,-.1,.07),(.11,.12,.08),darkrock,7)
def shellbank():
 rock((0,0,.018),(.26,.23,.03),cream,2)
 for i in range(3):
  angle=i*2.2;x=math.cos(angle)*.13;y=math.sin(angle)*.13
  rock((x,y,.055),(.07,.05,.025),cream,i)
 grass(dry)
def mooring():
 stem((0,0,0),(0,0,.45),.14,wood,.13)
 for z in [.13,.36]:
  bpy.ops.mesh.primitive_torus_add(major_radius=.14,minor_radius=.016,major_segments=16,minor_segments=6,location=(0,0,z));register(bpy.context.object,'iron binding',metal)
 for i in range(3):
  bpy.ops.mesh.primitive_torus_add(major_radius=.155,minor_radius=.018,major_segments=16,minor_segments=6,location=(0,0,.20+i*.035));register(bpy.context.object,'mooring rope',rope)
 stem((-.21,0,.39),(.21,0,.39),.035,metal)
def marker():
 stem((0,0,0),(0,0,.65),.065,bleached,.05)
 for z in [.28,.44,.60]:stem((0,0,z),(0,0,z+.065),.067,red)
 rock((0,0,.03),(.23,.20,.05),stone,1)
def export(label,make,index):
 before=set(collection.objects);make();parts=[o for o in collection.objects if o not in before]
 # Join per material: small scene trees and bounded draw calls in VR.
 merged=[]
 groups={}
 for o in parts:groups.setdefault(o.data.materials[0],[]).append(o)
 for m,group in groups.items():
  bpy.ops.object.select_all(action='DESELECT')
  for o in group:o.select_set(True)
  bpy.context.view_layer.objects.active=group[0]
  if len(group)>1:bpy.ops.object.join()
  o=bpy.context.object
  o.name='MG2 '+label+' '+m.name;merged.append(o)
 bpy.ops.object.select_all(action='DESELECT')
 for o in merged:o.select_set(True)
 bpy.context.view_layer.objects.active=merged[0]
 bpy.ops.export_scene.gltf(filepath=str(OUT/(label+'.glb')),use_selection=True,export_yup=True)
 for o in merged:o.location+=Vector(((index%5)*1.3,(index//5)*1.3+4,0))
 print(label, sum(len(o.data.polygons) for o in merged),'polygons')
for i,(label,make) in enumerate([('shore_pebbles',pebbles),('coastal_granite',outcrop),('bleached_driftwood',driftwood),('cattail_clump',cattails),('meadow_grass',lambda:grass(green,True)),('dune_grass',lambda:grass(dry)),('mossy_cedar',cedar),('alpine_granite',alpine),('shell_bank',shellbank),('rope_mooring',mooring),('channel_marker',marker)]):export(label,make,i)
print('Location art collection:',len(collection.objects),'mesh objects')
