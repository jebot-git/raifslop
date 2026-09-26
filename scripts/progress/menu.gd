extends VBoxContainer
var progress:Node
var destinations:Node
func _ready()->void:
	add_theme_constant_override("separation",14)
	progress.changed.connect(refresh);destinations.changed.connect(refresh);refresh()
func refresh()->void:
	for child in get_children():remove_child(child);child.queue_free()
	if not destinations.pending.is_empty():
		var button:=Button.new();button.custom_minimum_size.y=48
		button.text="Travel to "+destinations.Catalog.all()[destinations.pending].name
		button.pressed.connect(destinations.travel);add_child(button)
		var note:=Label.new();note.text="Finish your cast or retire from your current online round before travelling.";note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(note)
	for id in progress.Catalog.ALL:
		var entry:Dictionary=progress.Catalog.ALL[id]
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",14);add_child(row)
		var icon:=TextureRect.new();icon.custom_minimum_size=Vector2(96,96);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture=load("res://assets/ui/achievements/art/"+(id if progress.unlocked.has(id) else "locked")+".png");row.add_child(icon)
		var label:=Label.new();label.text=("✓ " if progress.unlocked.has(id) else "○ ")+entry.name+"\n"+entry.description
		label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;row.add_child(label)
	if not progress.error.is_empty():
		var error:=Label.new();error.text=progress.error;add_child(error)
