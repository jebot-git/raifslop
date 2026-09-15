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
func setup(game_root:Node):owner_game=game_root
func update(delta:float):
 var g=owner_game.game
 var show_fish:bool=g.state==S.State.FIGHT and (g.distance<=g.landing_distance+4.0 or g.jump_time>0)
 visible=show_fish
 owner_game.water_material.set_shader_parameter("hooked_visibility",0.0)
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
 age+=delta
 twitch.set_amount(sin(age*TAU*11.0)*.85)
 var direction:Vector3=owner_game.cast_anchor-owner_game.cast_target;direction.y=0
 if direction.length_squared()<.001:direction=Vector3.RIGHT
 direction=direction.normalized()
 var depth:float=maxf(.18,measured.size.y*.6)
 var at:Vector3=owner_game.bobber.global_position
 at.y=owner_game.water_level-depth
 if g.jump_time>0:
  direction=owner_game.fish_escape_direction()
  var flight:float=clampf(1.0-g.jump_time/S.JUMP_AIR,0,1)
  at.y+=sin(flight*PI)*(.65+measured.size.x*.5)
 global_position=at
 global_basis=Basis(direction,Vector3.UP,direction.cross(Vector3.UP)).orthonormalized()
 owner_game.water_material.set_shader_parameter("hooked_position",global_position)
 owner_game.water_material.set_shader_parameter("hooked_radius",maxf(.55,measured.size.x*.8))
 owner_game.water_material.set_shader_parameter("hooked_visibility",1.0 if global_position.y<owner_game.water_level else 0.0)
