extends Node3D
## World-space alignment guide; the real club displays the unsaved candidate.
var prompts=preload("res://addons/golfminus/scripts/golf/guidance_strip.gd").new()
var geometry:=MeshInstance3D.new()
var instructions:=Label3D.new()
var material:=StandardMaterial3D.new()
func _ready()->void:
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color("f3ca75")
	geometry.material_override=material;add_child(geometry)
	instructions.font_size=38;instructions.pixel_size=.0011
	instructions.modulate=Color("f4e6c5");instructions.outline_size=8
	add_child(instructions);instructions.add_child(prompts);prompts.position=Vector3(0,-.32,.01);visible=false
func update_guide(tip:Vector3,face:Vector3,target:Vector3,viewer:Vector3,text:String,tracked:bool)->void:
	visible=true
	material.albedo_color=Color("f3ca75") if tracked else Color("e98070")
	var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in 32:
		for a in [i*TAU/32,(i+1)*TAU/32]:mesh.surface_add_vertex(target+Vector3(cos(a)*.035,.008,sin(a)*.035))
	mesh.surface_add_vertex(target);mesh.surface_add_vertex(tip)
	var direction:=face.normalized()
	var end:=tip+direction*.23
	var side:=direction.cross(Vector3.UP).normalized()*.035
	for p in [tip,end,end,end-direction*.055+side,end,end-direction*.055-side]:mesh.surface_add_vertex(p)
	mesh.surface_end();geometry.mesh=mesh
	var viewer_right:=Vector3.UP.cross((viewer-target).normalized()).normalized()
	instructions.position=target-viewer_right*.45+Vector3(0,.52,0)
	if instructions.position.distance_to(viewer)>.01:instructions.look_at(viewer,Vector3.UP,true)
	instructions.text=text
