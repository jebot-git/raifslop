extends Node
## One requested page, polled only while the rankings panel is visible.
const PAGE_SIZE := 10
const MAX_PAGE := 4 # Preserve the existing top-50 limit.
const Fish = preload("res://scripts/network/leaderboard.gd")
const Golf = preload("res://addons/golfminus/scripts/golf/server_records.gd")
const Courses = preload("res://addons/golfminus/scripts/golf/catalog.gd")
var session:Node
var limits:Dictionary={}
var view:Dictionary={}
var serial:=0
var pending:=""
var pending_due:=0
signal changed
func setup(owner_session:Node)->void:
 session=owner_session;name="Rankings"
func reset()->void:
 limits.clear();view.clear();pending="";serial+=1;changed.emit()
static func valid_query(kind:String,key:String,page:int)->bool:
 return page>=0 and page<=MAX_PAGE and ((kind=="fishing" and key in Fish.CATEGORIES) or (kind=="golf" and key in Courses.ALL))
func request(kind:String,key:String,page:int=0)->void:
 if not session.active or not valid_query(kind,key,page):return
 var query:="%s:%s:%d"%[kind,key,page]
 if query==pending and Time.get_ticks_msec()<pending_due:return
 pending=query;pending_due=Time.get_ticks_msec()+5000
 serial+=1
 if multiplayer.is_server():_receive(serial,make_page(kind,key,page))
 else:_request.rpc_id(1,serial,kind,key,page)
func make_page(kind:String,key:String,page:int)->Dictionary:
 if not valid_query(kind,key,page):return {}
 var rows:Array
 if kind=="fishing":rows=session.leaderboard.category_rows(key)
 else:rows=Golf.snapshot(session.leaderboard.records)[key]
 return {"kind":kind,"key":key,"page":page,"total":rows.size(),"players":session.leaderboard.records.size(),"rows":rows.slice(page*PAGE_SIZE,(page+1)*PAGE_SIZE)}
@rpc("any_peer","call_remote","reliable",0)
func _request(id:int,kind:String,key:String,page:int)->void:
 if not session.active or not multiplayer.is_server():return
 var peer:=multiplayer.get_remote_sender_id()
 if not session.players.has(peer) or not valid_query(kind,key,page):return
 var guard:Dictionary=limits.get(peer,{"time":session.clock,"tokens":4.0})
 guard.tokens=minf(4,guard.tokens+maxf(0,session.clock-guard.time)*2);guard.time=session.clock;limits[peer]=guard
 if guard.tokens<1:return
 guard.tokens-=1
 _receive.rpc_id(peer,id,make_page(kind,key,page))
@rpc("authority","call_remote","reliable",0)
func _receive(id:int,data:Dictionary)->void:
 if id!=serial or not valid_page(data):return
 pending="";view=data.duplicate(true);changed.emit()
static func valid_page(data:Dictionary)->bool:
 if data.size()!=6:return false
 for field in ["kind","key"]:
  if not data.get(field) is String:return false
 for field in ["page","total","players"]:
  if not data.get(field) is int or data[field]<0:return false
 if not valid_query(data.kind,data.key,data.page) or data.total>50 or not data.get("rows") is Array:return false
 if data.rows.size()!=mini(PAGE_SIZE,maxi(0,data.total-data.page*PAGE_SIZE)):return false
 for row in data.rows:
  if data.kind=="fishing":
   if not Fish.valid_projection(row,data.key):return false
  else:
   if not row is Dictionary or not row.get("name") is String or row.name.length()>32:return false
   for key in ["best","rounds","forfeits","last","handicap"]:
    var value=row.get(key)
    if not (value is int or value is float) or not is_finite(value) or absf(value)>1e9:return false
 return true
