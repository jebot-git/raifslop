extends Node
## Static shadows are baked. A single ground-projected quad grounds each moving rig.
var root_game: Node
var mode:="blob"
var blobs: Dictionary={}
func setup(game: Node) -> void:
 root_game=game
 var cfg:=ConfigFile.new();cfg.load("user://graphics.cfg")
 var chosen=str(cfg.get_value("shadows","mode","blob"))
 if "--dynamic-shadows" in OS.get_cmdline_user_args():chosen="dynamic"
 elif "--blob-shadows" in OS.get_cmdline_user_args():chosen="blob"
 set_mode(chosen,false)
func set_mode(value: String,persist:=true) -> void:
 mode=value if value in ["blob","dynamic"] else "blob"
 root_game.location_sun.shadow_enabled=mode=="dynamic"
 apply_materials(root_game.foreground)
 for blob in blobs.values():blob.visible=false
 if persist:
  var cfg:=ConfigFile.new();cfg.set_value("shadows","mode",mode);cfg.save("user://graphics.cfg")
func apply_materials(node: Node) -> void:
 if not is_instance_valid(node):return
 if node is MeshInstance3D:
  for i in range(node.mesh.get_surface_count()):
   var mat=node.get_active_material(i)
   if mat is ShaderMaterial and mat.shader.resource_path.ends_with("baked_foreground.gdshader"):
    mat.set_shader_parameter("dynamic_shadows",mode=="dynamic")
 for child in node.get_children():apply_materials(child)
func _physics_process(_delta: float) -> void:
 for rig in blobs.keys():
  if not is_instance_valid(rig):blobs[rig].queue_free();blobs.erase(rig)
 if mode!="blob":return
 for rig in get_tree().get_nodes_in_group("fishing_avatar_rigs"):
  if not blobs.has(rig):
   var mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(.9,1.15);mesh.mesh=plane
   var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/environment/blob_shadow.gdshader");mesh.material_override=mat
   mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mesh.layers=1
   root_game.add_child(mesh);blobs[rig]=mesh
  var blob: MeshInstance3D=blobs[rig];blob.hide()
  if not rig.is_visible_in_tree():continue
  var from: Vector3=rig.global_position+Vector3.UP*.4
  var hit: Dictionary=root_game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,from-Vector3.UP*1.5,1))
  if hit.is_empty() or hit.normal.y<.6:continue
  var floor_node: Node=hit.collider
  if floor_node.get_meta("role","")!="floor":continue
  var up: Vector3=hit.normal
  var right: Vector3=rig.global_basis.x.slide(up).normalized()
  blob.global_transform=Transform3D(Basis(right,up,right.cross(up)),hit.position+up*.012)
  blob.show()
func _exit_tree() -> void:
 for blob in blobs.values():
  if is_instance_valid(blob):blob.queue_free()
 blobs.clear()
