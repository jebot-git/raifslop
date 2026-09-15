extends SceneTree
const S=preload("res://scripts/fishing_session.gd")
const Size=preload("res://scripts/fish_size.gd")
const Scale=preload("res://scripts/avatar_scale.gd")
var failures: Array=[]
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok: failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 await create_timer(.3).timeout
 g.set_process(false);g.motor.set_physics_process(false);g.fishing_feedback.set_process(false)
 var model:Node3D=g.avatar.model
 var body_bounds:AABB=model.transform*model.get_meta(preload("res://scripts/avatar_rest_bounds.gd").CACHE_KEY)
 check(absf(body_bounds.size.y-Scale.BODY_HEIGHT)<.001 and is_equal_approx(Scale.BODY_HEIGHT,1.70),"Loaded avatar body is 170 cm; eye reference is separate")
 for index in S.SPECIES.size():
  var species:Dictionary=S.SPECIES[index]
  g.game.fish_index=index;g.game.journal=[{"length":species.length*1.13}]
  g._show_fish()
  var expected:float=species.length*.0113
  check(absf(g.catch_bounds.size.x-expected)<.0001,"Journal catch length in metres: "+species.name)
  var valid:=true;var moves:=false;var anchored:=true;var length_preserved:=true
  for node in g.catch_twitch.meshes:
   var relative:Transform3D=g.fish_display.global_transform.affine_inverse()*node.global_transform
   valid=valid and node.mesh.get_blend_shape_count()==2
   for surface in node.mesh.get_surface_count():
    var base:Array=node.mesh.surface_get_arrays(surface)
    for shape in node.mesh.surface_get_blend_shape_arrays(surface):
     for i in base[Mesh.ARRAY_VERTEX].size():
      var rest:Vector3=relative*base[Mesh.ARRAY_VERTEX][i]
      var bent:Vector3=relative*shape[Mesh.ARRAY_VERTEX][i]
      valid=valid and bent.is_finite() and rest.distance_to(bent)<=expected*.018+.00001
      moves=moves or rest.distance_to(bent)>expected*.001
      length_preserved=length_preserved and absf(rest.x-bent.x)<.00001
      if rest.x>g.catch_bounds.end.x-expected*.15:anchored=anchored and rest.distance_to(bent)<.00001
  check(valid and moves and anchored and length_preserved,"Bounded twitch keeps head fixed and mouth-to-tail length intact: "+species.name)
  for world_scale in [.7,1.0,1.4]:
   XRServer.world_scale=world_scale
   g.xr=true;g._update_catch(0)
   var mouth:Vector3=g.fish_display.to_global(Vector3(g.catch_bounds.end.x,0,0))
   var tail:Vector3=g.fish_display.to_global(Vector3(g.catch_bounds.position.x,0,0))
   check(absf(mouth.distance_to(tail)/body_bounds.size.y-expected/1.70)<.0001,"Attached catch/avatar ratio remains physical at XR scale "+str(world_scale))
   g.xr=false
 XRServer.world_scale=1.0
 var twitch=g.catch_twitch
 twitch.elapsed=0;twitch.next_twitch=0;twitch.tick(.01);twitch.tick(.10)
 check(twitch.meshes.any(func(m):return m.get_blend_shape_value(0)+m.get_blend_shape_value(1)>.01),"Short twitch burst deforms visible catch")
 twitch.tick(.5)
 check(twitch.meshes.all(func(m):return is_zero_approx(m.get_blend_shape_value(0)+m.get_blend_shape_value(1))),"Catch rests between twitches")
 g.xr=true;g.fish_guide.held=false;g._update_catch(0)
 var anchor:Vector3=g.tip.global_position-Vector3.UP*.28
 check(g.fish_display.to_global(g._catch_mouth()).distance_to(anchor)<.001,"Animated catch still attaches exactly below rod tip")
 g.xr=false;g.queue_free();await process_frame;await create_timer(.3).timeout
 print("CATCH_TWITCH_RESULT ",failures);quit(0 if failures.is_empty() else 1)
