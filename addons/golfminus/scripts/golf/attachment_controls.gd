extends VBoxContainer
## Golf-only mount corrections; shared controller calibration stays independent.
var game:Node3D
var hand:=1
var hand_choice:OptionButton
var mounted:CheckButton
var fields:Dictionary={}
var preview:Node3D
var preview_shaft:MeshInstance3D
var preview_head:MeshInstance3D
var show_preview:CheckButton
func _ready()->void:
	add_theme_constant_override("separation",8)
	hand=0 if game.left_handed else 1
	var title:=Label.new();title.text="Club attachment calibration";add_child(title)
	hand_choice=OptionButton.new();hand_choice.add_item("Left hand",0);hand_choice.add_item("Right hand",1);hand_choice.custom_minimum_size.y=46;add_child(hand_choice)
	hand_choice.item_selected.connect(func(index:int):hand=index;refresh())
	mounted=CheckButton.new();mounted.text="Controller-mounted club / physical attachment";mounted.custom_minimum_size.y=46;add_child(mounted)
	mounted.toggled.connect(func(value:bool):game.set_club_attachment(hand,"mounted",0,float(value)))
	var hint:=Label.new();hint.text="Offsets use the calibrated controller's local axes. Mounted mode keeps the club at that position instead of snapping it to the avatar palm. Changes save immediately for the selected hand. Address-pose fitting uses your current swing hand.";hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(hint)
	show_preview=CheckButton.new();show_preview.text="Show cyan attachment preview in VR";show_preview.button_pressed=true;show_preview.custom_minimum_size.y=46;add_child(show_preview)
	var fit:=Button.new();fit.text="Fit current swing hand from address pose";fit.custom_minimum_size.y=46;add_child(fit);fit.pressed.connect(game.begin_club_fit)
	_make_preview()
	for group in [["offset","Grip position (cm)",["X · right","Y · up","Z · back"],-100,100,.5],["rotation","Shaft rotation (degrees)",["Pitch · X","Yaw · Y","Roll · Z"],-180,180,1],["head","Clubface correction (degrees)",["Pitch · X","Yaw · Y","Roll · Z"],-180,180,1]]:
		var label:=Label.new();label.text=group[1];add_child(label)
		for axis in 3:_axis_row(group[0],axis,group[2][axis],group[3],group[4],group[5])
	var reset:=Button.new();reset.text="Reset selected hand attachment";reset.custom_minimum_size.y=46;add_child(reset)
	reset.pressed.connect(func():game.reset_club_attachment(hand);refresh())
	refresh()
func _axis_row(field:String,axis:int,title:String,minimum:float,maximum:float,step:float)->void:
	var row:=HBoxContainer.new();add_child(row)
	var label:=Label.new();label.text=title;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label)
	var minus:=Button.new();minus.text="−";minus.custom_minimum_size=Vector2(52,46);row.add_child(minus)
	var value:=SpinBox.new();value.min_value=minimum;value.max_value=maximum;value.step=step;value.custom_minimum_size=Vector2(125,46);row.add_child(value)
	var plus:=Button.new();plus.text="+";plus.custom_minimum_size=Vector2(52,46);row.add_child(plus)
	fields[field+str(axis)]=value
	minus.pressed.connect(func():value.value-=step)
	plus.pressed.connect(func():value.value+=step)
	value.value_changed.connect(func(number:float):game.set_club_attachment(hand,field,axis,number*.01 if field=="offset" else number))
func refresh()->void:
	if not is_instance_valid(hand_choice):return
	hand_choice.select(hand);mounted.set_pressed_no_signal(game.club_controller_mount[hand])
	for field in ["offset","rotation","head"]:
		var values:Vector3=game.club_offsets[hand]*100 if field=="offset" else game.club_rotations[hand] if field=="rotation" else game.head_correction(hand)
		for axis in 3:fields[field+str(axis)].set_value_no_signal(values[axis])

func _make_preview()->void:
	preview=Node3D.new();preview.name="ClubAttachmentPreview";game.add_child(preview);preview.hide()
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.albedo_color=Color(.15,.85,1,.65)
	preview_shaft=MeshInstance3D.new();var shaft:=CylinderMesh.new();shaft.top_radius=.009;shaft.bottom_radius=.006;shaft.height=1;preview_shaft.mesh=shaft;preview_shaft.material_override=material;preview.add_child(preview_shaft)
	preview_head=MeshInstance3D.new();preview_head.material_override=material;preview.add_child(preview_head)
func _process(_delta:float)->void:
	var controller:XRController3D=game.left if hand==0 else game.right
	preview.visible=is_visible_in_tree() and show_preview.button_pressed and game.menu_open and game.xr and game.focused and controller.get_has_tracking_data() and game.head_shape!=null
	if not preview.visible:return
	var grip:Transform3D=controller.global_transform*game.club_grip_pose(hand)
	if not game.club_controller_mount[hand] and is_instance_valid(game.host_game):
		var palm=game.host_game.avatar.hand_grip_pose(hand==0)
		if palm is Transform3D:grip.origin=palm.origin+controller.global_basis*game.calibration.pose(hand).basis*game.club_offsets[hand]
	var basis:=grip.basis.orthonormalized()*Basis.from_euler(game.club_rotations[hand]*PI/180)
	var length:float=game.CLUBS.BAG[game.club_index].length*game.club_reach
	preview_shaft.global_transform=Transform3D(basis.scaled(Vector3(1,length,1)),grip.origin-basis.y*length*.5)
	preview_head.mesh=game.head_shape.mesh
	preview_head.global_transform=Transform3D(basis*Basis.from_euler(game.head_correction(hand)*PI/180)*Basis(Vector3.RIGHT,game.head_shape.loft),grip.origin+basis*Vector3(.055*game.club_reach,-length,0))
