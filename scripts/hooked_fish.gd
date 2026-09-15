extends Node3D
## One reused model for the local active fish, horizontal under water or in a leap.
const S=preload("res://scripts/fishing_session.gd")
const Size=preload("res://scripts/fish_size.gd")
var owner_game: Node
var model: Node3D
var index := -1
var twitch=preload("res://scripts/catch_twitch.gd").new()
var measured:=AABB()
var age:=0.0
var leap_id := -1
var leap_start := Vector3.ZERO
var leap_end := Vector3.ZERO
var leap_height := 1.0
func landing_position() -> Vector3:
 return leap_end if leap_id==owner_game.game.jump_count else owner_game.bobber.global_position
func jump_position(progress: float) -> Vector3:
 var t:=clampf(progress,0.0,1.0)
 return leap_start.lerp(leap_end,t)+Vector3.UP*(4.0*leap_height*t*(1.0-t))
func jump_tangent(progress: float) -> Vector3:
 return (leap_end-leap_start+Vector3.UP*(4.0*leap_height*(1.0-2.0*clampf(progress,0.0,1.0)))).normalized()
func mouth_position() -> Vector3:
 return to_global(model.position+Vector3(measured.end.x,measured.get_center().y,measured.get_center().z))
func begin_jump(at: Vector3, direction: Vector3, depth: float) -> void:
 leap_id=owner_game.game.jump_count
 leap_start=Vector3(at.x,owner_game.water_level-depth,at.z)
 direction.y=0
 if direction.length_squared()<.001:direction=Vector3.RIGHT
 direction=direction.normalized()
 leap_end=leap_start+direction*2.16
 if owner_game.game.is_fly_fishing():
  if leap_end.z< -18.3 or leap_end.z> -4.0:
   direction.z=-direction.z;leap_end=leap_start+direction*2.16
  leap_end.z=clampf(leap_end.z,-18.3,-4.0)
  leap_end.x=clampf(leap_end.x,-110,110)
 leap_height=.65+measured.size.x*.5
func setup(game_root:Node):owner_game=game_root
func update(delta:float):
 var g=owner_game.game
 var show_fish:bool=g.state==S.State.FIGHT and (g.distance<=g.landing_distance+4.0 or g.jump_time>0)
 visible=show_fish
 owner_game.water_material.set_shader_parameter("hooked_visibility",0.0)
 if g.jump_time<=0:leap_id=-1
 if not show_fish:return
 if index!=g.fish_index:
  if is_instance_valid(model):remove_child(model);model.queue_free()
  index=g.fish_index
  var species:Dictionary=S.SPECIES[index]
  model=Node3D.new();add_child(model)
  var asset=load(species.get("model","res://assets/models/european_perch.glb")).instantiate()
  model.add_child(asset);asset.rotate_y(float(species.get("model_yaw",0.0)))
  measured=Size.fit(model,species.length)
  twitch.configure(model,measured,index+101)
  # Imported fish are not guaranteed to be centred on their glTF root.
  # The animated trajectory represents the body centre, not that arbitrary pivot.
  model.position=-measured.get_center()
 age+=delta
 twitch.set_amount(sin(age*TAU*11.0)*.85)
 var direction:Vector3=owner_game.cast_anchor-owner_game.cast_target;direction.y=0
 if direction.length_squared()<.001:direction=Vector3.RIGHT
 direction=direction.normalized()
 var depth:float=maxf(.18,measured.size.y*.6)
 var at:Vector3=owner_game.bobber.global_position
 at.y=owner_game.water_level-depth
 if g.jump_time>0:
  if leap_id!=g.jump_count:begin_jump(at,owner_game.fish_escape_direction(),depth)
  var flight:float=clampf(1.0-g.jump_time/S.JUMP_AIR,0,1)
  at=jump_position(flight)
  direction=jump_tangent(flight)
  # During the warning keep the body below water and turn gradually for takeoff.
  if g.jump_time>S.JUMP_AIR:
   var approach:float=1.0-(g.jump_time-S.JUMP_AIR)/S.JUMP_WARNING
   var swimming:Vector3=(leap_end-leap_start).normalized()
   direction=swimming.slerp(direction,smoothstep(0.0,1.0,approach))
 global_position=at
 var side:=direction.cross(Vector3.UP).normalized()
 global_basis=Basis(direction,side.cross(direction).normalized(),side)
 owner_game.water_material.set_shader_parameter("hooked_position",global_position)
 owner_game.water_material.set_shader_parameter("hooked_radius",maxf(.55,measured.size.x*.8))
 owner_game.water_material.set_shader_parameter("hooked_visibility",1.0 if global_position.y<owner_game.water_level else 0.0)
