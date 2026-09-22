extends RefCounted
const Handicap=preload("res://addons/golfminus/scripts/golf/handicap.gd")
## Nested in Fishing's existing player records, saved by its atomic leaderboard writer.
static func valid(data:Variant)->bool:
	if not data is Dictionary or data.size()>4:return false
	for course in data:
		if course not in ["spyglass","pebble","dalkey","alpine"] or not data[course] is Dictionary:return false
		var row:Dictionary=data[course]
		for field in ["rounds","forfeits","best","last"]:
			var n=row.get(field)
			if not (n is int or n is float) or not is_finite(n) or n<0 or n>1e9 or n!=int(n):return false
		var history=row.get("history",[])
		if not history is Array or history.size()>20:return false
		for r in history:
			if not r is Dictionary:return false
			for field in ["time","differential"]:
				if not (r.get(field) is float or r.get(field) is int) or not is_finite(float(r[field])):return false
	return true
static func finish(records:Dictionary,key:String,course:String,scores:Array,count_forfeits:=true)->bool:
	if not records.has(key) or scores.size()!=18:return false
	if not records[key].has("golf"):records[key].golf={}
	var golf:Dictionary=records[key].golf
	if not golf.has(course):golf[course]={"rounds":0,"forfeits":0,"best":0,"last":0}
	var row:Dictionary=golf[course]
	var total:=0;var forfeits:=0
	for score in scores:
		if score<0:forfeits+=1
		else:total+=score
	if count_forfeits:row.forfeits+=forfeits
	# DNF/forfeited cards never become a deceptively low ranked score.
	if forfeits==0:
		row.rounds+=1;row.last=total
		row.best=total if row.best==0 else mini(row.best,total)
		var history:Array=row.get("history",[])
		history.append({"time":Time.get_unix_time_from_system(),"differential":float(total-Handicap.total_par(course))})
		row.history=history.slice(maxi(0,history.size()-20))
	return true
static func snapshot(records:Dictionary)->Dictionary:
	var result:Dictionary={}
	for course in ["spyglass","pebble","dalkey","alpine"]:
		var rows:Array=[]
		for record in records.values():
			var stats:Dictionary=record.get("golf",{}).get(course,{})
			if stats.is_empty() or stats.rounds==0:continue
			var row:Dictionary=stats.duplicate();row.erase("history");row.handicap=Handicap.index(record.get("golf",{}));row.name=record.name;rows.append(row)
		rows.sort_custom(func(a,b):return a.name.naturalnocasecmp_to(b.name)<0 if a.best==b.best else a.best<b.best)
		result[course]=rows.slice(0,50)
	return result

static func forfeit(records:Dictionary,key:String,course:String)->bool:
	if not records.has(key):return false
	if not records[key].has("golf"):records[key].golf={}
	if not records[key].golf.has(course):records[key].golf[course]={"rounds":0,"forfeits":0,"best":0,"last":0}
	records[key].golf[course].forfeits+=1
	return true
