extends "res://scripts/ui/choice.gd"
## Small OptionButton-compatible adapter using the shared in-canvas selector.
signal item_selected(index:int)
func _ready()->void:
	super._ready()
	selected.connect(func(id:String):item_selected.emit(int(id)))
func add_item(title:String,id:=-1)->void:
	var options:=items.duplicate(true)
	options.append({"id":str(options.size() if id<0 else id),"title":title})
	configure(options,"Select")
	if value.is_empty():select(0)
func select(index:int)->void:
	if index<0 or index>=items.size():return
	value=items[index].id;update_label()
