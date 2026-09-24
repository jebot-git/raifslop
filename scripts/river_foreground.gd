extends RefCounted
## Deterministic modeled banks, gravel bed and boulder pockets; no wading.
static func material(texture:String,color:Color)->StandardMaterial3D:
 var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.95
 m.albedo_texture=load("res://assets/models/locations/lit/"+texture)
 var normal_path:String="res://assets/models/locations/lit/"+texture.replace("Diffuse.jpg","nor_gl.jpg")
 if ResourceLoader.exists(normal_path):m.normal_enabled=true;m.normal_texture=load(normal_path);m.normal_scale=.45
 m.uv1_triplanar=true;m.uv1_scale=Vector3.ONE*.35
 return m
static func box(root:Node3D,at:Vector3,size:Vector3,mat:Material,collision:=true):
 var n:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;n.mesh=mesh;n.position=at;n.material_override=mat;root.add_child(n)
 if collision:n.create_trimesh_collision()
static func create(id:String)->Node3D:
 var root:=Node3D.new();root.name="RiverForeground";root.set_meta("location_id",id);root.set_meta("spawn",Vector3(0,0,1))
 var alpine:bool=id=="glacier_run"
 var cedar:bool=id=="cedar_creek"
 var gravel=material("gray_pier_gravelly_sand_Diffuse.jpg",Color("849caa") if alpine else Color("c0b7a1"))
 var bank:=ShaderMaterial.new();bank.shader=load("res://assets/environment/rivers/bank.gdshader")
 bank.set_shader_parameter("cover",load("res://assets/environment/rivers/river_bank.png"))
 bank.set_shader_parameter("gravel",gravel.albedo_texture)
 bank.set_shader_parameter("grass_normal",load("res://assets/models/locations/lit/lakeside_aerial_grass_rock_nor_gl.jpg"))
 bank.set_shader_parameter("gravel_normal",gravel.normal_texture)
 bank.set_shader_parameter("grass_roughness",load("res://assets/models/locations/lit/lakeside_aerial_grass_rock_Rough.png"))
 bank.set_shader_parameter("grass",load("res://assets/models/locations/lit/lakeside_aerial_grass_rock_Diffuse.jpg"))
 bank.set_shader_parameter("snow_cover",1.0 if alpine else 0.0)
 if alpine or cedar:bank.set_shader_parameter("ambient_fill",.32)
 var bake_path:String="res://assets/textures/lighting/"+id+"_irradiance.exr"
 if ResourceLoader.exists(bake_path):
  bank.set_shader_parameter("irradiance",load(bake_path))
  bank.set_shader_parameter("bank_ao",load("res://assets/textures/lighting/"+id+"_ao.png"))
  bank.set_shader_parameter("has_bake",true)
 var prototype:Node3D=load("res://assets/environment/rivers/river_boulder.glb").instantiate()
 var rock_node:MeshInstance3D=prototype.find_children("*","MeshInstance3D",true,false)[0]
 var rock_mesh:Mesh=rock_node.mesh
 var rockmat:=ShaderMaterial.new();rockmat.shader=load("res://assets/environment/rivers/rock.gdshader")
 rockmat.set_shader_parameter("albedo_tex",rock_node.get_active_material(0).albedo_texture)
 rockmat.set_shader_parameter("occlusion_tex",load("res://assets/environment/rivers/rock_ao.png"))
 rockmat.set_shader_parameter("normal_tex",gravel.normal_texture)
 prototype.free()
 terrain(root,false,bank,bank)
 box(root,Vector3(0,-1.8,-11),Vector3(180,1,18),gravel,false)
 terrain(root,true,bank,bank)
 # Invisible bank-edge collision keeps the player on dry ground.
 var body:=StaticBody3D.new();root.add_child(body);body.position=Vector3(0,0,-3.1)
 var shape:=CollisionShape3D.new();var bounds:=BoxShape3D.new();bounds.size=Vector3(180,.6,.15);shape.shape=bounds;body.add_child(shape)
 var rng:=RandomNumberGenerator.new();rng.seed=1223 if cedar else (1447 if alpine else (711 if id=="meadow_bend" else 919))
 var stones:=MultiMesh.new();stones.transform_format=MultiMesh.TRANSFORM_3D;stones.mesh=rock_mesh
 stones.instance_count=30 if id=="meadow_bend" else 65
 for i in stones.instance_count:
  var n:=MeshInstance3D.new();n.mesh=rock_mesh;n.material_override=rockmat
  var x:=rng.randf_range(-65,65);var z:=rng.randf_range(-2.8,-1.8) if i%2==0 else rng.randf_range(-20,-18)
  n.position=Vector3(x,-.25,z);n.rotation.y=rng.randf_range(-PI,PI);n.scale=Vector3(rng.randf_range(.4,1.2),.7,rng.randf_range(.4,1.0))
  stones.set_instance_transform(i,n.transform);n.free()
 var stone_visual:=MultiMeshInstance3D.new();stone_visual.name="InstancedRiverStones";stone_visual.multimesh=stones;stone_visual.material_override=rockmat;root.add_child(stone_visual)
 if not preload("res://scripts/fly_fishing.gd").pockets(id).is_empty():
  for pocket in preload("res://scripts/fly_fishing.gd").pockets(id):
   var at:=Vector3(pocket.x,-.6,pocket.z)
   var n:=MeshInstance3D.new();n.mesh=rock_mesh;n.material_override=rockmat;n.position=at;n.scale=Vector3(3.2,3.0,2.7);root.add_child(n);n.create_trimesh_collision();n.set_meta("fish_ground",true)
 # Crossed cutouts in separated depth groups retain silhouettes from oblique views.
 var shrub_texture=load("res://assets/environment/rivers/river_shrubs.png")
 var tree_texture=load("res://assets/environment/rivers/river_alder.png")
 var shrubs:=Node3D.new();shrubs.name="LayeredRiverShrubs";root.add_child(shrubs)
 for i in (10 if alpine else 52):
  var x:=rng.randf_range(-75,75)
  var far:bool=i%3!=0
  var t:float=rng.randf_range(.065,.13) if far else rng.randf_range(.045,.08)
  if not far and absf(x)<3:continue
  for layer in 2:
   var local_t:float=t+layer*.016
   var z:float=(-19-local_t*45 if far else -3.6+local_t*38)+sin(x*.07)*.65+sin(x*.19)*.2
   var size:=Vector2(rng.randf_range(2.4,4.2),rng.randf_range(1.2,2.1))
   if not far:
    local_t=maxf(local_t,(size.x*.5+.35)/38.0)
    var root_x:float=x+layer*.6
    z=-3.6+local_t*38+sin(root_x*.07)*.65+sin(root_x*.19)*.2
   var at:=Vector3(x+layer*.6,0,z)
   at.y=footprint_height(at,size.x*.5,far)-size.y*.08
   card(shrubs,at,size,shrub_texture,rng.randf_range(-.3,.3),rng.randf_range(.88,1.05),rng.randf()<.5)
 var trees:=Node3D.new();trees.name="RiverAlders";root.add_child(trees)
 for i in (0 if alpine or cedar else (9 if id=="meadow_bend" else 24)):
  var x:=rng.randf_range(-85,85);var t:=rng.randf_range(.18,.42)
  var z:float=-19-t*45+sin(x*.07)*.65+sin(x*.19)*.2
  var height:=rng.randf_range(6.0,9.0)
  card(trees,Vector3(x,bank_height(x,t,true)-.12,z),Vector2(height*.67,height),tree_texture,rng.randf_range(-.2,.2),rng.randf_range(.9,1.08),rng.randf()<.5)

 # A second, smaller tree band breaks up the bare modeled ridge and masks
 # the source panorama's stretched lower horizon when viewed from the side.
 var backdrop_rng:=RandomNumberGenerator.new();backdrop_rng.seed=1701 if id=="meadow_bend" else 1702
 for i in (0 if alpine or cedar else (18 if id=="meadow_bend" else 26)):
  var x:float=-82.0+i*(164.0/(17.0 if id=="meadow_bend" else 25.0))+backdrop_rng.randf_range(-2,2)
  var t:float=backdrop_rng.randf_range(.48,.72)
  var z:float=-19-t*45+sin(x*.07)*.65+sin(x*.19)*.2
  var height:float=backdrop_rng.randf_range(3.8,6.2)
  card(trees,Vector3(x,footprint_height(Vector3(x,0,z),height*.3,true)-.15,z),Vector2(height*backdrop_rng.randf_range(.58,.82),height),tree_texture,backdrop_rng.randf_range(-.5,.5),backdrop_rng.randf_range(.83,1.0),backdrop_rng.randf()<.5)
 if not alpine:add_margin_reeds(root,rng)
 if alpine or cedar:add_expansion_props(root,rng,alpine,rock_mesh,rockmat)
 batch_cards(shrubs,shrub_texture,3)
 batch_cards(trees,tree_texture,2)
 preload("res://scripts/shore_dressing.gd").add_to(root,id)
 return root
static func ground_height(x:float,z:float,far:bool)->float:
 # Match the authored terrain triangles, including their linear interpolation.
 var x0:float=floor((x+120.0)/4.0)*4.0-120.0
 var fx:float=(x-x0)/4.0
 var edge0:float=sin(x0*.07)*.65+sin(x0*.19)*.2
 var edge1:float=sin((x0+4)*.07)*.65+sin((x0+4)*.19)*.2
 var edge:float=lerpf(edge0,edge1,fx)
 var t:float=clampf((-19.0+edge-z)/45.0 if far else (z+3.6-edge)/38.0,0,1)
 var start:float=0.0 if t<.09 else .09
 var step:float=.09/12.0 if t<.09 else .91/12.0
 var t0:float=start+floor((t-start)/step)*step
 var fz:float=(t-t0)/step
 var a:float=bank_height(x0,t0,far)
 var b:float=bank_height(x0+4,t0,far)
 var c:float=bank_height(x0,t0+step,far)
 var d:float=bank_height(x0+4,t0+step,far)
 return a+(b-a)*fx+(c-a)*fz if fx+fz<=1.0 else d+(c-d)*(1.0-fx)+(b-d)*(1.0-fz)
static func footprint_height(at:Vector3,radius:float,far:bool)->float:
 var lowest:float=ground_height(at.x,at.z,far)
 for i in 16:
  var offset:=Vector3(cos(i*TAU/16),0,sin(i*TAU/16))*radius
  lowest=minf(lowest,ground_height(at.x+offset.x,at.z+offset.z,far))
 return lowest
static func bank_height(x:float,t:float,far:bool)->float:
 if not far:return -.6+minf(t*15.0,1.0)*.65+maxf(t-.2,0)*1.8
 return -.8+minf(t*7.0,1.0)*2.3+t*(3.0+sin(x*.055)*2.0)+sin(x*.13+t*8)*.22*minf(t*8,1)
static func terrain(root:Node3D,far:bool,grass:Material,gravel:Material):
 for strip in 2:
  var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  for xstep in 60:
   for zstep in 12:
    var t0:float=lerpf(0,.09,zstep/12.0) if strip==0 else lerpf(.09,1,zstep/12.0)
    var t1:float=lerpf(0,.09,(zstep+1)/12.0) if strip==0 else lerpf(.09,1,(zstep+1)/12.0)
    var x0:float=-120+xstep*4;var x1:=x0+4
    var points:Array[Vector3]=[]
    for uv in [Vector2(x0,t0),Vector2(x1,t0),Vector2(x0,t1),Vector2(x1,t1)]:
     var edge:float=sin(uv.x*.07)*.65+sin(uv.x*.19)*.2
     var z:float=(-19.0-uv.y*45 if far else -3.6+uv.y*38)+edge
     points.append(Vector3(uv.x,bank_height(uv.x,uv.y,far),z))
    for index in ([0,2,1,1,2,3] if far else [0,1,2,1,3,2]):
     st.set_uv(Vector2(points[index].x,points[index].z)*.25);st.add_vertex(points[index])
  st.generate_normals();st.generate_tangents();var node:=MeshInstance3D.new();node.mesh=st.commit();node.material_override=gravel if strip==0 else grass;node.set_meta("fish_ground",true)
  root.add_child(node);node.create_trimesh_collision()
  for body in node.find_children("*", "StaticBody3D", true, false):body.set_meta("role", "floor")

static func card(root:Node3D,at:Vector3,size:Vector2,texture:Texture2D,yaw:float,shade:float,flip:bool):
 var mesh:=QuadMesh.new();mesh.size=size
 var node:=MeshInstance3D.new();node.mesh=mesh;node.position=at+Vector3.UP*size.y*.5
 node.rotation.y=yaw;node.scale.x=-1 if flip else 1
 var mat:=ShaderMaterial.new();mat.shader=load("res://assets/environment/rivers/vegetation.gdshader")
 mat.set_shader_parameter("foliage",texture);mat.set_shader_parameter("shade",shade)
 mat.set_shader_parameter("sway",.025 if size.y<3 else .06)
 node.material_override=mat;root.add_child(node)

static func batch_cards(group:Node3D,texture:Texture2D,sections:int):
 var cards:=group.get_children()
 var bases:Array=[]
 if cards.size()>1:group.set_meta("layer_depth_separation",absf(cards[0].position.z-cards[1].position.z))
 var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_custom_data=true
 multi.mesh=preload("res://scripts/shore_details.gd").crossed_mesh(true,sections);multi.instance_count=cards.size()
 for i in cards.size():
  var node:MeshInstance3D=cards[i];var transform:=node.transform
  transform.basis=transform.basis.scaled_local(Vector3(node.mesh.size.x,node.mesh.size.y,node.mesh.size.x))
  multi.set_instance_transform(i,transform)
  bases.append({"at":node.position-Vector3.UP*node.mesh.size.y*.5,"radius":node.mesh.size.x*.5})
  multi.set_instance_custom_data(i,Color(node.material_override.get_shader_parameter("shade"),0,0,1))
  group.remove_child(node);node.free()
 var visual:=MultiMeshInstance3D.new();visual.multimesh=multi
 var mat:=ShaderMaterial.new();mat.shader=load("res://assets/environment/rivers/vegetation.gdshader")
 mat.set_shader_parameter("foliage",texture);mat.set_shader_parameter("sway",.008)
 mat.set_shader_parameter("exposure",.22 if group.get_parent().get_meta("location_id")=="boulder_run" else .4)
 visual.material_override=mat;group.add_child(visual)
 group.set_meta("plant_footprints",bases)
 group.set_meta("instances",multi.instance_count)
 group.set_meta("cross_sections",sections)

static func add_margin_reeds(root:Node3D,rng:RandomNumberGenerator):
 # Real crossed geometry, anchored to the bank. Never rotate a card per eye.
 var group:=Node3D.new();group.name="RiverMarginReeds";root.add_child(group)
 var texture=load("res://assets/environment/shore_details/lakeshore_reeds.png")
 for i in 64:
  var far:bool=i%2==0
  var x:float=rng.randf_range(-48,48)
  if not far and absf(x)<3.8:continue
  var t:float=rng.randf_range(.018,.035) if far else rng.randf_range(.025,.045)
  var z:float=(-19-t*45 if far else -3.6+t*38)+sin(x*.07)*.65+sin(x*.19)*.2
  var size:=Vector2(rng.randf_range(.55,.95),rng.randf_range(.65,1.25))
  card(group,Vector3(x,footprint_height(Vector3(x,0,z),size.x*.5,far)-.05,z),size,texture,rng.randf_range(-PI,PI),rng.randf_range(.85,1.0),false)
 batch_cards(group,texture,3)

static func add_expansion_props(root:Node3D,rng:RandomNumberGenerator,alpine:bool,rock_mesh:Mesh,rock_material:Material):
 var group:=Node3D.new();group.name="GlacialRidge" if alpine else "CedarGrove";root.add_child(group)
 if alpine:
  # Share the established UV-mapped river granite, normal detail, AO and wetness.
  var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=rock_mesh;multi.instance_count=28
  for i in multi.instance_count:
   var x:float=rng.randf_range(-88,88);var z:float=rng.randf_range(-49,-22)
   var scale:=Vector3(rng.randf_range(1.0,2.4),rng.randf_range(.7,1.65),rng.randf_range(.9,2.0))
   var at:=Vector3(x,ground_height(x,z,true)-rock_mesh.get_aabb().position.y*scale.y-.12,z)
   multi.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(scale),at))
  var visual:=MultiMeshInstance3D.new();visual.multimesh=multi;visual.material_override=rock_material;group.add_child(visual)
 else:
  var texture:Texture2D=load("res://assets/environment/rivers/expansion/cedar_card.png")
  for i in 44:
   var x:float=rng.randf_range(-88,88);var z:float=rng.randf_range(-50,-26)
   var height:float=rng.randf_range(5.5,9.0)
   var at:=Vector3(x,0,z);at.y=footprint_height(at,height*.22,true)-.1
   card(group,at,Vector2(height*2.0/3.0,height),texture,rng.randf_range(-.6,.6),rng.randf_range(.85,1.05),rng.randf()<.5)
  batch_cards(group,texture,2)
  # Use the same grain, weathering and baked vertex AO as the shore deadwood.
  var dressing=preload("res://scripts/shore_dressing.gd")
  var log_mesh:Mesh=dressing.mesh_for(dressing.DIR+"ForkedDriftwood.glb")
  var finish:=ShaderMaterial.new();finish.shader=load(dressing.DIR+"fibres.gdshader")
  finish.set_shader_parameter("timber",load("res://assets/models/locations/lit/secluded_beach_weathered_timber_Diffuse.jpg"))
  var logs:=Node3D.new();logs.name="CedarDeadwood";root.add_child(logs)
  for at in [Vector3(-8,0,-1),Vector3(13,0,-.5),Vector3(-17,0,-22)]:
   var visual:=MeshInstance3D.new();visual.mesh=log_mesh;visual.material_override=finish
   visual.transform=deadwood_transform(log_mesh,at,rng.randf_range(-.5,.5),1.65,at.z< -18)
   logs.add_child(visual)

static func deadwood_transform(mesh:Mesh,at:Vector3,yaw:float,size:float,far:bool)->Transform3D:
 # Fit a rigid trunk to the bank plane, then seat its lower envelope. Using
 # the asset origin or a single centre height leaves the ends floating.
 var half_length:float=mesh.get_aabb().size.x*size*.5
 var forward:=Basis(Vector3.UP,yaw).x
 var across:=Basis(Vector3.UP,yaw).z
 var a:Vector3=at-forward*half_length;var b:Vector3=at+forward*half_length
 forward.y=(ground_height(b.x,b.z,far)-ground_height(a.x,a.z,far))/(half_length*2)
 a=at-across*.4;b=at+across*.4
 across.y=(ground_height(b.x,b.z,far)-ground_height(a.x,a.z,far))/.8
 var up:=across.cross(forward).normalized()
 forward=forward.normalized();across=forward.cross(up).normalized()
 var result:=Transform3D(Basis(forward,up,across).scaled_local(Vector3.ONE*size),at)
 var lift:=-INF
 for vertex in mesh.get_faces():
  # The main trunk supports the prop; branch tips can project into the air.
  if absf(vertex.z)>.14:continue
  var point:Vector3=result*vertex
  lift=maxf(lift,ground_height(point.x,point.z,far)-point.y)
 result.origin.y+=lift-.035
 return result
