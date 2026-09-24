@tool
extends EditorScenePostImport
## VRM embeds ImageTextures instead of using the regular texture importer.
var visited:Dictionary={}
func _post_import(scene:Node)->Object:
	visited.clear()
	visit(scene)
	return scene
func visit(value:Variant)->void:
	if value is ImageTexture:
		if visited.has(value.get_instance_id()):return
		visited[value.get_instance_id()]=true
		var image:Image=value.get_image()
		if image==null or image.has_mipmaps():return
		if image.is_compressed() and image.decompress()!=OK:
			push_error("Could not decompress avatar texture: "+value.resource_path);return
		if image.generate_mipmaps()!=OK:
			push_error("Could not mipmap avatar texture: "+value.resource_path);return
		value.set_image(image)
	elif value is Resource or value is Node:
		if visited.has(value.get_instance_id()):return
		visited[value.get_instance_id()]=true
		for property in value.get_property_list():
			if property.usage&PROPERTY_USAGE_STORAGE and property.type in [TYPE_OBJECT,TYPE_ARRAY,TYPE_DICTIONARY]:visit(value.get(property.name))
		if value is Node:
			for child in value.get_children():visit(child)
	elif value is Array:
		for item in value:visit(item)
	elif value is Dictionary:
		for item in value.values():visit(item)
