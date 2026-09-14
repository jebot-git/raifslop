extends Node3D
## Recognizable tackle silhouettes at physical lure scale; no imported physics.
var selected := -1
func set_bait(index: int) -> void:
	if selected==index:return
	selected=index
	for child in get_children():remove_child(child);child.queue_free()
	match index:
		0: worm()
		1: corn()
		2: spinner()
		3: maggots()
		4: bread()
		5: fly()
	set_meta("bait_type",index)
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
