extends SceneTree
## Verify import policy AND the mip chain stored in imported textures/models.
var imports:Array[String]=[]
var models:Array[String]=[]
var failures:Array[String]=[]
var exceptions:Array[String]=[]
var seen:Dictionary={}
var texture_count:=0
var model_textures:=0
func _initialize()->void:run.call_deferred()
func gather(path:String)->void:
	for file in DirAccess.get_files_at(path):
		if not file.ends_with(".import"):continue
		var config:=ConfigFile.new()
		if config.load(path.path_join(file))!=OK:continue
		var importer:String=config.get_value("remap","importer","")
		if importer=="texture":imports.append(path.path_join(file))
		elif importer=="scene":models.append(path.path_join(file.trim_suffix(".import")))
	for folder in DirAccess.get_directories_at(path):
		if not folder.begins_with(".") and folder!="test-results":gather(path.path_join(folder))
func is_ui_only(path:String)->bool:
	return path=="res://assets/icon.svg" or path.begins_with("res://addons/vrm/node_constraint/icons/") or path.ends_with("_preview.jpg")
func verify_texture(texture:Texture2D,label:String,required:bool)->void:
	if texture==null:failures.append(label+": could not load texture");return
	var image:=texture.get_image()
	if image==null:failures.append(label+": could not read imported image");return
	if not required:return
	var levels:=0;var edge:=maxi(image.get_width(),image.get_height())
	while edge>1:edge=maxi(1,edge/2);levels+=1
	if image.get_mipmap_count()!=levels:
		failures.append("%s: expected %d mip levels, found %d"%[label,levels,image.get_mipmap_count()])
func inspect(value:Variant,label:String)->void:
	if value is Texture2D:
		if seen.has(value.get_instance_id()):return
		seen[value.get_instance_id()]=true;model_textures+=1
		verify_texture(value,label+" "+value.resource_path,true)
	elif value is Resource:
		if seen.has(value.get_instance_id()):return
		seen[value.get_instance_id()]=true
		for property in value.get_property_list():
			if property.usage&PROPERTY_USAGE_STORAGE and property.type in [TYPE_OBJECT,TYPE_ARRAY,TYPE_DICTIONARY]:
				inspect(value.get(property.name),label)
	elif value is Array:
		for item in value:inspect(item,label)
	elif value is Dictionary:
		for item in value.values():inspect(item,label)
func run()->void:
	gather("res://")
	for path in imports:
		var config:=ConfigFile.new();config.load(path)
		var source:=path.trim_suffix(".import")
		var required:=not is_ui_only(source)
		if required and not config.get_value("params","mipmaps/generate",false):failures.append(source+": mipmaps disabled")
		if not required:exceptions.append(source)
		verify_texture(load(source) as Texture2D,source,required)
		texture_count+=1
		if texture_count%50==0:print("MIPMAP AUDIT textures ",texture_count,"/",imports.size())
		await process_frame
	for path in models:
		seen.clear()
		var scene:=load(path) as PackedScene
		if scene==null:failures.append(path+": could not load model");continue
		var state:=scene.get_state()
		for node in state.get_node_count():
			for property in state.get_node_property_count(node):inspect(state.get_node_property_value(node,property),path)
		await process_frame
	var noise:=NoiseTexture2D.new()
	if not noise.generate_mipmaps:failures.append("Runtime NoiseTexture2D mipmap default is disabled")
	var sprite:=Sprite3D.new()
	if sprite.texture_filter not in [BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS,BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC,BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC]:
		failures.append("Sprite3D default filter does not sample mipmaps")
	sprite.free()
	var report:={"texture_imports":texture_count,"models":models.size(),"model_texture_references":model_textures,"ui_only_exceptions":exceptions,"failures":failures}
	var file:=FileAccess.open("/tmp/texture-mipmap-audit.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
	print("TEXTURE_MIPMAP_AUDIT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
