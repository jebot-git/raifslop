extends "res://scripts/fish_water_boundary.gd"
## Exhaustive pre-optimization predicate retained only for differential tests.
func segment_obstructed(start:Vector3,end:Vector3)->bool:
	for face in ground_faces:
		if Geometry3D.segment_intersects_triangle(start,end,face[0],face[1],face[2])!=null:return true
	return false
