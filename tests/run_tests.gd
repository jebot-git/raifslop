extends SceneTree
const Session = preload("res://scripts/fishing_session.gd")
const Reel = preload("res://scripts/reel_tracker.gd")
var failures := 0
var checks := 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var s = Session.new()
	s.rng.seed = 42
	s.select_bait(2)
	s.cast(100)
	check(s.cast_distance == 24, "Cast distance must be clamped")
	s.select_bait(0)
	check(s.bait == 2, "Bait cannot change after cast")
	s.tick(1, 0, 0)
	check(s.state == Session.State.WAITING and Session.SPECIES[s.fish_index].bait == 2, "Spinner must attract a compatible predator")
	s.tick(10, 0, 0)
	check(s.state == Session.State.BITE, "Waiting must produce bite")
	s.tick(2, 0, 0)
	check(s.state == Session.State.LOST, "Missed bite must escape")
	s.reset()
	s.cast(12)
	s.tick(1, 0, 0)
	s.strike()
	check(s.state == Session.State.LOST, "Early strikes must fail")
	s.reset()
	s.cast(12)
	s.tick(1, 0, 0)
	s.tick(10, 0, 0)
	s.strike()
	check(s.state == Session.State.FIGHT, "Timed strike must hook fish")
	s.cue = 0
	check(not s.gesture(1), "Wrong directional gesture must not succeed")
	check(s.gesture(0), "Matching gesture must succeed")
	check(s.cue==0 and is_equal_approx(s.resistance,1.0), "An input event alone cannot clear a counter")
	for i in range(12000):
		if s.state != Session.State.FIGHT: break
		if s.cue >= 0: s.gesture(s.cue)
		var rate := 0.0 if s.is_running() else 1.0
		if s.tension < 0.18: rate = 0.8
		if s.tension > 0.7: rate = 0.0
		s.tick(1.0 / 90.0, rate, 0.2)
	check(s.state == Session.State.LANDED, "Competent play must land a fish")
	check(s.journal.size() == 1 and s.catches == 1, "Catch must be recorded once")
	s.state = Session.State.FIGHT
	s.tension = 1.0
	s.distance = 20
	for i in range(200): s.tick(0.02, 2, 1)
	check(s.state == Session.State.LOST, "Over-reeling must snap line")
	s.state = Session.State.FIGHT
	s.tension = 0
	s.danger_time = 0
	s.cue = -1
	s.next_cue = 100
	for i in range(200): s.tick(0.02, 0, 0)
	check(s.state == Session.State.LOST, "Sustained slack must lose fish")
	var r = Reel.new()
	check(r.sample(Vector3(0, 0.08, 0), true, 0.01) == 0, "First grab must not reel")
	var turns := 0.0
	for i in range(1, 101):
		var a := i * TAU / 100
		turns += r.sample(Vector3(0, cos(a) * 0.08, sin(a) * 0.08), true, 0.01) * 0.01
	check(absf(turns - 1.0) < 0.01, "One circular hand rotation must produce one turn, including wrap")
	check(r.sample(Vector3(1, 0.08, 0), true, 0.01) == 0, "Distant hand must not reel")
	check(r.sample(Vector3(0, 0.08, 0), true, 0.01) == 0, "Regrab must reset baseline")
	check(r.sample(Vector3(0, -0.08, 0), true, 0.01) == 0, "Tracking jump must not reel")
	check(r.sample(Vector3(0, 0.08, 0), false, 0.01) == 0, "Released grip must not reel")
	# Sample real cast transitions: every species is reachable and bait stays valid.
	var seen := {}
	var pools_valid := true
	for bait_index in range(Session.BAITS.size()):
		for attempt in range(128):
			s.reset()
			s.select_bait(bait_index)
			s.cast(12)
			s.tick(1, 0, 0)
			seen[s.fish_index] = true
			pools_valid = pools_valid and s.fish_index in Session.species_for_bait(bait_index, s.location_id)
	check(pools_valid, "Every cast must choose a species compatible with its bait")
	check(seen.size() == Session.species_for_location(s.location_id).size(), "All local species must be reachable through normal casting")
	# Full fights verify that every power profile can be landed at maximum cast range.
	for index in range(Session.SPECIES.size()):
		var species: Dictionary = Session.SPECIES[index]
		var fight = Session.new()
		fight.rng.seed = 1234 + index
		fight.fish_index = index
		fight.state = Session.State.BITE
		fight.distance = 24.0
		fight.strike()
		for frame in range(18000):
			if fight.state != Session.State.FIGHT: break
			if fight.cue >= 0: fight.gesture(fight.cue)
			var rate := 0.0 if fight.is_running() else 1.0
			if fight.tension < 0.18: rate = 0.8
			if fight.tension > 0.7: rate = 0.0
			fight.tick(1.0 / 90.0, rate, 0.2)
		check(fight.state == Session.State.LANDED, "Full fight must land " + species.name)
		if fight.journal.is_empty(): continue
		var record: Dictionary = fight.journal.back()
		check(record.name == species.name and record.latin == species.latin, "Journal must preserve species identity")
		check(record.length >= species.length * 0.85 and record.length <= species.length * 1.15, "Catch length is bounded")
		check(absf(record.weight / species.weight - pow(record.length / species.length, 3)) < 0.0001, "Weight must scale with catch length")
		check(fight.message.contains(species.latin) and fight.message.contains("kg"), "Catch display identifies species and weight")
		fight.tick(1, 1, 1)
		check(fight.journal.size() == 1, "Landed catch cannot be recorded twice")
		var restored = JSON.parse_string(JSON.stringify(fight.journal))
		check(restored[0].latin == species.latin and is_equal_approx(restored[0].weight, record.weight), "New catch survives journal JSON round trip")
		fight.reset()
		check(fight.state == Session.State.READY and fight.journal.size() == 1, "Release returns to ready and preserves catch")
	print("Fishing tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
