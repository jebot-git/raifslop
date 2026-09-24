extends SceneTree
const Head=preload("res://addons/golfminus/scripts/golf/club_head.gd")
const Tracker=preload("res://addons/golfminus/scripts/golf/swing_tracker.gd")
const Clubs=preload("res://addons/golfminus/scripts/golf/clubs.gd")
var failures:Array=[]
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize()->void:
	for index in 8:
		var shape=Head.for_club(index)
		var start:=Transform3D(Basis.IDENTITY,Vector3(0,0,.15))
		var finish:=Transform3D(Basis.IDENTITY,Vector3(0,0,-.12))
		var exact:Dictionary=shape.sweep(start,finish,Vector3.ZERO)
		var tracked:Dictionary=shape.sweep_tracked(start,finish,Vector3.ZERO)
		var same:=true
		for key in exact:same=same and exact[key]==tracked[key]
		check(same and tracked.contact_policy=="exact","Exact geometry unchanged: "+str(index))
		var impact:Dictionary=Clubs.impact(index,Vector3(1,-.2,-10),Vector3.FORWARD,"fairway",exact)
		var tolerant_impact:Dictionary=Clubs.impact(index,Vector3(1,-.2,-10),Vector3.FORWARD,"fairway",tracked)
		check(impact==tolerant_impact,"Exact launch and spin unchanged: "+str(index))
		# Stop short of the ball: only the uncertainty shell reaches the face.
		var gap_end:=Transform3D(Basis.IDENTITY,Vector3(0,0,shape.depth*.5+Head.BALL_RADIUS+.001))
		var rescue:Dictionary=shape.sweep_tracked(start,gap_end,Vector3.ZERO)
		check(shape.sweep(start,gap_end,Vector3.ZERO).is_empty() and not rescue.is_empty(),"1 mm face gap rescued: "+str(index))
		if not rescue.is_empty():
			check(rescue.contact_policy=="tracking_tolerance" and rescue.tracking_correction_m>0 and rescue.tracking_correction_m<=.002,"Correction bounded to 2 mm: "+str(index))
			check(shape.nearest(rescue.contact_local).distance<.000001 and rescue.contact_local.length()>.001,"Contact stays on real mesh, not sweet-spot proxy: "+str(index))
		check(shape.sweep_tracked(start,gap_end,Vector3.ZERO,Vector3.ZERO,0).is_empty(),"Exact mode does not rescue: "+str(index))
		gap_end.origin.z=shape.depth*.5+Head.BALL_RADIUS+.0021
		check(shape.sweep_tracked(start,gap_end,Vector3.ZERO).is_empty(),"2.1 mm face gap remains a miss: "+str(index))
		check(shape.sweep_tracked(start,gap_end,Vector3.ZERO,Vector3.ZERO,.05).is_empty(),"Oversized requested allowance is capped: "+str(index))
		check(shape.sweep_tracked(gap_end,gap_end,Vector3.ZERO).is_empty(),"Stationary near contact cannot launch: "+str(index))
		var rear_start:=Transform3D(Basis.IDENTITY,Vector3(0,0,-.15))
		var rear_end:=Transform3D(Basis.IDENTITY,Vector3(0,0,-shape.depth*.5-Head.BALL_RADIUS-.001))
		check(shape.sweep_tracked(rear_start,rear_end,Vector3.ZERO).is_empty(),"No allowance behind the head: "+str(index))
		check(shape.sweep_tracked(start,finish,Vector3(.15,0,0)).is_empty(),"Deliberate wide miss remains a miss: "+str(index))
		for hz in [72.0,90.0,120.0]:
			var tracker:=Tracker.new()
			gap_end.origin.z=shape.depth*.5+Head.BALL_RADIUS+.001
			tracker.sample_pose(start,shape,Vector3.ZERO,1/hz,false)
			var hit:Dictionary=tracker.sample_pose(gap_end,shape,Vector3.ZERO,1/hz,true)
			check(not hit.is_empty() and hit.contact_policy=="tracking_tolerance","Tracker rescues trustworthy approach: %s / %s"%[index,hz])
			tracker.resolve_contact(false)
			check(tracker.cooldown==0,"Rejected contact clears accepted-shot cooldown: %s / %s"%[index,hz])
			tracker.resolve_contact(true)
			check(tracker.sample_pose(finish,shape,Vector3.ZERO,1/hz,true).is_empty(),"Accepted contact suppresses duplicate: %s / %s"%[index,hz])
			tracker.reset()
			check(tracker.sample_pose(start,shape,Vector3.ZERO,.08,true).is_empty() and tracker.sample_pose(gap_end,shape,Vector3.ZERO,1/hz,true).is_empty(),"No reconstructed hit across tracking outage: %s / %s"%[index,hz])
			for confidence in [[false,true],[true,false]]:
				tracker=Tracker.new()
				tracker.sample_pose(start,shape,Vector3.ZERO,1/hz,false,Vector3.ZERO,null,confidence[0])
				check(tracker.sample_pose(gap_end,shape,Vector3.ZERO,1/hz,true,Vector3.ZERO,null,confidence[1]).is_empty(),"Both poses must have reliable tracking for rescue: %s / %s / %s"%[index,hz,confidence])
			tracker=Tracker.new();tracker.sample_pose(gap_end,shape,Vector3.ZERO,1/hz,false)
			check(tracker.sample_pose(start,shape,Vector3.ZERO,1/hz,true).is_empty(),"Receding near contact remains a miss: %s / %s"%[index,hz])
	var arm:=Tracker.new()
	check(not arm.activation(.5,0,false,true),"Half press cannot arm")
	check(arm.activation(.56,0,false,true) and arm.activation(.5,0,false,true),"Armed grip tolerates threshold noise")
	check(not arm.activation(.44,0,false,true),"Release disarms without grace period")
	check(arm.activation(0,0,true,true) and not arm.activation(0,0,false,true),"Digital press and release stay immediate")
	arm.activation(1,0,false,true)
	check(not arm.activation(1,0,true,false) and not arm.activation(.5,0,false,true),"Blocking state clears activation latch")
	print("GOLF_TRACKING_TOLERANCE_RESULT ",failures);quit(0 if failures.is_empty() else 1)
