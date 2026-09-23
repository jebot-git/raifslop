extends Node3D
## The field guide becomes a hole/course tracker during golf.
const GRIP_BASIS=Basis(Vector3.RIGHT,-PI/2)
const GRIP_ANCHOR=Vector3(0,-.225,-.006)
const BUTTON_CENTERS=[Vector3(-.052,-.128,.031),Vector3(.052,-.128,.031)]
var game_root:Node3D
var device:Node3D
var photo_camera:Node
var game:Node3D
var held:=false
var held_hand:=-1
var grip_down:=[true,true]
var stick_latched:=false
var page_index:=0
var belt_pose:=Transform3D.IDENTITY
var viewport:SubViewport
var screen:Control
var button_nodes:Array[MeshInstance3D]=[]
var button_down:=[false,false]
var previous_touch:=Vector3(INF,INF,INF)
var touch_source:=""
var refresh_elapsed:=0.0
func box(position_:Vector3,size_:Vector3,material:Material)->MeshInstance3D:
	var node:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size_;node.mesh=mesh;node.position=position_;node.material_override=material;add_child(node);return node
func _ready()->void:
	var shell:=StandardMaterial3D.new();shell.albedo_color=Color("c86337");shell.roughness=.65
	var dark:=StandardMaterial3D.new();dark.albedo_color=Color("172e29")
	var button:=StandardMaterial3D.new();button.albedo_color=Color("a7d9b5")
	box(Vector3.ZERO,Vector3(.205,.305,.035),shell)
	box(Vector3(0,.015,.022),Vector3(.183,.247,.014),dark)
	box(GRIP_ANCHOR,Vector3(.065,.16,.045),dark)
	box(Vector3(0,-.29,-.006),Vector3(.075,.025,.052),shell)
	box(Vector3(.078,.16,0),Vector3(.017,.055,.02),dark)
	for center in BUTTON_CENTERS:
		button_nodes.append(box(center-Vector3(0,0,.006),Vector3(.045,.028,.012),button))
		var symbol:=Label3D.new();symbol.text="‹" if button_nodes.size()==1 else "›";symbol.font_size=48;symbol.pixel_size=.00045;symbol.position=center+Vector3(0,0,.001);symbol.modulate=Color("172e29");add_child(symbol)
	viewport=SubViewport.new();viewport.size=Vector2i(640,840);viewport.transparent_bg=false;viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;add_child(viewport)
	screen=preload("res://addons/golfminus/scripts/golf/course_guide_screen.gd").new();screen.guide=self;viewport.add_child(screen)
	var surface:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(.169,.222);surface.mesh=quad;surface.position=Vector3(0,.018,.031)
	var display:=StandardMaterial3D.new();display.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;display.albedo_texture=viewport.get_texture();display.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR;surface.material_override=display;add_child(surface)
	if is_instance_valid(game.host_game):
		game_root=game.host_game;device=self
		for front in [false,true]:
			var lens:=MeshInstance3D.new();var cylinder:=CylinderMesh.new();cylinder.top_radius=.006;cylinder.bottom_radius=.006;cylinder.height=.004;lens.mesh=cylinder;lens.material_override=dark
			lens.transform=preload("res://scripts/guide_camera.gd").lens_pose(front);lens.rotate_object_local(Vector3.RIGHT,PI/2);add_child(lens)
		photo_camera=preload("res://scripts/guide_camera.gd").new();add_child(photo_camera);photo_camera.setup(self)
func page(direction:int)->void:
	if is_instance_valid(photo_camera) and photo_camera.active:return
	page_index=posmod(page_index+direction,2);refresh()
func dock()->void:
	held=false;held_hand=-1;stick_latched=false;reset_touch()
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if is_instance_valid(photo_camera):photo_camera.view.render_target_update_mode=SubViewport.UPDATE_DISABLED
func toggle(hand:=-1)->void:
	if game.menu_open or game.fitting_club or (game.club_radial.opened or game.godview.active):return
	held=not held
	if held:
		held_hand=hand if hand>=0 else (1 if game.left_handed else 0)
		page_index=0;reset_touch();game.equipment.set_stowed(true)
		if is_instance_valid(game.host_game) and is_instance_valid(game.host_game.bbq):game.host_game.bbq.release_all()
	game.reset_swing();refresh()
func refresh()->void:
	if not is_instance_valid(screen) or game.model.hole.is_empty():return
	screen.refresh();viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
func reset_touch()->void:
	previous_touch=Vector3(INF,INF,INF);button_down=[false,false]
	for i in button_nodes.size():button_nodes[i].position.z=BUTTON_CENTERS[i].z-.006
func press_buttons(point:Vector3)->void:
	if not held or not point.is_finite():reset_touch();return
	var local:=to_local(point)
	var continuous:=previous_touch.is_finite() and local.distance_to(previous_touch)<.15
	for i in 2:
		var p:Vector3=local-BUTTON_CENTERS[i]
		var before:Vector3=previous_touch-BUTTON_CENTERS[i]
		if absf(p.x)>.032 or absf(p.y)>.025 or p.z>.018:button_down[i]=false
		if continuous and before.z>.010 and p.z<=.010 and not button_down[i]:
			var contact:Vector3=before.lerp(p,(before.z-.010)/(before.z-p.z))
			if absf(contact.x)<.032 and absf(contact.y)<.025:
				button_down[i]=true
				if is_instance_valid(photo_camera) and photo_camera.active:
					if i==0:photo_camera.toggle_selfie()
					else:photo_camera.capture()
				else:page(-1 if i==0 else 1)
		button_nodes[i].position.z=BUTTON_CENTERS[i].z-(.010 if button_down[i] else .006)
	previous_touch=local
func touch_position()->Variant:
	var hand:=1-held_hand if held_hand>=0 else (0 if game.left_handed else 1)
	var source:="controller"
	var point:Variant=null
	var tracker=XRServer.get_tracker("/user/hand_tracker/left" if hand==0 else "/user/hand_tracker/right") as XRHandTracker
	if tracker and tracker.has_tracking_data and tracker.get_hand_joint_flags(XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP)&XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID:
		point=game.origin.to_global(tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP).origin*XRServer.world_scale);source="native"
	elif hand==1 and game.right.get_has_tracking_data() and is_instance_valid(game.host_game) and is_instance_valid(game.host_game.avatar) and game.host_game.avatar.has_method("index_touch_position"):
		point=game.host_game.avatar.index_touch_position();source="avatar"
	else:
		var controller:XRController3D=game.left if hand==0 else game.right
		if controller.get_has_tracking_data():point=controller.global_transform*game.calibration.pose(hand)*Vector3(0,0,-.10)
	if source!=touch_source:reset_touch();touch_source=source
	return point
func update()->void:
	var hip:Transform3D=game.equipment.hip_pose(1.0 if game.left_handed else -1.0)
	var basis:=hip.basis*Basis(Vector3.FORWARD,Vector3.DOWN,Vector3.LEFT)
	belt_pose=Transform3D(basis,hip.origin-basis*GRIP_ANCHOR)
	if game.menu_open or game.fitting_club or game.club_radial.opened or game.godview.active or not game.focused:
		dock();grip_down=[true,true]
	else:
		for hand in 2:
			var controller:XRController3D=game.left if hand==0 else game.right
			var tracked:=controller.get_has_tracking_data()
			var down:=tracked and controller.get_float("grip")>(.35 if grip_down[hand] else .55)
			var pose:Transform3D=controller.global_transform*game.calibration.pose(hand)
			if held and held_hand==hand and not down:dock()
			if not held and down and not grip_down[hand] and pose.origin.distance_to(hip.origin)<.24:toggle(hand)
			grip_down[hand]=down if tracked else true
		if held:
			var controller:XRController3D=game.left if held_hand==0 else game.right
			var pose:Transform3D=controller.global_transform*game.calibration.pose(held_hand)
			global_transform=pose*Transform3D(GRIP_BASIS,-(GRIP_BASIS*GRIP_ANCHOR))
			var axis:=controller.get_vector2("primary").x
			if absf(axis)>.65 and not stick_latched:page(1 if axis>0 else -1);stick_latched=true
			if absf(axis)<.25:stick_latched=false
			var point:Variant=touch_position()
			if point is Vector3:press_buttons(point)
			else:reset_touch()
	if not held:global_transform=belt_pose
	visible=not game.menu_open and not game.godview.active
	game.body.catch_controls=held or (game.club_radial.opened or game.godview.active)
	if held:game.body.turn_reserved=true
	if held:
		refresh_elapsed+=get_process_delta_time()
		if refresh_elapsed>=.1:refresh();refresh_elapsed=0

func photo_input_hand()->XRController3D:
	var free:XRController3D=game.right if held_hand==0 else game.left
	return free if free.get_has_tracking_data() else (game.left if held_hand==0 else game.right)
func camera_controls()->Dictionary:
	var hand_name:="LEFT" if held_hand==0 else "RIGHT"
	var free_name:="LEFT" if photo_input_hand()==game.left else "RIGHT"
	return {"toggle":hand_name+(" B/Y: GUIDE" if game.only_one_controller() else " TRIGGER: GUIDE"), "capture":free_name+" TRIGGER / ›: PHOTO", "selfie":free_name+" A/X / ‹: SELFIE", "extend":free_name+" STICK ↑/↓: EXTEND"}
func camera_button(action:String,left_hand:bool)->bool:
	if not held or not is_instance_valid(photo_camera) or action in ["menu_button","primary_click"]:return false
	var guide_hand:bool=(0 if left_hand else 1)==held_hand
	var single:bool=game.only_one_controller()
	if action=="trigger_click":
		if guide_hand and not (single and photo_camera.active):photo_camera.toggle()
		else:photo_camera.capture()
	elif action=="ax_button" and (not guide_hand or single and photo_camera.active):photo_camera.toggle_selfie()
	elif single and guide_hand and action=="by_button" and photo_camera.active:photo_camera.toggle()
	elif guide_hand and action in ["ax_button","by_button"]:page(1 if action=="ax_button" else -1)
	return true
