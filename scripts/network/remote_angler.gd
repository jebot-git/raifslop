extends Node3D
const Rig = preload("res://scripts/avatar_rig.gd")
const Fish = preload("res://scripts/fishing_session.gd")
var session: Node
var player_name := "Angler"
var avatar_hash := ""
var avatar: Node3D
var head := Camera3D.new()
var left := Node3D.new()
var right := Node3D.new()
var rod := Node3D.new()
var rod_visual: Node3D
var golf_club:Node3D
var golf_ball:=MeshInstance3D.new()
var golf_index:=-1
var caught := Node3D.new()
var float_mesh: MeshInstance3D
var bait_visual: Node3D
var feeder_visual:Node3D
var label := Label3D.new()
var line := ImmediateMesh.new()
var target: Dictionary = {}
var rendered: Dictionary = {}
var fish_key: Array = []
var fallback := Node3D.new()
func _ready() -> void:
	add_child(head); head.current=false
	add_child(left); add_child(right); add_child(rod); add_child(caught); add_child(label); add_child(fallback)
	label.layers=preload("res://scripts/guide_camera.gd").UI_LAYER
	label.font_size=32; label.pixel_size=.004; label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate=Color("d9f6e7"); label.no_depth_test=false
	var game=session.root_game
	rod_visual=preload("res://scripts/rod_visual.gd").new()
	rod.add_child(rod_visual)
	rod_visual.equip(0)
	float_mesh=preload("res://scripts/bobber_visual.gd").new();add_child(float_mesh);float_mesh.hide()
	feeder_visual=load("res://assets/models/rods/cage_feeder.glb").instantiate();add_child(feeder_visual);feeder_visual.hide()
	bait_visual=preload("res://scripts/bait_visual.gd").new();add_child(bait_visual);bait_visual.hide()
	game.mesh_node(line,self,Vector3.ZERO,game.material(Color("d8f5e5")))
	# Visible while a custom VRM is transferring; never creates a local camera.
	game.box(fallback,Vector3(0,1.05,0),Vector3(.35,.6,.20),game.material(Color("4d7667")))
	game.box(fallback,Vector3(0,1.55,0),Vector3(.20,.23,.20),game.material(Color("bf9f84")))
	var ball_mesh:=SphereMesh.new();ball_mesh.radius=.021335;ball_mesh.height=.04267;golf_ball.mesh=ball_mesh;add_child(golf_ball);golf_ball.hide()
	visible=false

func set_avatar(model: Node3D, hash: String) -> void:
	var next := Rig.new(); add_child(next); next.add_child(model)
	if not next.configure(model): next.queue_free(); return
	_full_body(model)
	if is_instance_valid(avatar): avatar.queue_free()
	next.first_person=false
	avatar=next; avatar_hash=hash; fallback.hide()
	next.right_grip_updated.connect(_attach_rod_to_hand.bind(next))
	next.hand_attachments_updated.connect(_attach_golf_to_hand.bind(next))

func _attach_rod_to_hand(grip: Transform3D, source: Node3D) -> void:
	if not target.is_empty() and target.golf_club>=0:return
	if source != avatar or target.is_empty() or not target.xr or rod_visual.folded: return
	rod.global_transform=grip*preload("res://scripts/rod_holster.gd").HELD_POSE
	rendered.tip=rod.to_global(Vector3(0,0,-1.68))
	_draw_line()

func _full_body(node: Node) -> void:
	if node is MeshInstance3D: node.layers=1 if node.layers&4 else 0
	for child in node.get_children(): _full_body(child)

func receive_state(data: Dictionary) -> void:
	var snap: bool=target.is_empty() or target.location!=data.location or target.feet.distance_to(data.feet)>3
	target=data.duplicate(true)
	if snap: rendered=target.duplicate(true)

func _build_fish(index: int, length_cm: float) -> void:
	var diagnostic_started:=Time.get_ticks_usec()
	for child in caught.get_children(): caught.remove_child(child); child.queue_free()
	var species: Dictionary=Fish.SPECIES[index]
	var path: String=species.get("model","res://assets/models/european_perch.glb" if index==0 else "")
	if not path.is_empty():
		var model: Node3D=load(path).instantiate()
		model.rotate_y(float(species.get("model_yaw",0.0)))
		caught.add_child(model)
	else:
		var game=session.root_game
		var body:=SphereMesh.new(); body.radius=.12; body.height=.24
		var mesh=game.mesh_node(body,caught,Vector3.ZERO,game.material(Color("9d9860") if index==1 else Color("537c5b"),.3))
		mesh.scale=Vector3(2.5,.9,.65)
		var tail:=PrismMesh.new(); tail.size=Vector3(.17,.22,.025)
		game.mesh_node(tail,caught,Vector3(-.33,0,0),game.material(Color("787648")))

	preload("res://scripts/fish_size.gd").fit(caught,length_cm)
	preload("res://scripts/client_diagnostics.gd").stage("remote_fish",diagnostic_started,{"species":index})

func _process(delta: float) -> void:
	if target.is_empty(): return
	visible=preload("res://addons/golfminus/scripts/golf/host_locations.gd").same_world(target.location,session.root_game.current_location)
	if not visible: return
	if target.caught and fish_key!=[target.species,target.length]:
		fish_key=[target.species,target.length]
		_build_fish(target.species,target.length)
	var blend:=1.0-exp(-delta*18.0)
	for key in preload("res://scripts/network/state.gd").TRANSFORMS:
		rendered[key]=rendered[key].interpolate_with(target[key],blend)
	for key in preload("res://scripts/network/state.gd").VECTORS:
		rendered[key]=rendered[key].lerp(target[key],blend)
	head.global_transform=rendered.head
	left.global_transform=rendered.left; right.global_transform=rendered.right
	rod_visual.equip(target.rod_tier,Fish.Fly.river(target.location) and target.rig==0,target.rig==1,target.rig==2)
	rod_visual.update_tip(target.state,Time.get_ticks_msec()/1000.0)
	rod_visual.set_folded(preload("res://scripts/rod_holster.gd").remote_stowed(target))
	rod_visual.crank.rotation.x=lerp_angle(rod_visual.crank.rotation.x,target.reel_angle,blend)
	rod.global_transform=rendered.rod; caught.global_transform=rendered.fish
	rod.visible=target.golf_club<0
	golf_ball.visible=target.golf_club>=0 and not target.location.ends_with("_clubhouse");golf_ball.global_position=rendered.bobber
	if golf_index!=target.golf_club:
		if is_instance_valid(golf_club):golf_club.queue_free();golf_club=null
		golf_index=target.golf_club
		if golf_index>=0:
			var kind:String="putter" if golf_index==7 else "driver" if golf_index<2 else "iron"
			golf_club=load("res://addons/golfminus/assets/models/%s.glb"%kind).instantiate();add_child(golf_club)
	if is_instance_valid(golf_club):
		preload("res://addons/golfminus/scripts/golf/club_style.gd").apply(golf_club,target.rod_tier)
		golf_club.global_transform=rendered.rod
		if target.golf_stowed:golf_club.scale*=.65
	caught.visible=target.caught
	float_mesh.global_position=rendered.bobber
	var fly_mode:bool=Fish.Fly.river(target.location) and target.rig==0
	feeder_visual.visible=target.rig==1 and target.bait_visible and not target.caught
	feeder_visual.global_position=rendered.bobber
	float_mesh.visible=target.bobber_visible and not target.caught
	float_mesh.scale=Vector3.ONE*(.32 if fly_mode else 1.0)
	bait_visual.visible=target.bait_visible and not target.caught
	bait_visual.set_bait(Fish.Feeder.BAIT_MODELS[target.bait] if target.rig==1 else clampi(target.bait,0,1) if fly_mode else target.bait,Fish.is_marine_location(target.location),fly_mode,target.rig==2,target.rig==1)
	bait_visual.global_position=rendered.bobber if target.rig==1 else rendered.bait_position
	bait_visual.pose_lure(rendered.tip-rendered.bobber,target.state in [Fish.State.WAITING,Fish.State.BITE,Fish.State.FIGHT])
	fallback.global_position=rendered.feet
	if is_instance_valid(avatar):
		var body: Dictionary={}
		for key in target.body:
			var value=target.body[key]
			body[key]=rendered.get("body",{}).get(key,value).interpolate_with(value,blend) if value is Transform3D else value
		rendered.body=body
		avatar.set_user_height(target.user_height)
		avatar.apply_tracking(Transform3D(Basis.IDENTITY,rendered.feet),body,target.face)
		if not target.face.has("mouth"): avatar.mouth.speak(target.visemes)
		avatar.left_curl=target.curl
		avatar.update_targets(head,left,right,rendered.feet.y,rendered.motion,delta)
	label.global_position=rendered.head.origin+Vector3.UP*.32
	label.text=""
	label.visible=target.caught
	if target.caught:
		var species:Dictionary=Fish.SPECIES[target.species]
		var weight:float=species.weight*pow(target.length/species.length,3)
		label.text+=("" if label.text.is_empty() else "\n")+"%s · %.0f cm · %.2f kg"%[species.name,target.length,weight]
	_draw_line()

func _draw_line() -> void:
	line.clear_surfaces()
	if target.caught or float_mesh.visible or bait_visual.visible:
		line.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		if not target.caught and target.rig==0 and Fish.Fly.river(target.location):
			line.surface_add_vertex(rod.to_global(Fish.Fly.LINE_OUTLET))
			if target.in_hand:
				var grip = avatar.hand_grip_pose(true) if is_instance_valid(avatar) else null
				line.surface_add_vertex(grip.origin if grip is Transform3D else rendered.left.origin)
			line.surface_add_vertex(rod.to_global(Fish.Fly.LINE_GUIDE))
		line.surface_add_vertex(rendered.tip)
		if target.caught:
			if target.in_hand: line.surface_add_vertex(rendered.left.origin)
			line.surface_add_vertex(rendered.mouth)
		else:
			for i in range(1,25):
				var t:=i/24.0
				line.surface_add_vertex(rendered.tip.lerp(rendered.bobber,t)-Vector3.UP*sin(t*PI)*.15)
			if bait_visual.visible and target.rig!=1:line.surface_add_vertex(rendered.bait_position)
		line.surface_end()

func _attach_golf_to_hand(source:Node3D)->void:
	if source!=avatar or target.is_empty() or target.golf_club<0 or target.golf_stowed or not is_instance_valid(golf_club):return
	var use_left:bool=rendered.rod.origin.distance_to(rendered.left.origin)<rendered.rod.origin.distance_to(rendered.right.origin)
	var grip=avatar.hand_grip_pose(use_left)
	if grip is Transform3D:golf_club.global_position=grip.origin
