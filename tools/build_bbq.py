"""Original BBQ assets. Run in Blender (or via Blender MCP). Metres, Godot Y-up."""
import bpy, math, random
from mathutils import Vector
from pathlib import Path
ROOT = Path('/home/blux/raifslop')
OUT = ROOT / 'assets/models/bbq'
OUT.mkdir(parents=True, exist_ok=True)
rng = random.Random(421)
scene = bpy.context.scene
created = []

def xyz(v): return (v[0], -v[2], v[1])
def mat(name, color, metal=0, rough=.5, emit=0):
    m = bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    n=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    n.inputs['Base Color'].default_value=(*color,1)
    n.inputs['Metallic'].default_value=metal; n.inputs['Roughness'].default_value=rough
    n.inputs['Emission Color'].default_value=(*color,1); n.inputs['Emission Strength'].default_value=emit
    return m
steel=mat('Brushed stainless',(.40,.46,.48),.85,.27)
enamel=mat('Deep teal enamel',(.025,.105,.115),.45,.24)
black=mat('Cast iron',(.022,.027,.030),.5,.72)
wood=mat('Warm ash wood',(.42,.24,.10),0,.60)
cream=mat('Warm porcelain',(.89,.85,.69),.05,.26)
coal=mat('Charcoal',(.018,.014,.012),0,.95)
ember=mat('Embers',(.9,.11,.008),0,.7,2.2)
ice=mat('Ice',(.59,.78,.84),.2,.23)
bun=mat('Golden brioche',(.67,.31,.085),0,.64)
crumb=mat('Fish patty',(.58,.36,.15),0,.83)
lettuce=mat('Lettuce',(.17,.32,.035),0,.6)
seed=mat('Sesame',(.88,.77,.48),0,.73)
label=mat('Beer label',(.88,.58,.17),.25,.4)

def finish(o,name,m):
    o.name=name; o.data.materials.append(m); created.append(o)
    return o

def box(name, p, size, m, bevel=.006):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz(p)); o=bpy.context.object
    o.scale=(size[0],size[2],size[1]); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        b=o.modifiers.new('Soft manufactured edges','BEVEL'); b.width=bevel; b.segments=3
        bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=b.name)
    return finish(o,name,m)

def cyl(name,p,r,h,m,vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=h,location=xyz(p)); o=bpy.context.object
    b=o.modifiers.new('Rolled edge','BEVEL'); b.width=min(.003,h*.2); b.segments=2
    bpy.ops.object.modifier_apply(modifier=b.name)
    for f in o.data.polygons:f.use_smooth=True
    return finish(o,name,m)

def ball(name,p,scale,m):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=1,location=xyz(p)); o=bpy.context.object
    o.scale=(scale[0],scale[2],scale[1]); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for f in o.data.polygons:f.use_smooth=True
    return finish(o,name,m)

def bar(name,a,b,r,m):
    mid=tuple((a[i]+b[i])/2 for i in range(3)); d=Vector(xyz(b))-Vector(xyz(a))
    o=cyl(name,mid,r,d.length,m,12); o.rotation_mode='QUATERNION'; o.rotation_quaternion=d.to_track_quat('Z','Y'); return o

def export(name):
    # Join by material to keep the mobile draw count small.
    objects=list(created)
    groups={}
    for o in objects: groups.setdefault(o.data.materials[0],[]).append(o)
    joined=[]
    for material,group in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in group:o.select_set(True)
        bpy.context.view_layer.objects.active=group[0]
        if len(group)>1: bpy.ops.object.join()
        group[0].name=material.name; joined.append(group[0])
    bpy.ops.object.select_all(action='DESELECT')
    for o in joined: o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),use_selection=True, use_active_scene=True)
    saved=bpy.data.scenes.new('Asset_'+name)
    for o in joined:
        copy=o.copy(); saved.collection.objects.link(copy)
        bpy.data.objects.remove(o,do_unlink=True)
    created.clear()

# Raised portable charcoal grill, side prep board, low cooler stand.
for x in [-.27,.27]:
    for z in [-.19,.19]:
        bar('Folding leg',(x,.05,z*1.35),(x*.8,.83,z),.018,steel)
        box('Rubber foot',(x,.035,z*1.35),(.07,.035,.065),black)
box('Lower shelf',(0,.23,0),(.56,.025,.42),black)
box('Firebox base',(0,.76,0),(.62,.06,.46),enamel,.025)
for x in [-.31,.31]:box('Firebox side',(x,.825,0),(.025,.13,.46),enamel)
for z in [-.23,.23]:box('Firebox wall',(0,.825,z),(.64,.13,.025),enamel)
for i in range(45):
    x=rng.uniform(-.27,.27);z=rng.uniform(-.19,.19)
    ball('Coal',(x,.803+rng.uniform(0,.016),z),(.038,.022,.029),coal)
    if i%3==0:ball('Hot core',(x+.012,.82,z),(.016,.006,.017),ember)
for i in range(20):bar('Grate',(-.29+i*.0305,.906,-.22),(-.29+i*.0305,.906,.22),.004,steel)
for z in [-.20,.20]:bar('Grate brace',(-.31,.899,z),(.31,.899,z),.006,black)
for x in [-.35,.35]:
    bar('Handle',(x,.86,-.12),(x,.86,.12),.014,wood)
for i in range(6):
    box('Vent',(i*.065-.16,.80,.244),(.035,.027,.003),black,.007)
# Side worktop with individual slats, serving plate and inset metal rim.
for i in range(7):box('Prep slat',(-.64,.86,-.21+i*.067),(.50,.035,.058),wood)
for x in [-.83,-.45]:bar('Prep leg',(x,.04,.12),(x,.84,.12),.015,steel)
cyl('Plate',(-.65,.887,0),.205,.018,cream,64)
cyl('Plate well',(-.65,.899,0),.178,.006,cream,64)
box('Cooler stand',(.66,.46,0),(.48,.04,.40),wood)
for x in [.47,.85]:
    for z in [-.15,.15]:bar('Stand leg',(x,.04,z),(x,.45,z),.014,steel)
export('station')

# Hollow cooler; separate lid rotates around the rear hinge.
box('Cooler bottom',(0,.027,0),(.43,.054,.34),enamel,.022)
for x in [-.207,.207]:box('Insulated side',(x,.19,0),(.036,.34,.34),enamel,.012)
for z in [-.153,.153]:box('Insulated wall',(0,.19,z),(.40,.34,.036),enamel,.012)
for x in [-.184,.184]:box('White inner liner',(x,.20,0),(.013,.30,.286),cream,.004)
for z in [-.131,.131]:box('White inner liner',(0,.20,z),(.37,.30,.013),cream,.004)
for i in range(24):
    o=box('Ice cube',(rng.uniform(-.16,.16),.10+rng.uniform(0,.025),rng.uniform(-.11,.11)),(.044,.027,.035),ice,.009)
    o.rotation_euler.z=rng.random()*math.pi
for x in [-.234,.234]:bar('Carry handle',(x,.16,-.09),(x,.16,.09),.013,steel)
export('cooler')
box('Insulated lid',(0,0,-.17),(.46,.065,.37),cream,.025)
box('Lid insert',(0,-.037,-.17),(.37,.012,.28),black,.006)
box('Latch',(0,-.033,-.363),(.055,.065,.02),steel,.006)
export('cooler_lid')

# Handheld lager can with recessed opening and rolled rims.
cyl('Can',(0,0,0),.033,.116,enamel,48)
cyl('Label',(0,-.003,0),.0332,.079,label,48)
for y in [-.059,.059]:cyl('Rolled rim',(0,y,0),.034,.006,steel,48)
cyl('Recessed top',(0,.060,0),.030,.001,steel,48)
ball('Opening',(0,.061,-.013),(.011,.001,.008),black)
box('Pull tab',(0,.063,.003),(.013,.003,.025),steel,.005)
for y in [-.025,-.012,0,.013,.024]:
    box('Label stripe',(0,y,.033),(.039,.002,.001),cream,.0003)
bpy.ops.object.text_add(location=xyz((-.021,-.008,.0336)),rotation=(math.pi/2,0,0))
t=bpy.context.object; t.data.body='LAGER'; t.data.size=.012; t.data.extrude=.0002
bpy.ops.object.convert(target='MESH'); finish(bpy.context.object,'Lager lettering',cream)
export('beer_can')

# Fish burger has a crisp patty, ruffled greens, sauce, and sesame crown.
ball('Bottom bun',(0,-.030,0),(.080,.020,.077),bun)
cyl('Fish patty',(0,-.006,0),.077,.025,crumb,40)
for i in range(24):
    a=i*math.tau/24
    ball('Crisp crumb',(.074*math.cos(a),-.005,.074*math.sin(a)),(.007,.010,.007),crumb)
for i in range(12):
    a=i*math.tau/12
    ball('Leaf',(.054*math.cos(a),.012,.054*math.sin(a)),(.031,.005,.023),lettuce)
cyl('Sauce',(0,.015,0),.064,.004,cream)
ball('Brioche crown',(0,.032,0),(.080,.033,.077),bun)
for i in range(42):
    x=rng.uniform(-.060,.060);z=rng.uniform(-.056,.056)
    if (x/.074)**2+(z/.071)**2>.83:continue
    y=.032+.033*math.sqrt(1-(x/.080)**2-(z/.077)**2)
    o=ball('Sesame',(x,y,z),(.003,.001,.0015),seed);o.rotation_euler.z=rng.random()*math.pi
export('fish_burger')
for name,at in [('station',(0,0,0)),('cooler',(.66,0,.48)),('cooler_lid',(.66,-.17,.85)),('fish_burger',(-.65,0,.95))]:
    asset=bpy.data.scenes.get('Asset_'+name)
    for original in asset.objects:
        o=original.copy(); scene.collection.objects.link(o); o.location+=Vector(at)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source/bbq_quality.blend'))
print('Exported BBQ assets to',OUT)
