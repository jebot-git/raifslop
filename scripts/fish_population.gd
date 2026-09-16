extends RefCounted
## A 3×3 world-space grid. Populations survive recasts and travel.
const GRID_SIZE := 3
const SECTOR_COUNT := GRID_SIZE * GRID_SIZE
const RECOVERY_SECONDS := 240.0
const CATCH_REMAINING := .35
const OFF_BAIT_CHANCE := .15
var waters: Dictionary = {}
var layouts: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func ensure_location(id: String, roster: Array) -> void:
	if waters.has(id): return
	var stocks: Dictionary = {}
	# Start the first species in separate quadrants, including small river
	# rosters. Fill the remaining cells before any species share a sector.
	var sectors: Array[int] = [0, 2, 6, 8]
	_shuffle(sectors)
	var remaining: Array[int] = [1, 3, 4, 5, 7]
	_shuffle(remaining)
	sectors.append_array(remaining)
	for n in roster.size():
		stocks[roster[n]] = {"sector": sectors[n % SECTOR_COUNT], "abundance": 1.0, "migration": rng.randf_range(25.0, 55.0)}
	waters[id] = stocks

func _shuffle(values: Array[int]) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var value := values[i]; values[i] = values[j]; values[j] = value

static func sector_at(at: Vector3) -> int:
	var column := 0 if at.x < -5.0 else 2 if at.x > 5.0 else 1
	var row := 0 if at.z >= -10.5 else 1 if at.z >= -15.5 else 2
	return column + row * GRID_SIZE

static func sector_center(sector: int, water_y: float) -> Vector3:
	return Vector3((sector % GRID_SIZE - 1) * 10.0, water_y, -8.0 - floori(float(sector) / GRID_SIZE) * 5.0)

func set_layout(id: String, centres: Array[Vector3]) -> void:
	assert(centres.size()==SECTOR_COUNT)
	layouts[id]=centres.duplicate()

func center_for(id: String, sector: int, water_y: float) -> Vector3:
	var at: Vector3 = layouts[id][sector] if layouts.has(id) else sector_center(sector,water_y)
	at.y=water_y
	return at

func sector_for(id: String, at: Vector3) -> int:
	if not layouts.has(id): return sector_at(at)
	var closest := 0
	var distance := INF
	for sector in SECTOR_COUNT:
		var centre := center_for(id,sector,at.y)
		var candidate := at.distance_squared_to(centre)
		if candidate < distance: distance=candidate;closest=sector
	return closest

static func neighbors_of(sector: int) -> Array[int]:
	var neighbors: Array[int] = []
	if sector >= GRID_SIZE: neighbors.append(sector - GRID_SIZE)
	if sector < SECTOR_COUNT - GRID_SIZE: neighbors.append(sector + GRID_SIZE)
	if sector % GRID_SIZE > 0: neighbors.append(sector - 1)
	if sector % GRID_SIZE < GRID_SIZE - 1: neighbors.append(sector + 1)
	return neighbors

func tick(delta: float) -> void:
	for stocks in waters.values():
		for stock in stocks.values():
			stock.abundance = minf(1.0, stock.abundance + delta / RECOVERY_SECONDS)
			stock.migration -= delta
			while stock.migration <= 0.0:
				var sector: int = stock.sector
				var neighbors := neighbors_of(sector)
				stock.sector = neighbors[rng.randi_range(0, neighbors.size() - 1)]
				stock.migration += rng.randf_range(25.0, 55.0)

func caught(id: String, species: int) -> void:
	if waters.has(id) and waters[id].has(species):
		waters[id][species].abundance *= CATCH_REMAINING

func weight(id: String, species: int, sector: int, rarity: float) -> float:
	var stock: Dictionary = waters[id][species]
	# A small roaming population keeps every local species reachable.
	var presence := 1.0 if stock.sector == sector else .08
	return presence * pow(stock.abundance, 2.0) / rarity

func choose(id: String, preferred: Array, sector: int, species: Array, roll_rng: RandomNumberGenerator) -> int:
	var off_bait: Array = []
	for index in waters[id]:
		if index not in preferred: off_bait.append(index)
	var pool: Array = off_bait if not off_bait.is_empty() and roll_rng.randf() < OFF_BAIT_CHANCE else preferred
	if pool.is_empty(): pool = waters[id].keys()
	var total := 0.0
	for index in pool: total += weight(id, index, sector, species[index].rarity)
	var roll := roll_rng.randf() * total
	for index in pool:
		roll -= weight(id, index, sector, species[index].rarity)
		if roll <= 0.0: return index
	return pool.back()

func activity(id: String, preferred: Array, sector: int) -> float:
	var amount := 0.0
	for index in preferred:
		var stock: Dictionary = waters[id][index]
		if stock.sector == sector: amount += pow(stock.abundance, 2.0)
	return clampf(amount, 0.0, 1.0)

func bite_delay(id: String, preferred: Array, sector: int, roll_rng: RandomNumberGenerator, river: bool) -> float:
	# Four seconds remains the absolute minimum. Most casts take longer;
	# quiet/depleted sectors add waiting time. River drifts have a finite length.
	var variation := pow(roll_rng.randf(), 1.5) * (8.0 if river else 20.0)
	return 4.0 + variation + (1.0 - activity(id, preferred, sector)) * (2.0 if river else 8.0)
