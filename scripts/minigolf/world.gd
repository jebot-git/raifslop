extends Node3D
## Compact instanced waterfront platforms; surface mesh and rolling solver share height().
const Catalog=preload("res://scripts/minigolf/catalog.gd")
const Ball=preload("res://scripts/minigolf/ball.gd")
var course:Dictionary
var palette:Dictionary
var soil:StandardMaterial3D
var decoration_index:=0
var ambient_fill:=0.0
var prop_scenes:Dictionary={}
var prop_materials:Dictionary={}
var lost_balls:Array[MeshInstance3D]=[]
var signs:Array[Node3D]=[]
var green:Material
var trim:StandardMaterial3D
var wood:Material
var dark:StandardMaterial3D
var pearl:StandardMaterial3D
static func material(color:Color,roughness:=.8)->StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=roughness;m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC;return m
func setup(id:String)->void:
	course=Catalog.course(id)
	palette=preload("res://scripts/minigolf/decoration.gd").profile(id)
	# A small material fill keeps overcast greens and obstacles legible without lights.
	ambient_fill=.12 if id in ["lake_pier","gray_pier","bell_park_pier","fish_hoek_beach","boulder_run","cedar_creek"] else .025
	green=ShaderMaterial.new();green.shader=preload("res://shaders/minigolf_turf.gdshader");green.set_shader_parameter("turf_color",Color(course.turf))
	wood=ShaderMaterial.new();wood.shader=preload("res://shaders/minigolf_deck.gdshader");wood.set_shader_parameter("wood_color",Color(palette.deck))
	green.set_shader_parameter("ambient_fill",ambient_fill)
	wood.set_shader_parameter("ambient_fill",ambient_fill)
	wood.set_shader_parameter("grain_texture",load("res://assets/minigolf/textures/weathered_wood.png"))
	trim=material(Color(palette.border));trim.albedo_texture=load("res://assets/minigolf/textures/weathered_wood.png");trim.uv1_triplanar=true
	soil=material(Color(palette.soil));soil.albedo_texture=load("res://assets/minigolf/textures/shore_stone.png");soil.uv1_triplanar=true
	for mat in [trim,soil]:
		mat.emission_enabled=true;mat.emission=mat.albedo_color;mat.emission_energy_multiplier=ambient_fill
	dark=material(Color("101e20"));pearl=material(Color("f9eed5"),.28)
	# Wide walking galleries connect all tees without stepping over a lane.
	for row in 3:box(self,Vector3(0,1.86,26+row*19),Vector3(49,.25,2.5),wood,true)
	for x in [-24.0,24.0]:box(self,Vector3(x,1.86,40),Vector3(2.5,.25,30),wood,true)
	if Catalog.needs_boat(id):build_shuttle()
	if id in ["meadow_bend","boulder_run","cedar_creek","glacier_run"]:extend_course_bank(id)
	for i in 18:build_hole(i)
	for x in [-2.0,2.0]:box(self,Vector3(x,2.7,28),Vector3(.13,1.5,.13),wood)
	box(self,Vector3(0,3.3,28),Vector3(4.3,.9,.12),trim)
	var course_sign:=Label3D.new();course_sign.text=course.name+"\nWATERFRONT MINIGOLF · 18 HOLES";course_sign.font=preload("res://scripts/ui/waterside_theme.gd").DISPLAY_FONT;course_sign.font_size=52;course_sign.pixel_size=.004;course_sign.position=Vector3(0,3.3,28.075);course_sign.modulate=Color("f4f0dd");course_sign.outline_modulate=Color("20352e");add_child(course_sign)
	preload("res://scripts/minigolf/lightmaps.gd").apply(self)

func box(parent:Node3D,at:Vector3,size:Vector3,mat:Material,solid:=false)->MeshInstance3D:
	var mesh:=BoxMesh.new();mesh.size=size
	var node:=MeshInstance3D.new();node.mesh=mesh;node.material_override=mat;parent.add_child(node);node.position=at
	if solid:
		var body:=StaticBody3D.new();node.add_child(body);var shape:=CollisionShape3D.new();var form:=BoxShape3D.new();form.size=size;shape.shape=form;body.add_child(shape)
	return node
func cylinder(parent:Node3D,at:Vector3,radius:float,height:float,mat:Material)->MeshInstance3D:
	var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=12
	var node:=MeshInstance3D.new();node.mesh=mesh;node.material_override=mat;parent.add_child(node);node.position=at;return node
func build_hole(index:int)->void:
	var hole:Dictionary=course.holes[index]
	var root:=Node3D.new();root.name="Hole%02d"%(index+1);add_child(root);root.position=Catalog.origin(index)
	var w:float=hole.width;var length:float=hole.length
	# The subfloor must sit below recessed greens; level side walks stay accessible.
	box(root,Vector3(0,-.85,-length/2),Vector3(w+1.8,.25,length+2),wood,true)
	for side in [-1,1]:box(root,Vector3(side*(w/2+.45),-.16,-length/2),Vector3(.9,.25,length+2),wood,true)
	for z in [.5,-length-.5]:box(root,Vector3(0,-.16,z),Vector3(w,.25,1),wood,true)
	var ball:=Ball.new();ball.reset(hole)
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx:=ceili(w/.25);var nz:=ceili(length/.25)
	var xs:Array[float]=[];var zs:Array[float]=[]
	for x in nx+1:xs.append(-w/2+w*x/nx)
	for z in nz+1:zs.append(-length*z/nz)
	# Align mesh edges to exact hazard bounds: visible water equals penalty area.
	for hazard in hole.hazards:
		var center:=Catalog.point(hazard.center);var size:=Catalog.point(hazard.size)
		for side in [-1,1]:
			var x:=clampf(center.x+side*size.x/2,-w/2,w/2)
			var z:=clampf(center.y+side*size.y/2,-length,0)
			if not xs.has(x):xs.append(x)
			if not zs.has(z):zs.append(z)
	xs.sort();zs.sort();zs.reverse()
	for z in zs.size()-1:
		for x in xs.size()-1:
			var a:=Vector2(xs[x],zs[z]);var b:=Vector2(xs[x+1],zs[z])
			var c:=Vector2(a.x,zs[z+1]);var d:=Vector2(b.x,c.y)
			var pond:=false
			for hazard in hole.hazards:
				var size:=Catalog.point(hazard.size)
				if Rect2(Catalog.point(hazard.center)-size/2,size).has_point((a+d)/2):pond=true
			if pond:continue
			for p in [a,c,b,b,c,d]:
				surface.set_uv(Vector2(p.x,p.y));surface.add_vertex(Vector3(p.x,ball.height(p),p.y))
	surface.generate_normals();var node:=MeshInstance3D.new();node.mesh=surface.commit();node.material_override=green;root.add_child(node);node.create_trimesh_collision()
	for x in [-w/2-.05,w/2+.05]:terrain_bank(root,ball,Vector2(x,0),Vector2(x,-length),.05,true)
	for z in [.05,-length-.05]:terrain_bank(root,ball,Vector2(-w/2,z),Vector2(w/2,z),.05,true)
	for hazard in hole.hazards:
		var p:=Catalog.point(hazard.center);var size:=Catalog.point(hazard.size)
		hazard_surface(root,ball,p,size)
	for rail in hole.get("rails",[]):
		terrain_bank(root,ball,Catalog.point(rail.a),Catalog.point(rail.b),float(rail.radius))
	for obstacle in hole.obstacles:
		var p:=Catalog.point(obstacle.center);var radius:float=obstacle.radius
		cylinder(root,Vector3(p.x,.045+ball.height(p),p.y),radius,.09,soil)
		decorate(root,Vector3(p.x,.09+ball.height(p),p.y),radius)
	if "Tunnel" in hole.name:
		var portal:Node3D=load("res://assets/minigolf/models/timber_portal.glb").instantiate();root.add_child(portal);portal.position=Vector3(0,0,-length/2)
	var cup:=Catalog.point(hole.cup)
	cylinder(root,Vector3(cup.x,ball.height(cup)+.002,cup.y),Ball.CUP_RADIUS,.006,dark)
	var ring:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.065;torus.outer_radius=.073;torus.rings=16;torus.ring_segments=8;ring.mesh=torus;ring.material_override=pearl;root.add_child(ring);ring.position=Vector3(cup.x,ball.height(cup)+.005,cup.y)
	var tee:=Catalog.point(hole.tee);cylinder(root,Vector3(tee.x,ball.height(tee)+.004,tee.y),.08,.005,pearl)
	var sign:=preload("res://scripts/minigolf/tee_sign.gd").new();root.add_child(sign)
	sign.build(index+1,hole);sign.position=Vector3(-w/2-.4,-.035,.35);signs.append(sign)
	var secret:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.028;sphere.height=.056;secret.mesh=sphere;secret.material_override=material(Color.from_hsv(index/18.0,.65,1));root.add_child(secret);var at:=Catalog.point(hole.lost_ball);secret.position=Vector3(at.x,.015,at.y);lost_balls.append(secret)
	if Catalog.origin(index).x<19:side_garden(root,w,length,index)
	# Visible supports root the deck in its water location.
	for x in [-w/2-.4,w/2+.4]:cylinder(root,Vector3(x,-1.1,-length*.5),.12,2,wood)
func decorate(parent:Node3D,at:Vector3,r:float)->void:
	var assets:Array=palette.props
	prop(parent,str(assets[decoration_index%assets.size()]),at,r/.30,decoration_index*2.4)
	decoration_index+=1
func prop(parent:Node3D,asset:String,at:Vector3,size:float,angle:=0.0)->void:
	if not prop_scenes.has(asset):prop_scenes[asset]=load("res://assets/minigolf/models/%s.glb"%asset)
	var node:Node3D=prop_scenes[asset].instantiate();parent.add_child(node);node.position=at;node.scale=Vector3.ONE*size;node.rotation.y=angle
	texture_prop(node)
func texture_prop(node:Node)->void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var original:Material=node.mesh.surface_get_material(i)
			if not original is StandardMaterial3D:continue
			var key:String=original.resource_name
			var texture_path:=""
			if "Wood" in key or "Cedar" in key or "Endgrain" in key:texture_path="weathered_wood"
			elif "Stone" in key or "Granite" in key or "Moss" in key:texture_path="shore_stone"
			if not prop_materials.has(key):
				var textured:StandardMaterial3D=original.duplicate()
				textured.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				if not texture_path.is_empty():
					textured.albedo_texture=load("res://assets/minigolf/textures/%s.png"%texture_path);textured.uv1_triplanar=true;textured.uv1_scale=Vector3.ONE*3
				textured.emission_enabled=true;textured.emission=textured.albedo_color;textured.emission_energy_multiplier=ambient_fill
				prop_materials[key]=textured
			node.set_surface_override_material(i,prop_materials[key])
	for child in node.get_children():texture_prop(child)
func side_garden(parent:Node3D,w:float,length:float,index:int)->void:
	# Outside the existing side walk and outside all ball collision/penalty areas.
	var x:=w/2+1.25;var z:=-length*.52;var span:=minf(length*.48,4.2)
	box(parent,Vector3(x,-.11,z),Vector3(.74,.22,span),wood)
	box(parent,Vector3(x,.015,z),Vector3(.65,.04,span-.12),soil)
	for end in [-1,1]:
		cylinder(parent,Vector3(x,-1.05,z+end*(span/2-.15)),.07,2.1,wood)
		box(parent,Vector3(x,.06,z+end*span/2),Vector3(.8,.1,.08),trim)
	for side in [-1,1]:box(parent,Vector3(x+side*.37,.06,z),Vector3(.07,.12,span),trim)
	for i in 5:
		var asset:String=palette.bed[(i+index)%palette.bed.size()]
		prop(parent,asset,Vector3(x,.04,z+(i-2)*span/5),1.1+(i%2)*.15,(index+i)*2.4)

func terrain_bank(parent:Node3D,ball:RefCounted,a:Vector2,b:Vector2,radius:float,fascia:=false)->void:
	# Segment banks so their top follows the same elevation as the rolling solver.
	var delta:=b-a;var count:=ceili(delta.length()/.22)
	var mesh_builder:=SurfaceTool.new();mesh_builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var middle:=a.lerp(b,(i+.5)/count)
		var y:float=ball.height(middle)
		var bottom:float=-.72 if fascia else y
		var height:float=y+.18-bottom
		var piece:=BoxMesh.new();piece.size=Vector3(radius*2,height,delta.length()/count+.006)
		mesh_builder.append_from(piece,0,Transform3D(Basis(Vector3.UP,atan2(delta.x,delta.y)),Vector3(middle.x,bottom+height/2,middle.y)))
	var bank:=MeshInstance3D.new();bank.mesh=mesh_builder.commit();bank.material_override=trim;parent.add_child(bank)
	if not fascia:
		for end in [a,b]:cylinder(parent,Vector3(end.x,ball.height(end)+.09,end.y),radius,.18,trim)

func hazard_surface(parent:Node3D,ball:RefCounted,center:Vector2,size:Vector2)->void:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx:=ceili(size.x/.2);var nz:=ceili(size.y/.2)
	for z in nz:
		for x in nx:
			var a:=center-size/2+Vector2(size.x*x/nx,size.y*z/nz)
			var b:=a+Vector2(size.x/nx,0);var c:=a+Vector2(0,size.y/nz);var d:=b+c-a
			for p in [a,b,c,b,d,c]:surface.add_vertex(Vector3(p.x,ball.height(p)-.025,p.y))
	surface.generate_normals();var water:=MeshInstance3D.new();water.mesh=surface.commit();water.material_override=material(Color("163a4d"),.12);parent.add_child(water)

func build_shuttle()->void:
	var berth:=Node3D.new();berth.name="ShoreShuttle";add_child(berth);berth.position.z=19
	var boat:Node3D=load("res://assets/minigolf/models/shore_ferry.glb").instantiate()
	berth.add_child(boat);boat.position=Vector3(28,0,26)
	# The gangway connects the walking gallery to the moored boat's floor.
	var start:=Vector3(24.7,1.98,26);var end:=Vector3(27.6,.48,26)
	var ramp:=box(berth,(start+end)/2,Vector3(start.distance_to(end),.12,1.1),wood,true)
	ramp.rotation.z=atan2(end.y-start.y,end.x-start.x)
	box(berth,Vector3(28,.39,26),Vector3(1.7,.15,4.8),wood,true)
	for z in [23.2,28.8]:
		cylinder(berth,Vector3(25.3,.95,z),.14,2.5,wood)
		var a:=Vector3(25.3,1.95,z);var b:=Vector3(27.25,.8,z)
		var rope:=box(berth,(a+b)/2,Vector3(a.distance_to(b),.045,.045),pearl)
		rope.rotation.z=atan2(b.y-a.y,b.x-a.x)
	box(berth,Vector3(24,2.75,28),Vector3(.1,1.6,.1),wood)
	box(berth,Vector3(24,3.3,28),Vector3(2,.65,.1),trim)
	var sign:=Label3D.new();sign.text="SHORE SHUTTLE";sign.font_size=42;sign.pixel_size=.003
	sign.position=Vector3(24,3.3,28.06);berth.add_child(sign)

func extend_course_bank(id:String)->void:
	# Continue the existing bank with the same world-space material and exact
	# boundary vertices. Keep its outer silhouette well beyond the rear gallery.
	var river=preload("res://scripts/river_foreground.gd")
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-120,120,4):
		for row in 36:
			for corner in [Vector2(0,0),Vector2(4,0),Vector2(4,1),Vector2(0,0),Vector2(4,1),Vector2(0,1)]:
				var px:float=x+corner.x
				var depth:float=(row+corner.y)*4.0
				var edge:float=sin(px*.07)*.65+sin(px*.19)*.2
				var z:float=34.4+edge+depth
				var height:float=lerpf(river.bank_height(px,1.0,false),1.3,smoothstep(0.0,6.0,depth))
				# Gentle ground variation outside the playing footprint.
				height+=sin(px*.06)*sin(z*.05)*.18*smoothstep(74.0,100.0,z)
				surface.set_uv(Vector2(px,z)*.25);surface.add_vertex(Vector3(px,height,z))
	surface.generate_normals();surface.generate_tangents()
	var ground:=MeshInstance3D.new();ground.name="CourseBankExtension";ground.mesh=surface.commit();ground.material_override=river.bank_material(id)
	add_child(ground);ground.create_trimesh_collision()

func blend_environment(water:ShaderMaterial)->void:
	var ground=get_node_or_null("CourseBankExtension")
	if not is_instance_valid(ground):return
	var mat:ShaderMaterial=ground.material_override
	mat.set_shader_parameter("course_backdrop",true)
	for setting in ["panorama","sky_inverse","sky_energy","detail_strength","vibrance","shadow_lift"]:
		mat.set_shader_parameter(setting,water.get_shader_parameter(setting))
