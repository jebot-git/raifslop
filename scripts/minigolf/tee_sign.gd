extends Node3D
## A small, fixed course sign facing players approaching the tee.
const Style=preload("res://scripts/ui/waterside_theme.gd")
func build(number:int,hole:Dictionary)->void:
	name="TeeSign"
	box("Post",Vector3(.085,1.15,.085),Vector3(0,.575,0),Color("64503b"))
	box("Frame",Vector3(.96,.62,.075),Vector3(0,1.12,0),Color("64503b"))
	box("Face",Vector3(.90,.56,.012),Vector3(0,1.12,.043),Color("193d32"))
	caption("HoleNumber","HOLE %02d"%number,Vector3(0,1.31,.052),30,Style.BODY_FONT,Style.BRASS)
	var title:=caption("HoleName",str(hole.name),Vector3(0,1.13,.052),38,Style.DISPLAY_FONT,Style.INK)
	title.width=460;title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	caption("Par","PAR %d"%int(hole.par),Vector3(0,.92,.052),30,Style.BODY_FONT,Style.BRASS)
func box(label:String,dimensions:Vector3,at:Vector3,color:Color)->void:
	var mesh:=BoxMesh.new();mesh.size=dimensions
	var material:=StandardMaterial3D.new();material.albedo_color=color;material.roughness=.9
	var part:=MeshInstance3D.new();part.name=label;part.mesh=mesh;part.material_override=material;part.set_meta("skip_lightmap",true);part.position=at;add_child(part)
func caption(label:String,text:String,at:Vector3,size_px:int,font:Font,color:Color)->Label3D:
	var result:=Label3D.new();result.name=label;result.text=text;result.font=font;result.font_size=size_px;result.pixel_size=.0018
	result.position=at;result.modulate=color;result.outline_size=0;result.double_sided=false
	add_child(result);return result
