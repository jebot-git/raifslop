extends RefCounted
## Rod-tip displacement relative to the head; room movement cannot score a pull.
const ENTER_DISTANCE := .24
const EXIT_DISTANCE := .18
var previous_cue := -1
var neutral := Vector3.ZERO
var held := false
var cue_basis := Basis.IDENTITY
func sample(cue: int, tip_from_head: Vector3, facing: Basis = Basis.IDENTITY) -> int:
	if cue != previous_cue:
		previous_cue=cue; neutral=tip_from_head; held=false;cue_basis=facing
	if cue < 0: return -1
	var delta := cue_basis.inverse()*(tip_from_head-neutral)
	var amount: float = -delta.x if cue==0 else delta.x if cue==1 else delta.y
	held = amount >= (EXIT_DISTANCE if held else ENTER_DISTANCE)
	return cue if held else -1
func reset() -> void:
	previous_cue=-1;held=false
