extends RefCounted
## In-game estimate: reconstructed courses use par rating / slope 113 until rated.
static var courses:Dictionary={}
static func course(id:String)->Dictionary:
	if not courses.has(id):courses[id]=JSON.parse_string(FileAccess.get_file_as_string("res://addons/golfminus/courses/%s.json"%id))
	return courses[id]
static func par(id:String,hole:int)->int:return int(course(id).holes[hole].par)
static func total_par(id:String)->int:
	var total:=0
	for h in course(id).holes:total+=int(h.par)
	return total
static func index(stats:Dictionary)->float:
	var recent:Array=[]
	for id in stats:
		var row:Dictionary=stats[id]
		for round_data in row.get("history",[]):recent.append(round_data)
		if row.get("history",[]).is_empty() and row.get("rounds",0)>0:
			recent.append({"time":0.0,"differential":float(row.get("best",total_par(id))-total_par(id))})
	recent.sort_custom(func(a,b):return a.time<b.time)
	recent=recent.slice(maxi(0,recent.size()-20))
	if recent.is_empty():return 54.0
	var values:Array=[]
	for r in recent:values.append(float(r.differential))
	values.sort()
	var n:=values.size();var count:=1;var adjustment:=0.0
	if n<=3:adjustment=-2
	elif n==4:adjustment=-1
	elif n<=5:count=1
	elif n==6:count=2;adjustment=-1
	elif n<=8:count=2
	elif n<=11:count=3
	elif n<=14:count=4
	elif n<=16:count=5
	elif n<=18:count=6
	elif n==19:count=7
	else:count=8
	var total:=0.0
	for i in count:total+=values[i]
	return snappedf(clampf(total/count+adjustment,0,54),.1)
static func strokes(id:String,hole:int,handicap:int)->int:
	var holes:Array=[]
	for i in 18:holes.append(i)
	# Provisional allocation by playing length; explicit stroke_index overrides it.
	holes.sort_custom(func(a,b):return float(course(id).holes[a].length)>float(course(id).holes[b].length))
	var rank:int=int(course(id).holes[hole].get("stroke_index",holes.find(hole)+1))
	return floori(handicap/18.0)+(1 if rank<=handicap%18 else 0)
static func cap(id:String,hole:int,handicap:int)->int:return par(id,hole)+2+strokes(id,hole,handicap)

static func net(id:String,scores:Array,handicap:int)->int:
	var total:=0
	for i in scores.size():total+=maxi(0,int(scores[i]))-strokes(id,i,handicap)
	return total
