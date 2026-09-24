extends SceneTree
const Effects=preload("res://addons/golfminus/scripts/golf/contact_effects.gd")
const Head=preload("res://addons/golfminus/scripts/golf/club_head.gd")
class Ground:
	extends RefCounted
	var surface:="fairway"
	func height(_x:float,_z:float)->float:return 0.0
	func normal_at(_x:float,_z:float)->Vector3:return Vector3.UP
	func lie(_x:float,_z:float)->String:return surface
var failures:Array=[]
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	var fx:=Effects.new();root.add_child(fx);fx.set_process(false)
	var ground:=Ground.new();var shape=Head.for_club(7)
	var bottom:=0.0
	for p in shape.surface_points:bottom=minf(bottom,p.y)
	var pose:=Transform3D(Basis.IDENTITY,Vector3(0,-bottom-.001,.1))
	fx.sample_ground(pose,shape,ground,.01,true)
	pose.origin.z-=.01
	var graze:=fx.sample_ground(pose,shape,ground,.01,true)
	check(not graze.is_empty() and not graze.hard and graze.strength>0,"Moving shallow sole contact creates light feedback")
	check(fx.debris.size()==4 and fx.audio.stream!=null,"Graze emits four flecks and spatial audio")
	pose.origin.z-=.01
	check(fx.sample_ground(pose,shape,ground,.01,true).is_empty(),"Sustained scraping feedback is rate limited")
	fx.clear();pose.origin.y=-bottom-.01;ground.surface="sand"
	fx.sample_ground(pose,shape,ground,.01,true);pose.origin.z-=.05
	var hard:=fx.sample_ground(pose,shape,ground,.01,true)
	check(not hard.is_empty() and hard.hard and hard.surface=="sand","Deep fast sand contact creates impact feedback")
	check(fx.debris.size()==10 and fx.audio.stream==fx.sounds['sandtrue'],"Bunker contact uses sand burst and sound")
	fx.clear();fx.sample_ground(pose,shape,ground,.01,true)
	check(fx.sample_ground(pose,shape,ground,.01,true).is_empty(),"Resting club cannot repeatedly emit contact effects")
	pose.origin.z-=2
	check(fx.sample_ground(pose,shape,ground,.01,true).is_empty(),"Tracking jump produces no effects")
	check(fx.sample_ground(pose,shape,ground,.1,true).is_empty(),"Tracking gap produces no effects")
	check(fx.sample_ground(pose,shape,ground,.01,false).is_empty(),"Inactive club produces no effects")
	var at:=Vector3(0,.021335,0)
	fx.arm_tee(at)
	check(fx.tee_armed and is_instance_valid(fx.tee),"New hole has one armed visible tee")
	check(fx.launch_tee(at,Vector3(0,12,-50)),"Accepted tee launch starts flyoff")
	check(not fx.tee_armed and fx.debris.size()==1 and fx.debris[0].velocity.y>0,"Tee flies upwards and downrange")
	check(not fx.launch_tee(at,Vector3.FORWARD*50),"Tee flyoff cannot repeat")
	var before:Vector3=fx.debris[0].node.position
	fx._process(.1)
	check(fx.debris[0].node.position!=before and fx.debris[0].node.rotation.length()>0,"Airborne tee moves and tumbles")
	fx._process(3)
	check(fx.debris.is_empty(),"Tee effect expires without persistent debris")
	fx.arm_tee(at)
	check(not fx.launch_tee(at+Vector3.RIGHT,Vector3.FORWARD*50),"Shots elsewhere cannot eject a tee")
	fx.arm_tee(at);fx.clear()
	check(not fx.tee_armed and fx.debris.is_empty() and not fx.valid,"Course/practice reset clears effects and contact history")
	fx.queue_free();await process_frame
	var game=preload("res://addons/golfminus/scripts/main.gd").new();root.add_child(game)
	game.round_state.progress_path="user://contact_effects_test_round.cfg"
	game.set_process(false);game.set_physics_process(false);game.body.set_physics_process(false)
	check(game.contact_effects.tee_armed,"Game arms tee when loading hole")
	var teed_ball:Vector3=game.ball.position
	check(absf(teed_ball.y-game.model.height(teed_ball.x,teed_ball.z)-game.BALL.RADIUS-.035)<.00002 and absf(game.contact_effects.tee.position.y-(teed_ball.y-game.BALL.RADIUS))<.00002,"Ball rests visibly on the raised tee cup")
	game.ball.step(1.0)
	check(game.ball.position.is_equal_approx(teed_ball),"Tee supports stationary ball until the first strike")
	check(not game.strike(Vector3.FORWARD*30,Vector3.FORWARD) and game.contact_effects.tee_armed,"Rejected menu shot leaves tee in place")
	game.toggle_menu(false)
	check(game.strike(Vector3.FORWARD*30,Vector3.FORWARD) and not game.contact_effects.tee_armed and game.contact_effects.debris.size()==1,"Successful game shot ejects tee exactly once")
	game.start_practice()
	check(not game.contact_effects.tee_armed and game.contact_effects.debris.is_empty(),"Putting practice removes tee and previous shot effects")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.round_state.progress_path))
	game.queue_free();await process_frame
	print("GOLF_CONTACT_EFFECTS_RESULT ",failures);quit(0 if failures.is_empty() else 1)
