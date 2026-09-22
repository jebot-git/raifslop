extends RefCounted
## Offline-baked mapped surface. Height uses the same diagonal as rendered terrain.
const LIES:=["rough","fairway","fringe","green","sand","water","out"]
static var cache:Dictionary={}
var origin:=Vector2.ZERO
var width:=0
var depth:=0
var hwidth:=0
var hdepth:=0
var lies:PackedByteArray
var heights:PackedFloat32Array
func configure(course:Dictionary)->void:
	var data:Dictionary=course.layout.surface
	origin=Vector2(data.origin[0],data.origin[1]);width=int(data.width);depth=int(data.height)
	hwidth=(width-1)/2+1;hdepth=(depth-1)/2+1
	var key:String=course.id+"/"+str(course.layout.revision)
	if not cache.has(key):
		var path:String="res://addons/golfminus/assets/course_data/%s/"%course.id
		cache[key]=[FileAccess.get_file_as_bytes(path+"lies.bin"),FileAccess.get_file_as_bytes(path+"height.bin").to_float32_array()]
	lies=cache[key][0];heights=cache[key][1]
	assert(lies.size()==width*depth and heights.size()==hwidth*hdepth,"Invalid mapped course surface")
func lie(x:float,z:float)->String:
	var ix:=roundi(x-origin.x);var iz:=roundi(z-origin.y)
	if ix<0 or iz<0 or ix>=width or iz>=depth:return "out"
	return LIES[lies[iz*width+ix]]
func height(x:float,z:float)->float:
	var px:=clampf((x-origin.x)/2,0,hwidth-1.00001);var pz:=clampf((z-origin.y)/2,0,hdepth-1.00001)
	var ix:=int(px);var iz:=int(pz);var u:=px-ix;var v:=pz-iz
	var a:=heights[iz*hwidth+ix];var b:=heights[iz*hwidth+ix+1]
	var c:=heights[(iz+1)*hwidth+ix];var d:=heights[(iz+1)*hwidth+ix+1]
	return a+(b-a)*u+(c-a)*v if u+v<=1 else d+(c-d)*(1-u)+(b-d)*(1-v)
