extends RefCounted
## FPSloppa's shared physical reference; cosmetic VRM dimensions never set it.
const HEAD_HEIGHT := 1.65
const BODY_HEIGHT := 1.70
const HIP_HEIGHT := .92
const ANKLE_HEIGHT := .08
static func world_scale(current: float,tracked_height: float) -> float:
	return clampf(current*HEAD_HEIGHT/tracked_height,.65,1.5)
