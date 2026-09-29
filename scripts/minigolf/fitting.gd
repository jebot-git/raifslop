extends RefCounted
## Retains the accepted golf fitting profile, independent shaft/face corrections,
## stable capture, preview/accept/cancel and undo. Only the putter remains.
const Profile=preload("res://scripts/minigolf/club_fit_profile.gd")
const Solver=preload("res://scripts/minigolf/club_fit.gd")
const Session=preload("res://scripts/minigolf/fit_session.gd")
const LENGTH:=.86
class Head:
	extends RefCounted
	const BALL_RADIUS:=.021335
	var loft:=deg_to_rad(2)
	var surface_points:Array[Vector3]=[]
	func _init()->void:
		for x in [-.065,.065]:
			for y in [-.016,.016]:
				for z in [-.016,.016]:surface_points.append(Vector3(x,y,z))
var shape:=Head.new()
var session=Session.new()
var reach:=1.0
var rotations:Array[Vector3]=[Profile.default_shaft_rotation(0),Profile.default_shaft_rotation(1)]
var pose_rotations:Array[Vector3]=[Vector3.ZERO,Vector3.ZERO]
var heads:Array[Vector3]=[Profile.default_head_rotation(0,7),Profile.default_head_rotation(1,7)]
var offsets:Array[Vector3]=[Vector3.ZERO,Vector3.ZERO]
var mounted:Array=[false,false]
var fitted:Array=[false,false]
var sources:Array=["default","default"]
var active:=false
var left_handed:=false
var message:=""
func load_profile()->void:
	var cfg:=ConfigFile.new()
	# The existing golf profile is deliberately reused; no accepted fit is discarded.
	cfg.load("user://golf_controls.cfg")
	Profile.migrate(cfg)
	left_handed=cfg.get_value("golf","left_handed",false)==true
	var value=cfg.get_value("golf","reach",1.0)
	if (value is float or value is int) and is_finite(value):reach=clampf(value,.35,1.6)
	for hand in 2:
		for entry in [["club_rotation",rotations],["club_pose_rotation",pose_rotations],["club_head_rotation",heads],["club_offset",offsets]]:
			value=cfg.get_value("golf",entry[0]+"_%d"%hand,entry[1][hand])
			if value is Vector3 and value.is_finite():entry[1][hand]=value
		mounted[hand]=cfg.get_value("golf","club_controller_mount_%d"%hand,false)==true
		fitted[hand]=cfg.get_value("golf","club_fitted_%d"%hand,false)==true
		sources[hand]=str(cfg.get_value("golf","club_head_source_%d"%hand,"default"))
		if sources[hand]=="default":heads[hand]=Profile.default_head_rotation(hand,7)
func save_profile()->void:
	var cfg:=ConfigFile.new();cfg.load("user://golf_controls.cfg")
	cfg.set_value("golf","reach",reach);cfg.set_value("golf","fit_version",Profile.VERSION)
	for hand in 2:
		for entry in [["club_rotation",rotations],["club_pose_rotation",pose_rotations],["club_head_rotation",heads],["club_offset",offsets],["club_controller_mount",mounted],["club_fitted",fitted],["club_head_source",sources]]:
			cfg.set_value("golf",entry[0]+"_%d"%hand,entry[1][hand])
	cfg.save("user://golf_controls.cfg")
func grip_pose(controller:Transform3D,hand:int)->Transform3D:
	var rotation:Vector3=pose_rotations[hand]
	if active and not session.candidate.is_empty():rotation=session.candidate.get("pose_rotation",rotation)
	return controller*Transform3D(Basis.from_euler(rotation*PI/180),offsets[hand])
func transforms(grip:Transform3D,hand:int)->Dictionary:
	var fit:Dictionary={"reach":reach,"rotation":rotations[hand],"head_rotation":heads[hand]}
	if active and not session.candidate.is_empty():fit=session.candidate
	var shaft:Basis=grip.basis*Basis.from_euler(fit.rotation*PI/180)
	return {"shaft":Transform3D(shaft.scaled(Vector3(1,fit.reach,1)),grip.origin),"head":Solver.head_pose(grip,fit,LENGTH,shape)}
func begin(hand:int)->void:
	active=true;session.begin(reach,rotations,hand,heads,fitted);session.baseline.pose_rotations=pose_rotations.duplicate();session.baseline.effective_head=heads[hand]
	message="FIT PUTTER\nHold your comfortable address pose.\nTrigger: capture · A/X: accept · B/Y: cancel"
func update(controller:Transform3D,hand:int,ball:Vector3,aim:Vector3,ground:Callable,dt:float,tracked:bool)->void:
	if not active:return
	session.sample_pose(grip_pose(controller,hand),dt,tracked)
	if session.capture_requested:
		message="Keep steady · %d%%"%mini(100,roundi(session.stable_seconds/.4*100))
		var stable:Dictionary=session.stable_pose()
		if not stable.is_empty():
			session.capture_requested=false
			var fit:Dictionary=Solver.solve_address(stable.pose,ball,aim,LENGTH,shape,ground,heads[hand],rotations[hand],pose_rotations[hand])
			if session.stage(fit):message="FIT PREVIEW · %.2f m\nA/X: accept · B/Y: cancel\nTrigger: capture again"%(LENGTH*fit.reach)
			else:message="Cannot reach this address.\nStand beside the ball and capture again."
func accept()->void:
	var values:Dictionary=session.accept()
	if values.is_empty():return
	_apply(values);active=false;save_profile()
func _apply(values:Dictionary)->void:
	reach=values.reach;rotations.assign(values.rotations);heads.assign(values.head_rotations);pose_rotations.assign(values.get("pose_rotations",pose_rotations));fitted=values.fitted
func cancel()->void:active=false;session.cancel()
func undo()->void:
	var values:Dictionary=session.undo()
	if not values.is_empty():_apply(values);save_profile()
	cancel()
func set_axis(hand:int,field:String,axis:int,value:float)->void:
	cancel()
	match field:
		"offset":offsets[hand][axis]=value*.01
		"shaft":rotations[hand][axis]=value
		"pose":pose_rotations[hand][axis]=value
		"head":heads[hand][axis]=value;sources[hand]="manual"
	save_profile()
