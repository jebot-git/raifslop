extends RefCounted
## Progress adapter for FPSloppa's avatar transfer service.
var items: Dictionary = {}
var message := ""
func begin_item(id: String, size: int, title: String) -> void:
	items[id] = {"size":size,"received":0,"title":title}
func advance(id: String, count: int) -> void:
	if items.has(id): items[id].received = count
func complete(id: String) -> void: items.erase(id)
func fail(id: String, reason: String) -> void:
	items.erase(id)
	message = reason
