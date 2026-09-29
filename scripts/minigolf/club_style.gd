extends RefCounted
## Appearance only: no transforms, mesh edits, swing resets or gameplay attributes.
const PATH="res://assets/equipment/tackle_styles.json"
static var palettes:Array=JSON.parse_string(FileAccess.get_file_as_string(PATH))
static func linear_rgb(value:Array)->Color:return Color(value[0],value[1],value[2],1.0)
static func apply(club:Node3D,tier:int)->void:
 if not is_instance_valid(club):return
 tier=tier if tier>=0 and tier<palettes.size() else -1
 if club.get_meta("tackle_style",-2)==tier:return
 var palette:Dictionary=palettes[tier] if tier>=0 else {}
 for node in club.find_children("*","MeshInstance3D",true,false):
  if node.name=="PhysicalClubHead":
   var finish:ShaderMaterial=node.material_override
   finish.set_shader_parameter("style_enabled",tier>=0)
   if tier>=0:
    var blank:=linear_rgb(palette.blank);var trim:=linear_rgb(palette.trim)
    finish.set_shader_parameter("style_blank",Vector3(blank.r,blank.g,blank.b))
    finish.set_shader_parameter("style_trim",Vector3(trim.r,trim.g,trim.b))
   continue
  for surface in node.mesh.get_surface_count():
   var original:Material=node.mesh.surface_get_material(surface)
   if not original is StandardMaterial3D:continue
   if tier<0:node.set_surface_override_material(surface,null);continue
   var part:String=node.name.to_lower()
   var material_name:=original.resource_name.to_lower()
   var color:Color
   if "signature" in part or "accent" in part or "trim" in part or "champagne" in material_name:
    color=linear_rgb(palette.trim)
   elif "butt cap" in part and palette.cork:
    color=Color(.50,.33,.18)
   elif "shaft" in part or "carbon" in material_name or "powdercoat" in material_name:
    color=linear_rgb(palette.blank)
   elif "rubber" in material_name:
    color=Color(.025,.026,.026).lerp(linear_rgb(palette.reel),.15)
   else:continue # Preserve steel faces, hosels and their existing surface detail.
   var finish:StandardMaterial3D=node.get_surface_override_material(surface)
   if finish==null:finish=original.duplicate();node.set_surface_override_material(surface,finish)
   # Godot material colours are sRGB; source authoring numbers are linear.
   finish.albedo_color=color.linear_to_srgb()
 club.set_meta("tackle_style",tier)
