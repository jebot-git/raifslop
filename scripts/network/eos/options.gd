extends RefCounted
## EOSG's native interface accepts RefCounted option objects via Object.get().
## Keep the small used API surface independent of the optional high-level autoloads.
var values: Dictionary
func _init(data: Dictionary = {}) -> void: values = data
func _get(property: StringName) -> Variant: return values.get(property)
