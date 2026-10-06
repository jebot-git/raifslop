extends SceneTree
const River=preload("res://scripts/river_foreground.gd")
var failures:=0
func check(ok:bool,label:String):
 if not ok:failures+=1;push_error(label)
func _initialize():
 for id in ["meadow_bend","boulder_run","cedar_creek","glacier_run"]:
  var mat:=River.bank_material(id)
  check(mat.shader.resource_path.ends_with("bank_baked.gdshader"),"Baked material selected: "+id)
  for channel in ["albedo","emission","normal_rough"]:
   var texture:Texture2D=mat.get_shader_parameter("baked_"+channel)
   check(texture!=null and texture.get_size()==Vector2(8192,4096),"Atlas dimensions: "+id+" "+channel)
   if texture:
    var image:=texture.get_image()
    check(image.has_mipmaps(),"Atlas mipmaps: "+id+" "+channel)
    if channel=="normal_rough":
     if image.is_compressed():image.decompress()
     var sample:=image.get_pixel(4096,int(4096*83.0/128.0))
     check(sample.r>.25 and sample.r<.75 and sample.g>.25 and sample.g<.75 and sample.b>.8,"Packed normal/roughness survives GPU compression")
  var original:=Node3D.new();var optimized:=Node3D.new()
  var reference:=River.bank_material_reference(id)
  for far in [false,true]:
   River.terrain(original,far,reference,reference);River.terrain(optimized,far,mat,mat)
  check(original.get_child_count()==4 and optimized.get_child_count()==4,"All terrain strips retained")
  for i in 4:
   check(original.get_child(i).mesh.get_faces()==optimized.get_child(i).mesh.get_faces(),"Unchanged full-length terrain/collision geometry")
  original.free();optimized.free()
 var shore:=preload("res://scripts/shore.gd").create("lakeside")
 var rocks:=shore.find_child("NaturalShoreBoulders",true,false)
 check(rocks!=null and rocks.get_child_count()==8,"Eight natural shoreline rocks")
 if rocks:check(rocks.get_parent().get_meta("replaced_shore_rocks",0)==24,"All 24 faceted shoreline rocks removed intact")
 shore.free()
 print("BAKED_SHADING ",failures," failures")
 quit(1 if failures else 0)
