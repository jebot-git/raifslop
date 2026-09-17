"""Run in an isolated Blender scene (also through Blender MCP). Metres, Z up."""
import bpy, math, random
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/environment/shore_details/authored'
scene=bpy.data.scenes.new('Shore dressing authoring')
bpy.context.window.scene=scene
wood=bpy.data.materials.new('Silvered driftwood');wood.use_nodes=True
bsdf=next(n for n in wood.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
bsdf.inputs['Base Color'].default_value=(.28,.22,.15,1);bsdf.inputs['Roughness'].default_value=.86
rope=bpy.data.materials.new('Weathered mooring rope');rope.use_nodes=True
bsdf=next(n for n in rope.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
bsdf.inputs['Base Color'].default_value=(.32,.25,.14,1);bsdf.inputs['Roughness'].default_value=.9

def tube(vertices,faces,uvs,centres,radii,sides,seed):
 rng=random.Random(seed);start=len(vertices);phase=[rng.uniform(.88,1.12) for _ in range(sides)]
 for i,(c,r) in enumerate(zip(centres,radii)):
  tangent=(centres[min(i+1,len(centres)-1)]-centres[max(i-1,0)]).normalized()
  across=tangent.cross(Vector((0,0,1))).normalized();up=across.cross(tangent).normalized()
  for j in range(sides+1):
   a=2*math.pi*j/sides
   vertices.append(c+r*phase[j%sides]*(across*math.cos(a)+up*math.sin(a)))
   uvs.append((i/(len(centres)-1),j/sides))
 for i in range(len(centres)-1):
  for j in range(sides):
   a=start+i*(sides+1)+j;b=a+sides+1
   faces.append((a,b,b+1,a+1))
 faces.append(tuple(start+j for j in range(sides)))
 faces.append(tuple(start+(len(centres)-1)*(sides+1)+j for j in reversed(range(sides))))

def mesh_object(name,v,f,uv,mat):
 m=bpy.data.meshes.new(name);m.from_pydata(v,[],f);m.update()
 obj=bpy.data.objects.new(name,m);scene.collection.objects.link(obj);m.materials.append(mat)
 layer=m.uv_layers.new(name='Grain')
 for face in m.polygons:
  face.use_smooth=len(face.vertices)==4
  for j,loop in enumerate(face.loop_indices):
   if len(face.vertices)!=4:
    angle=math.tau*j/len(face.vertices)
    layer.data[loop].uv=(2.5+math.cos(angle)*.45,.5+math.sin(angle)*.45)
   else:layer.data[loop].uv=uv[m.loops[loop].vertex_index]
 return obj

v=[];f=[];uv=[]
centres=[Vector((-1.05+i*.15,.025*math.sin(i*.5),.135+.025*math.sin(i*.65))) for i in range(15)]
radii=[.105*(.75+.25*math.sin(i/14*math.pi))*(.65 if i in [0,14] else 1) for i in range(15)]
tube(v,f,uv,centres,radii,14,31)
for base,tip,radius in [(centres[4],Vector((-.12,.43,.23)),.055),(centres[10],Vector((.82,-.37,.25)),.042)]:
 points=[base.lerp(tip,i/5)+Vector((0,0,.03*math.sin(i/5*math.pi))) for i in range(6)]
 tube(v,f,uv,points,[radius*(1-.72*i/5) for i in range(6)],10,42)
log=mesh_object('ForkedDriftwood',v,f,uv,wood)
v=[];f=[];uv=[]
points=[]
for i in range(241):
 t=i/240;a=t*math.tau*3.4;r=.12+t*.34
 points.append(Vector((math.cos(a)*r,math.sin(a)*r,.025+.003*math.sin(a*2))))
# A loose end leads out of the coil.
end=points[-1];direction=(points[-1]-points[-2]).normalized()
points += [end+direction*.04*i+Vector((0,0,.002*math.sin(i))) for i in range(1,10)]
tube(v,f,uv,points,[.019]*len(points),8,5)
coil=mesh_object('MooringCoil',v,f,uv,rope)
def bake_vertex_ao(obj):
 import random
 from mathutils.bvhtree import BVHTree
 mesh=obj.data;mesh.update()
 tree=BVHTree.FromPolygons([v.co for v in mesh.vertices],[list(p.vertices) for p in mesh.polygons],all_triangles=False)
 rng=random.Random(73)
 samples=[]
 for _ in range(24):
  z=rng.random();a=rng.random()*math.tau;r=math.sqrt(1-z*z)
  samples.append(Vector((r*math.cos(a),r*math.sin(a),z)))
 attr=mesh.color_attributes.new(name='ContactAO',type='FLOAT_COLOR',domain='POINT')
 for v in mesh.vertices:
  normal=v.normal.normalized();q=Vector((0,0,1)).rotation_difference(normal)
  occlusion=sum(tree.ray_cast(v.co+normal*.0015,q@d,.25)[0] is not None for d in samples)/len(samples)
  ao=max(.28,1-occlusion*.8)
  attr.data[v.index].color=(ao,ao,ao,1)
 mesh.color_attributes.active_color=attr
 mat=mesh.materials[0];nodes=mat.node_tree.nodes
 color=nodes.new('ShaderNodeVertexColor');color.layer_name='ContactAO'
 bsdf=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
 mat.node_tree.links.new(color.outputs['Color'],bsdf.inputs['Base Color'])

# Export each prop at its own origin; preserve the editable authoring scene.
for obj in [log,coil]:
 bake_vertex_ao(obj)
 bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
 bpy.ops.export_scene.gltf(filepath=str(OUT/(obj.name+'.glb')),use_selection=True,use_active_scene=True,export_yup=True)
coil.location=(0,1.5,0)
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  area.spaces.active.region_3d.view_distance=4
  area.spaces.active.region_3d.view_location=(0,.6,0)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source/shore_dressing.blend'))
print({o.name:len(o.data.polygons) for o in [log,coil]})
