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
const FISH_CHOICES=[{"id":"catches","title":"Most fish caught"},{"id":"earned","title":"Most shekels earned"},{"id":"heaviest","title":"Heaviest catch"},{"id":"longest","title":"Longest catch"},{"id":"exceptional","title":"Exceptional catches"}]
func _ready()->void:
 add_theme_constant_override("separation",14)
 summary=Label.new();summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(summary)
 var choice=preload("res://scripts/ui/choice.gd").new();add_child(choice)
 choice.configure(FISH_CHOICES,"Rankings")
 category_choice=choice
 choice.value=category;choice.update_label()
 choice.selected.connect(func(value:String):
  category=value
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
 var kind:String="fishing"
 var key:String=category
 var selection:=kind+":"+key
 if is_online():
  var online_key:String=key
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
 if is_online():
  refresh_online();return
 category_choice.configure(FISH_CHOICES,"Rankings");category_choice.value=category;category_choice.update_label()
 category_choice.visible=true
 var data:Dictionary=session.rankings.view
 var kind:String="fishing"
 var key:String=category
 var ready:bool=not data.is_empty() and data.kind==kind and data.key==key and data.page==page
 previous.disabled=page==0
 next.disabled=not ready or (page+1)*10>=int(data.get("total",0))
 page_label.text="Page %d"%[page+1]
 if not session.active:
  summary.text="Join or host a server to see its accomplishments.";return
 if not ready:
  summary.text="Loading rankings…";return
 var board:Array=data.rows
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
func refresh_online()->void:
 category_choice.visible=true;category_choice.configure(FISH_CHOICES,"Rankings")
 category_choice.value=category;category_choice.update_label()
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
  match category:
   "heaviest":formatted="%.2f kg"%value
   "longest":formatted="%.1f cm"%value
   "catches":formatted="%d fish"%value
   "earned":formatted="%d shekels"%value
   "exceptional":formatted="%d exceptional catches"%value
   _:formatted=str(value)
  var label:=Label.new();label.text="%d. %s · %s"%[row.position,row.name,formatted];label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;rows.add_child(label)
