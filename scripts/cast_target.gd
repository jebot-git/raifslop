extends RefCounted
## Keep a motion cast on reachable water along its measured heading.
static func fit(anchor:Vector3,direction:Vector3,distance:float,valid:Callable)->Vector3:
	if not anchor.is_finite() or not direction.is_finite() or not is_finite(distance) or direction.length_squared()<.000001:return Vector3.INF
	direction=direction.normalized()
	distance=clampf(distance,5.0,24.0)
	var target:=anchor+direction*distance
	if valid.call(target):return target
	# A powerful fly cast can overshoot the opposite bank. Search backward only
	# on this ray; never rotate toward the headset or cast through an obstruction.
	var rejected:=distance
	for index in range(1,39):
		var reach:=maxf(5.0,distance-index*.5)
		target=anchor+direction*reach
		if valid.call(target):
			var accepted:=reach
			for _step in 4:
				var midpoint:float=(accepted+rejected)*.5
				if valid.call(anchor+direction*midpoint):accepted=midpoint
				else:rejected=midpoint
			return anchor+direction*accepted
		if reach==5.0:break
		rejected=reach
	return Vector3.INF
