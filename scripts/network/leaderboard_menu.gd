extends VBoxContainer
var session:Node
var category:="catches"
var summary:Label
var rows:VBoxContainer
var category_choice:Control
var page:=0
var query:=""
var due:=0.0
var previous:Button
var next:Button
var page_label:Label
func _ready()->void:
 add_theme_constant_override("separation",14)
 summary=Label.new();summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(summary)
 var choice=preload("res://scripts/ui/choice.gd").new();add_child(choice)
 choice.configure([{"id":"catches","title":"Most fish caught"},{"id":"earned","title":"Most shekels earned"},{"id":"heaviest","title":"Heaviest catch"},{"id":"longest","title":"Longest catch"},{"id":"exceptional","title":"Exceptional catches"}],"Rankings")
 category_choice=choice
 choice.value=category;choice.update_label()
 choice.selected.connect(func(value:String):category=value;page=0;query="";poll())
 rows=VBoxContainer.new();rows.add_theme_constant_override("separation",10);add_child(rows)
 var navigation:=HBoxContainer.new();add_child(navigation)
 previous=Button.new();previous.text="Previous";navigation.add_child(previous)
 page_label=Label.new();navigation.add_child(page_label)
 next=Button.new();next.text="Next";navigation.add_child(next)
 previous.pressed.connect(func():page=maxi(0,page-1);query="";poll())
 next.pressed.connect(func():page+=1;query="";poll())
 visibility_changed.connect(func():due=0;poll())
 session.rankings.changed.connect(refresh);session.changed.connect(func():due=0;poll());refresh()
func _process(delta:float)->void:
 due-=delta
 if due<=0:poll()
func poll()->void:
 if not is_node_ready() or not is_visible_in_tree():return
 due=2.0
 var activity=session.root_game.get("golf_activity")
 var kind:String="golf" if is_instance_valid(activity) and activity.active else "fishing"
 var key:String=activity.golf.course_id if kind=="golf" else category
 var selection:=kind+":"+key
 if not query.is_empty() and query!=selection:page=0
 query=selection
 session.rankings.request(kind,key,page)
 refresh()
func refresh()->void:
 for child in rows.get_children():rows.remove_child(child);child.queue_free()
 var activity=session.root_game.get("golf_activity")
 category_choice.visible=not (is_instance_valid(activity) and activity.active)
 var data:Dictionary=session.rankings.view
 var golf_active:bool=is_instance_valid(activity) and activity.active
 var kind:String="golf" if golf_active else "fishing"
 var key:String=activity.golf.course_id if golf_active else category
 var ready:bool=not data.is_empty() and data.kind==kind and data.key==key and data.page==page
 previous.disabled=page==0
 next.disabled=not ready or (page+1)*10>=int(data.get("total",0))
 page_label.text="Page %d"%[page+1]
 if not session.active:
  summary.text="Join or host a server to see its accomplishments.";return
 if not ready:
  summary.text="Loading rankings…";return
 var board:Array=data.rows
 if golf_active:
  summary.text="Golf leaderboard · "+activity.golf.model.course.name+" · lowest completed score"
  if board.is_empty():
   var empty:=Label.new();empty.text="No completed rounds yet.";rows.add_child(empty)
  for i in board.size():
   var entry:Dictionary=board[i];var label:=Label.new()
   label.text="%d. %s · %d strokes · %d rounds"%[page*10+i+1,entry.name,entry.best,entry.rounds];rows.add_child(label)
  return
 summary.text="Server accomplishments · %d anglers · Top 50 per category\nRecords include disconnected players. Earnings count catch rewards before spending."%int(data.get("players",0))
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
  var label:=Label.new();label.text="%d.  %s\n     %s"%[page*10+i+1,row.name,value]
  label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",22);rows.add_child(label)
 if category=="exceptional":
  var note:=Label.new();note.text="Exceptional: at least 112% of the species' typical length, or a rare predator.";note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;rows.add_child(note)
func catch_text(fish:Dictionary)->String:
 return "No catch yet" if fish.is_empty() else "%s · %.0f cm · %.2f kg"%[fish.get("name","Fish"),fish.get("length",0),fish.get("weight",0)]
