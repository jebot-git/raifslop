extends Node3D
## Giant-scale inspection of the shared course; never changes ball physics or shot state.
const Icons=preload("res://addons/golfminus/scripts/golf/pictograms.gd")
var prompts=preload("res://addons/golfminus/scripts/golf/guidance_strip.gd").new()
var game:Node3D
var active:=false
var saved:Dictionary={}
var center:=Vector3.ZERO
var span:=200.0
var zoom:=1.0
var yaw:=0.0
var camera:=Camera3D.new()
var marker:=MeshInstance3D.new()
var path:=MeshInstance3D.new()
var caption:=Label3D.new()
var course_labels:=Node3D.new()
func setup(g:Node3D)->void:
	game=g;camera.far=4000;camera.fov=65;add_child(camera);add_child(course_labels)
	var sphere:=SphereMesh.new();sphere.radius=1;sphere.height=2;marker.mesh=sphere
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("fff4cc")
	marker.material_override=mat;marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(marker)
	var line_mat:=StandardMaterial3D.new();line_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;line_mat.albedo_color=Color("ffc75d");line_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	path.material_override=line_mat;path.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(path)
	caption.font_size=32;caption.pixel_size=.0012;caption.outline_size=6;caption.no_depth_test=true;add_child(caption);caption.add_child(prompts);prompts.position=Vector3(0,-.16,.002);hide()
func _head_tracked()->bool:
	var tracker=XRServer.get_tracker("head") as XRPositionalTracker
	return tracker!=null and tracker.has_pose("default") and tracker.get_pose("default").has_tracking_data
func _head_offset()->Vector3:
	var tracker=XRServer.get_tracker("head") as XRPositionalTracker
	return tracker.get_pose("default").get_adjusted_transform().origin/XRServer.world_scale
func toggle()->void:
	if active:exit_view()
	else:enter()
func enter()->bool:
	if is_instance_valid(game.host_activity) and game.host_activity.clubhouse_round!=null:return false
	if active or game.fitting_club or not game.focused:return false
	if game.xr and not _head_tracked():return false
	if is_instance_valid(game.host_activity) and game.host_activity.settings_open:return false
	if game.menu_open:game.toggle_menu(false)
	game.club_radial.close();game.course_guide.dock()
	saved={"origin":game.origin.global_transform,"body":game.body.global_transform,"blocked":game.body.blocked,"catch":game.body.catch_controls,"turn":game.body.turn_reserved,"radial":game.body.radial_open,"scale":XRServer.world_scale,"camera":game.get_viewport().get_camera_3d(),"club":game.club.visible,"hud":game.hud.visible,"trail":game.trail.visible,"background_mode":game.world_environment.background_mode,"background_color":game.world_environment.background_color}
	saved.head_far=game.head.far
	saved.head_offset=_head_offset() if game.xr else Vector3.ZERO
	var ocean:Node3D=game.world.get_node_or_null("OceanBackdrop")
	if is_instance_valid(ocean):saved.ocean=ocean;saved.ocean_visible=ocean.visible;ocean.hide()
	if is_instance_valid(game.host_game) and is_instance_valid(game.host_game.avatar):saved.avatar_visible=game.host_game.avatar.visible;game.host_game.avatar.hide()
	# The ground-level panorama contains photographed ground outside the mesh.
	# Use a clean backdrop above the course while retaining sky illumination.
	game.world_environment.background_mode=Environment.BG_COLOR
	game.world_environment.background_color=Color("233e42")
	active=true;show();game.body.blocked=true;game.body.catch_controls=true;game.body.turn_reserved=true
	game.charging=false;game.power=0;game.reset_swing();game.club.hide();game.hud.hide();game.trail.hide()
	zoom=1;reset_view()
	if not game.xr:camera.make_current()
	update(0)
	return true
func exit_view()->void:
	if not active:return
	active=false;hide();XRServer.world_scale=saved.scale
	game.head.far=saved.head_far
	game.world_environment.background_mode=saved.background_mode;game.world_environment.background_color=saved.background_color
	if saved.has("ocean") and is_instance_valid(saved.ocean):saved.ocean.visible=saved.ocean_visible
	game.body.global_transform=saved.body;game.origin.global_transform=saved.origin
	game.body.blocked=saved.blocked;game.body.catch_controls=saved.catch;game.body.radial_open=saved.radial
	# Prevent the navigation stick becoming a turn on the return frame.
	game.body.turn_reserved=true
	game.club.visible=saved.club;game.hud.visible=saved.hud;game.trail.visible=saved.trail
	if is_instance_valid(saved.camera) and saved.camera.is_inside_tree():saved.camera.make_current()
	if saved.has("avatar_visible") and is_instance_valid(game.host_game.avatar):game.host_game.avatar.visible=saved.avatar_visible
	game.reset_swing();game.swing.cooldown=.8;saved.clear()
	game.status_text="Returned from Godview · ready at your original stance."
func reset_view()->void:
	for child in course_labels.get_children():course_labels.remove_child(child);child.queue_free()
	var tee:Vector3=game.model.tee(game.tee_kind)
	var pin:Vector3=game.model.pin()
	center=(tee+pin)*.5
	span=maxf(80,Vector2(pin.x-tee.x,pin.z-tee.z).length()*1.15)
	yaw=atan2(tee.x-pin.x,tee.z-pin.z);zoom=1
	if game.model.connected:
		var bounds:Rect2=game.model.course_bounds()
		var middle:=bounds.get_center()
		center=Vector3(middle.x,game.model.height(middle.x,middle.y),middle.y)
		span=maxf(bounds.size.x,bounds.size.y)*1.25;yaw=0
		for i in game.model.course.holes.size():
			var number:=Label3D.new();number.text="%02d"%(i+1);number.font_size=48;number.pixel_size=span*.00035
			number.position=game.model.pin_for(i)+Vector3.UP*span*.02;number.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			number.modulate=Color("f6d888") if i==game.model.index else Color("dcecd7");course_labels.add_child(number)
func focus_ball()->void:
	center=game.ball.position;zoom=.4
func navigate(pan:Vector2,orbit_zoom:Vector2,dt:float)->void:
	if pan.length()>.2:center+=Basis(Vector3.UP,yaw)*Vector3(pan.x,0,-pan.y)*span*.4*dt
	if absf(orbit_zoom.x)>.2:yaw-=orbit_zoom.x*dt*.7
	if absf(orbit_zoom.y)>.2:zoom=clampf(zoom*exp(-orbit_zoom.y*dt),.2,2.0)
	var midpoint:Vector3=(game.model.tee(game.tee_kind)+game.model.pin())*.5
	if game.model.connected:
		var bounds:Rect2=game.model.course_bounds()
		center.x=clampf(center.x,bounds.position.x,bounds.end.x)
		center.z=clampf(center.z,bounds.position.y,bounds.end.y)
	else:
		center.x=clampf(center.x,midpoint.x-span,midpoint.x+span)
		center.z=clampf(center.z,midpoint.z-span,midpoint.z+span)
	center.y=game.model.height(center.x,center.z)
func update(dt:float)->void:
	if not active:return
	if not game.focused or (game.xr and not _head_tracked()):exit_view();return
	var pan:=Vector2.ZERO;var rotation:=Vector2.ZERO
	if game.xr:
		if game.left.get_has_tracking_data():pan=game.left.get_vector2("primary")
		if game.right.get_has_tracking_data():rotation=game.right.get_vector2("primary")
	else:
		pan=Vector2(float(Input.is_key_pressed(KEY_D))-float(Input.is_key_pressed(KEY_A)),float(Input.is_key_pressed(KEY_W))-float(Input.is_key_pressed(KEY_S)))
		rotation=Vector2(float(Input.is_key_pressed(KEY_E))-float(Input.is_key_pressed(KEY_Q)),float(Input.is_key_pressed(KEY_UP))-float(Input.is_key_pressed(KEY_DOWN)))
	navigate(pan,rotation,clampf(dt,0,.05))
	var eye:Vector3=center+Basis(Vector3.UP,yaw)*Vector3(0,span*.65*zoom,span*.55*zoom)
	var size:=span*zoom/5.0
	if game.xr:
		XRServer.world_scale=size
		# Keep the tracked headset upright: players look down naturally, without
		# forcing pitch/roll or replacing the runtime's camera pose.
		game.origin.global_basis=Basis(Vector3.UP,yaw)
		var lean:Vector3=(_head_offset()-saved.head_offset)*size
		game.origin.global_position=eye+game.origin.global_basis*lean-game.origin.global_basis*game.head.position
	else:
		camera.global_position=eye;camera.look_at(center,Vector3.UP)
	var viewer:Camera3D=game.head if game.xr else camera
	viewer.far=maxf(4000,span*5)
	marker.global_position=game.ball.position+Vector3.UP*span*.004
	marker.scale=Vector3.ONE*maxf(.25,span*zoom*.004)
	game.club.hide();game.aim_mesh.hide()
	caption.global_transform=viewer.global_transform*Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),Vector3(0,-.36,-1.1)*size)
	caption.text="GODVIEW · HOLE %02d · %s\n%s\n%s"%[game.round_state.hole+1,"BALL IN FLIGHT" if game.ball.moving else "LAST SHOT" if game.trail_points.size()>1 else "COURSE OVERVIEW",("Live shot · carry %.0f m · apex %.1f m"%[game.ball.carry,game.ball.peak]) if game.ball.moving else "Actual recorded shot trajectory" if game.trail_points.size()>1 else ("Inspect all %d holes"%game.model.course.holes.size() if game.model.connected else "Inspect the current hole"),"Left stick: pan · right: orbit / zoom\nX: course · A: ball · left click / B: return" if game.xr else "WASD: pan · Q/E: orbit · ↑/↓: zoom\nH: course · F: ball · V/Esc: return"]
	prompts.show_entries([["pan","L stick" if game.xr else "WASD"],["orbit","R stick" if game.xr else "Q / E"],["zoom","R stick" if game.xr else "↑ / ↓"],["flag","X" if game.xr else "H"],["ball","A" if game.xr else "F"],["return","L click / B" if game.xr else "V / Esc"]])
	if Icons.enabled:
		var lines:=caption.text.split("\n")
		caption.text=lines[0]+"\n"+lines[1]
	_draw_path(viewer.global_position)
func _draw_path(eye:Vector3)->void:
	var points:PackedVector3Array=game.trail_points.duplicate()
	if points.size()>0 and game.ball.moving:points.append(game.ball.position)
	if points.size()<2:path.mesh=null;return
	var vertices:=PackedVector3Array()
	var width:=maxf(.15,span*zoom*.0015)
	for i in range(1,points.size()):
		var a:=points[i-1];var b:=points[i]
		if a.distance_squared_to(b)<.00001:continue
		var side:Vector3=(b-a).cross(eye-(a+b)*.5).normalized()*width
		for point in [a-side,a+side,b+side,a-side,b+side,b-side]:vertices.append(point)
	if vertices.is_empty():path.mesh=null;return
	var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in vertices:mesh.surface_add_vertex(point)
	mesh.surface_end();path.mesh=mesh
