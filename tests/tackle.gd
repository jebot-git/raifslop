extends SceneTree
const S = preload("res://scripts/fishing_session.gd")
const T = preload("res://scripts/tackle.gd")
var failures: Array = []
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("PASS " if ok else "FAIL ", label)
func _initialize() -> void: run.call_deferred()
func fight(index := 0, rod := 0):
	var sim = S.new()
	sim.fish_index = index
	sim.tackle.equipped = rod
	sim.state = S.State.BITE
	sim.distance = 24
	sim.strike()
	return sim
func run() -> void:
	var p = T.new()
	if FileAccess.file_exists(T.PATH): DirAccess.remove_absolute(T.PATH)
	check(p.shekels == 0 and p.equipped == 0, "New angler starts with free Willow rod")
	check(not p.purchase_or_equip(1, true), "Cannot purchase without funds")
	p.shekels = 600
	check(not p.purchase_or_equip(1, false) and p.shekels == 600, "Purchases blocked during cast")
	check(p.purchase_or_equip(1, true) and p.shekels == 450 and p.equipped == 1, "Purchase deducts exact price and equips")
	check(p.purchase_or_equip(0, true) and p.purchase_or_equip(1, true) and p.shekels == 450, "Owned rods can be re-equipped without paying again")
	var restored = T.new(); restored.load_profile()
	check(restored.shekels == 450 and restored.equipped == 1 and 1 in restored.owned, "Balance and tackle survive reload")
	check(not p.purchase_or_equip(2, true, "user://missing/tackle.json") and p.shekels == 450 and not 2 in p.owned and p.equipped == 1, "Save failure rolls back purchase and equipment")
	check(not p.purchase_or_equip(-1, true) and not p.purchase_or_equip(99, true), "Invalid rod indices are rejected")
	var bad := FileAccess.open("user://bad_tackle.json", FileAccess.WRITE)
	bad.store_string('{"shekels":-10,"owned":[-1,99,1.5,"2"],"equipped":99}'); bad.close()
	var sanitized = T.new(); sanitized.load_profile("user://bad_tackle.json")
	check(sanitized.shekels == 0 and sanitized.owned.size() == 1 and sanitized.equipped == 0, "Malformed profile cannot grant invalid rods or negative balance")
	var lost = fight(); lost.lose("Missed")
	check(lost.tackle.shekels == 0, "Lost fish never earn shekels")
	var perch: Dictionary = S.SPECIES[0]
	check(T.reward(perch, 36) > T.reward(perch, 28), "Larger specimens earn more")
	check(T.reward(S.SPECIES[2], S.SPECIES[2].length) > T.reward(perch, perch.length), "Rarer species earn more at typical size")
	var fresh = fight(); fresh.phase = 6
	var tired = fight(); tired.phase = 6; tired.stamina = .1
	fresh.tick(.2, 0, 0); tired.tick(.2, 0, 0)
	check(fresh.tension > tired.tension, "Fresh escape attempts exert more line tension")
	var weak = fight(3); var strong = fight(2)
	weak.cue = 0; strong.cue = 0; weak.gesture(0); strong.gesture(0); weak.tick(.05,0,0); strong.tick(.05,0,0)
	check(strong.stamina > weak.stamina, "Species endurance controls fatigue per counter")
	var base = fight(); var upgraded = fight(0, 3)
	base.cue = 0; upgraded.cue = 0; base.gesture(0); upgraded.gesture(0); base.tick(.05,0,0); upgraded.tick(.05,0,0)
	check(upgraded.stamina < base.stamina, "Better rod drains more stamina on counter")
	base = fight(); upgraded = fight(0, 3)
	base.tick(.5, 1, 0); upgraded.tick(.5, 1, 0)
	check(upgraded.stamina < base.stamina, "Better rod tires fish faster while reeling")
	base = fight(); upgraded = fight(0, 3)
	base.tension = 1; upgraded.tension = 1
	for i in range(80): base.tick(.02, 2, 1); upgraded.tick(.02, 2, 1)
	check(base.state == S.State.LOST and upgraded.state == S.State.FIGHT, "Upgraded line survives longer under overload")
	var counter = fight(); counter.phase = 6; counter.cue = 1
	check(not counter.gesture(0) and counter.is_running(), "Wrong counter does not stop escape")
	counter.cue_time=S.COUNTER_WINDOW
	for step in range(260):
		if counter.cue<0:break
		counter.gesture(1);counter.tick(.02,.7 if counter.tension<.25 else 0,0)
	check(not counter.is_running() and counter.cue<0 and counter.next_cue >= 3.5, "Sustained counter stops run and postpones escape cue")
	for i in range(60): counter.tick(.05, .7, 0)
	check(not counter.is_running() and counter.cue == -1, "Counter provides a sustained recovery window")
	for i in range(180): counter.tick(.05, .7 if counter.tension < .5 else 0, 0)
	check(counter.cue >= 0 or counter.next_cue < 3.0, "Escape attempts resume after recovery")
	var reward_sim = fight(); reward_sim.distance = 1; reward_sim.stamina = 0
	reward_sim.tick(.01, 0, 0)
	var earned: int = reward_sim.tackle.shekels
	reward_sim.tick(10, 1, 0); reward_sim.reset()
	check(earned > 0 and reward_sim.tackle.shekels == earned and reward_sim.journal.size() == 1, "Landing pays once; holding and releasing never repeat reward")
	check(reward_sim.journal[0].shekels == earned, "Catch journal records exact payout")
	for index in range(S.SPECIES.size()):
		var times := []
		for rod in [0, 3]:
			var sim = fight(index, rod); var elapsed := 0.0
			for frame in range(18000):
				if sim.state != S.State.FIGHT: break
				if sim.cue >= 0: sim.gesture(sim.cue)
				var rate := 0.0 if sim.is_running() or sim.tension > .7 else 1.0
				if sim.tension < .18: rate = .8
				sim.tick(1.0 / 90, rate, .2); elapsed += 1.0 / 90
			check(sim.state == S.State.LANDED, "Land %s with rod %d" % [S.SPECIES[index].name, rod])
			times.append(elapsed)
		check(times[1] < times[0], "Upgrade shortens full fight: " + S.SPECIES[index].name)
	var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await create_timer(.3).timeout
	game.set_process(false); game.motor.set_physics_process(false)
	var menu = game.avatar_menu
	menu.show(); menu.show_page("tackle")
	await process_frame; await process_frame
	check(menu.size.x <= 900 and menu.tabs.size.x <= 864, "Six tabs fit the desktop and VR panel width")
	check(menu.pages.tackle.view.visible and menu.tackle_buttons.size() == 4, "Tackle shop integrated into shared desktop/VR menu")
	game.game.tackle.shekels = 600; game.game.tackle.owned.assign([0]); game.game.tackle.equipped = 0
	menu.refresh_tackle(); menu.tackle_buttons[1].pressed.emit()
	check(game.game.tackle.equipped == 1 and game.game.tackle.shekels == 450 and menu.tackle_buttons[1].text == "Equipped", "Shop button buys, equips and refreshes displayed balance")
	game.game.state = S.State.FIGHT; menu.refresh_tackle()
	check(menu.tackle_buttons.all(func(b): return b.disabled), "Shop disables equipment changes during fights")
	game.queue_free(); await process_frame; await create_timer(.3).timeout
	print("TACKLE_RESULT %d checks: %s" % [checks, failures]); quit(0 if failures.is_empty() else 1)
