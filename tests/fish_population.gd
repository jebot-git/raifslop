extends SceneTree
const S = preload("res://scripts/fishing_session.gd")
const P = preload("res://scripts/fish_population.gd")
var failures: Array = []

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func _initialize() -> void:
	var s = S.new(); s.rng.seed = 481; s.population.rng.seed = 123
	s.prepare_population()
	var p = s.population
	var id: String = s.location_id
	var preferred := S.species_for_bait(0, id)
	check(P.SECTOR_COUNT >= 9, "Every water has at least nine grid sectors")
	for cell in P.SECTOR_COUNT:
		check(P.sector_at(P.sector_center(cell, -.35)) == cell, "Grid centre maps to its own sector " + str(cell))
		for neighbor in P.neighbors_of(cell):
			var a := Vector2i(cell % 3, cell / 3); var b := Vector2i(neighbor % 3, neighbor / 3)
			check(absi(a.x - b.x) + absi(a.y - b.y) == 1, "Migration crosses one adjoining grid edge without wrapping")
	for location in S.LOCATION_SPECIES:
		var distribution = P.new(); distribution.rng.seed = 123
		distribution.ensure_location(location, S.LOCATION_SPECIES[location])
		var starting: Array = []
		for species in S.LOCATION_SPECIES[location].slice(0, 4): starting.append(distribution.waters[location][species].sector)
		var distinct: Dictionary = {}
		for cell in starting: distinct[cell] = true
		check(distinct.size() == starting.size() and starting.all(func(cell): return cell in [0, 2, 6, 8]), "Species start in separate quadrants: " + location)
	var idle_sector: int = p.waters[id][1].sector
	var idle_timer: float = p.waters[id][1].migration
	p.waters[id][0].migration = .1
	var moving_sector: int = p.waters[id][0].sector
	p.tick(.2)
	check(p.waters[id][0].sector != moving_sector and p.waters[id][1].sector == idle_sector and is_equal_approx(p.waters[id][1].migration, idle_timer - .2), "Each species migrates on its own clock without moving other shoals")

	var wrong := 0
	var counts: Dictionary = {}
	for attempt in 12000:
		var caught: int = p.choose(id, preferred, attempt % P.SECTOR_COUNT, S.SPECIES, s.rng)
		if caught not in preferred: wrong += 1
		counts[caught] = counts.get(caught, 0) + 1
	check(wrong >= 1200 and wrong <= 2400, "Off-bait catches stay within 10–20% over 12,000 samples")
	check(counts.size() == S.LOCATION_SPECIES[id].size() and not counts.has(S.WELS), "Every local species reachable; predators remain takeover-only")
	var stock: Dictionary = p.waters[id][0]
	var sector: int = stock.sector
	check(p.weight(id, 0, sector, 1) > p.weight(id, 0, (sector + 1) % P.SECTOR_COUNT, 1) * 10, "Sector choice strongly changes species odds")
	check(p.activity(id, [0], sector) == 1 and p.activity(id, [0], (sector + 1) % P.SECTOR_COUNT) == 0, "Feeding signal identifies the matching shoal's sector")
	var initial: float = p.weight(id, 0, sector, 1)
	for i in 3: p.caught(id, 0)
	check(p.weight(id, 0, sector, 1) < initial * .002, "Three catches rapidly deplete species weight by over 99.8%")
	check(p.waters[id][1].abundance == 1, "Depletion affects only the caught species")
	var depleted: float = stock.abundance
	s.reset(); s.location_id = "lake_pier"; s.prepare_population(); s.location_id = id; s.prepare_population()
	check(stock.abundance == depleted, "Recasting and location travel do not reset depletion")
	stock.migration = 1.0; p.tick(1.1)
	check(stock.sector != sector and p.activity(id, [0], sector) == 0, "Migration moves the feeding signal to another sector")
	p.tick(30)
	check(stock.abundance < .2 and stock.abundance > depleted, "Thirty seconds only partially replenishes a depleted species")
	p.tick(P.RECOVERY_SECONDS)
	check(is_equal_approx(stock.abundance, 1), "Population replenishes over four minutes")
	var shortest := INF; var longest := 0.0
	for i in 1000:
		var wait: float = p.bite_delay(id, preferred, i % P.SECTOR_COUNT, s.rng, false)
		shortest = minf(shortest, wait); longest = maxf(longest, wait)
	check(shortest >= 4.0 and shortest < 5.0 and longest > 24.0 and longest <= 32.0, "Bites range from old four-second minimum to longer waits")
	s.cast(12, Vector3(-10, 0, -8)); s.tick(.9, 0, 0)
	check(s.cast_position == Vector3(-10, 0, -8) and s.state == S.State.WAITING, "Simulation uses the actual cast endpoint")
	s.tick(s.timer + .01, 0, 0)
	check(s.state == S.State.BITE and s.fish_index in S.LOCATION_SPECIES[id], "Longer wait still produces a local bite")
	s.strike(); s.stamina = .1; s.distance = s.landing_distance; s.next_submerge = 100; s.next_cue = 100; s.phase = 0; s.counter_rest = 2
	var fish: int = s.fish_index
	s.tick(.02, .6, 0)
	var remaining: float = p.waters[id][fish].abundance
	check(s.state == S.State.LANDED and remaining <= .351, "Landing applies population depletion")
	s.tick(.01, 0, 0)
	check(p.waters[id][fish].abundance >= remaining, "Landed state does not deplete repeatedly")
	print("FISH_POPULATION_RESULT ", failures)
	quit(0 if failures.is_empty() else 1)
