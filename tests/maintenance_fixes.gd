extends SceneTree
const Model=preload("res://scripts/bbq/model.gd")
const Replication=preload("res://scripts/bbq/replication.gd")
const River=preload("res://scripts/river_foreground.gd")
const Config=preload("res://scripts/network/eos/config.gd")
var failures:Array=[]
func check(ok:bool,label:String)->void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var m=Model.new();m.start("lakeside")
 var item:Dictionary=m.stations.lakeside.items[0]
 var release:=Transform3D(Basis.IDENTITY,Vector3(0,1.5,1))
 check(m.apply("lakeside",1,1,"grab",0),"Grab food")
 check(m.apply("lakeside",1,1,"drop",0,Vector3(4,3,0),release),"Release food with hand velocity")
 check(item.place=="thrown" and item.pos==release.origin,"Release keeps hand position instead of snapping to plate")
 var full:=Replication.build({},"lakeside",m.stations.lakeside,m.clock)
 check(Replication.valid(full.data),"Thrown state is accepted by wire schema")
 var client:=Replication.apply({},full.data)
 for i in 72:
  m.tick(1.0/72,["lakeside"]);Replication.cook(client.state,1.0/72,"lakeside")
 check(item.pos.x>3 and item.pos.y>=Model.HALF_HEIGHT[item.kind],"Food flies and collides with ground")
 check(item.pos.is_equal_approx(client.state.items[0].pos),"Client extrapolation matches authority")
 m.tick(20,["lakeside"])
 check(item.place=="pantry" and not item.has("velocity"),"Thrown food respawns and clears physics")
 m.apply("lakeside",1,0,"cooler",-1);m.apply("lakeside",1,0,"grab",8)
 m.apply("lakeside",1,0,"drop",8,Vector3(2,1,0),release)
 m.apply("lakeside",1,0,"cooler",-1)
 check(m.apply("lakeside",2,0,"grab",8),"Can outside cooler remains grabbable after lid closes")
 m.tick(21,["lakeside"])
 check(m.stations.lakeside.items[8].owner==2,"Picking up a thrown can cancels respawn")
 m.apply("lakeside",3,1,"grab",6)
 var food_pose:=Model.resting_pose(item)
 m.apply("lakeside",3,1,"clamp",0,Vector3.ZERO,food_pose)
 m.apply("lakeside",3,1,"unclamp",0,Vector3(3,2,0),release)
 check(item.place=="thrown", "Food can also be thrown by opening moving tongs")
 var root3d:=Node3D.new();root.add_child(root3d);River.add_boundaries(root3d)
 check(root3d.get_child_count()==244,"Both full-length banks have inner, outer and end boundaries")
 for far in [false,true]:
  for x in [-119.0,-95.0,0.0,95.0,119.0]:
   var point:=River.edge_point(x,1.0,far)
   check(is_finite(River.ground_height(x,point.z,far)),"Terrain spans full river length")
 await physics_frame
 var space:=root3d.get_world_3d().direct_space_state
 for far in [false,true]:
  for x in [-116.0,0.0,116.0]:
   var edge:=River.edge_point(x,1.0,far);var inward:=Vector3(0,0,1 if far else -1)
   var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(edge+inward+Vector3.UP,edge-inward+Vector3.UP,1))
   check(not hit.is_empty(),"Rear boundary collision at x=%s far=%s"%[x,far])
 for far in [false,true]:
  for x in [-120.0,120.0]:
   for t in [.07,.5,.98]:
    var edge:=River.edge_point(x,t,far);var inward:=Vector3.RIGHT if x<0 else Vector3.LEFT
    var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(edge+inward+Vector3.UP,edge-inward+Vector3.UP,1))
    check(not hit.is_empty(),"End boundary follows bank elevation x=%s t=%s far=%s"%[x,t,far])
 root3d.free()
 var save_path:="user://legacy-maintenance-achievements.json"
 var legacy:=FileAccess.open(save_path,FileAccess.WRITE)
 legacy.store_string(JSON.stringify({"version":1,"catches":12,"unlocked":{"ubs_first_catch":true,"ubs_first_round":true,"ubs_birdie":true},"visits":["water_lakeside","course_lakeside"]}));legacy.close()
 var progress=preload("res://scripts/progress/service.gd").new();root.add_child(progress);progress.path=save_path;progress.setup(null)
 check(progress.error.is_empty() and progress.catches==12 and progress.unlocked=={"ubs_first_catch":true} and progress.visits==["water_lakeside"],"Old minigolf saves migrate without losing fishing progress")
 progress.free();DirAccess.remove_absolute(save_path)
 var cfg:Dictionary={"product_id":"p","sandbox_id":"s","deployment_id":"d","client_id":"c","client_secret":"fixture","relay":"auto","provider":"device"}
 check(Config.validate(cfg,"Windows").is_empty(),"Desktop accepts device identity")
 check(not Config.validate(cfg,"Android").is_empty(),"Quest still requires Meta entitlement identity")
 var runtime=preload("res://scripts/network/eos/runtime.gd").new()
 check(runtime.settings_error(cfg).is_empty(),"Desktop login no longer requires test flag")
 for node in [runtime.backend,runtime.meta,runtime.leaderboards,runtime.achievements]:
  for property in node.get_property_list():
   if property.name=="requests":
    var requests=node.get("requests")
    if requests is Node and requests.get_parent()==null:requests.free()
  node.free()
 runtime.free()
 check(ProjectSettings.get_setting("xr/openxr/extensions/meta/dynamic_resolution")==false,"Quest dynamic resolution disabled")
 check(ProjectSettings.get_setting("xr/openxr/extensions/meta/application_space_warp")==false,"Application spacewarp disabled")
 check(preload("res://scripts/network/pose_codec.gd").location_table().size()==12,"Only fishing waters remain in protocol")
 check(preload("res://scripts/network/session.gd").VERSION==Config.PROTOCOL,"Lobby and gameplay versions agree")
 print("MAINTENANCE_FIXES_RESULT ",failures);quit(0 if failures.is_empty() else 1)
