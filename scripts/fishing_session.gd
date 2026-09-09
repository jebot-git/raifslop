extends RefCounted
## Pure simulation shared by tracked VR and desktop input.
enum State { READY, CASTING, WAITING, BITE, FIGHT, LANDED, LOST }
const BAITS = ["Earthworm", "Sweetcorn", "Spinner"]
const SPECIES = [
	{"name": "European perch", "latin": "Perca fluviatilis", "bait": 0, "length": 32.0, "weight": 0.65},
	{"name": "Common carp", "latin": "Cyprinus carpio", "bait": 1, "length": 58.0, "weight": 3.8},
	{"name": "Northern pike", "latin": "Esox lucius", "bait": 2, "length": 72.0, "weight": 2.9},
]
var state: State = State.READY
var bait := 0
var fish_index := 0
var tension := 0.35
var distance := 12.0
var stamina := 1.0
var timer := 0.0
var phase := 0.0
var cue := -1
var cue_time := 0.0
var next_cue := 3.0
var danger_time := 0.0
var cast_distance := 12.0
var catches := 0
var message := "Choose your bait, then cast into open water."
var rng := RandomNumberGenerator.new()
var journal: Array = []

func _init() -> void:
	rng.randomize()

func select_bait(index: int) -> void:
	if state == State.READY:
		bait = clampi(index, 0, 2)

func cast(power: float) -> void:
	if state != State.READY:
		return
	cast_distance = clampf(power, 5.0, 24.0)
	distance = cast_distance
	state = State.CASTING
	timer = 0.8
	message = "Line away"

func strike() -> void:
	if state == State.BITE:
		state = State.FIGHT
		tension = 0.4
		stamina = 1.0
		phase = 0.0
		cue = -1
		next_cue = 2.5
		danger_time = 0.0
		message = "Hook set! Reel steadily; ease off during a run."
	elif state == State.WAITING:
		lose("Too early. Wait for the float to dip.")

func gesture(direction: int) -> bool:
	if state != State.FIGHT or cue != direction:
		return false
	stamina = maxf(0.0, stamina - 0.19)
	tension = clampf(tension - 0.16, 0.08, 0.85)
	cue = -1
	next_cue = 3.5
	message = "Good counter! Bring it closer."
	return true

func is_running() -> bool:
	return state == State.FIGHT and fmod(phase, 9.0) > 5.5

func tick(delta: float, reel: float, rod_lift: float) -> void:
	match state:
		State.CASTING:
			timer -= delta
			if timer <= 0.0:
				state = State.WAITING
				timer = rng.randf_range(4.0, 8.0)
				fish_index = bait
				message = "Watch the float. A quick lift sets the hook."
		State.WAITING:
			timer -= delta
			if timer <= 0.0:
				state = State.BITE
				timer = 1.8
				message = "BITE! Lift the rod now!"
		State.BITE:
			timer -= delta
			if timer <= 0.0:
				lose("Missed the bite. Cast again.")
		State.FIGHT:
			phase += delta
			var running := is_running()
			var rate := clampf(reel, 0.0, 2.0)
			tension += delta * (rate * (0.29 if running else 0.12) + maxf(rod_lift, 0.0) * 0.035 - (0.065 if running else 0.075))
			if running:
				distance += delta * 0.35 * stamina
			elif tension > 0.12:
				distance -= delta * rate * (1.05 + (1.0 - stamina) * 0.9)
			stamina = maxf(0.0, stamina - delta * rate * 0.008)
			tension = clampf(tension, 0.0, 1.0)
			if tension >= 0.98 or tension <= 0.02:
				danger_time += delta
			else:
				danger_time = 0.0
			if danger_time > 1.4:
				lose("Line snapped. Ease off the reel." if tension > 0.5 else "The hook slipped. Keep some tension.")
				return
			next_cue -= delta
			if cue < 0 and next_cue <= 0.0:
				cue = rng.randi_range(0, 2)
				cue_time = 2.2
			if cue >= 0:
				cue_time -= delta
				if cue_time <= 0.0:
					tension = minf(1.0, tension + 0.18)
					cue = -1
					next_cue = 3.0
					message = "Missed counter. Ease the tension."
			if distance <= 1.6 and stamina <= 0.35:
				state = State.LANDED
				catches += 1
				var fish: Dictionary = SPECIES[fish_index].duplicate()
				fish["length"] *= rng.randf_range(0.85, 1.15)
				journal.append(fish)
				message = "%s · %.0f cm\nCatch recorded. Release to fish again." % [fish.name, fish.length]
			else:
				distance = maxf(distance, 1.0)

func lose(reason: String) -> void:
	state = State.LOST
	message = reason

func reset() -> void:
	state = State.READY
	cue = -1
	tension = 0.35
	message = "Choose your bait, then cast into open water."
