extends SceneTree
## Exact runtime geometry and cutouts for the offline Cycles lighting bake.
func _initialize():
	if DisplayServer.get_name()=="headless":
		push_error("Bake export requires a real renderer: dummy MultiMesh readback returns identity transforms. Run without --headless.")
		quit(1)
		return
	for id in ["meadow_bend","boulder_run"]:
		var river=preload("res://scripts/river_foreground.gd").create(id)
		var meshes:Array=[]
		for node in river.find_children("*","GeometryInstance3D",true,false):
			if node is MeshInstance3D:
				append_mesh(meshes,node.mesh,node.transform,node.material_override)
			elif node is MultiMeshInstance3D:
				for i in node.multimesh.instance_count:
					append_mesh(meshes,node.multimesh.mesh,node.multimesh.get_instance_transform(i),node.material_override)
		var file=FileAccess.open("res://source/"+id+"_bake_geometry.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(meshes))
		river.free()
	quit()
func append_mesh(output:Array,mesh:Mesh,transform:Transform3D,material:Material):
	var kind:="rock"
	var texture:=""
	if material is ShaderMaterial:
		if material.shader.resource_path.ends_with("bank.gdshader"):kind="bank"
		if material.shader.resource_path.ends_with("vegetation.gdshader"):
			kind="foliage";texture=material.get_shader_parameter("foliage").resource_path
	if kind!="bank" and (absf(transform.origin.x)>52 or transform.origin.z < -54 or transform.origin.z>24):return
	for surface in mesh.get_surface_count():
		var arrays=mesh.surface_get_arrays(surface)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
		var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if indices.is_empty():
			for i in vertices.size():indices.append(i)
		var points:Array=[];var coords:Array=[];var faces:Array=[]
		for i in vertices.size():
			var p:Vector3=transform*vertices[i]
			points.append([p.x,-p.z,p.y]);coords.append([uv[i].x,1.0-uv[i].y])
		for i in range(0,indices.size(),3):
			var center:Vector3=transform*((vertices[indices[i]]+vertices[indices[i+1]]+vertices[indices[i+2]])/3.0)
			if kind=="bank" and (absf(center.x)>50 or center.z < -52 or center.z>22):continue
			# Godot clockwise -> Blender counter-clockwise.
			faces.append([indices[i+2],indices[i+1],indices[i]])
		if not faces.is_empty():output.append({"kind":kind,"texture":texture,"vertices":points,"uv":coords,"faces":faces})
