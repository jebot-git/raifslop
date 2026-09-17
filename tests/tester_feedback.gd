extends SceneTree
const S=preload("res://scripts/fishing_session.gd")
var failures:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func fight():
	var s=S.new();s.state=S.State.BITE;s.strike();s.distance=100;s.cue=0;s.cue_time=S.COUNTER_WINDOW;return s
func run():
	var s=fight();s.gesture(0);s.tick(.01,.65,0)
	check(s.cue==0 and s.resistance>.99,"A microinput cannot clear resistance")
	var left:float=s.resistance
	for i in 20:s.tick(.01,.65,0)
	check(is_equal_approx(left,s.resistance),"Progress stops when correct input stops")
	for i in 20:s.gesture(1);s.tick(.01,.65,0)
	check(is_equal_approx(left,s.resistance),"Wrong direction cannot drain resistance")
	for fps in [30,72,90]:
		s=fight();var elapsed:=0.0
		while s.cue>=0 and elapsed<5:
			s.gesture(0);s.tick(1.0/fps,.5,0);elapsed+=1.0/fps
		check(absf(elapsed-s.counter_seconds())<.04,"Counter duration independent of frame rate: "+str(fps))
	var input=preload("res://scripts/fight_input.gd").new()
	check(input.sample(0,Vector3.ZERO)==-1 and input.sample(0,Vector3(-.02,0,0))==-1,"Small physical movements do not engage hold")
	check(input.sample(0,Vector3(-.3,0,0))==0 and input.sample(0,Vector3(-.3,0,0))==0,"Deliberate pull remains active while held")
	check(input.sample(0,Vector3.ZERO)==-1,"Returning rod stops hold")
	input.reset();input.sample(0,Vector3(0,0,-1))
	check(input.sample(0,Vector3(0,0,-1),Basis(Vector3.UP,PI/2))==-1,"Turning head alone cannot engage a counter")
	var h=preload("res://scripts/line_haptics.gd").new();s=S.new();s.state=S.State.BITE
	check(h.sample(s,.02).get("kind")=="bite","Bite produces rumble event")
	s.strike();check(h.sample(s,.02).get("kind")=="hook","Hook set produces rumble event")
	s.cue=0;check(h.sample(s,.02).get("kind")=="fight","Fish directional fight produces rumble event")
	s.phase=6;check(h.sample(s,.02).get("kind")=="run","Fish run produces rumble event")
	s.tension=.75;check(h.sample(s,1.0).is_empty(),"Uncountered escape does not reward rising tension with rumble")
	check(h.sample(s,.01).is_empty(),"Steady tension does not spam haptics")
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await create_timer(.3).timeout
	game.set_process(false);game.motor.set_physics_process(false)
	for i in S.SPECIES.size():
		game.game.fish_index=i;game.game.journal=[{"length":S.SPECIES[i].length*1.13}];game._show_fish()
		check(absf(game.catch_bounds.size.x-S.SPECIES[i].length*.0113)<.0001 and game.catch_bounds.size.x>game.catch_bounds.size.y and game.catch_bounds.size.x>game.catch_bounds.size.z,"Visual catch length matches report: "+S.SPECIES[i].name)
	var guide=game.fish_guide
	check(guide.selected==-1,"Guide opens on session status")
	game.game.tackle.shekels=123;game.game.bait=2;game.game.last_reward=17
	var rows:Array=guide.screen.status_rows()
	check(rows[0][1]==game.game.location_name and rows[1][1]=="123" and rows[2][1]=="+17 shekels" and rows[3][1]==game.game.BAITS[2],"Guide reads current location, balance, earnings and bait")
	game.game.bait=3
	check(guide.screen.status_rows()[3][1]==game.game.BAITS[3],"Guide status follows bait changes")
	var menu=game.avatar_menu;menu.show();game._layout_avatar_menu();await process_frame
	check(menu.quit_button.is_visible_in_tree() and menu.get_global_rect().encloses(menu.quit_button.get_global_rect()),"Quit button visible inside fixed menu footer")
	menu.leaderboard_button.pressed.emit();await process_frame
	check(menu.active_page=="leaderboard" and menu.pages.leaderboard.view.visible,"Leaderboard button opens server accomplishments")
	check(menu.get_global_rect().encloses(menu.leaderboard_button.get_global_rect()),"Leaderboard button stays inside the fixed header")
	game.queue_free();await process_frame;await create_timer(.3).timeout
	print("TESTER_FEEDBACK_RESULT ",failures);quit(0 if failures.is_empty() else 1)
