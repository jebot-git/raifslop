extends RefCounted
## Per-asset progress and recoverable failures. A successful unrelated asset
## must not hide an error that still needs attention.
var items: Dictionary = {}
var errors: Dictionary = {}
var message: String:
	get: return str(errors.values().back()) if not errors.is_empty() else ""
func begin_item(id: String, size: int, title: String) -> void:
	errors.erase(id)
	items[id] = {"size":size,"received":0,"title":title,"started_usec":Time.get_ticks_usec()}
func advance(id: String, count: int) -> void:
	if items.has(id): items[id].received = count
func complete(id: String) -> void:
	items.erase(id);errors.erase(id)
func cancel(id: String) -> void:
	complete(id)
func fail(id: String, reason: String) -> void:
	var item:Dictionary=items.get(id,{})
	print("ASSET_LOAD_FAILED ",JSON.stringify({"asset":id,"reason":reason,"received":item.get("received",0),"size":item.get("size",0),"elapsed_ms":(Time.get_ticks_usec()-item.get("started_usec",Time.get_ticks_usec()))/1000.0}))
	items.erase(id)
	errors[id] = reason
