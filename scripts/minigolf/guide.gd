extends Node3D
## Reuses the original field-guide housing, hip pickup and physical page buttons.
const GRIP_BASIS=Basis(Vector3.RIGHT,-PI/2)
const GRIP_ANCHOR=Vector3(0,-.225,-.006)
const BUTTON_CENTERS=[Vector3(-.052,-.128,.031),Vector3(.052,-.128,.031)]
var activity:Node3D
var game_root:Node3D
var device:Node3D
var photo_camera:Node
var held:=false
var held_hand:=-1
var awaiting_grip:=false
var page_index:=0
var viewport:SubViewport
var screen:Control
var grip_down:=[true,true]
var previous_touch:=Vector3.INF
var button_down:=[false,false]
var button_nodes:Array[MeshInstance3D]=[]
var stick_latched:=false
var elapsed:=0.0
func box(at:Vector3,size:Vector3,material:Material)->MeshInstance3D:
	var node:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;node.mesh=mesh;node.position=at;node.material_override=material;add_child(node);return node
func _ready()->void:
	game_root=activity.host;device=self
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
	viewport=SubViewport.new();viewport.size=Vector2i(640,840);viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;add_child(viewport)
	screen=preload("res://scripts/minigolf/guide_screen.gd").new();screen.guide=self;viewport.add_child(screen)
	var surface:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(.169,.222);surface.mesh=quad;surface.position=Vector3(0,.018,.031)
	var display:=StandardMaterial3D.new();display.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;display.albedo_texture=viewport.get_texture();display.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR;surface.material_override=display;add_child(surface)
	photo_camera=preload("res://scripts/guide_camera.gd").new();add_child(photo_camera);photo_camera.setup(self)
	for front in [false,true]:
		var lens:=MeshInstance3D.new();var cylinder:=CylinderMesh.new();cylinder.top_radius=.006;cylinder.bottom_radius=.006;cylinder.height=.004;lens.mesh=cylinder;lens.material_override=dark
		lens.transform=preload("res://scripts/guide_camera.gd").lens_pose(front);lens.rotate_object_local(Vector3.RIGHT,PI/2);add_child(lens)
func page(direction:int)->void:
	if is_instance_valid(photo_camera) and photo_camera.active:return
	page_index=posmod(page_index+direction,3);refresh()
func refresh()->void:
	screen.queue_redraw();viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
func dock()->void:
	held=false;held_hand=-1;awaiting_grip=false;previous_touch=Vector3.INF;button_down=[false,false];stick_latched=false
	if is_instance_valid(viewport):viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if is_instance_valid(photo_camera):photo_camera.view.render_target_update_mode=SubViewport.UPDATE_DISABLED
func toggle(hand:=-1)->void:
	if activity.fitting.active:return
	if held:dock();return
	awaiting_grip=hand<0
	held=true;held_hand=hand if hand>=0 else (1 if activity.left_handed else 0);activity.swing.reset();refresh()
func press_buttons(point:Vector3)->void:
	var local:=to_local(point)
	var continuous:=previous_touch.is_finite() and local.distance_to(previous_touch)<.15
	for i in 2:
		var p:Vector3=local-BUTTON_CENTERS[i];var before:Vector3=previous_touch-BUTTON_CENTERS[i]
		if absf(p.x)>.032 or absf(p.y)>.025 or p.z>.018:button_down[i]=false
		if continuous and before.z>.01 and p.z<=.01 and not button_down[i]:
			var contact:=before.lerp(p,(before.z-.01)/(before.z-p.z))
			if absf(contact.x)<.032 and absf(contact.y)<.025:
				button_down[i]=true
				if photo_camera.active:
					if i==0:photo_camera.toggle_selfie()
					else:photo_camera.capture()
				else:page(-1 if i==0 else 1)
		button_nodes[i].position.z=BUTTON_CENTERS[i].z-(.01 if button_down[i] else .006)
	previous_touch=local
func update()->void:
	var host=activity.host
	var mount:Transform3D=preload("res://scripts/tracking/hip_mount.gd").pose(host.head,host.motor,host.tracking_manager)
	var hip:=mount.origin+mount.basis*Vector3(.28 if activity.left_handed else -.28,0,0)
	if host.menu_open or activity.fitting.active or not host.tracking_manager.focused:dock()
	for hand in 2:
		var controller:XRController3D=host.left if hand==0 else host.right
		var down:bool=controller.get_has_tracking_data() and (controller.get_float("grip")>.55 or controller.is_button_pressed("grip_click"))
		if held and held_hand==hand:
			if down:awaiting_grip=false
			elif not awaiting_grip and host.xr:dock()
		if not held and down and not grip_down[hand] and controller.global_position.distance_to(hip)<.24:toggle(hand)
		grip_down[hand]=down
	if held:
		var controller:XRController3D=host.left if held_hand==0 else host.right
		global_transform=host.controller_pose(held_hand)*Transform3D(GRIP_BASIS,-(GRIP_BASIS*GRIP_ANCHOR))
		if not host.xr:global_transform=Transform3D(host.head.global_basis,host.head.global_position-host.head.global_basis.z*.45)
		var axis:=controller.get_vector2("primary").x
		if absf(axis)>.65 and not stick_latched:page(1 if axis>0 else -1);stick_latched=true
		if absf(axis)<.25:stick_latched=false
		var other:XRController3D=host.right if held_hand==0 else host.left
		if other.get_has_tracking_data():press_buttons(other.to_global(Vector3(0,0,-.1)))
		elapsed+=get_process_delta_time()
		if elapsed>.1:refresh();elapsed=0
	else:
		var basis:=mount.basis*Basis(Vector3.FORWARD,Vector3.DOWN,Vector3.LEFT)
		global_transform=Transform3D(basis,hip-basis*GRIP_ANCHOR)
	visible=not host.menu_open
	host.motor.catch_controls=held;host.motor.turn_reserved=held

func photo_input_hand()->XRController3D:
	var free:XRController3D=game_root.right if held_hand==0 else game_root.left
	return free if free.get_has_tracking_data() else (game_root.left if held_hand==0 else game_root.right)
func camera_controls()->Dictionary:
	return {"toggle":"GUIDE HAND TRIGGER: GUIDE", "capture":"FREE HAND TRIGGER / ›: PHOTO", "selfie":"FREE HAND A/X / ‹: SELFIE", "extend":"FREE HAND STICK ↑/↓: EXTEND"}
func controller_button(button:String,controller:XRController3D)->void:
	var guide_hand:bool=controller==(game_root.left if held_hand==0 else game_root.right)
	if button=="trigger_click":
		if guide_hand:photo_camera.toggle()
		else:photo_camera.capture()
	elif button=="ax_button" and not guide_hand and photo_camera.active:photo_camera.toggle_selfie()
	elif button in ["ax_button","by_button"]:page(1 if button=="ax_button" else -1)
