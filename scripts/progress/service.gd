extends Node
## Local profile milestones. Cloud unlocks use the currently authenticated account.
const Catalog=preload("res://scripts/progress/achievement_catalog.gd")
const Destinations=preload("res://scripts/progress/destination_catalog.gd")
var host:Node
var path:="user://achievements.json"
var unlocked:Dictionary={}
var visits:Array=[]
var catches:=0
var error:=""
signal changed
func setup(game:Node)->void:
	host=game;name="Achievements";add_to_group("activity_services")
	if FileAccess.file_exists(path):
		var file:=FileAccess.open(path,FileAccess.READ)
		if file==null or file.get_length()>16384:error="Achievements could not be read.";return
		var data=JSON.parse_string(file.get_as_text())
		if not data is Dictionary or data.get("version")!=1 or not data.get("unlocked") is Dictionary or not data.get("visits") is Array or data.visits.size()>Destinations.all().size():
			error="Saved achievements are invalid.";return
		var count=data.get("catches")
		if not (count is int or count is float) or not is_finite(count) or count<0 or count>2147483647 or count!=int(count):error="Saved achievement count is invalid.";return
		for id in data.unlocked:
			if not Catalog.ALL.has(id) or data.unlocked[id]!=true:error="Saved achievements are invalid.";return
		for id in data.visits:
			if not id is String or not Destinations.all().has(id):error="Saved destinations are invalid.";return
		unlocked=data.unlocked;visits=data.visits;catches=int(count)
func save()->void:
	if not error.is_empty():return
	var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:error="Achievements could not be saved.";changed.emit();return
	file.store_string(JSON.stringify({"version":1,"catches":catches,"unlocked":unlocked,"visits":visits}));file.flush()
	var code:=file.get_error();file.close()
	if code!=OK or DirAccess.rename_absolute(path+".tmp",path)!=OK:error="Achievements could not be saved."
	changed.emit()
func unlock(id:String)->void:
	if not error.is_empty() or not Catalog.ALL.has(id):return
	unlocked[id]=true
	if is_instance_valid(host) and is_instance_valid(host.get("network")):
		var online:Node=host.network.get("online")
		if is_instance_valid(online):online.achievements.earn(id)
func visit(location:String)->void:
	var id:=Destinations.for_location(location)
	if id.is_empty() or id in visits:return
	visits.append(id)
	if visits.size()>=3:unlock("ubs_explorer")
	save()
func caught(species:Dictionary,length:float)->void:
	if not is_finite(length) or length<=0 or float(species.get("length",0))<=0:return
	catches=mini(2147483647,catches+1);unlock("ubs_first_catch")
	if catches>=10:unlock("ubs_ten_catches")
	if length/float(species.length)>=1.12 or int(species.get("rarity",0))>=4:unlock("ubs_exceptional_catch")
	save()
func golf(course:String,scores:Array,finished:bool,forfeits:Array=[])->void:
	if course not in preload("res://addons/golfminus/scripts/golf/catalog.gd").ALL or scores.size()>18:return
	var changed_before:=unlocked.size()
	for score in scores:
		if not score is int or score<1 or score>1000:return
	for i in scores.size():
		var score:int=scores[i]
		if i not in forfeits and score<preload("res://addons/golfminus/scripts/golf/handicap.gd").par(course,i):unlock("ubs_birdie")
	if finished and scores.size()==18 and forfeits.is_empty():unlock("ubs_first_round")
	if unlocked.size()!=changed_before:save()
