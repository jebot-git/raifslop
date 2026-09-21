"""Reconstruct textured fish from retained side references and reviewed anatomy landmarks.
Run in Blender. Original roach/tench/bream/zander/perch assets are preserved.
"""
import bpy, math, json, sys, numpy as np
from pathlib import Path
from mathutils import Vector
from mathutils.geometry import tessellate_polygon
ROOT=Path(__file__).resolve().parents[1]; REF=ROOT/'source/fish_references'; OUT=ROOT/'assets/models/fish'; TEX=ROOT/'source/textures/fish'
DATA=json.loads((REF/'anatomy.json').read_text()); scenes=[]
sys.path.insert(0,str(ROOT/'tools'))
from fish_fin_geometry import repair_fins
from fish_surface_sampling import BodyUVSampler, inside_region

def build(name,d):
 scene=bpy.data.scenes.new('Photographic_'+name);bpy.context.window.scene=scene;scenes.append(scene)
 im=bpy.data.images.load(str(REF/(name+'.png')),check_existing=False);im.pack();W,H=im.size
 pixels=np.array(im.pixels[:],dtype=np.float32).reshape(H,W,4)
 # Blender pixels are linear; .835 corresponds to .92 in the retained sRGB PNG.
 body_uv=BodyUVSampler(pixels[::-1],d,threshold=.835)
 # Replace white backdrop inside the open mouth with a subdued oral-cavity tone.
 # Retain the untouched reference and its silhouette mask separately.
 corrected=pixels.copy()
 for x in range(int(d['eye'][0]+d['eye'][2]),min(W,int(d['extent'][1])+1)):
  top=np.interp(x,[v[0] for v in d['body']],[v[1] for v in d['body']])
  bottom=np.interp(x,[v[0] for v in d['body']],[v[2] for v in d['body']])
  for y in range(max(0,int(top)),min(H,int(bottom)+1)):
   if pixels[H-1-y,x,:3].min()>.92:corrected[H-1-y,x,:3]=(.085,.035,.022)
 im.pixels.foreach_set(corrected.ravel());im.update()
 im.filepath_raw=str(TEX/(name+'_photographic.png'));im.file_format='PNG';im.save();im.pack()
 mat=bpy.data.materials.new(name+' photographic skin');mat.use_nodes=True;mat.use_backface_culling=False
 p=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');p.inputs['Roughness'].default_value=.42;p.inputs['Metallic'].default_value=.035
 p.inputs['Coat Weight'].default_value=.25;p.inputs['Coat Roughness'].default_value=.27
 tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im;mat.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
 xmin,xmax=d['extent'];length=xmax-xmin;cy=d['center'];thickness=d['thickness']
 def pos(x,y,side=0):return Vector(((x-(xmin+xmax)/2)/length,side,(cy-y)/length*d.get('height_scale',1)))
 def mesh(label,verts,faces,material,coords):
  me=bpy.data.meshes.new(label);me.from_pydata(verts,[],faces);me.materials.append(material);me.update()
  uv=me.uv_layers.new(name='ReferenceUV')
  for f in me.polygons:
   f.use_smooth=True
   for loop in f.loop_indices:
    x,y=coords[me.loops[loop].vertex_index];uv.data[loop].uv=(x/W,1-y/H)
  ob=bpy.data.objects.new(label,me);scene.collection.objects.link(ob);return ob
 # Reviewed dorsal/ventral body landmarks; smooth cubic interpolation preserves a natural muzzle.
 profile=d['body']; dense=[]
 for i in range(len(profile)-1):
  aa=np.array(profile[max(0,i-1)],float);bb=np.array(profile[i],float);cc=np.array(profile[i+1],float);dd=np.array(profile[min(len(profile)-1,i+2)],float)
  for j in range(d.get("profile_steps",6)):
   t=j/d.get("profile_steps",6);v=.5*((2*bb)+(-aa+cc)*t+(2*aa-5*bb+4*cc-dd)*t*t+(-aa+3*bb-3*cc+dd)*t*t*t)
   dense.append(v)
 dense.append(profile[-1]);dense=np.array(dense)
 verts=[];coords=[];faces=[];N=d.get("radial_steps",64)
 for x,top,bottom,width in dense:
  center=(top+bottom)/2;radius=(bottom-top)/2
  for j in range(N+1):
   a=j/N*math.tau;y=center-radius*math.sin(a)
   px=x
   # Keep silhouette samples inside the skin instead of projecting the white backdrop.
   for attempt in range(16):
    sample=pixels[H-1-min(H-1,max(0,int(y))),min(W-1,max(0,int(px))),:3]
    if sample.min()<.92:break
    y+=(center-y)*.12
   if x>d['eye'][0]+d['eye'][2]+15:
    row=pixels[H-1-min(H-1,max(0,int(y))),:,:3].min(axis=1)
    colored=np.where((row<.92)&(np.arange(W)>d['eye'][0]))[0]
    if len(colored):px=min(x,float(colored[-1])-2)
   verts.append(pos(px,y,width*math.cos(a)));coords.append(body_uv.sample(px,y,width*math.cos(a)))
 for i in range(len(dense)-1):
  for j in range(N):
   a=i*(N+1)+j;faces.append((a,a+1,a+N+2,a+N+1))
 faces.extend([tuple(reversed(range(N+1))),tuple((len(dense)-1)*(N+1)+j for j in range(N+1))])
 body=mesh(name+' reconstructed body',verts,faces,mat,coords)
 # Thin fin surfaces follow the photographed contour. Only external fins/tail are kept;
 # body and cheek are fully volumetric, not a billboard.
 mask=(pixels[:,:,:3].min(axis=2)<.94)
 step=d.get("fin_step",3); fv=[];fc=[];ff=[];lookup={}
 def vtx(x,y):
  key=(x,y)
  if key not in lookup:lookup[key]=len(fv);fv.append(pos(x,y));fc.append((x,y))
  return lookup[key]
 for y in range(0,H-step,step):
  for x in range(0,W-step,step):
   yy=y+step/2;xx=x+step/2
   if xx< xmin or xx>xmax:continue
   if d.get('fin_regions') and not any(inside_region(xx,yy,poly) for poly in d['fin_regions']):continue
   if xx>d.get("fin_max_x",1200):continue # cheek and jaws are volumetric; do not duplicate them as a flat fringe
   if not mask[H-1-int(yy),int(xx)]:continue
   if dense[0,0] <= xx <= dense[-1,0]:
    top=np.interp(xx,dense[:,0],dense[:,1]);bottom=np.interp(xx,dense[:,0],dense[:,2])
    if top+4<yy<bottom-4:continue
   corners=[(x,y),(x+step,y),(x+step,y+step),(x,y+step)]
   # Reject white corners to avoid a white fringe around membranes.
   if not all(mask[H-1-min(H-1,int(py)),min(W-1,int(px))] for px,py in corners):continue
   ff.append(tuple(vtx(px,py) for px,py in corners))
 finmat=mat.copy();finmat.name=name+' fin membranes';fp=next(n for n in finmat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');fp.inputs['Roughness'].default_value=.57;fp.inputs['Coat Weight'].default_value=.1
 if d.get('fin_outline_file'):
  # Continuous contours replace the coarse square-cell fringe on reviewed fins.
  fv=[];fc=[];ff=[]
  for outline in json.loads((REF/d['fin_outline_file']).read_text()):
   start=len(fv)
   polygon=[Vector((x,y,0)) for x,y in outline]
   indices={tuple(point):start+i for i,point in enumerate(polygon)}
   fv.extend(pos(x,y) for x,y in outline);fc.extend(outline)
   ff.extend(tuple(start+point if isinstance(point,int) else indices[tuple(point)] for point in triangle) for triangle in tessellate_polygon([polygon]))
 mesh(name+' traced fins',fv,ff,finmat,fc)
 # Paired pectoral fins lift away from the flank, retaining their reference markings.
 for side in [-1,1]:
  poly=d.get('pectoral',[])
  if poly:
   pv=[];pc=[];pf=[];origin=np.array(poly[0],float)
   for j in range(1,len(poly)-1):
    base=len(pv)
    for xy in [origin,np.array(poly[j]),np.array(poly[j+1])]:
     x,y=xy;ok,pt,n,_=body.ray_cast(pos(x,y,side*.35),Vector((0,-side,0)))
     point=pt if ok else pos(x,y,side*thickness*.65)
     point.y+=side*(.001+min(d.get("pectoral_spread",.028),np.linalg.norm(xy-origin)/length*d.get("pectoral_lift",.25)))
     pv.append(point);pc.append((x,y))
    pf.append((base,base+1,base+2) if side>0 else (base+2,base+1,base))
   mesh('Paired pectoral fin',pv,pf,finmat,pc)
 # Two or four tapered sensory barbels, according to species.
 for side in [-1,1]:
  for path in d.get('barbels',[]):
   bv=[];bc=[];bf=[]
   for k,(x,y) in enumerate(path):
    radius=.003*(1-k/len(path))
    for j in range(8):
     a=j/8*math.tau;point=pos(x,y,side*(.012+.003*k))
     point.x+=radius*math.cos(a);point.y+=radius*math.sin(a)
     bv.append(point);bc.append(path[0])
   for k in range(len(path)-1):
    for j in range(8):a=k*8+j;b=k*8+(j+1)%8;bf.append((a,b,b+8,a+8))
   mesh('Sensory barbel',bv,bf,mat,bc)
 # Convex corneas use the reference iris, keeping exact natural eye size and colour.
 eye_mat=mat.copy();eye_mat.name=name+' wet cornea';ep=next(n for n in eye_mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');ep.inputs['Roughness'].default_value=.12;ep.inputs['Coat Weight'].default_value=.7;ep.inputs['Coat Roughness'].default_value=.075;ep.inputs['Metallic'].default_value=0
 ex,ey,er=d['eye']
 for side in [-1,1]:
  ev=[];ec=[];ef=[];R=10;M=48
  for i in range(R+1):
   rr=i/R
   for j in range(M+1):
    angle=j/M*math.tau;x=ex+er*rr*math.cos(angle);y=ey+er*rr*math.sin(angle)
    ok,pt,n,_=body.ray_cast(pos(x,y,side*.35),Vector((0,-side,0)))
    if ok:
     point=pt;point.y+=side*(.0003+.0022*(1-rr*rr))
    else:
     # A rim just above the body profile must sit on the nearest skin;
     # a half-width fallback creates a protruding tube above the eye.
     found,pt,n,_=body.closest_point_on_mesh(pos(x,y))
     point=pt+n*.0003 if found else pos(x,y)
    ev.append(point);ec.append((x,y))
  for i in range(R):
   for j in range(M):
    q=i*(M+1)+j;face=(q,q+1,q+M+2,q+M+1);ef.append(face if side<0 else tuple(reversed(face)))
  mesh('Inset eye cornea',ev,ef,eye_mat,ec)
 # Physical upper/lower lip margins traced directly from the reference; same UV and colour.
 for side in [-1,1]:
  for path in d.get('lips',[]):
   lv=[];lc=[];lf=[]
   for x,y in path:
    for offset in [-1.4,1.4]:
     ok,pt,n,_=body.ray_cast(pos(x,y+offset,side*.35),Vector((0,-side,0)))
     point=pt if ok else pos(x,y+offset,side*.003)
     point.y+=side*.001;lv.append(point);lc.append((x,y+offset))
   for k in range(len(path)-1):lf.append((2*k,2*k+1,2*k+3,2*k+2))
   mesh('Fleshy lip margin',lv,lf,mat,lc)
 # Bake restrained albedo-derived relief; the separate corneas keep their smooth surface.
 bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body
 nodes=mat.node_tree.nodes;links=mat.node_tree.links
 bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.12;bump.inputs['Distance'].default_value=.00035;links.new(tex.outputs['Color'],bump.inputs['Height']);links.new(bump.outputs['Normal'],p.inputs['Normal'])
 try:scene.render.engine='CYCLES'
 except TypeError as error:raise RuntimeError('Cycles is required to bake fish normals') from error
 scene.cycles.samples=8;scene.cycles.device='CPU'
 image=bpy.data.images.new(name+' baked normal',width=1024,height=1024);image.colorspace_settings.name='Non-Color'
 target=nodes.new('ShaderNodeTexImage');target.image=image;nodes.active=target
 bpy.ops.object.bake(type='NORMAL',margin=8,use_clear=True)
 image.filepath_raw=str(TEX/(name+'_baked_normal.png'));image.file_format='PNG';image.save();image.pack()
 normal=nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.35;links.new(target.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],p.inputs['Normal'])
 bpy.ops.object.select_all(action='DESELECT');objects=[o for o in scene.objects if o.type=='MESH']
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=body;bpy.ops.object.join();body.name=name+'_realistic'
 # Normalize all extremities to exactly one metre; journal sizing and mouth anchoring stay valid.
 lo=min(v.co.x for v in body.data.vertices);hi=max(v.co.x for v in body.data.vertices)
 for v in body.data.vertices:v.co.x=(v.co.x-(lo+hi)/2)/(hi-lo);v.co.y/=(hi-lo);v.co.z/=(hi-lo)
 # Continuous contours already overlap the skin. Projecting their small rays
 # onto the nearest body surface would fold the fin tips into square stubs.
 repair_fins(body,photographic=True,anchor_roots=not d.get('fin_outline_file'));body['fin_roots_repaired']=True
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_active_scene=True,export_animations=False)
 print('PHOTOGRAPHIC_FISH_COMPLETE',name,flush=True)

if __name__ == "__main__":
 for name,data in DATA.items():
  if (REF/(name+'.png')).exists():build(name,data)
 bpy.data.libraries.write(str(ROOT/'source/photographic_fish.blend'),set(scenes),path_remap='RELATIVE',fake_user=True,compress=True)
