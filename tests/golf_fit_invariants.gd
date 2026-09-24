extends SceneTree
const Fit=preload("res://addons/golfminus/scripts/golf/club_fit.gd")
const Session=preload("res://addons/golfminus/scripts/golf/fit_session.gd")
const Profile=preload("res://addons/golfminus/scripts/golf/club_fit_profile.gd")
const Head=preload("res://addons/golfminus/scripts/golf/club_head.gd")
const Clubs=preload("res://addons/golfminus/scripts/golf/clubs.gd")
var failures:Array=[]
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize()->void:
	for hand in 2:
		for index in 8:
			var grip:=Transform3D(Basis.from_euler(Vector3(.5,-.4,.7)),Vector3(.4 if hand==0 else -.4,.9,.1))
			var shape:=Head.for_club(index);var length:float=Clubs.BAG[index].length
			var fit:=Fit.solve_grounded(grip,Vector3(0,.021335,0),Vector3.FORWARD,length,shape,func(_x,_z):return 0.0)
			check(not fit.is_empty(),"Independent head fit exists %d/%d"%[hand,index])
			if fit.is_empty():continue
			var before:=Fit.head_pose(grip,fit,length,shape)
			check(before.basis.is_equal_approx(grip.basis*Basis(Vector3.RIGHT,shape.loft)),"Auto fit preserves existing grip-relative head %d/%d"%[hand,index])
			var session:=Session.new();session.begin(1.0,[Vector3.ZERO,Vector3.ZERO],hand);session.stage(fit)
			for axis in 3:
				session.adjust(.015)
				var after:=Fit.head_pose(grip,session.candidate,length,shape)
				check(session.candidate.rotation==Vector3.ZERO,"Length adjustment retains initial shaft frame")
				check(after.basis.is_equal_approx(before.basis),"Length adjustment cannot rotate head %d/%d/%d"%[hand,index,axis])
				var shaft:Basis=grip.basis*Basis.from_euler(session.candidate.rotation*PI/180)
				var end:Vector3=grip.origin-shaft.y*length*session.candidate.reach
				check((after.origin-after.basis.x*.055).distance_to(end)<.00001,"Shaft stays connected to unscaled hosel %d/%d/%d"%[hand,index,axis])
			var values:=session.accept()
			check(values.head_rotations[hand].is_equal_approx(fit.head_rotation),"Accept preserves independent head frame")
			var delta:=Basis(Vector3.UP,.3)
			var moved:=Fit.head_pose(Transform3D(delta*grip.basis,grip.origin),fit,length,shape)
			check(moved.basis.is_equal_approx(delta*before.basis),"Normal controller rotation still rotates the complete club")
			check(session.undo().reach==1.0,"Undo restores pre-fit reach")
			for aim in [Vector3.FORWARD,Vector3.BACK,Vector3.RIGHT]:
				var correction:=Vector3(7,112,-32)
				var recaptured:=Fit.solve_grounded(grip,Vector3(0,.021335,0),aim,length,shape,func(_x,_z):return 0.0,correction)
				check(not recaptured.is_empty() and Fit.head_pose(grip,recaptured,length,shape).basis.is_equal_approx(grip.basis*Basis.from_euler(correction*PI/180)*Basis(Vector3.RIGHT,shape.loft)),"Changed target cannot rotate existing head %d/%d/%s"%[hand,index,aim])
			check(values.rotations==[Vector3.ZERO,Vector3.ZERO] and values.head_rotations==[Vector3.ZERO,Vector3.ZERO] and values.fitted==[false,false],"Accept changes length only, retaining per-club default head behavior")
			var short:=Session.new();short.begin(1.0,[Vector3(5,10,15),Vector3(15,10,5)],hand)
			short.stage(fit)
			check(short.candidate.rotation==short.baseline.rotations[hand],"Preview cannot replace initial handle angle")

	var cfg:=ConfigFile.new();var shaft:=Vector3(66,129,62);var correction:=Vector3(2.86,-1.45,-39.33)
	cfg.set_value("golf","club_rotation_1",shaft);cfg.set_value("golf","club_head_rotation_1",correction);cfg.set_value("golf","club_fitted_1",true)
	check(Profile.migrate(cfg),"Legacy fitting profile migrates once")
	var migrated:Vector3=cfg.get_value("golf","club_head_rotation_1")
	check(Basis.from_euler(migrated*PI/180).is_equal_approx(Basis.from_euler(shaft*PI/180)*Basis.from_euler(correction*PI/180)),"Migration preserves current pose before user refits")
	check(cfg.get_value("legacy_fit","head_rotation_1")==correction and cfg.get_value("golf","club_head_source_1")=="legacy","Unattributed legacy corrections are archived, not silently treated as explicit")
	check(not Profile.migrate(cfg),"Migration is idempotent")
	cfg.set_value("golf","club_head_source_1","explicit");cfg.save("user://fit-profile-fixture.cfg")
	var loaded:=ConfigFile.new();loaded.load("user://fit-profile-fixture.cfg")
	check(not Profile.migrate(loaded) and loaded.get_value("golf","club_head_source_1")=="explicit","Explicit correction provenance survives reload")
	print("GOLF_FIT_INVARIANTS_RESULT ",failures);quit(0 if failures.is_empty() else 1)
