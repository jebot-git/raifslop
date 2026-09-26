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
var online_view:Dictionary={}
var online_error:=""
var online_busy:=false
var golf_category:="best"
const FISH_CHOICES=[{"id":"catches","title":"Most fish caught"},{"id":"earned","title":"Most shekels earned"},{"id":"heaviest","title":"Heaviest catch"},{"id":"longest","title":"Longest catch"},{"id":"exceptional","title":"Exceptional catches"}]
const GOLF_CHOICES=[{"id":"best","title":"Best completed score"},{"id":"rounds","title":"Completed rounds"},{"id":"forfeits","title":"Forfeited holes"},{"id":"last","title":"Latest completed score"},{"id":"handicap","title":"Current handicap"}]
func _ready()->void:
 add_theme_constant_override("separation",14)
 summary=Label.new();summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(summary)
 var choice=preload("res://scripts/ui/choice.gd").new();add_child(choice)
 choice.configure(FISH_CHOICES,"Rankings")
 category_choice=choice
 choice.value=category;choice.update_label()
 choice.selected.connect(func(value:String):
  if value in ["best","rounds","forfeits","last","handicap"]:golf_category=value
  else:category=value
  page=0;query="";online_view.clear();poll())
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
 if is_online():
  var online_key:String=("golf/" if golf_category=="best" else "golf_"+golf_category+"/")+key if kind=="golf" else key
  if not query.is_empty() and query!=online_key:page=0
  query=online_key
  if online_busy:return
  online_busy=true
  var requested_page:=page
  var result:Dictionary=await session.online.leaderboards.query_page(online_key,page)
  online_busy=false
  if query==online_key and requested_page==page and is_online():
   online_error=str(result.get("error",""))
   if online_error.is_empty():online_view=result
  refresh();return
 if not query.is_empty() and query!=selection:page=0
 query=selection
 session.rankings.request(kind,key,page)
 refresh()
func refresh()->void:
 for child in rows.get_children():rows.remove_child(child);child.queue_free()
 var activity=session.root_game.get("golf_activity")
 if is_online():
  refresh_online(activity);return
 category_choice.configure(FISH_CHOICES,"Rankings");category_choice.value=category;category_choice.update_label()
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
   label.text="%d. %s · %d strokes · %d rounds\nLast: %d · Forfeited holes: %d · Handicap: %.1f"%[page*10+i+1,entry.name,entry.best,entry.rounds,entry.last,entry.forfeits,entry.handicap];label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;rows.add_child(label)
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
func is_online()->bool:
 return is_instance_valid(session.get("online")) and session.online.leaderboards.enabled and not session.online.lobby.is_empty()
func refresh_online(activity:Node)->void:
 var golf_active:bool=is_instance_valid(activity) and activity.active
 category_choice.visible=true;category_choice.configure(GOLF_CHOICES if golf_active else FISH_CHOICES,"Rankings")
 category_choice.value=golf_category if golf_active else category;category_choice.update_label()
 var ready:bool=online_view.get("key")==query and online_view.get("page")==page
 previous.disabled=page==0;next.disabled=not ready or (page+1)*10>=int(online_view.get("total",0))
 page_label.text="Page %d"%[page+1]
 summary.text="Online accomplishments · EOS · Top 50"
 if not online_error.is_empty():summary.text+="\n"+online_error;return
 if not ready:summary.text+="\nLoading rankings…";return
 if online_view.rows.is_empty():
  var empty:=Label.new();empty.text="No records yet.";rows.add_child(empty)
 for row in online_view.rows:
  var value:float=preload("res://scripts/network/leaderboards/catalog.gd").decode(query,int(row.score))
  var formatted:String
  match category if not golf_active else golf_category:
   "heaviest":formatted="%.2f kg"%value
   "longest":formatted="%.1f cm"%value
   "catches":formatted="%d fish"%value
   "earned":formatted="%d shekels"%value
   "exceptional":formatted="%d exceptional catches"%value
   "rounds":formatted="%d completed rounds"%value
   "forfeits":formatted="%d forfeited holes"%value
   "handicap":formatted="Handicap %.1f"%value
   _:formatted="%d strokes"%value
  var label:=Label.new();label.text="%d. %s · %s"%[row.position,row.name,formatted];label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;rows.add_child(label)
