extends SceneTree
const Model=preload("res://addons/golfminus/scripts/golf/course_model.gd")
const World=preload("res://addons/golfminus/scripts/world/connected_course_world.gd")
var failures:Array=[]
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	root.size=Vector2i(640,640)
	for id in ["spyglass","pebble","cypress","poppy"]:
		var model:=Model.new();model.load_course(id)
		var world:=World.new();world.model=model;root.add_child(world)
		var mat:=world.terrain_material()
		# Exact mode verifies classification separately from the visual feather.
		mat.set_shader_parameter("terrain_blend_width",0.0)
		check(mat.get_shader_parameter("has_mapped_lies")==true and mat.get_shader_parameter("lie_origin")==model.surface.origin,"Rendered surface uses physics map coordinates: "+id)
		var texture:Texture2D=mat.get_shader_parameter("mapped_lies")
		check(texture!=null and texture.get_width()==model.surface.width and texture.get_height()==model.surface.depth,"Full resolution lie map is supplied to terrain: "+id)
		var boundary:=Vector2i.ZERO
		for z in range(1,model.surface.depth-1):
			for x in range(1,model.surface.width-1):
				var i:int=z*model.surface.width+x
				if model.surface.lies[i]==4 and model.surface.lies[i+1]==0:
					boundary=Vector2i(x,z);break
			if boundary!=Vector2i.ZERO:break
		var at:Vector2=model.surface.origin+Vector2(boundary)
		check(boundary!=Vector2i.ZERO and model.lie(at.x+.49,at.y)=="sand" and model.lie(at.x+.51,at.y)=="rough","Bunker lip has a precise shared sand/rough boundary: "+id)
		if DisplayServer.get_name()!="headless":
			check(texture.get_image().get_data()==model.surface.lies,"GPU classification bytes match every physics cell: "+id)
			# Neutral textures isolate lie colour; exercise the actual terrain shader
			# across a real bunker boundary, rather than a second classification shader.
			var white:=Image.create(2,2,false,Image.FORMAT_RGB8);white.fill(Color.WHITE)
			for name in ["cover","grass","gravel"]:mat.set_shader_parameter(name,ImageTexture.create_from_image(white))
			var flat:=Image.create(2,2,false,Image.FORMAT_RGB8);flat.fill(Color(.5,.5,1))
			for name in ["grass_normal","gravel_normal"]:mat.set_shader_parameter(name,ImageTexture.create_from_image(flat))
			var floor:=MeshInstance3D.new();floor.mesh=PlaneMesh.new();floor.mesh.size=Vector2(24,24)
			floor.position=Vector3(at.x,0,at.y);floor.material_override=mat;world.add_child(floor)
			var camera:=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL
			camera.size=8;camera.position=Vector3(at.x,100,at.y);camera.look_at(Vector3(at.x,0,at.y),Vector3.FORWARD);camera.current=true
			for frame in 4:await process_frame
			await RenderingServer.frame_post_draw
			var shot:=root.get_texture().get_image();var matches:=true;var sampled:=0;var mismatches:=0
			for y in range(8,shot.get_height()-8,8):
				for x in range(8,shot.get_width()-8,8):
					var position:Vector3=camera.project_position(Vector2(x+.5,y+.5)*root.get_visible_rect().size/Vector2(shot.get_size()),100)
					var lie:String=model.lie(position.x,position.z)
					if lie not in ["sand","rough"]:continue
					var visible_sand:bool=shot.get_pixel(x,y).r>.8
					if visible_sand!=(lie=="sand"):
						if mismatches<5:print("SURFACE_PIXEL ",id," pixel=",Vector2i(x,y)," at=",position," lie=",lie," color=",shot.get_pixel(x,y)," view=",root.get_visible_rect().size," image=",shot.get_size())
						mismatches+=1
					matches=matches and visible_sand==(lie=="sand");sampled+=1
			check(matches and sampled>100,"Rendered bunker pixels agree with ball lies: "+id)
			shot.save_png("res://test-results/rec3-review/bunker-%s.png"%id)
			var arrays:Array=floor.mesh.surface_get_arrays(0)
			var colors:=PackedColorArray();colors.resize(arrays[Mesh.ARRAY_VERTEX].size())
			var sand_color:Color=World.COLORS.sand.srgb_to_linear();sand_color.a=0.0;colors.fill(sand_color)
			arrays[Mesh.ARRAY_COLOR]=colors
			var legacy:=ArrayMesh.new();legacy.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			floor.mesh=legacy;mat.set_shader_parameter("has_mapped_lies",false)
			for frame in 3:await process_frame
			await RenderingServer.frame_post_draw
			var old_image:=root.get_texture().get_image()
			var center:=Vector2i(shot.get_width()/2,shot.get_height()/2)
			var mapped_color:Color=shot.get_pixelv(center);var old_color:Color=old_image.get_pixelv(center)
			check(absf(mapped_color.r-old_color.r)<.025 and absf(mapped_color.g-old_color.g)<.025,"Mapped lie palette preserves existing terrain exposure: "+id+" "+str(mapped_color)+" / "+str(old_color))

		world.queue_free();await process_frame
	print("GOLF_SURFACE_ALIGNMENT_RESULT ",failures);quit(0 if failures.is_empty() else 1)
