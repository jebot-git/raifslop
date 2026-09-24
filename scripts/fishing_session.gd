extends RefCounted
## Pure simulation driven by tracked VR gameplay.
enum State { READY, CASTING, WAITING, BITE, FIGHT, LANDED, LOST }
enum Submerge { NONE, PULL, SLACK }
const SUBMERGE_WARNING := .8
const SUBMERGE_DURATION := 3.2
const MAX_SUBMERGE_CHANGE := .28
const FAST_REEL_RATE := 1.4
var submerge: Submerge = Submerge.NONE
var submerge_time := 0.0
var next_submerge := 9.0
var next_submerge_kind: Submerge = Submerge.PULL
var reel_rate := 0.0
var fly_reel_penalty := false
const BAITS = ["Earthworm", "Sweetcorn", "Spinner", "Maggots", "Bread", "Wet fly"]
const SPECIES = [
	{"model_yaw": PI / 2, "rarity": 1, "endurance": 85.0, "name": "European perch", "latin": "Perca fluviatilis", "bait": 0, "length": 32.0, "weight": 0.65},
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
	{"name": "Blacktail", "latin": "Diplodus capensis", "length": 30.0, "weight": 0.65, "rarity": 1, "endurance": 85.0, "power": 0.85, "bait": 0, "habitat": "marine", "model": "res://assets/models/fish/blacktail.glb"},
	{"name": "Galjoen", "latin": "Dichistius capensis", "length": 38.0, "weight": 1.2, "rarity": 2, "endurance": 125.0, "power": 1.1, "bait": 0, "habitat": "marine", "model": "res://assets/models/fish/galjoen.glb"},
	{"name": "Hottentot", "latin": "Pachymetopon blochii", "length": 35.0, "weight": 0.8, "rarity": 1, "endurance": 95.0, "power": 0.95, "bait": 1, "habitat": "marine", "model": "res://assets/models/fish/hottentot.glb"},
	{"name": "Red roman", "latin": "Chrysoblephus laticeps", "length": 40.0, "weight": 1.4, "rarity": 2, "endurance": 125.0, "power": 1.15, "bait": 1, "habitat": "marine", "model": "res://assets/models/fish/roman.glb"},
	{"name": "White steenbras", "latin": "Lithognathus lithognathus", "length": 65.0, "weight": 3.2, "rarity": 3, "endurance": 155.0, "power": 1.3, "bait": 3, "habitat": "marine", "model": "res://assets/models/fish/white_steenbras.glb"},
	{"name": "Elf / bluefish", "latin": "Pomatomus saltatrix", "length": 45.0, "weight": 1.1, "rarity": 2, "endurance": 120.0, "power": 1.2, "bait": 2, "habitat": "marine", "model": "res://assets/models/fish/elf.glb"},
	{"name": "Cape yellowtail", "latin": "Seriola lalandi", "length": 85.0, "weight": 5.5, "rarity": 3, "endurance": 170.0, "power": 1.4, "bait": 2, "habitat": "marine", "model": "res://assets/models/fish/yellowtail.glb"},
	{"name": "Harder mullet", "latin": "Chelon richardsonii", "length": 32.0, "weight": 0.4, "rarity": 1, "endurance": 75.0, "power": 0.8, "bait": 0, "habitat": "marine", "model": "res://assets/models/fish/harder.glb"},
	{"name":"Wels catfish", "latin":"Silurus glanis", "length":180.0, "weight":45.0, "rarity":5, "endurance":400.0, "power":1.7, "bait":-1, "habitat":"freshwater", "predator":true, "model":"res://assets/models/fish/wels_catfish.glb"},
	{"name":"Bronze whaler shark", "latin":"Carcharhinus brachyurus", "length":240.0, "weight":100.0, "rarity":5, "endurance":520.0, "power":2.1, "bait":-1, "habitat":"marine", "predator":true, "model":"res://assets/models/fish/bronze_whaler.glb"},
	{"name": "Dusky kob", "latin": "Argyrosomus japonicus", "length": 70.0, "weight": 3.2, "rarity": 3, "endurance": 160.0, "power": 1.3, "bait": 4, "habitat": "marine", "model": "res://assets/models/fish/dusky_kob.glb"},
	{"name": "White stumpnose", "latin": "Rhabdosargus globiceps", "length": 38.0, "weight": 0.95, "rarity": 2, "endurance": 105.0, "power": 1.0, "bait": 3, "habitat": "marine", "model": "res://assets/models/fish/white_stumpnose.glb"},
	{"name": "Zebra seabream", "latin": "Diplodus hottentotus", "length": 35.0, "weight": 0.85, "rarity": 2, "endurance": 115.0, "power": 1.05, "bait": 0, "habitat": "marine", "model": "res://assets/models/fish/zebra_seabream.glb"},
	{"name": "Cape horse mackerel", "latin": "Trachurus capensis", "length": 30.0, "weight": 0.28, "rarity": 1, "endurance": 65.0, "power": 0.78, "bait": 2, "habitat": "marine", "model": "res://assets/models/fish/cape_horse_mackerel.glb"},
	{"name": "Silver bream", "latin": "Blicca bjoerkna", "length": 25.0, "weight": 0.24, "rarity": 1, "endurance": 65.0, "power": 0.75, "bait": 3, "model": "res://assets/models/fish/silver_bream.glb"},
	{"name": "Ruffe", "latin": "Gymnocephalus cernua", "length": 15.0, "weight": 0.04, "rarity": 1, "endurance": 45.0, "power": 0.6, "bait": 0, "model": "res://assets/models/fish/ruffe.glb"},
	{"name": "Ide", "latin": "Leuciscus idus", "length": 42.0, "weight": 1.05, "rarity": 2, "endurance": 115.0, "power": 1.05, "bait": 4, "model": "res://assets/models/fish/ide.glb"},
	{"name": "Asp", "latin": "Leuciscus aspius", "length": 65.0, "weight": 2.6, "rarity": 3, "endurance": 150.0, "power": 1.25, "bait": 2, "model": "res://assets/models/fish/asp.glb"},
	{"name": "Leervis", "latin": "Lichia amia", "length": 85.0, "weight": 5.0, "rarity": 3, "endurance": 165.0, "power": 1.3, "bait": 4, "habitat": "marine", "model": "res://assets/models/fish/leervis.glb"},
	{"name": "Atlantic chub mackerel", "latin": "Scomber colias", "length": 35.0, "weight": 0.42, "rarity": 1, "endurance": 80.0, "power": 0.85, "bait": 2, "habitat": "marine", "model": "res://assets/models/fish/atlantic_chub_mackerel.glb"},
	{"name":"Huchen", "latin":"Hucho hucho", "length":120.0, "weight":18.0, "rarity":5, "endurance":340.0, "power":1.6, "bait":-1, "habitat":"freshwater", "predator":true, "model":"res://assets/models/fish/huchen.glb"},
	{"name":"Ragged-tooth shark", "latin":"Carcharias taurus", "length":220.0, "weight":90.0, "rarity":5, "endurance":480.0, "power":1.95, "bait":-1, "habitat":"marine", "predator":true, "model":"res://assets/models/fish/raggedtooth_shark.glb"},
	{"name":"Cutthroat trout","latin":"Oncorhynchus clarkii","length":40.0,"weight":.85,"rarity":2,"endurance":118.0,"power":1.1,"bait":5,"model":"res://assets/models/fish/cutthroat_trout.glb"},
	{"name":"Arctic char","latin":"Salvelinus alpinus","length":45.0,"weight":1.2,"rarity":3,"endurance":138.0,"power":1.18,"bait":5,"model":"res://assets/models/fish/arctic_char.glb"}
]
# Stable indices preserve existing catch records and model mapping.
const MARINE_BAITS = ["Ragworm", "Squid", "Spinner", "Prawn", "Sardine", "Saltwater fly"]
const MARINE_BAIT_SPECIES = {0:[18,19,20,22,25,29,30], 1:[18,20,21,22,23,24,28,29,30,31,37], 2:[23,24,28,31,36,37], 3:[18,19,20,21,22,25,29,30], 4:[18,21,23,24,28,31,36,37], 5:[18,23,24,25,28,31,36,37]}
const EXTRA_BAIT_SPECIES = {2:[34], 1:[32,34], 0:[32,34], 3: [0,3,5,7,9,12,13,16,33,34], 4: [1,3,4,7,8,9,13,14,15,32], 5: [9,10,11,14,15,17,34,35]}
const LOCATION_SPECIES = {
 "lakeside": [0,1,2,3,4,5,6,7,8,9,13,14,15,16,32,33,34],
 "lake_pier": [0,1,2,3,5,6,7,9,10,11,12,14,15,17,32,33,34,35],
 "gray_pier": [0,1,2,3,4,5,6,7,8,11,12,13,15,16,32,33],
 "bell_park_pier": [0,1,2,3,4,5,8,9,10,11,13,14,16,17,32,34,35],
 "simons_town_rocks": [18,19,20,21,23,24,28,30,31,37],
 "blouberg_sunrise_2": [18,19,22,23,24,25,28,29,31,37],
 "secluded_beach": [18,19,20,21,23,25,29,30,31,36],
 "fish_hoek_beach": [18,20,22,23,24,25,28,29,31,36,37],
 "meadow_bend":[11,12,9,14,3,13,16,33,34,35],
 "boulder_run":[10,11,12,17],
 "cedar_creek":[10,17,40],
 "glacier_run":[11,12,41]
}
# A single chance per eligible retrieval, never a per-frame probability.
const PREDATOR_CHANCE := .03
const WELS := 26
const BRONZE_WHALER := 27
const HUCHEN := 38
const RAGGEDTOOTH := 39
const PREDATOR_LOCATIONS = {
 "lakeside":[WELS], "lake_pier":[WELS], "gray_pier":[WELS], "bell_park_pier":[WELS],
 "meadow_bend":[HUCHEN], "boulder_run":[HUCHEN],
 "simons_town_rocks":[BRONZE_WHALER,RAGGEDTOOTH], "blouberg_sunrise_2":[BRONZE_WHALER],
 "secluded_beach":[BRONZE_WHALER,RAGGEDTOOTH], "fish_hoek_beach":[BRONZE_WHALER,RAGGEDTOOTH]
}
const PREDATOR_PREY = {WELS:[0,3,7,14,15,16,32,33], BRONZE_WHALER:[18,23,25,31,37], HUCHEN:[11,12,14,16,17,33], RAGGEDTOOTH:[18,20,21,23,25,30,31,37]}
# 0/1/2: directional hold; 3: deep pull; 4: slack rush; 5: long run.
const PREDATOR_SEQUENCES = {WELS:[5,2,3,0,3,1,4], BRONZE_WHALER:[5,0,3,1,5,2,4], HUCHEN:[5,0,1,4,2,3,0], RAGGEDTOOTH:[5,2,3,1,3,0,4]}
var predator_encounters_enabled := true
var encounter_rng := RandomNumberGenerator.new()
var predator_checked := false
var retrieval_time := 0.0
var retrieved_metres := 0.0
var rebaited_from := -1
var takeover_count := 0
var predator_step := 0
var predator_run_time := 0.0
var predator_notice_time := 0.0
var predator_opening_time := 0.0
const FightProfiles = preload("res://scripts/fish_fight_profiles.gd")
var fight_step := 0
var dive_step := 0
var mirror_fight := false
const JUMP_WARNING := .7
const JUMP_AIR := 1.2
var jump_time := 0.0
var jump_tug := false
var jump_resolved := false
var jump_count := 0
var jump_attempts := 0
var next_jump := 7.0
var jumps_enabled := true
const Fly = preload("res://scripts/fly_fishing.gd")
var fly=Fly.new()
const Feeder=preload("res://scripts/feeder_fishing.gd")
var feeder=Feeder.new()
const Lure=preload("res://scripts/lure_fishing.gd")
var lure=Lure.new()
enum Rig { CLASSIC, FEEDER, LURE }
var rig:Rig=Rig.CLASSIC
func is_feeder_fishing()->bool:return rig==Rig.FEEDER and Feeder.supported(location_id)
func is_lure_fishing()->bool:return rig==Rig.LURE and Lure.supported(location_id)
static func rig_supported(value:int,id:String)->bool:
	return value==Rig.CLASSIC or value==Rig.FEEDER and Feeder.supported(id) or value==Rig.LURE and Lure.supported(id)
func select_rig(value:int)->bool:
	if state!=State.READY or not rig_supported(value,location_id):return false
	if rig==value:return true
	rig=value; bait=0;fly.reset();feeder.reset();lure.reset();return true
func current_species()->Array:
	return Lure.preferred(bait,location_id) if is_lure_fishing() else Feeder.preferred(bait,location_id) if is_feeder_fishing() else species_for_bait(bait,location_id)
func choose_fish(sector:int)->int:
	return population.choose(location_id,current_species(),sector,SPECIES,rng,Lure.POOLS[location_id] if is_lure_fishing() else Feeder.POOLS[location_id] if is_feeder_fishing() else current_species() if Fly.river(location_id) else [])
func bait_model()->int:return Feeder.BAIT_MODELS[bait] if is_feeder_fishing() else bait

const Population = preload("res://scripts/fish_population.gd")
var population = Population.new()
var cast_position := Vector3(0, 0, -12)

func prepare_population() -> void:
	population.ensure_location(location_id, species_for_location(location_id, false))

func feeding_activity(sector: int) -> float:
	prepare_population()
	return population.activity(location_id, current_species(), sector)

func is_fly_fishing()->bool:return Fly.river(location_id) and rig==Rig.CLASSIC
func bait_count()->int:return Lure.BAIT_NAMES.size() if is_lure_fishing() else Feeder.BAIT_NAMES.size() if is_feeder_fishing() else 2 if is_fly_fishing() else BAITS.size()
const Tackle = preload("res://scripts/tackle.gd")
var tackle = Tackle.new()
var counter_rest := 0.0
var last_reward := 0
var state: State = State.READY
var bait := 0
var fish_index := 0
var tension := 0.35
var distance := 12.0
var landing_distance := 1.6
var at_ground_boundary := false
var retrieve_origin := Vector3.ZERO
var stamina := 1.0
const RECOVERY_REACTION := .65
var recovery_time := 0.0
var recovery_count := 0
func recover_strength(amount: float = 0.0) -> void:
	stamina=minf(1.0,stamina+amount)
	# Never erase inherited line strain or extend an already active window.
	if recovery_time<=0.0:
		recovery_time=RECOVERY_REACTION;recovery_count+=1

var timer := 0.0
var phase := 0.0
var cue := -1
const COUNTER_WINDOW := 6.0
const MAX_FAILED_COUNTERS := 3
const SLACK_LIMIT := 0.10
const STRAIN_LIMIT := 0.90
const STRAIN_GRACE := 2.5
const MAX_TENSION_RISE := 0.14
var failed_counters := 0
var danger_side := 0
var cue_time := 0.0
var resistance := 1.0
var counter_direction := -1
var counter_active := false
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
	encounter_rng.randomize()

func select_bait(index: int) -> void:
	if state == State.READY:
		bait = clampi(index, 0, bait_count() - 1)

static func species_for_location(id: String, include_predators: bool = true) -> Array:
	var result: Array = LOCATION_SPECIES.get(id, LOCATION_SPECIES["lakeside"]).duplicate()
	if include_predators: result.append_array(PREDATOR_LOCATIONS.get(id,[]))
	return result

static func predators_for_prey(index: int, id: String) -> Array:
	var result:Array=[]
	if not LOCATION_SPECIES.has(id) or index not in LOCATION_SPECIES[id]:return result
	for predator in PREDATOR_LOCATIONS.get(id,[]):
		if index in PREDATOR_PREY[predator]:result.append(predator)
	return result

static func predator_for_prey(index: int, id: String) -> int:
	var choices:=predators_for_prey(index,id)
	return -1 if choices.is_empty() else int(choices[0])

func is_predator() -> bool:
	return bool(SPECIES[fish_index].get("predator",false))

static func is_marine_location(id: String) -> bool:
	return id in ["simons_town_rocks", "blouberg_sunrise_2", "secluded_beach", "fish_hoek_beach"]

func bait_name(index: int) -> String:
	if is_lure_fishing():return (Lure.MARINE_NAMES if is_marine_location(location_id) else Lure.BAIT_NAMES)[clampi(index,0,2)]
	if is_feeder_fishing():return Feeder.BAIT_NAMES[clampi(index,0,3)]
	if is_fly_fishing():return ["Dry fly","Nymph"][clampi(index,0,1)]
	return (MARINE_BAITS if is_marine_location(location_id) else BAITS)[clampi(index,0,BAITS.size()-1)]

static func species_for_bait(index: int, id: String = "") -> Array[int]:
	var candidates: Array[int] = []
	if Fly.river(id):
		for i in Fly.preferred(index,id):candidates.append(i)
		return candidates
	var local := species_for_location(id, false) if not id.is_empty() else range(SPECIES.size())
	for i in local:
		if SPECIES[i].get("predator",false): continue
		if SPECIES[i].get("habitat", "freshwater")=="marine":
			if i in MARINE_BAIT_SPECIES.get(index, []): candidates.append(i)
		elif SPECIES[i].bait==index or i in EXTRA_BAIT_SPECIES.get(index, []):
			candidates.append(i)
	return candidates

func bait_hint(index: int) -> String:
	if is_lure_fishing():return "%d species · %s"%[Lure.preferred(index,location_id).size(),["Steady retrieve","Slow hops and pauses","Retrieve and pause"][clampi(index,0,2)]]
	if is_feeder_fishing():return "%d bottom-feeding species · Cage feeder"%Feeder.preferred(index,location_id).size()
	if is_fly_fishing():return "Surface drift · Watch the rise" if index==0 else "Subsurface · Watch indicator"
	var pool := species_for_bait(index, location_id)
	var hints := ["Worm feeders", "Reef / surf fish", "Coastal predators", "Crustacean feeders", "Baitfish hunters", "Coastal fly fish"] if is_marine_location(location_id) else ["Worm feeders", "Coarse fish", "Predators", "Shoal fish", "Surface feeders", "Trout / chub"]
	return "%d species · %s" % [pool.size(), hints[clampi(index, 0, bait_count() - 1)]]

func cast(power: float, target := Vector3(INF, INF, INF), anchor := Vector3(INF, INF, INF)) -> void:
	if state != State.READY:
		return
	at_ground_boundary = false
	fly.reset()
	cast_distance = clampf(power, 5.0, 24.0)
	cast_position = target if target.is_finite() else Vector3(0, 0, -cast_distance)
	retrieve_origin=anchor if anchor.is_finite() else Vector3(0,cast_position.y,0)
	if is_feeder_fishing():feeder.cast(location_id,population.sector_for(location_id,cast_position))
	lure.reset()
	fly.start = cast_position
	prepare_population()
	distance = cast_distance
	state = State.CASTING
	timer = 0.8
	message = "Line away"

func strike() -> void:
	if state == State.BITE:
		state = State.FIGHT
		predator_checked=false;retrieval_time=0.0;retrieved_metres=0.0;rebaited_from=-1
		predator_step=0;predator_run_time=0.0;predator_notice_time=0.0;predator_opening_time=0.0
		tension = 0.4
		stamina = 1.0
		resistance=1.0;counter_direction=-1;counter_active=false
		phase = 0.0
		counter_rest = 0.0
		cue = -1
		next_cue = 2.5
		danger_time = 0.0
		danger_side = 0
		failed_counters = 0
		_reset_submerge()
		jump_attempts=0;next_jump=7.0
		fight_step=0;dive_step=0;mirror_fight=rng.randf()<.5
		if not is_predator():
			next_submerge=float(FightProfiles.profile(fish_index).dive_gap)*.7*FightProfiles.tempo(fish_index)
			next_submerge_kind=FightProfiles.profile(fish_index).dives[0]
			var family: String=FightProfiles.SPECIES[fish_index][0]
			if family in ["runner","cruiser","ambush"]:
				var profile := FightProfiles.profile(fish_index)
				var tempo := FightProfiles.tempo(fish_index)
				phase=(float(profile.cycle)-float(profile.run))*tempo+.01
				next_cue=float(profile.run)*tempo+.8
		message = "Hook set! Strip line; save the reel for a rush or tired fish." if is_fly_fishing() else "Hook set! Reel steadily; ease off during a run."
	elif state == State.WAITING:
		lose("Too early. Wait for the strong feeder bite, not the light nibbles." if is_feeder_fishing() else "Too early. Wait for the float to dip.")

func gesture(direction: int) -> bool:
	# Sampled once per simulation step. An event or a brief flick cannot finish
	# the counter, and an old input is never held implicitly across future ticks.
	counter_direction = direction
	return state == State.FIGHT and cue >= 0 and cue == direction

func counter_seconds() -> float:
	var base := (3.0 if is_predator() else 2.0) + float(SPECIES[fish_index].get("power",1.0)) * .6
	return base if is_predator() else base*float(FightProfiles.profile(fish_index).hold)

func set_ground_boundary(touching: bool) -> void:
	at_ground_boundary = touching
	if not touching or state != State.FIGHT: return
	if jump_time > 0.0:
		jump_time = 0.0; jump_resolved = false; jump_tug = false
	if cue in [0, 1]:
		cue = 2; cue_time = maxf(cue_time, COUNTER_WINDOW)
		counter_active = false; counter_direction = -1
		message = "Fish turning toward open water — lift to counter."
	if submerge == Submerge.SLACK:
		submerge = Submerge.PULL; submerge_time = SUBMERGE_WARNING + SUBMERGE_DURATION
		message = reel_instruction()

func _counter_tick(delta: float) -> void:
	counter_active = cue >= 0 and counter_direction == cue
	counter_direction = -1
	if not counter_active: return
	var progress := minf(resistance, delta / counter_seconds())
	resistance = maxf(0.0, resistance-progress)
	stamina = maxf(0.0, stamina-progress*19.0*float(tackle.rod().fatigue)/float(SPECIES[fish_index].endurance))
	tension = clampf(tension-progress*.16,0.0,1.0)
	if resistance <= .00001:
		cue=-1
		counter_rest=(2.5+(1.0-stamina)*1.5) if is_predator() else (3.5+(1.0-stamina)*2.0)
		if not is_predator(): counter_rest*=float(FightProfiles.profile(fish_index).rest)*rng.randf_range(.92,1.08)
		phase=0.0;next_cue=counter_rest
		if not is_predator() and FightProfiles.SPECIES[fish_index][0] in ["runner","cruiser"]:
			# Leave room for a complete run between directional counters.
			next_cue=counter_rest+float(FightProfiles.profile(fish_index).cycle)*FightProfiles.tempo(fish_index)+.4
		message="Counter complete. Keep stripping and following the fish." if is_fly_fishing() and not fly_reel_allowed() else "Fish tired! Reel it closer."


func is_running() -> bool:
	if jump_time>0.0:return false
	if is_predator(): return state==State.FIGHT and predator_run_time>0.0
	var p := FightProfiles.profile(fish_index)
	var tempo := FightProfiles.tempo(fish_index)
	return state == State.FIGHT and submerge == Submerge.NONE and counter_rest <= 0.0 and fmod(phase, float(p.cycle)*tempo) > (float(p.cycle)-float(p.run))*tempo

func _reset_submerge() -> void:
	recovery_time=0.0
	jump_time=0.0;jump_resolved=false;jump_tug=false
	submerge=Submerge.NONE;submerge_time=0.0;next_submerge=9.0
	next_submerge_kind=Submerge.PULL;reel_rate=0.0
	predator_run_time=0.0;predator_notice_time=0.0;predator_opening_time=0.0

func submerge_active() -> bool:
	return state==State.FIGHT and submerge!=Submerge.NONE and submerge_time<=SUBMERGE_DURATION

func effective_counter() -> bool:
	if state!=State.FIGHT: return false
	if jump_time>0.0:return counter_active and reel_rate<=.1
	if is_predator() and is_running():return reel_rate<=.1
	if submerge_active():
		return reel_rate<=.1 if submerge==Submerge.PULL else reel_rate>=FAST_REEL_RATE
	return counter_active

func reel_instruction() -> String:
	if jump_time>0.0:return "JUMP · STOP REELING · TUG " + ("LEFT" if cue==0 else "RIGHT")
	if submerge==Submerge.PULL: return "FISH DIVING · STOP REELING"
	if submerge==Submerge.SLACK: return "FISH RUSHING IN · REEL FASTER"
	if is_fly_fishing():return "FISH TIRED · REEL IN" if fly_reel_allowed() else "STRIP LINE · FOLLOW THE FISH"
	return "FISH RUNNING · STOP REELING" if is_running() else "REEL STEADILY"

func fly_reel_allowed() -> bool:
	if jump_time>0.0:return false
	return submerge==Submerge.SLACK or (stamina<=.35 and submerge==Submerge.NONE and cue<0 and not is_running())

func _submerge_tick(delta: float) -> void:
	if submerge!=Submerge.NONE:
		submerge_time=maxf(0.0,submerge_time-delta)
		if submerge_time<=0.0:
			submerge=Submerge.NONE;next_submerge=float(FightProfiles.profile(fish_index).dive_gap)*FightProfiles.tempo(fish_index)*rng.randf_range(.9,1.1)
			phase=0.0;next_cue=maxf(next_cue,2.0)
			message="Fish resurfaced. " + (reel_instruction() if is_fly_fishing() else "Reel steadily.")
		return
	next_submerge-=delta
	# Do not overlap directional holds/runs, or start at already unsafe tension.
	if next_submerge<=0.0 and cue<0 and counter_rest<=0.0 and not is_running() and tension>=.25 and tension<=.75:
		submerge=Submerge.PULL if at_ground_boundary else next_submerge_kind
		dive_step+=1
		var dives: Array=FightProfiles.profile(fish_index).dives
		next_submerge_kind=dives[dive_step%dives.size()]
		submerge_time=SUBMERGE_WARNING+SUBMERGE_DURATION
		message=reel_instruction()

func _try_jump() -> bool:
	if at_ground_boundary: return false
	if not jumps_enabled or fish_index not in [10,11,40] or stamina<.55 or jump_attempts>=2 or next_jump>0.0:return false
	if cue>=0 or submerge!=Submerge.NONE or is_running() or counter_rest>0.0 or distance<landing_distance+2 or tension<.25 or tension>.75:return false
	next_jump=18.0; jump_attempts+=1
	if rng.randf()>(.60 if fish_index==10 else .35):return false
	_start_jump(rng.randi_range(0,1))
	return true

func _start_jump(direction: int) -> void:
	jump_time=JUMP_WARNING+JUMP_AIR;jump_resolved=false;jump_tug=false;jump_count+=1
	cue=clampi(direction,0,1);resistance=1.0;counter_active=false;counter_direction=-1
	message="Fish rising to jump! " + reel_instruction()

func tug(direction: int) -> void:
	if state==State.FIGHT and jump_time>0.0 and jump_time<=JUMP_AIR and direction==cue:
		jump_tug=true

func _jump_tick(delta: float) -> void:
	counter_active=jump_tug and reel_rate<=.1 and not jump_resolved
	jump_tug=false;counter_direction=-1
	if counter_active:
		stamina=maxf(0.0,stamina-.28);jump_resolved=true;resistance=0.0
		message="Jump countered! Fish exhausted."
	jump_time=maxf(0.0,jump_time-delta)
	if jump_time<=0.0:
		if not jump_resolved:
			recover_strength(.25);message="Missed jump. Keep control of the fish."
		cue=-1;counter_active=false;counter_rest=3.0;next_cue=3.0;phase=0.0
		next_submerge=maxf(next_submerge,4.0)

func _try_predator(delta: float, rate: float, previous_distance: float) -> void:
	if not predator_encounters_enabled or predator_checked or is_predator() or state!=State.FIGHT: return
	var predator := predator_for_prey(fish_index, location_id)
	if predator<0: predator_checked=true;return
	# Count actual active retrieval, not waiting, running, paused time or repeated rolls.
	if rate<.2 or is_running() or submerge!=Submerge.NONE or tension<=SLACK_LIMIT: return
	var progress := maxf(0.0,previous_distance-distance)
	if progress<=0.0:return
	retrieval_time+=delta;retrieved_metres+=progress
	if retrieval_time<6.0 or retrieved_metres<2.0 or distance<landing_distance+3.0:return
	predator_checked=true
	if encounter_rng.randf()<PREDATOR_CHANCE:
		var choices:=predators_for_prey(fish_index,location_id)
		_takeover(choices[encounter_rng.randi_range(0,choices.size()-1)] if choices.size()>1 else predator)

func _takeover(predator: int) -> void:
	if state!=State.FIGHT or is_predator() or predator not in predators_for_prey(fish_index,location_id):return
	rebaited_from=fish_index;fish_index=predator;takeover_count+=1;predator_checked=true
	stamina=1.0 # Preserve the prey fight’s tension and accumulated line strain.
	cue=-1;cue_time=0.0;counter_direction=-1;counter_active=false;resistance=1.0
	failed_counters=0;phase=0.0;counter_rest=0.0
	_reset_submerge();predator_step=1;next_cue=0.0;predator_notice_time=.6
	predator_opening_time=7.0 if predator in [WELS,HUCHEN] else 9.0
	predator_run_time=predator_opening_time
	message="%s took your %s!\nSTOP REELING — powerful run!" % [SPECIES[predator].name,SPECIES[rebaited_from].name]

func _predator_sequence_tick(delta: float) -> void:
	if submerge!=Submerge.NONE:
		submerge_time=maxf(0.0,submerge_time-delta)
		if submerge_time<=0.0:
			submerge=Submerge.NONE;next_cue=2.5;counter_rest=2.5
			message="Predator resurfaced. Reel it closer."
		return
	if predator_run_time>0.0:
		predator_run_time=maxf(0.0,predator_run_time-delta)
		if predator_run_time<=0.0:next_cue=2.5;counter_rest=2.5;message="Run ended. Recover some line."
		return
	if cue>=0 or counter_rest>0.0:return
	next_cue-=delta
	if next_cue>0.0:return
	var sequence: Array=PREDATOR_SEQUENCES[fish_index]
	var action: int=sequence[predator_step%sequence.size()]
	if at_ground_boundary and action in [0,1,4]: action = 5 if action < 3 else 3
	# Recovery is never cut short by a dive at unsafe tension.
	if action>=3 and (tension<.25 or tension>.75):return
	predator_step+=1
	if action<3:
		cue=action;cue_time=8.0;resistance=1.0
		message="Large predator turning — hold the counter."
	elif action==5:
		predator_run_time=4.5 if fish_index in [WELS,HUCHEN] else 6.0
		message="Powerful run! Stop reeling."
	else:
		submerge=Submerge.PULL if action==3 else Submerge.SLACK
		submerge_time=SUBMERGE_WARNING+SUBMERGE_DURATION
		message=reel_instruction()

func tick(delta: float, reel: float, rod_lift: float, winding_reel := false, rod_side_speed:float=0.0) -> void:
	fly_reel_penalty=false
	population.tick(delta)
	feeder.tick(delta)
	match state:
		State.LOST:
			timer -= delta
			if timer <= 0:
				var reason := message
				reset()
				message = reason + " Cast again when ready."
		State.CASTING:
			timer -= delta
			if timer <= 0.0:
				state = State.WAITING
				var sector := population.sector_for(location_id,cast_position)
				var preferred := current_species()
				timer = population.bite_delay(location_id, preferred, sector, rng, is_fly_fishing())
				if is_lure_fishing():timer=clampf(timer*.55,3,14)
				fish_index = choose_fish(sector)
				message = "Drift naturally. Sweep upstream against the current to mend." if is_fly_fishing() else "Retrieve the lure; lift on a strike." if is_lure_fishing() else "Wait through light nibbles. Lift on the strong pull." if is_feeder_fishing() else "Watch the float. A quick lift sets the hook."
		State.WAITING:
			if is_lure_fishing():
				if _retrieve_empty_line(delta,reel):return
				cast_position=lure.move_sideways(cast_position,retrieve_origin,rod_side_speed,delta)
				distance=retrieve_origin.distance_to(cast_position)
				timer-=delta*lure.work(delta,reel,rod_lift,bait,Fly.river(location_id),rod_side_speed)
			elif is_feeder_fishing():
				if feeder.nibbling:
					# Guard before retrieval, including quiet gaps between knocks.
					if reel>.03:
						lose("Reeled during a nibble. Wait for the strong feeder bite.");return
					if not feeder.advance_nibbles(delta,rng):return
				else:
					if _retrieve_empty_line(delta,reel):return
					if reel>.03:feeder.age=maxf(0,feeder.age-delta*2);return
					var sector:=population.sector_for(location_id,cast_position)
					if not feeder.settle(delta,location_id,sector):return
					timer-=delta*feeder.attraction(location_id,sector)
					if timer<=0:
						feeder.begin_nibbles(rng)
						message="Light nibbles — hold still. Wait for the strong pull."
						return
			elif is_fly_fishing():
				fly.drift(delta,reel,location_id,bait==1)
				if _retrieve_empty_line(delta,reel):return
				if fly.age>32.0 or fly.start.z+fly.offset.z> -4.0:
					reset();message="Drift finished. Cast upstream again.";return
				timer-=delta*fly.quality
			else:
				if _retrieve_empty_line(delta,reel):return
				timer -= delta
			if timer <= 0.0:
				var at: Vector3 = fly.start + fly.offset if is_fly_fishing() else cast_position
				fish_index = choose_fish(population.sector_for(location_id,at))
				state = State.BITE
				timer = (1.25 if bait==0 else 1.6) if is_fly_fishing() else Feeder.HOOK_WINDOW if is_feeder_fishing() else 1.8
				message = "TAKE! Lift the rod now!" if is_fly_fishing() else "BITE! Lift the rod now!"
		State.BITE:
			if _retrieve_empty_line(delta,reel):return
			timer -= delta
			if timer <= 0.0:
				lose("Missed the bite. Cast again.")
		State.FIGHT:
			recovery_time=maxf(0.0,recovery_time-delta)
			reel_rate=clampf(reel,0.0,2.0)
			fly_reel_penalty=is_fly_fishing() and winding_reel and reel_rate>.03 and not fly_reel_allowed()
			if fly_reel_penalty:
				# A fly reel loads a fighting fish sharply; stripping remains separate.
				# Add this outside the ordinary load cap so rod upgrades cannot erase it.
				tension=clampf(tension+delta*.55*reel_rate,0,1)
				message="Too much strain! Strip line; reel only for a rush or tired fish."
			if jump_time>0.0:
				_jump_tick(delta)
				if fly_reel_penalty:_check_line_failure(delta)
				return
			next_jump=maxf(0.0,next_jump-delta)
			if _try_jump():return
			if predator_notice_time>0.0:
				predator_notice_time=maxf(0.0,predator_notice_time-delta)
			predator_opening_time=maxf(0.0,predator_opening_time-delta)
			var previous_distance := distance
			_counter_tick(delta)
			if counter_rest > 0.0:
				counter_rest = maxf(0.0, counter_rest - delta)
				if counter_rest<=0.0:
					recover_strength();message=reel_instruction()
			if _try_jump():return
			if is_predator(): _predator_sequence_tick(delta)
			else: _submerge_tick(delta)
			if counter_rest<=0.0 and submerge==Submerge.NONE: phase += delta
			var power: float = SPECIES[fish_index].get("power", 1.0)
			var running := is_running()
			var rate := clampf(reel, 0.0, 2.0)
			var durability: float = tackle.rod().durability
			var escape_load := (0.025 + stamina * 0.065) * power if running or cue >= 0 else 0.0
			if is_predator() and counter_active: escape_load *= .45
			# Fatigued fish pull less; upgraded lines carry more load before the red band.
			var current_load := minf(.045,fly.current_speed*.035) if is_fly_fishing() else 0.0
			var load := current_load + rate * (0.17 if running else 0.0) + maxf(rod_lift, 0.0) * 0.035 + escape_load
			# Keep enough reel response to recover slack even with the strongest rod.
			var change := delta * (rate * 0.12 + load / sqrt(durability) - (0.065 if running else 0.075))
			if is_predator() and running and rate<=.1:
				change=delta*(.62-tension)*.6
			if predator_opening_time>0.0:
				# A brief reaction window softens the shock but never resets an overloaded line.
				if rate<=.1: change=delta*(.62-tension)*.9
				elif predator_notice_time>0.0: change=delta*.10/durability
				else: change=delta*(.15+rate*.85)/sqrt(durability)
			if submerge_active():
				# A deep pull loads a wound reel; a fish rushing toward us creates slack.
				# Both remain recoverable with the requested reel response on every rod.
				if submerge==Submerge.PULL:
					change=delta*((.45-tension)*.4 if rate<=.1 else .18+rate*.18/sqrt(durability))
				else:
					change=delta*(rate*.22-.30)
			if recovery_time>0.0 and rate<=.1 and not fly_reel_penalty:
				# A deliberate release unloads the line smoothly during the warning.
				change=minf(change,-delta*.14)
			# Bound the load buildup so warning haptics give time to ease off.
			var limit := MAX_SUBMERGE_CHANGE if submerge_active() else MAX_TENSION_RISE
			if predator_opening_time>0.0: limit=1.5
			tension += clampf(change, -delta * (MAX_SUBMERGE_CHANGE if submerge_active() else .18), delta * limit)
			if running:
				distance += delta * (1.0 if is_predator() else float(FightProfiles.profile(fish_index).speed)) * stamina * power
				if is_predator():distance=minf(distance,cast_distance+18.0)
			elif submerge_active() and submerge == Submerge.SLACK:
				# The fish closes distance even when the angler fails to take up slack.
				distance -= delta * (1.4 + stamina * .6)
			elif tension > 0.12:
				distance -= delta * rate * (1.05 + (1.0 - stamina) * 0.9) / power
			stamina = maxf(0.0, stamina - delta * rate * 0.8 * float(tackle.rod().fatigue) / float(SPECIES[fish_index].endurance))
			tension = clampf(tension, 0.0, 1.0)
			if _check_line_failure(delta):return
			if not is_predator() and submerge==Submerge.NONE: next_cue -= delta
			if not is_predator() and submerge==Submerge.NONE and cue < 0 and next_cue <= 0.0:
				var directions: Array=FightProfiles.profile(fish_index).directions
				cue = directions[fight_step%directions.size()]
				if mirror_fight and cue<2: cue=1-cue
				if at_ground_boundary: cue=2
				fight_step+=1
				cue_time = COUNTER_WINDOW
				resistance = 1.0
			if cue >= 0:
				cue_time -= delta
				if cue_time <= 0.0:
					failed_counters += 1
					if failed_counters >= MAX_FAILED_COUNTERS:
						lose("The fish broke free after three missed counters.")
						return
					recover_strength(.18)
					cue = -1
					next_cue = 3.0
					message = "Missed counter (%d/%d). Keep control of the fish." % [failed_counters, MAX_FAILED_COUNTERS]
			_try_predator(delta,rate,previous_distance)
			if predator_notice_time>0.0:return
			if distance <= landing_distance and stamina <= (.15 if is_predator() else .35) and rate>.03 and cue<0:
				state = State.LANDED
				_reset_submerge()
				catches += 1
				population.caught(location_id, fish_index)
				var fish: Dictionary = SPECIES[fish_index].duplicate()
				var size_factor := rng.randf_range(0.85, 1.15)
				fish["length"] *= size_factor
				fish["weight"] *= pow(size_factor, 3.0)
				if rebaited_from>=0:fish["bait_fish_latin"]=SPECIES[rebaited_from].latin
				fish["location_id"] = location_id
				fish["location_name"] = location_name
				last_reward = Tackle.reward(SPECIES[fish_index], float(fish.length))
				fish["shekels"] = last_reward
				tackle.shekels += last_reward
				journal.append(fish)
				message = "%s · %.0f cm · %.2f kg\n%s · +%d shekels" % [fish.name, fish.length, fish.weight, fish.latin, last_reward]
			else:
				distance = maxf(distance, landing_distance)

func lose(reason: String) -> void:
	_reset_submerge()
	state = State.LOST
	timer = 1.2
	cue = -1
	counter_direction = -1
	counter_active = false
	message = reason

func _retrieve_empty_line(delta:float,rate:float) -> bool:
	if rate<=.03:return false
	var at:Vector3=fly.start+fly.offset if is_fly_fishing() else cast_position
	var next:=at.move_toward(retrieve_origin,clampf(rate,0,2)*delta*2.2)
	distance=retrieve_origin.distance_to(next)
	if distance<=landing_distance:
		reset();message="Line retrieved · bait ready for the next cast."
		return true
	if is_fly_fishing():fly.offset=next-fly.start
	else:cast_position=next
	return false

func _check_line_failure(delta: float) -> bool:
	var unsafe_side := 1 if tension >= STRAIN_LIMIT else -1 if tension <= SLACK_LIMIT else 0
	if unsafe_side != danger_side: danger_time = 0.0
	danger_side = unsafe_side
	if unsafe_side != 0:
		if unsafe_side==1 and recovery_time>0.0 and not fly_reel_penalty and predator_opening_time<=0.0:
			# Briefly pause new strain; never reset it. Only easing off relieves it.
			if reel_rate<=.1:danger_time=maxf(0.0,danger_time-delta*.8)
		else:danger_time += delta
	else: danger_time = 0.0
	var strain_grace := .45 if predator_opening_time>0.0 else STRAIN_GRACE
	if danger_time > (strain_grace * sqrt(float(tackle.rod().durability)) if tension > .5 else 1.8):
		lose("Line snapped. Ease off the reel." if tension > .5 else "The hook slipped. Keep some tension.")
		return true
	return false

func reset() -> void:
	fly_reel_penalty=false
	feeder.reset()
	lure.reset()
	fly.reset()
	_reset_submerge()
	state = State.READY
	predator_checked=false;retrieval_time=0.0;retrieved_metres=0.0;rebaited_from=-1;predator_step=0
	failed_counters = 0
	danger_time = 0.0
	danger_side = 0
	cue = -1
	counter_direction=-1;counter_active=false;resistance=1.0
	tension = 0.35
	message = "Choose your bait, then cast into open water."
