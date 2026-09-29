"""Original six-seat shore shuttle, moored beside each waterfront minigolf course."""
from pathlib import Path
source=Path('/home/blux/Documents/Real AI Fishing/source/minigolf/build_location_props.py').read_text()
header=source[:source.index('for i,(label,make) in enumerate(')]
exec(header.replace("name='Minigolf Location Art v2'","name='Minigolf Shore Ferry'"))
hullmat=mat('Paint ferry teal','3c6969');inside=mat('Paint ferry ivory','c6bc9e');band=mat('Paint ferry stripe','b97b4d')
def cube(label,loc,size,m):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=register(bpy.context.object,label,m);o.scale=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
def ferry():
 # Open-topped hard-chine launch: beam 2.2 m, length 6.6 m.
 outline=[(-.72,-3.0),(.72,-3.0),(1.1,-1.9),(1.1,1.5),(.65,2.8),(0,3.6),(-.65,2.8),(-1.1,1.5),(-1.1,-1.9)]
 n=len(outline);verts=[(x*.66,y*.9,-.36) for x,y in outline]+[(x,y,.78) for x,y in outline]
 faces=[tuple(reversed(range(n)))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 mesh=bpy.data.meshes.new('Shore shuttle hull');mesh.from_pydata(verts,[],faces)
 o=bpy.data.objects.new('MG2 Shore shuttle hull',mesh);collection.objects.link(o);mesh.materials.append(hullmat)
 for i,(x,y) in enumerate(outline):
  xx,yy=outline[(i+1)%n];stem((x,y,.80),(xx,yy,.80),.07,inside)
 cube('deck',(0,-.1,.42),(1.7,4.9,.12),bleached)
 for y in [-1.8,-.4,1.0]:
  cube('passenger bench',(0,y,.67),(1.8,.40,.12),wood)
  for x in [-.67,.67]:cube('bench support',(x,y,.50),(.09,.32,.35),inside)
 for x in [-.86,.86]:
  for y in [-2.25,1.55]:stem((x,y,.79),(x,y,1.25),.026,metal)
  stem((x,-2.25,1.25),(x,1.55,1.25),.025,rope)
 # Two visible bow cleats and a bright lifebuoy.
 for x in [-.35,.35]:stem((x,2.4,.82),(x,2.4,.95),.04,metal)
 bpy.ops.mesh.primitive_torus_add(major_radius=.25,minor_radius=.065,major_segments=20,minor_segments=8,location=(0,-2.75,.92));register(bpy.context.object,'life ring',band)
 cube('transom plate',(0,-3.02,.38),(1.0,.045,.3),inside)
export('shore_ferry',ferry,0)
