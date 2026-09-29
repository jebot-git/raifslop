"""Original low-poly waterfront props, authored for this project via Blender MCP.
Run in Blender. Existing scene objects are preserved in their collections.
"""
import bpy, math
from pathlib import Path
from mathutils import Vector
ROOT=Path('/home/blux/Documents/Real AI Fishing')
OUT=ROOT/'assets/minigolf/models'
OUT.mkdir(parents=True,exist_ok=True)
collection=bpy.data.collections.get('Waterfront Minigolf Props')
if collection is None:
 collection=bpy.data.collections.new('Waterfront Minigolf Props');bpy.context.scene.collection.children.link(collection)
def material(name,color,metal=0):
 m=bpy.data.materials.get(name) or bpy.data.materials.new(name);m.use_nodes=True
 node=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 node.inputs['Base Color'].default_value=(*color,1);node.inputs['Roughness'].default_value=.7;node.inputs['Metallic'].default_value=metal
 m.diffuse_color=(*color,1);return m
wood=material('MG Cedar',(.24,.105,.045));grain=material('MG Endgrain',(.56,.33,.14));ivory=material('MG Ivory',(.9,.81,.59));red=material('MG Buoy Vermilion',(.67,.12,.045));teal=material('MG Painted Teal',(.04,.29,.29));stone=material('MG Granite',(.4,.43,.41));ice=material('MG Glacial Blue',(.3,.65,.75));reed=material('MG Reeds',(.22,.36,.1));brass=material('MG Brass',(.6,.39,.12),.65)
def register(obj,name,mat):
 obj.name=name
 for c in list(obj.users_collection):c.objects.unlink(obj)
 collection.objects.link(obj);obj.data.materials.append(mat);return obj
def cyl(name,r,h,z,mat,vertices=12,xy=(0,0),top=None):
 bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r if top is None else top,depth=h,location=(xy[0],xy[1],z))
 return register(bpy.context.object,name,mat)
def box(name,loc,size,mat):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=register(bpy.context.object,name,mat);o.scale=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return o
def export(name,make,index):
 before=set(collection.objects);make();parts=[o for o in collection.objects if o not in before]
 bpy.ops.object.select_all(action='DESELECT')
 for o in parts:o.select_set(True)
 bpy.context.view_layer.objects.active=parts[0]
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),use_selection=True,export_yup=True)
 # Show each prop in a non-overlapping gallery after its origin-centred export.
 for o in parts:o.location.x+=(index%4)*1.6;o.location.y+=(index//4)*1.6
 print(name, sum(len(o.data.polygons) for o in parts),'faces')
def buoy():
 cyl('Buoy base',.27,.15,.075,teal);cyl('Buoy belly',.25,.32,.3,red,top=.15);cyl('Buoy stripe',.211,.06,.29,ivory,top=.2);cyl('Buoy cap',.14,.13,.525,red,top=.035);cyl('Beacon pin',.025,.16,.63,brass)
def stump():
 cyl('Cedar stump',.28,.37,.185,wood,10,top=.23);cyl('Cut face',.222,.012,.374,grain,10)
 for i in range(5):
  a=i*math.tau/5; o=cyl('Root',.09,.32,.1,wood,6,(math.cos(a)*.21,math.sin(a)*.21),top=.045);o.rotation_euler[1]=.7
 cyl('Heartwood',.08,.014,.382,wood,10)
def cairn():
 for i in range(4):
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(.035*(-1)**i,0,.12+i*.13));o=register(bpy.context.object,'Balanced granite',stone);o.scale=(.29-i*.05,.24-i*.035,.15-i*.018)
def glacier():
 for x,y,h in [(-.13,0,.5),(.07,.08,.68),(.13,-.1,.38)]:
  o=cyl('Ice prism',.11,h/2,h/4,ice,5,(x,y));cyl('Ice tip',.11,h/2,3*h/4,ice,5,(x,y),top=0)
def reeds():
 cyl('Reed island',.27,.09,.045,wood,12)
 for i in range(7):
  a=i*2.4;r=.14*(i%3)/2;x=math.cos(a)*r;y=math.sin(a)*r;h=.42+(i%3)*.07
  cyl('Reed stalk',.012,h,h/2+.05,reed,5,(x,y));cyl('Reed head',.027,.13,h+.05,grain,6,(x,y))
def bollard():
 cyl('Bollard plinth',.27,.06,.03,stone);cyl('Bollard',.16,.32,.22,teal);cyl('Bollard crown',.23,.08,.41,teal);cyl('Brass collar',.17,.045,.28,brass)
def tunnel():
 for x in [-.74,.74]:box('Pier portal', (x,0,.37),(.22,.6,.74),wood)
 box('Weathered lintel',(0,0,.82),(1.72,.62,.16),grain)
 for x in [-.64,.64]:box('Portal strap',(x,-.318,.59),(.055,.016,.55),brass)
def boat():
 cyl('Mooring island',.28,.07,.035,teal)
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=1,location=(0,0,.16));o=register(bpy.context.object,'Toy hull',ivory);o.scale=(.24,.12,.08)
 cyl('Mast',.012,.4,.36,wood,6)
 mesh=bpy.data.meshes.new('Sail');mesh.from_pydata([(0,0,.2),(0,0,.55),(.22,0,.22)],[],[(0,1,2)]);o=bpy.data.objects.new('Sail',mesh);collection.objects.link(o);mesh.materials.append(red)
for i,(name,make) in enumerate([('buoy',buoy),('cedar_stump',stump),('granite_cairn',cairn),('ice_crystals',glacier),('reed_island',reeds),('harbour_bollard',bollard),('timber_portal',tunnel),('regatta_boat',boat)]):export(name,make,i)
# Select the authored collection for viewport review, without deleting the user's scene.
bpy.ops.object.select_all(action='DESELECT')
for o in collection.objects:o.select_set(True)
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  area.spaces.active.region_3d.view_distance=9
  area.spaces.active.region_3d.view_location=Vector((2.4,.8,.2))
  area.spaces.active.shading.color_type='MATERIAL'
print('Created',len(collection.objects),'objects in Waterfront Minigolf Props')
