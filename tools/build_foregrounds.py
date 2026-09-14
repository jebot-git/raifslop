"""Blender: build four metre-scaled location meshes and explicit collision proxies.
Invoke build('lakeside') etc through Blender MCP, then finish().
All geometry is authored here; photographed PBR maps retain their CC0 sources.
"""
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'source/models/locations';OUT.mkdir(parents=True,exist_ok=True)
TEX=ROOT/'source/textures/foreground'
SCENES=[];RECORDS={};MATS={}
def material(name,color,texture=None,metal=0,rough=.8):
 m=bpy.data.materials.new('FG_'+name);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal
 if texture:
  for suffix,socket in [('Diffuse','Base Color'),('Rough','Roughness'),('nor_gl','Normal')]:
   path=TEX/(texture+'_'+suffix+'.jpg')
   if not path.exists():continue
   n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=bpy.data.images.load(str(path),check_existing=True)
   if suffix!='Diffuse':n.image.colorspace_settings.name='Non-Color'
   if suffix=='nor_gl':
    normal=m.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.5
    m.node_tree.links.new(n.outputs['Color'],normal.inputs['Color']);m.node_tree.links.new(normal.outputs['Normal'],bs.inputs[socket])
   else:m.node_tree.links.new(n.outputs['Color'],bs.inputs[socket])
 MATS[name]=m
 return m
material('timber',(.5,.38,.25),'brown_planks_03')
material('concrete',(.6,.6,.55),'concrete_floor_02')
material('gravel',(.47,.42,.3),'gravelly_sand')
material('mud',(.2,.18,.13),'gravelly_sand')
material('bank',(.3,.34,.2),'aerial_grass_rock')
material('stone',(.4,.38,.33),'concrete_floor_02')
material('steel',(.26,.3,.31),metal=.8,rough=.35)
material('paint',(.23,.34,.31),metal=.35,rough=.52)
material('rubber',(.035,.04,.038),rough=.9)
material('rope',(.35,.29,.18),rough=1)
material('grass',(.23,.25,.12),rough=1)
material('reed',(.34,.28,.16),rough=1)
material('wood_end',(.29,.23,.16),rough=.9)
material('seat',(.30,.34,.31),rough=.8)
# A genuinely grey wood variation, derived in Blender from the photographed diffuse.
image=bpy.data.images.load(str(TEX/'brown_planks_03_Diffuse.jpg'),check_existing=False)
pixels=list(image.pixels)
for i in range(0,len(pixels),4):
 grey=.2126*pixels[i]+.7152*pixels[i+1]+.0722*pixels[i+2]
 pixels[i]=grey*.83;pixels[i+1]=grey*.86;pixels[i+2]=grey*.87
image.pixels[:]=pixels;image.filepath_raw=str(TEX/'weathered_timber_Diffuse.jpg');image.file_format='JPEG';image.save()
material('weathered',(.45,.46,.45),'weathered_timber')

def cv(p):return (p[0],-p[2],p[1])
def build(id):
 rng=random.Random(246+len(id));scene=bpy.data.scenes.new('Foreground_'+id);SCENES.append(scene)
 groups={};collision=[]
 def face(mat,points):
  verts,faces=groups.setdefault(mat,([],[]));start=len(verts);verts.extend(cv(p) for p in points);faces.append(tuple(range(start,start+len(points))))
 def box(mat,p,d,rot=0):
  x,y,z=p;w,h,l=[a/2 for a in d];c=math.cos(rot);s=math.sin(rot)
  pts=[(x+u*c+v*s,y+b,z-u*s+v*c) for u,b,v in [(-w,-h,-l),(w,-h,-l),(w,-h,l),(-w,-h,l),(-w,h,-l),(w,h,-l),(w,h,l),(-w,h,l)]]
  for inds in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:face(mat,[pts[i] for i in reversed(inds)])
 def col(p,d,role='barrier',rot=0):collision.append({'position':list(p),'size':list(d),'yaw':rot,'role':role})
 def slab(mat,p,d):box(mat,p,d);col(p,d,'floor')
 def beam(mat,a,b,r,sides=8):
  a=Vector(a);b=Vector(b);axis=(b-a).normalized();u=axis.cross(Vector((0,1,0)))
  if u.length<.01:u=axis.cross(Vector((1,0,0)))
  u.normalize();v=axis.cross(u)
  aa=[a+r*(u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides)) for i in range(sides)];bb=[q+b-a for q in aa]
  face(mat,list(reversed(aa)));face(mat,bb)
  for i in range(sides):j=(i+1)%sides;face(mat,[aa[i],aa[j],bb[j],bb[i]])
 def rail(a,b,mat='timber',height=.85):
  aa=Vector((a[0],0,a[1]));bb=Vector((b[0],0,b[1]));length=(bb-aa).length;n=math.ceil(length/1.8)
  for i in range(n+1):
   p=aa.lerp(bb,i/n);beam(mat,p-Vector((0,.18,0)),p+Vector((0,height+.05,0)),.045)
  for h in [height*.5,height]:beam(mat,aa+Vector((0,h,0)),bb+Vector((0,h,0)),.025 if mat=='steel' else .033)
  center=(aa+bb)/2+Vector((0,height/2,0));direction=bb-aa
  col(center,(.11,height+.1,length+.08),'barrier',math.atan2(direction.x,direction.z))
 def rock(x,z,size):
  center=(x,-.20,z);rings=[]
  for y,r in [(-.18,.7),(.18,1),(.65,.55)]:
   rings.append([(x+math.cos(i*math.tau/7)*size*r*(.85+rng.random()*.3),y*size,z+math.sin(i*math.tau/7)*size*r*(.85+rng.random()*.3)) for i in range(7)])
  face('stone',rings[0]);face('stone',list(reversed(rings[-1])))
  if z>-2.2:col((x,.22*size,z),(size*1.1,size*.5,size*1.1),'prop')
  for j in range(2):
   for i in range(7):k=(i+1)%7;face('stone',[rings[j+1][i],rings[j+1][k],rings[j][k],rings[j][i]])
 def plants(x,z,count,reed=False):
  for i in range(count):
   px=x+rng.uniform(-.6,.6);pz=z+rng.uniform(-.6,.6);h=rng.uniform(.55,1.25) if reed else rng.uniform(.2,.5);y=-.22 if reed else .0
   top=(px+rng.uniform(-.15,.15),y+h,pz+rng.uniform(-.15,.15));mat='reed' if reed else 'grass'
   # Crossed narrow leaves and occasional seed heads; opaque low-poly geometry.
   for axis in [0,1]:
    width=.015 if reed else .035
    a=(px-width if axis==0 else px,y,pz-width if axis else pz)
    b=(px+width if axis==0 else px,y,pz+width if axis else pz)
    face(mat,[a,b,top]);face(mat,[top,b,a])
   if reed and i%3==0:beam('wood_end',Vector(top)-Vector((0,.15,0)),top,.02,5)
 def planks(x,z,w,l,mat='timber'):
  count=math.ceil(l/.18)
  for i in range(count):
   zz=z-l/2+(i+.5)*l/count
   box(mat,(x,-.065+rng.uniform(-.003,.003),zz),(w,.12,l/count-.008))
  col((x,-.10,z),(w,.2,l),'floor')
  for xx in [x-w*.36,x+w*.36]:box('wood_end',(xx,-.23,z),(.14,.22,l+.1))
 def bench(x,z):
  for dz in [-.19,0,.19]:box('timber',(x,.47,z+dz),(1.8,.055,.17))
  for yy in [.77,.98]:box('timber',(x,yy,z+.28),(1.8,.16,.055))
  for dx in [-.68,.68]:
   beam('steel',(x+dx,0,z-.2),(x+dx,.45,z-.2),.035);beam('steel',(x+dx,0,z+.23),(x+dx,1.07,z+.23),.035)
  col((x,.48,z),(1.85,1.0,.7),'seat')
 def cleat(x,z):
  box('steel',(x,.12,z),(.18,.12,.10));beam('steel',(x-.2,.20,z),(x+.2,.20,z),.035)
 def coil(x,z):
  for k in range(3):
   r=.13+k*.022
   for i in range(24):
    a=i*math.tau/24;b=(i+1)*math.tau/24
    beam('rope',(x+math.cos(a)*r,.035,z+math.sin(a)*r),(x+math.cos(b)*r,.035,z+math.sin(b)*r),.012,5)
 def land(front,mat='bank'):
  # Continuous sloped mainland reaches beyond the water plane, behind protected play areas.
  xs=list(range(-120,121,4)); rows=[0,1.8,5,12,25,50,90,150]
  def point(x,depth):
   z=front(x)+depth
   y=-.65 if depth==0 else -.10 if depth==1.8 else min(1.8,depth*.024)+.12*math.sin(x*.14)
   if (id=='lakeside' and abs(x)<=8 and z<=25) or (id=='gray_pier' and abs(x)<=4.5 and z<=10) or (id=='lake_pier' and abs(x)<=5 and z<=9): y=min(y,-.10)
   return (x,y,z)
  for i in range(len(xs)-1):
   for j in range(len(rows)-1):
    a=point(xs[i],rows[j]);b=point(xs[i+1],rows[j]);c=point(xs[i+1],rows[j+1]);d=point(xs[i],rows[j+1])
    face(mat,[d,c,b,a])
  scene['shore_connected']=True
 spawn=[0,.02,.65]
 if id=='lakeside':
  land(lambda x:-3.5 if abs(x)<=8 else -3.5+min(12,(abs(x)-8)*.27)+.8*math.sin(x*.21))
  slab('gravel',(0,-.24,5.3),(16,.48,15.4))
  # An irregular stony water margin; low kerb keeps feet on the supported shore.
  for i in range(24):rock(-7.8+i*.68,-2.55+rng.uniform(-.22,.08),rng.uniform(.28,.55))
  col((0,.22,-2.4),(16,.5,.25))
  for side in [-1,1]:
   rail((side*7.8,-2.1),(side*7.8,12.7),height=.85)
   for j in range(18):
    rock(side*rng.uniform(6.8,7.5),rng.uniform(-1.5,12),rng.uniform(.2,.55));plants(side*7.1,rng.uniform(-1,12),12)
  rail((-7.8,12.8),(7.8,12.8))
  bench(-4,7);bench(4,9)
  for x in [-6.2,6.2]:
   for z in [-3.4,-4.4]:plants(x,z,30,True)
 elif id=='lake_pier':
  land(lambda x:7.0,'concrete')
  slab('concrete',(0,-.35,3),(10,.7,12))
  # Expansion joints, capped quay edge and metal bollards.
  for x in [-5,-2.5,0,2.5,5]:box('rubber',(x,.002,3),(.018,.008,12))
  for z in [-3,0,3,6,9]:box('rubber',(0,.002,z),(10,.008,.018))
  for x in [-5,5]:
   rail((x,-3),(x,9),'steel',.95)
   box('concrete',(x,-.02,3),(.26,.16,12.2))
  rail((-5,9),(5,9),'steel',.95)
  rail((-5,-3),(5,-3),'steel',.75)
  for x in [-4,-2,2,4]:
   beam('steel',(x,0,-2.65),(x,.42,-2.65),.10,12);beam('steel',(x-.18,.35,-2.65),(x+.18,.35,-2.65),.045)
  bench(-3,6);bench(3,6)
  coil(-4,-2.2);cleat(4,-2.4)
  # Fender strips on the outer face of the harbour wall.
  for x in [-4,-2,0,2,4]:box('rubber',(x,-.3,-3.07),(.24,.5,.12))
 elif id=='gray_pier':
  land(lambda x:4.4+.5*math.sin(x*.2))
  planks(0,1,1.8,10,'weathered');planks(0,-4.5,4.8,3,'weathered')
  slab('mud',(0,-.23,8),(9,.46,4))
  for x in [-.9,.9]:rail((x,-3),(x,6),'weathered',.8)
  rail((-2.4,-6),(2.4,-6),'weathered',.65)
  rail((-2.4,-6),(-2.4,-3),'weathered',.8);rail((2.4,-6),(2.4,-3),'weathered',.8)
  rail((-2.4,-3),(-.9,-3),'weathered',.8);rail((.9,-3),(2.4,-3),'weathered',.8)
  for x in [-.72,.72]:
   for z in [-5.8,-3,0,3,5.8]:beam('wood_end',(x,-1.1,z),(x,-.14,z),.09)
  rail((-4.5,6),(-.9,6),'weathered');rail((.9,6),(4.5,6),'weathered')
  rail((-4.5,6),(-4.5,10),'weathered');rail((4.5,6),(4.5,10),'weathered');rail((-4.5,10),(4.5,10),'weathered')
  for side in [-1,1]:
   for z in range(-2,10):plants(side*rng.uniform(1.8,4),z,28,True)
  bench(-2.9,8.5);coil(1.7,-4.8)
 elif id=='bell_park_pier':
  land(lambda x:8+.8*math.sin(x*.2))
  # Shore-connected landing stage and piles behind the transom.
  planks(0,6.4,2.4,7.2,'weathered');planks(0,3.5,7,1.4,'weathered')
  for x in [-3,3]:
   beam('wood_end',(x,-1,3.5),(x,.45,3.5),.12);cleat(x,3.5)
  for x in [-1,1]:
   for z in [4,7,9]:beam('wood_end',(x,-1,z),(x,-.15,z),.10)
  # Stable, moored boat: broad stern and tapered bow, with a low continuous gunwale.
  plan=[(-1.55,2.5),(1.55,2.5),(1.55,-1.6),(.85,-3.1),(0,-3.7),(-.85,-3.1),(-1.55,-1.6)]
  for i,a in enumerate(plan):
   b=plan[(i+1)%len(plan)]
   face('paint',[(a[0],.53,a[1]),(b[0],.53,b[1]),(b[0]*.72,-.48,b[1]*.92),(a[0]*.72,-.48,a[1]*.92)])
   aa=(a[0],.55,a[1]);bb=(b[0],.55,b[1]);beam('steel',aa,bb,.055)
   direction=Vector((b[0]-a[0],0,b[1]-a[1]));mid=((a[0]+b[0])/2,.24,(a[1]+b[1])/2)
   box('paint',mid,(.10,.5,direction.length),math.atan2(direction.x,direction.z));col(mid,(.14,.65,direction.length+.05),'barrier',math.atan2(direction.x,direction.z))
  # Floor follows the hull outline, no invisible rectangular platform outside the bow.
  face('timber',[(x,0,z) for x,z in plan])
  collision.append({'points':[[x,y,z] for y in [-.20,0] for x,z in plan], 'role':'floor'})
  for z in [i*.2-1.6 for i in range(21)]:box('wood_end',(0,.003,z),(2.9,.008,.006))
  box('seat',(0,.34,1.65),(2.8,.15,.42));col((0,.3,1.65),(2.85,.7,.45),'seat')
  for x in [-1.15,1.15]:box('steel',(x,.14,1.65),(.10,.3,.38))
  # Outboard housing and shaft, transom details and a stowed tackle box.
  box('rubber',(0,.47,2.72),(.55,.5,.45));box('steel',(0,-.18,2.86),(.12,.8,.14))
  beam('steel',(-.2,-.51,2.87),(.2,-.51,2.87),.035)
  box('paint',(1.04,.18,.2),(.48,.36,.6));box('seat',(1.04,.38,.2),(.50,.06,.62));col((1.04,.22,.2),(.5,.44,.62),'seat')
  for x in [-1.3,1.3]:cleat(x,2.25)
  coil(-1.0,1.15)
  # Visible mooring lines, no boat bobbing or unstable player motion.
  beam('rope',(-1.3,.2,2.25),(-3,.20,3.5),.022)
  beam('rope',(1.3,.2,2.25),(3,.20,3.5),.022)
  spawn=[0,.02,.35]
 else:raise ValueError(id)
 objects=[]
 for mat,(vertices,faces) in groups.items():
  mesh=bpy.data.meshes.new(id+'_'+mat);mesh.from_pydata(vertices,[],faces);mesh.update()
  uv=mesh.uv_layers.new(name='UVMap')
  for poly in mesh.polygons:
   normal=poly.normal;axis=max(range(3),key=lambda i:abs(normal[i]));axes=[i for i in range(3) if i!=axis]
   for loop in poly.loop_indices:
    co=mesh.vertices[mesh.loops[loop].vertex_index].co;uv.data[loop].uv=(co[axes[0]]*(.08 if mat=='bank' else .5),co[axes[1]]*(.08 if mat=='bank' else .5))
  ob=bpy.data.objects.new(id+'_'+mat,mesh);scene.collection.objects.link(ob);ob.data.materials.append(MATS[mat]);objects.append(ob)
 # Export only this scene and retain separate material batches (not thousands of nodes).
 old=bpy.context.window.scene;bpy.context.window.scene=scene
 with bpy.context.temp_override(scene=scene,view_layer=scene.view_layers[0]):
  bpy.ops.export_scene.gltf(filepath=str(OUT/(id+'.glb')),export_format='GLB',use_active_scene=True,export_yup=True,export_apply=True)
 triangles=sum(sum(len(p.vertices)-2 for p in ob.data.polygons) for ob in objects)
 RECORDS[id]={'model':'res://assets/models/locations/lit/'+id+'.glb','spawn':spawn,'colliders':collision,'triangles':triangles,'shore_connected':True,'material_batches':len(objects),'bytes':(OUT/(id+'.glb')).stat().st_size}
 bpy.context.window.scene=old
 print(id,triangles,'triangles',len(objects),'batches',len(collision),'colliders')
 return scene

def finish():
 (ROOT/'assets/models/locations/manifest.json').write_text(json.dumps(RECORDS,indent=2))
 bpy.data.libraries.write(str(ROOT/'source/foregrounds.blend'),set(SCENES),path_remap='RELATIVE',fake_user=True,compress=True)
 print('Saved four foregrounds and collision manifest')

if __name__ == '__main__':
 for location in ['lakeside','lake_pier','gray_pier','bell_park_pier']:build(location)
 finish()
