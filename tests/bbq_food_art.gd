extends SceneTree
var failures:Array=[]
func check(ok:bool,label:String)->void:
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 for food in ["fish_burger","sausage","corn","mushroom"]:
  var root_asset:Node3D=load("res://assets/models/bbq/"+food+".glb").instantiate()
  var surfaces:=0;var triangles:=0
  for mesh in root_asset.find_children("*","MeshInstance3D",true,false):
   for i in mesh.mesh.get_surface_count():
    surfaces+=1
    var mat:StandardMaterial3D=mesh.get_active_material(i)
    check(mat.albedo_texture!=null,food+" retains baked colour")
    check(mat.normal_enabled and mat.normal_texture!=null,food+" retains surface relief")
    check(mat.roughness_texture!=null,food+" retains roughness variation")
    var arrays:Array=mesh.mesh.surface_get_arrays(i);triangles+=arrays[Mesh.ARRAY_INDEX].size()/3
    for uv in arrays[Mesh.ARRAY_TEX_UV]:check(uv.is_finite() and uv.x>=-.00001 and uv.y>=-.00001 and uv.x<=1.00001 and uv.y<=1.00001,food+" stays inside its baked atlas")
  check(surfaces==1,food+" uses one material draw")
  check(triangles<=18100,food+" stays within mobile mesh budget")
  root_asset.free()
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);await create_timer(.6).timeout
 g.set_process(false);g.motor.set_physics_process(false);g.fishing_feedback.set_process(false)
 g.game.reset();g.bbq.service.request("start");await process_frame
 for id in 6:
  var item:Dictionary=g.bbq.service.model.stations[g.current_location].items[id]
  check(absf(g.bbq.food_bounds[id].size.y*.5-preload("res://scripts/bbq/model.gd").HALF_HEIGHT[item.kind])<.00001,"Network food height matches actual mesh")
  for material in g.bbq.food_materials[id]:
   check(material.get_shader_parameter("use_texture"),"Cooking retains baked colour")
   check(material.get_shader_parameter("use_normal_texture"),"Cooking retains normal map")
   check(material.get_shader_parameter("use_roughness_texture"),"Cooking retains roughness map")
 g.queue_free();await process_frame;await create_timer(.3).timeout
 print("BBQ_FOOD_ART ",failures);quit(0 if failures.is_empty() else 1)
