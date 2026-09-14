extends SceneTree
func _initialize() -> void:
 var helper=load("res://addons/fishing_export/hdr.gd")
 var results={};var failed=false
 for folder in ["res://assets/environment/locations","res://assets/textures/lighting"]:
  for name in DirAccess.get_files_at(folder):
   if not name.ends_with(".hdr.import") and not name.ends_with(".exr.import"):continue
   var config=ConfigFile.new();config.load(folder.path_join(name))
   var imported=config.get_value("remap","path")
   var original=load(imported).get_image()
   var packed=helper.prepare(imported)
   if packed.is_empty():quit(1);return
   var compressed=load(packed).get_image()
   assert(compressed.get_size()==original.get_size())
   assert(compressed.has_mipmaps()==original.has_mipmaps())
   assert(compressed.decompress()==OK)
   # Godot metrics only accept LDR: compare clamped linear RGB at equal size.
   # Rendered comparisons additionally cover exposure, HDR highlights and shaders.
   original.convert(Image.FORMAT_RGB8);compressed.convert(Image.FORMAT_RGB8)
   var metrics=original.compute_image_metrics(compressed,false)
   results[name]={"metrics":metrics,"original_bytes":FileAccess.get_file_as_bytes(imported).size(),"packed_bytes":FileAccess.get_file_as_bytes(packed).size()}
   print("HDR_QUALITY ",name," ",metrics)
   if metrics.peak_snr<38.0:failed=true
 var file=FileAccess.open("res://test-results/release-size/texture-quality.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(results,"  "));file.close()
 quit(1 if failed else 0)
