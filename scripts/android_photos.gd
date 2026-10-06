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
	values.put("relative_path","Pictures/Ultimate Boomer Simulator/");values.put("is_pending","1")
	if java.get_exception()!=null:return ERR_INVALID_DATA
	var uri=resolver.insert(media.EXTERNAL_CONTENT_URI,values)
	if java.get_exception()!=null or uri==null:return ERR_CANT_CREATE
	var file:=FileAccess.open(str(uri.toString()),FileAccess.WRITE)
	var error:=FileAccess.get_open_error() if file==null else OK
	if file!=null:
		file.store_buffer(photo.save_png_to_buffer())
		file.flush();error=file.get_error();file.close()
	if error==OK:
		values.clear();values.put("is_pending","0")
		if java.get_exception()!=null:error=ERR_FILE_CANT_WRITE
		else:
			var updated=resolver.update(uri,values,null,null)
			if java.get_exception()!=null or updated!=1:error=ERR_FILE_CANT_WRITE
	if error!=OK:resolver.delete(uri,null,null);java.get_exception()
	return error
