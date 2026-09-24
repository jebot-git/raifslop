extends SceneTree
const World=preload("res://addons/golfminus/scripts/world/connected_course_world.gd")
const Model=preload("res://addons/golfminus/scripts/golf/course_model.gd")
var failures:Array[String]=[]
func check(ok:bool,message:String)->void:
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures.append(message)
func pixel(shot:Image,camera:Camera3D,x:float)->Color:
	var p:=camera.unproject_position(Vector3(x,0,1.5))*Vector2(shot.get_size())/root.get_visible_rect().size
	return shot.get_pixel(clampi(roundi(p.x),0,shot.get_width()-1),clampi(roundi(p.y),0,shot.get_height()-1))
func difference(a:Color,b:Color)->float:
	return Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()
func _initialize()->void:run.call_deferred()
func run()->void:
	if DisplayServer.get_name()=="headless":push_error("This test requires a renderer");quit(1);return
	root.size=Vector2i(800,400)
	var model:=Model.new();model.load_course("spyglass")
	var world:=World.new();world.model=model;root.add_child(world)
	var mat:=world.terrain_material()
	var cells:=PackedByteArray()
	for z in 4:
		for lie in [0,0,4,4,1,1,3,3]:cells.append(lie)
	mat.set_shader_parameter("mapped_lies",ImageTexture.create_from_image(Image.create_from_data(8,4,false,Image.FORMAT_R8,cells)))
	mat.set_shader_parameter("lie_origin",Vector2.ZERO)
	var plane:=MeshInstance3D.new();plane.mesh=PlaneMesh.new();plane.mesh.size=Vector2(8,4)
	plane.position=Vector3(3.5,0,1.5);plane.material_override=mat;world.add_child(plane)
	var camera:=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.size=8;camera.position=Vector3(3.5,20,1.5)
	camera.look_at(Vector3(3.5,0,1.5),Vector3.FORWARD);camera.current=true
	mat.set_shader_parameter("terrain_blend_width",0.0)
	for frame in 4:await process_frame
	await RenderingServer.frame_post_draw
	var hard:=root.get_texture().get_image()
	mat.set_shader_parameter("terrain_blend_width",1.0)
	for frame in 4:await process_frame
	await RenderingServer.frame_post_draw
	var soft:=root.get_texture().get_image()
	for boundary in [1.5,3.5,5.5]:
		var jump:=difference(pixel(hard,camera,boundary-.02),pixel(hard,camera,boundary+.02))
		var blended_jump:=difference(pixel(soft,camera,boundary-.02),pixel(soft,camera,boundary+.02))
		check(jump>.05 and blended_jump<jump*.25,"Boundary %.1f is smoothly blended: %.3f -> %.3f"%[boundary,jump,blended_jump])
		for side in [-.6,.6]:
			check(difference(pixel(hard,camera,boundary+side),pixel(soft,camera,boundary+side))<.015,"Interior material remains unchanged")
	soft.save_png("/tmp/golf-terrain-transitions.png")
	print("GOLF_TERRAIN_BLENDING_RESULT ",failures)
	quit(0 if failures.is_empty() else 1)
