extends SceneTree
const Fit=preload("res://addons/golfminus/scripts/golf/club_fit.gd")
const Profile=preload("res://addons/golfminus/scripts/golf/club_fit_profile.gd")
const Head=preload("res://addons/golfminus/scripts/golf/club_head.gd")
const Clubs=preload("res://addons/golfminus/scripts/golf/clubs.gd")
var failures:Array=[]
func check(ok:bool,label:String):
	if not ok:failures.append(label);print("FAIL ",label)
func _initialize():
	var cases:=0
	for hand in 2:
		for index in 8:
			for slope in [-.2,0.0,.2]:
				for angle in [0.0,1.2]:
					var ground:Callable=func(x,z):return slope*x+.08*z
					var forward:=Basis(Vector3.UP,angle)*Vector3.FORWARD
					var grip:=Transform3D(Basis.from_euler(Vector3(.4,angle,1.2)),Vector3(.5 if hand==0 else -.5,.85,.2))
					var shape:=Head.for_club(index);var length:float=Clubs.BAG[index].length
					var fit:=Fit.solve_address(grip,Vector3(0,.021335,0),forward,length,shape,ground,Profile.default_head_rotation(hand,index),Profile.default_shaft_rotation(hand),Vector3.ZERO)
					var label:="%d/%d/%.1f/%.1f"%[hand,index,slope,angle];cases+=1
					check(not fit.is_empty(),"Address fit exists "+label)
					if fit.is_empty():continue
					var head:=Fit.head_pose(fit.capture_grip,fit,length,shape)
					var shaft:Basis=fit.capture_grip.basis*Basis.from_euler(fit.rotation*PI/180)
					var hosel:=head.origin-head.basis.x*.055
					check(head.origin.distance_to(fit.target)<.0001,"Head reaches address target "+label)
					check((hosel-grip.origin).normalized().dot(-shaft.y)>.99999,"Shaft follows controller-to-hosel line "+label)
					check((grip.origin-shaft.y*length*fit.reach).distance_to(hosel)<.0001,"Shaft endpoints reach hand and hosel "+label)
					check(absf(Fit.clearance(head,shape,ground)-.004)<.0001,"Ground clearance "+label)
					check(absf((-head.basis.z).dot(Fit.ground_normal(Vector3.ZERO,ground))-sin(shape.loft))<.0001,"Authored loft preserved "+label)
					for vertex in shape.surface_points:
						if (head*vertex).dot(forward)>-Head.BALL_RADIUS-.009:
							check(false,"Head clears ball "+label);break
	print("GOLF_ADDRESS_LINE_RESULT ",cases," cases; ",failures);quit(0 if failures.is_empty() else 1)
