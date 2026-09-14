extends RefCounted
## Pure simulation shared by tracked VR and desktop input.
enum State { READY, CASTING, WAITING, BITE, FIGHT, LANDED, LOST }
const BAITS = ["Earthworm", "Sweetcorn", "Spinner", "Maggots", "Bread", "Wet fly"]
const SPECIES = [
	{"rarity": 1, "endurance": 85.0, "name": "European perch", "latin": "Perca fluviatilis", "bait": 0, "length": 32.0, "weight": 0.65},
	{"rarity": 2, "endurance": 140.0, "name": "Common carp", "latin": "Cyprinus carpio", "bait": 1, "length": 58.0, "weight": 3.8, "model": "res://assets/models/fish/carp.glb"},
	{"rarity": 3, "endurance": 150.0, "name": "Northern pike", "latin": "Esox lucius", "bait": 2, "length": 72.0, "weight": 2.9, "model": "res://assets/models/fish/pike.glb"},
	{"rarity": 1, "endurance": 60.0, "name": "Common roach", "latin": "Rutilus rutilus", "bait": 0, "length": 25.0, "weight": 0.25, "power": 0.75, "model": "res://assets/models/fish/roach.glb"},
	{"rarity": 2, "endurance": 125.0, "name": "Tench", "latin": "Tinca tinca", "bait": 1, "length": 42.0, "weight": 1.4, "power": 1.15, "model": "res://assets/models/fish/tench.glb"},
	{"rarity": 1, "endurance": 100.0, "name": "Common bream", "latin": "Abramis brama", "bait": 1, "length": 45.0, "weight": 1.2, "power": 0.9, "model": "res://assets/models/fish/bream.glb"},
	{"rarity": 3, "endurance": 130.0, "name": "Zander", "latin": "Sander lucioperca", "bait": 2, "length": 60.0, "weight": 2.0, "power": 1.2, "model": "res://assets/models/fish/zander.glb"},
	{"rarity": 1, "endurance": 65.0, "name": "Rudd", "latin": "Scardinius erythrophthalmus", "bait": 0, "length": 28.0, "weight": 0.35, "power": 0.80, "model": "res://assets/models/fish/rudd.glb"},
	{"rarity": 2, "endurance": 95.0, "name": "Crucian carp", "latin": "Carassius carassius", "bait": 1, "length": 30.0, "weight": 0.65, "power": 0.95, "model": "res://assets/models/fish/crucian_carp.glb"},
	{"rarity": 2, "endurance": 110.0, "name": "European chub", "latin": "Squalius cephalus", "bait": 0, "length": 40.0, "weight": 0.90, "power": 1.05, "model": "res://assets/models/fish/chub.glb"},
	{"rarity": 2, "endurance": 115.0, "name": "Rainbow trout", "latin": "Oncorhynchus mykiss", "bait": 2, "length": 42.0, "weight": 1.10, "power": 1.15, "model": "res://assets/models/fish/rainbow_trout.glb"},
	{"rarity": 3, "endurance": 120.0, "name": "Brown trout", "latin": "Salmo trutta", "bait": 2, "length": 38.0, "weight": 0.80, "power": 1.10, "model": "res://assets/models/fish/brown_trout.glb"},
	{"name": "European grayling", "latin": "Thymallus thymallus", "bait": 5, "length": 35.0, "weight": 0.55, "power": 1.05, "rarity": 2, "endurance": 105.0, "model": "res://assets/models/fish/grayling.glb"},
	{"name": "Common barbel", "latin": "Barbus barbus", "bait": 0, "length": 60.0, "weight": 2.5, "power": 1.3, "rarity": 3, "endurance": 155.0, "model": "res://assets/models/fish/barbel.glb"},
	{"name": "Common dace", "latin": "Leuciscus leuciscus", "bait": 3, "length": 22.0, "weight": 0.13, "power": 0.7, "rarity": 1, "endurance": 55.0, "model": "res://assets/models/fish/dace.glb"},
	{"name": "Bleak", "latin": "Alburnus alburnus", "bait": 3, "length": 17.0, "weight": 0.04, "power": 0.6, "rarity": 1, "endurance": 45.0, "model": "res://assets/models/fish/bleak.glb"},
	{"name": "Gudgeon", "latin": "Gobio gobio", "bait": 0, "length": 15.0, "weight": 0.035, "power": 0.65, "rarity": 1, "endurance": 50.0, "model": "res://assets/models/fish/gudgeon.glb"},
	{"name": "Brook trout", "latin": "Salvelinus fontinalis", "bait": 2, "length": 32.0, "weight": 0.45, "power": 1.05, "rarity": 3, "endurance": 110.0, "model": "res://assets/models/fish/brook_trout.glb"},
]
# Stable indices preserve existing catch records and model mapping.
const EXTRA_BAIT_SPECIES = {3: [0,3,5,7,9,12,13,16], 4: [1,3,4,7,8,9,13,14,15], 5: [9,10,11,14,15,17]}
const LOCATION_SPECIES = {
 "lakeside": [0,1,2,3,4,5,6,7,8,9,13,14,15,16],
 "lake_pier": [0,1,2,3,5,6,7,9,10,11,12,14,15,17],
 "gray_pier": [0,1,2,3,4,5,6,7,8,11,12,13,15,16],
 "bell_park_pier": [0,1,2,3,4,5,8,9,10,11,13,14,16,17]
}
const Tackle = preload("res://scripts/tackle.gd")
var tackle = Tackle.new()
var counter_rest := 0.0
var last_reward := 0
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
var location_id := "lakeside"
var location_name := "Lakeside"

func _init() -> void:
	rng.randomize()

func select_bait(index: int) -> void:
	if state == State.READY:
		bait = clampi(index, 0, BAITS.size() - 1)

static func species_for_location(id: String) -> Array:
	return LOCATION_SPECIES.get(id, LOCATION_SPECIES["lakeside"]).duplicate()

static func species_for_bait(index: int, id: String = "") -> Array[int]:
	var candidates: Array[int] = []
	for i in range(SPECIES.size()):
		if (SPECIES[i].bait == index or i in EXTRA_BAIT_SPECIES.get(index, [])) and (id.is_empty() or i in species_for_location(id)):
			candidates.append(i)
	return candidates

func bait_hint(index: int) -> String:
	var pool := species_for_bait(index, location_id)
	return "%d species · %s" % [pool.size(), ["Worm feeders", "Coarse fish", "Predators", "Shoal fish", "Surface feeders", "Trout / chub"][clampi(index, 0, BAITS.size() - 1)]]

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
		counter_rest = 0.0
		cue = -1
		next_cue = 2.5
		danger_time = 0.0
		message = "Hook set! Reel steadily; ease off during a run."
	elif state == State.WAITING:
		lose("Too early. Wait for the float to dip.")

func gesture(direction: int) -> bool:
	if state != State.FIGHT or cue != direction:
		return false
	stamina = maxf(0.0, stamina - 19.0 * float(tackle.rod().fatigue) / float(SPECIES[fish_index].endurance))
	tension = clampf(tension - 0.16, 0.08, 0.85)
	cue = -1
	counter_rest = 3.5 + (1.0 - stamina) * 2.0
	phase = 0.0
	next_cue = counter_rest
	message = "Good counter! Bring it closer."
	return true

func is_running() -> bool:
	return state == State.FIGHT and counter_rest <= 0.0 and fmod(phase, 9.0) > 5.5

func tick(delta: float, reel: float, rod_lift: float) -> void:
	match state:
		State.CASTING:
			timer -= delta
			if timer <= 0.0:
				state = State.WAITING
				timer = rng.randf_range(4.0, 8.0)
				var candidates := species_for_bait(bait, location_id)
				var total := 0.0
				for index in candidates: total += 1.0 / float(SPECIES[index].rarity)
				var roll := rng.randf() * total
				fish_index = candidates.back()
				for index in candidates:
					roll -= 1.0 / float(SPECIES[index].rarity)
					if roll <= 0.0:
						fish_index = index
						break
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
			if counter_rest > 0.0: counter_rest = maxf(0.0, counter_rest - delta)
			else: phase += delta
			var power: float = SPECIES[fish_index].get("power", 1.0)
			var running := is_running()
			var rate := clampf(reel, 0.0, 2.0)
			var durability: float = tackle.rod().durability
			var escape_load := (0.025 + stamina * 0.065) * power if running or cue >= 0 else 0.0
			# Fatigued fish pull less; upgraded lines carry more load before the red band.
			var load := rate * (0.17 if running else 0.0) + maxf(rod_lift, 0.0) * 0.035 + escape_load
			# Keep enough reel response to recover slack even with the strongest rod.
			tension += delta * (rate * 0.12 + load / sqrt(durability) - (0.065 if running else 0.075))
			if running:
				distance += delta * 0.35 * stamina * power
			elif tension > 0.12:
				distance -= delta * rate * (1.05 + (1.0 - stamina) * 0.9) / power
			stamina = maxf(0.0, stamina - delta * rate * 0.8 * float(tackle.rod().fatigue) / float(SPECIES[fish_index].endurance))
			tension = clampf(tension, 0.0, 1.0)
			if tension >= 0.98 or tension <= 0.02:
				danger_time += delta
			else:
				danger_time = 0.0
			if danger_time > (1.4 * durability if tension > 0.5 else 1.4):
				lose("Line snapped. Ease off the reel." if tension > 0.5 else "The hook slipped. Keep some tension.")
				return
			next_cue -= delta
			if cue < 0 and next_cue <= 0.0:
				cue = rng.randi_range(0, 2)
				cue_time = 2.2
			if cue >= 0:
				cue_time -= delta
				if cue_time <= 0.0:
					tension = minf(1.0, tension + (0.08 + 0.10 * stamina) / durability)
					cue = -1
					next_cue = 3.0
					message = "Missed counter. Ease the tension."
			if distance <= 1.6 and stamina <= 0.35:
				state = State.LANDED
				catches += 1
				var fish: Dictionary = SPECIES[fish_index].duplicate()
				var size_factor := rng.randf_range(0.85, 1.15)
				fish["length"] *= size_factor
				fish["weight"] *= pow(size_factor, 3.0)
				fish["location_id"] = location_id
				fish["location_name"] = location_name
				last_reward = Tackle.reward(SPECIES[fish_index], float(fish.length))
				fish["shekels"] = last_reward
				tackle.shekels += last_reward
				journal.append(fish)
				message = "%s · %.0f cm · %.2f kg\n%s · +%d shekels" % [fish.name, fish.length, fish.weight, fish.latin, last_reward]
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
