extends RefCounted
## Compatibility API for shared score storage. Minigolf uses gross strokes only.
const Catalog=preload("res://scripts/minigolf/catalog.gd")
static func par(id:String,hole:int)->int:return int(Catalog.course(id).holes[hole].par) if id in Catalog.ALL else 4
static func total_par(id:String)->int:
	var total:=0
	for i in 18:total+=par(id,i)
	return total
static func index(_stats:Dictionary)->float:return 0.0
static func strokes(_id:String,_hole:int,_handicap:int)->int:return 0
static func cap(_id:String,_hole:int,_handicap:int)->int:return 12
static func net(_id:String,scores:Array,_handicap:int)->int:
	var total:=0
	for score in scores:total+=maxi(0,int(score))
	return total
