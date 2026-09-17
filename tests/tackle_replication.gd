extends SceneTree
const State=preload("res://scripts/network/state.gd")
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(.2).timeout
	g.set_process(false)
	var peer=preload("res://scripts/network/remote_angler.gd").new()
	peer.session=g.network;root.add_child(peer);peer.set_process(false)
	for location in ["lake","fish_hoek_beach","meadow_bend"]:
		# Use the startup freshwater location rather than relying on an alias.
		if location!="lake":g._select_location(location,false)
		for bait in g.game.bait_count():
			g._select_bait(bait)
			for phase in [0,1,2,3,4,6]:
				g.game.state=phase;g._update_line()
				var data=State.capture(g,checks)
				check(State.valid(data),"Valid tackle snapshot")
				peer.receive_state(data);peer._process(1.0)
				check(peer.float_mesh.visible==data.bobber_visible,"Remote float visibility matches owner")
				check(peer.bait_visual.visible==data.bait_visible,"Remote bait visibility matches owner")
				check(peer.bait_visual.selected==bait,"Selected lure replicated")
				check(peer.bait_visual.marine==g.game.is_marine_location(g.current_location),"Marine tackle replicated")
				check(peer.bait_visual.fly_mode==g.game.is_fly_fishing(),"Fly tackle replicated")
				check(peer.bait_visual.global_position.distance_to(data.bait_position)<.001,"Lure position interpolates to owner")
			g.game.reset()
	g.game.state=5;g._show_fish();g._update_line()
	var landed=State.capture(g,checks)
	peer.receive_state(landed);peer._process(1)
	check(peer.caught.visible and not peer.float_mesh.visible and not peer.bait_visual.visible,"Landed fish hides tackle on peer")
	g._primary_action();g.rod_holster.set_stowed(true);g._update_line()
	var stowed=State.capture(g,checks)
	peer.receive_state(stowed);peer._process(1)
	check(not peer.float_mesh.visible and not peer.bait_visual.visible,"Stowing hides remote float and bait")
	check(peer.float_mesh.mesh==g.bobber.mesh,"Local and remote floats share detailed mesh")
	print("TACKLE_RESULT ",checks," checks, ",failures)
	peer.queue_free();g.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
