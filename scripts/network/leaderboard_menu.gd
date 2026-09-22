extends VBoxContainer
var session:Node
var category:="catches"
var summary:Label
var rows:VBoxContainer
var category_choice:Control
func _ready()->void:
 add_theme_constant_override("separation",14)
 summary=Label.new();summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(summary)
 var choice=preload("res://scripts/ui/choice.gd").new();add_child(choice)
 choice.configure([{"id":"catches","title":"Most fish caught"},{"id":"earned","title":"Most shekels earned"},{"id":"heaviest","title":"Heaviest catch"},{"id":"longest","title":"Longest catch"},{"id":"exceptional","title":"Exceptional catches"}],"Rankings")
 category_choice=choice
 choice.value=category;choice.update_label()
 choice.selected.connect(func(value:String):category=value;refresh())
 rows=VBoxContainer.new();rows.add_theme_constant_override("separation",10);add_child(rows)
 session.golf.changed.connect(refresh);session.leaderboard_changed.connect(refresh);session.changed.connect(refresh);refresh()
func refresh()->void:
 for child in rows.get_children():rows.remove_child(child);child.queue_free()
 var activity=session.root_game.get("golf_activity")
 category_choice.visible=not (is_instance_valid(activity) and activity.active)
 if is_instance_valid(activity) and activity.active:
  summary.text="Golf leaderboard · "+activity.golf.model.course.name+" · lowest completed score"
  var board:Array=session.golf.board.get(activity.golf.course_id,[])
  if board.is_empty():
   var empty:=Label.new();empty.text="No completed rounds yet.";rows.add_child(empty)
  for i in board.size():
   var entry:Dictionary=board[i];var label:=Label.new()
   label.text="%d. %s · %d strokes · %d rounds"%[i+1,entry.name,entry.best,entry.rounds];rows.add_child(label)
  return
 var data:Dictionary=session.leaderboard_view
 if not session.active or data.is_empty():
  summary.text="Join or host a server to see its accomplishments.";return
 summary.text="Server accomplishments · %d anglers · Top 50 per category\nRecords include disconnected players. Earnings count catch rewards before spending."%int(data.get("players",0))
 var board:Array=data.categories.get(category,[])
 if board.is_empty():
  var label:=Label.new();label.text="No catches recorded yet.";rows.add_child(label)
 for i in board.size():
  var row:Dictionary=board[i]
  var value:String
  match category:
   "catches":value="%d fish"%row.catches
   "earned":value="%d shekels"%row.earned
   "heaviest":value=catch_text(row.biggest)
   "longest":value=catch_text(row.longest_fish)
   _:value="%d exceptional · %s"%[row.exceptional,catch_text(row.noteworthy)]
  var label:=Label.new();label.text="%d.  %s\n     %s"%[i+1,row.name,value]
  label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",22);rows.add_child(label)
 if category=="exceptional":
  var note:=Label.new();note.text="Exceptional: at least 112% of the species' typical length, or a rare predator.";note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;rows.add_child(note)
func catch_text(fish:Dictionary)->String:
 return "No catch yet" if fish.is_empty() else "%s · %.0f cm · %.2f kg"%[fish.get("name","Fish"),fish.get("length",0),fish.get("weight",0)]
