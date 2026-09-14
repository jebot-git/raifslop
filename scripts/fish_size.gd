extends RefCounted
## Callers orient each model toward +X before measuring mouth-to-tail mesh extent.
static func bounds(node: Node3D, parent := Transform3D.IDENTITY) -> AABB:
	var transform := parent*node.transform
	var result: AABB=transform*node.get_aabb() if node is MeshInstance3D else AABB()
	for child in node.get_children():
		if child is Node3D:
			var box:=bounds(child,transform)
			if box.has_volume(): result=result.merge(box) if result.has_volume() else box
	return result
static func fit(container: Node3D, length_cm: float) -> AABB:
	var measured:=AABB()
	for child in container.get_children():
		if child is Node3D:
			var box:=bounds(child)
			if box.has_volume():measured=measured.merge(box) if measured.has_volume() else box
	if measured.size.x<.001:return measured
	var factor:=length_cm*.01/measured.size.x
	for child in container.get_children():
		if child is Node3D:
			child.scale*=factor;child.position*=factor
	return AABB(measured.position*factor,measured.size*factor)
