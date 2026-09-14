extends RefCounted
## Android 10+ scoped storage: publish only the game's new image to Pictures.
## Uses Godot's built-in AndroidRuntime/JNI bridge; no broad storage permission.
static func save(photo: Image,filename: String) -> Error:
	if not Engine.has_singleton("AndroidRuntime") or not Engine.has_singleton("JavaClassWrapper"):return ERR_UNAVAILABLE
	var java=Engine.get_singleton("JavaClassWrapper")
	var runtime=Engine.get_singleton("AndroidRuntime")
	var context=runtime.getApplicationContext()
	if java.get_exception()!=null or context==null:return ERR_UNAVAILABLE
	var resolver=context.getContentResolver()
	var values_class=java.wrap("android.content.ContentValues")
	var media=java.wrap("android.provider.MediaStore$Images$Media")
	if java.get_exception()!=null or resolver==null or values_class==null or media==null:return ERR_UNAVAILABLE
	var values=values_class.ContentValues()
	if java.get_exception()!=null or values==null:return ERR_CANT_CREATE
	# String values avoid ambiguity between Java's boxed numeric put overloads.
	values.put("_display_name",filename);values.put("mime_type","image/png")
	values.put("relative_path","Pictures/Real AI Fishing/");values.put("is_pending","1")
	if java.get_exception()!=null:return ERR_INVALID_DATA
	var uri=resolver.insert(media.EXTERNAL_CONTENT_URI,values)
	if java.get_exception()!=null or uri==null:return ERR_CANT_CREATE
	var descriptor=resolver.openFileDescriptor(uri,"w")
	if java.get_exception()!=null or descriptor==null:
		resolver.delete(uri,null,null);java.get_exception();return ERR_CANT_OPEN
	var fd: int=descriptor.getFd()
	var error:=ERR_CANT_OPEN
	if java.get_exception()==null and fd>=0:
		# Opening our own descriptor through proc duplicates it; save_png closes
		# that duplicate while the MediaStore descriptor stays owned here.
		error=photo.save_png("/proc/self/fd/"+str(fd))
	descriptor.close()
	if java.get_exception()!=null:error=ERR_FILE_CANT_WRITE
	if error==OK:
		values.clear();values.put("is_pending","0")
		if java.get_exception()!=null:error=ERR_FILE_CANT_WRITE
		else:
			var updated=resolver.update(uri,values,null,null)
			if java.get_exception()!=null or updated!=1:error=ERR_FILE_CANT_WRITE
	if error!=OK:resolver.delete(uri,null,null);java.get_exception()
	return error
