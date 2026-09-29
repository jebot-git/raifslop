extends VBoxContainer
var activity:Node3D
var hand:=1
var fields:Dictionary={}
var mount:CheckButton
func _ready()->void:
	var title:=Label.new();title.text="Controller attachment fitting";add_child(title)
	var choice=preload("res://scripts/ui/vr_option.gd").new();choice.add_item("Left hand",0);choice.add_item("Right hand",1);add_child(choice);choice.select(hand);choice.item_selected.connect(func(value):hand=value;refresh())
	mount=CheckButton.new();mount.text="Controller-mounted physical putter";add_child(mount);mount.toggled.connect(func(value):activity.fitting.mounted[hand]=value;activity.fitting.save_profile();activity.swing.reset())
	for group in [["offset","Grip offset (cm)",-100,100,.5],["pose","Controller angle (degrees)",-180,180,1],["shaft","Shaft angle (degrees)",-180,180,1],["head","Face angle (degrees)",-180,180,1]]:
		var label:=Label.new();label.text=group[1];add_child(label)
		for axis in 3:
			var row:=HBoxContainer.new();add_child(row)
			var name_label:=Label.new();name_label.text=["X","Y","Z"][axis];row.add_child(name_label)
			var minus:=Button.new();minus.text="−";minus.custom_minimum_size=Vector2(50,46);row.add_child(minus)
			var number:=SpinBox.new();number.min_value=group[2];number.max_value=group[3];number.step=group[4];row.add_child(number)
			var plus:=Button.new();plus.text="+";plus.custom_minimum_size=Vector2(50,46);row.add_child(plus)
			minus.pressed.connect(func():number.value-=number.step);plus.pressed.connect(func():number.value+=number.step)
			fields[str(group[0])+str(axis)]=number
			number.value_changed.connect(func(value):activity.fitting.set_axis(hand,group[0],axis,value);activity.swing.reset())
	refresh()
func refresh()->void:
	mount.set_pressed_no_signal(activity.fitting.mounted[hand])
	for group in [["offset",activity.fitting.offsets[hand]*100],["pose",activity.fitting.pose_rotations[hand]],["shaft",activity.fitting.rotations[hand]],["head",activity.fitting.heads[hand]]]:
		for axis in 3:fields[group[0]+str(axis)].set_value_no_signal(group[1][axis])
