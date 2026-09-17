extends Node3D
## Recognizable tackle silhouettes at physical lure scale; no imported physics.
var selected := -1
var marine := false
var fly_mode := false
var lure_mode:=false
var feeder_mode:=false
func set_bait(index: int, saltwater: bool = false, fly_fishing:bool=false,lure_fishing:bool=false,feeder_fishing:bool=false) -> void:
	if selected==index and marine==saltwater and fly_mode==fly_fishing and lure_mode==lure_fishing and feeder_mode==feeder_fishing:return
	marine=saltwater;fly_mode=fly_fishing;lure_mode=lure_fishing;feeder_mode=feeder_fishing
	scale=Vector3.ONE;rotation=Vector3.ZERO
	selected=index
	for child in get_children():remove_child(child);child.queue_free()
	if feeder_mode:
		packed_feed(index)
	elif lure_mode:
		var asset:String="casting_spoon" if marine and index==0 else preload("res://scripts/lure_fishing.gd").MODELS[index]
		add_child(load("res://assets/models/lures/"+asset+".glb").instantiate())
		scale=Vector3.ONE*(1.3 if marine else 1.0)
	elif fly_mode:
		if index==0:fly()
		else:nymph()
	elif marine:
		match index:
			0: ragworm()
			1: squid()
			2: spinner()
			3: prawn()
			4: sardine()
			5: streamer()
	else:
		match index:
			0: worm()
			1: corn()
			2: spinner()
			3: maggots()
			4: bread()
			5: fly()
	set_meta("bait_type",index)
	set_meta("marine",marine)
func packed_feed(index:int) -> void:
	# Bait mixed into the groundbait, entirely inside the 22 mm cage radius.
	var food:=mat({0:"b96b69",1:"f5bd31",3:"ede4ca",4:"efe1b9"}.get(index,"efe1b9"))
	for row in 5:
		for piece in 10:
			var angle:=TAU*(piece+row*.37)/10.0
			var at:=Vector3(cos(angle)*.017,-.020-row*.010,sin(angle)*.017)
			var radii:=Vector3(.003,.004,.003) if index in [0,3] else Vector3(.0035,.0035,.0035)
			var bit:=oval(at,radii,food,"CageBait")
			bit.rotation.y=-angle
func mat(color: String,metallic: float=0.0) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=Color(color);m.metallic=metallic;m.roughness=.22 if metallic>0 else .82;return m
func oval(at: Vector3,radii: Vector3,material: Material,node_name: String) -> MeshInstance3D:
	var mesh:=SphereMesh.new();mesh.radius=1;mesh.height=2;mesh.radial_segments=12;mesh.rings=6
	var node:=MeshInstance3D.new();node.name=node_name;node.mesh=mesh;node.position=at;node.scale=radii;node.material_override=material;add_child(node);return node
func segment(a: Vector3,b: Vector3,radius: float,material: Material,node_name: String) -> void:
	var mesh:=CylinderMesh.new();mesh.top_radius=radius*.8;mesh.bottom_radius=radius;mesh.height=a.distance_to(b);mesh.radial_segments=8
	var node:=MeshInstance3D.new();node.name=node_name;node.mesh=mesh;node.position=(a+b)*.5
	node.quaternion=Quaternion(Vector3.UP,(b-a).normalized());node.material_override=material;add_child(node)
func hook(at: Vector3,scale_factor: float=1.0) -> void:
	var steel:=mat("737e87",.9)
	segment(at,at+Vector3(0,-.018,0)*scale_factor,.0009*scale_factor,steel,"HookShank")
	var previous:=at+Vector3(0,-.018,0)*scale_factor
	for i in range(1,9):
		var angle:=PI+PI*i/8.0
		var next:=at+Vector3(.005+cos(angle)*.005,-.018+sin(angle)*.005,0)*scale_factor
		segment(previous,next,.0009*scale_factor,steel,"HookBend");previous=next
	segment(previous,previous+Vector3(-.001,.008,0)*scale_factor,.0008*scale_factor,steel,"HookPoint")
func worm() -> void:
	var skin:=mat("b96b69");var band:=mat("884b4f")
	var previous:=Vector3(0,0,.003)
	for i in 18:
		var t:=float(i)/17
		var at:=Vector3(sin(t*TAU*1.15)*.008,-t*.061,cos(t*PI)*.003)
		if i>0:segment(previous,at,.0032,skin,"WormBody")
		oval(at,Vector3(.0045,.0032,.0045)*(sin(t*PI)*.3+.7),band if i in [5,6,7] else skin,"WormSegment")
		previous=at
	hook(Vector3(0,-.006,0),.7)
func corn() -> void:
	var yellow:=mat("f5bd31");var pale:=mat("ffe36c")
	for row in [[Vector3(-.005,-.004,0),-.4],[Vector3(.004,-.014,.001),.4],[Vector3(-.004,-.024,0),-.25]]:
		var kernel:=oval(row[0],Vector3(.006,.005,.0045),yellow,"CornKernel");kernel.rotation.z=row[1]
		oval(row[0]+Vector3(0,.001,.004),Vector3(.003,.003,.001),pale,"KernelTip")
	hook(Vector3(0,-.002,0))
func spinner() -> void:
	var gold:=mat("e7bd51",.92);var red:=mat("b52525");var steel:=mat("aebdc7",.95)
	segment(Vector3.ZERO,Vector3(0,-.055,0),.0009,steel,"SpinnerShaft")
	oval(Vector3(0,-.018,0),Vector3(.003,.012,.003),red,"WeightedBody")
	var blade:=oval(Vector3(.009,-.022,.001),Vector3(.012,.023,.0017),gold,"MetalBlade");blade.rotation.z=-.3
	oval(Vector3(.008,-.007,.003),Vector3(.002,.002,.001),steel,"BladePivot")
	for angle in [0.0,TAU/3,TAU*2/3]:
		var holder:=Node3D.new();holder.rotation.y=angle;add_child(holder)
		var before:=get_child_count();hook(Vector3(0,-.050,0),.65)
		for child in get_children().slice(before):child.reparent(holder,false)
func maggots() -> void:
	var cream:=mat("ede4ca");var tip:=mat("9b7858")
	for grub in 3:
		var offset:=Vector3((grub-1)*.007,-grub*.003,(grub%2)*.005)
		for i in 7:
			var t:=float(i)/6
			var at:=offset+Vector3(sin(t*PI)*.003,-t*.022,0)
			oval(at,Vector3(.003,.0026,.003)*(1.0-t*.35),tip if i==6 else cream,"MaggotSegment")
	hook(Vector3(0,-.002,0),.8)
func bread() -> void:
	var crust:=mat("a76a31");var crumb:=mat("efe1b9");var pores:=mat("c7b68d")
	var mesh:=BoxMesh.new();mesh.size=Vector3(.024,.021,.014)
	var node:=MeshInstance3D.new();node.name="BreadCrust";node.mesh=mesh;node.material_override=crust;node.position.y=-.013;node.rotation.z=.2;add_child(node)
	for row in [[Vector3(-.006,-.007,.005),Vector3(.008,.008,.008)],[Vector3(.006,-.010,.005),Vector3(.009,.009,.008)],[Vector3(0,-.018,.005),Vector3(.010,.007,.008)]]:
		oval(row[0],row[1],crumb,"TornBread")
	for i in 8:
		oval(Vector3(sin(i*2.4)*.008,-.012+cos(i*2.4)*.008,.012),Vector3(.0012,.0016,.0005),pores,"CrumbPore")
	hook(Vector3(0,-.003,0),.8)
func fly() -> void:
	var thread_material:=mat("8e3328");var wing:=mat("aea594");var hackle:=mat("544536");var tail:=mat("e0b670")
	oval(Vector3(0,-.013,0),Vector3(.0025,.013,.0025),thread_material,"FlyBody")
	for sign_x in [-1,1]:
		var feather:=oval(Vector3(sign_x*.010,-.009,0),Vector3(.012,.005,.001),wing,"FeatherWing");feather.rotation.z=sign_x*-.6
		for i in 5:segment(Vector3(0,-.004-i*.002,0),Vector3(sign_x*(.012-i*.001),-.010-i*.002,.002),.0005,hackle,"HackleFiber")
	for i in 3:segment(Vector3(0,-.022,0),Vector3((i-1)*.005,-.037,0),.0006,tail,"FlyTail")
	hook(Vector3(0,-.005,0),.8)

func ragworm() -> void:
	worm()
	var bristle:=mat("d29770")
	for i in range(2,16):
		var t:=float(i)/17
		var at:=Vector3(sin(t*TAU*1.15)*.008,-t*.061,cos(t*PI)*.003)
		for side in [-1,1]: segment(at,at+Vector3(side*.007,.002,0),.00045,bristle,"RagwormBristle")
func squid() -> void:
	var flesh:=mat("efe0db")
	oval(Vector3(0,-.018,0),Vector3(.006,.026,.0025),flesh,"SquidStrip")
	for i in 3:
		segment(Vector3((i-1)*.003,-.034,0),Vector3((i-1)*.006,-.07+i*.003,0),.0015,flesh,"SquidTentacle")
	hook(Vector3(0,-.004,0))
func prawn() -> void:
	var shell_material:=mat("cb997f");var legs:=mat("e0bb98")
	for i in 10:
		var t:=float(i)/9
		var at:=Vector3(sin(t*PI)*.015,-t*.052,0)
		oval(at,Vector3(.006,.004,.004)*(1-t*.5),shell_material,"PrawnSegment")
		if i<6:
			for side in [-1,1]:segment(at,at+Vector3(side*.011,-.005,.003),.0005,legs,"PrawnLeg")
	for side in [-1,1]:
		segment(Vector3.ZERO,Vector3(side*.012,.023,0),.00045,legs,"PrawnAntenna")
		oval(Vector3(side*.003,-.004,.004),Vector3.ONE*.001,mat("242626"),"PrawnEye")
	oval(Vector3(0,-.054,0),Vector3(.008,.004,.0015),legs,"PrawnTail")
	hook(Vector3(0,-.008,0))
func sardine() -> void:
	var silver:=mat("b8c9cc",.35)
	oval(Vector3(0,-.035,0),Vector3(.009,.037,.006),silver,"SardineBody")
	oval(Vector3(0,-.034,-.003),Vector3(.007,.032,.004),mat("3b6875",.2),"SardineBack")
	for side in [-1,1]:
		var tail:=oval(Vector3(side*.006,-.077,0),Vector3(.004,.013,.0015),silver,"SardineTail");tail.rotation.z=side*-.6
		oval(Vector3(side*.007,-.012,.002),Vector3(.001,.002,.002),mat("171e23"),"SardineEye")
	hook(Vector3(0,-.013,.005))
func streamer() -> void:
	var white:=mat("e8e8de");var blue:=mat("45848d")
	oval(Vector3(0,-.017,0),Vector3(.003,.018,.003),white,"StreamerBody")
	for i in 12:
		var angle:=TAU*i/12
		segment(Vector3(0,-.005,0),Vector3(sin(angle)*.007,-.07,cos(angle)*.005),.0006,blue if i<4 else white,"StreamerFiber")
	for side in [-1,1]:oval(Vector3(side*.004,-.006,0),Vector3.ONE*.002,mat("252a2c"),"StreamerEye")
	hook(Vector3(0,-.004,0),1.1)

func nymph():
	hook(Vector3.ZERO)
	oval(Vector3(0,0,0),Vector3(.004,.004,.004),mat("cba754",.7),"NymphBead")
	segment(Vector3(0,-.003,0),Vector3(0,-.014,0),.0025,mat("594834"),"NymphBody")

func pose_lure(toward:Vector3,swimming:bool)->void:
	if not lure_mode:return
	toward.y=0
	quaternion=Quaternion(Vector3.UP,toward.normalized()) if swimming and toward.length_squared()>.0001 else Quaternion.IDENTITY
