extends SceneTree
## Run with --path pointing at the patched Fishing integration checkout.
var failures:=0
var checks:=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,message:String)->void:
 checks+=1
 if ok:print("PASS ",message)
 else:failures+=1;push_error(message)
func run()->void:
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 await process_frame
 g.set_process(false);g.motor.set_physics_process(false)
 var a=g.golf_activity
 var location:String=g.current_location
 var network_id:int=g.network.get_instance_id();var radio_id:int=g.shoulder_radio.get_instance_id();var avatar_id:int=g.avatar.get_instance_id()
 check(g.avatar_menu.pages.has("golf") and g.avatar_menu.pages.has("bbq"),"Golf and BBQ use existing fishing menu navigation")
 check(g.network.host(28974,"127.0.0.1")==OK,"Ad-hoc Fishing host starts shared course service")
 a.join_course("spyglass");g.motor.set_physics_process(false)
 await process_frame
 check(a.active and g.current_location=="golf_spyglass_00","Golf uses distinct shared-world location")
 check(a.notice.remaining>0 and a.notice.sound.stream.data.size()>0,"Turn produces visible notification and an audible cue")
 check(not g.rod.visible and a.golf.club.visible,"Joining swaps rod for club")
 check(network_id==g.network.get_instance_id() and radio_id==g.shoulder_radio.get_instance_id() and avatar_id==g.avatar.get_instance_id(),"Network radio and VRM retain original identities")
 var state:Dictionary=load("res://scripts/network/state.gd").capture(g,1)
 check(load("res://scripts/network/state.gd").valid(state),"Golf pose accepted by shared network schema")
 a.golf.toggle_menu(true)
 check(g.menu_open and a.settings_open and g.avatar_menu.active_page=="golf","Golf menu opens within fishing shell")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("user://host-golf-menu.png")
 g.avatar_menu.show_page("leaderboard")
 check("Golf leaderboard" in g.avatar_menu.pages.leaderboard.page.summary.text,"Existing leaderboard button shows separate golf results")
 a.close_settings()
 var golf=a.golf
 golf.strike(golf.aim_direction()*15,golf.aim_direction())
 check(golf.ball.moving and g.network.golf.view.flight and g.network.golf.view.strokes==1,"Integrated shot waits for authority and counts once")
 golf.toggle_menu(true);var before:Vector3=golf.ball.position;golf._physics_process(.02)
 check(golf.ball.position!=before,"Opening shared menu does not freeze the current player's ball")
 a.close_settings()
 golf.ball.moving=false;golf.was_moving=false;golf._complete_shot()
 await process_frame
 a.visit_bbq()
 await create_timer(.6).timeout
 a.update_player(.016)
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("user://host-golf-bbq.png")
 check(g.bbq.visiting and g.current_location=="golf_spyglass_clubhouse" and g.network.bbq.model.stations.has(g.current_location),"Shared BBQ is at the clubhouse, separate from the active hole")
 check(a.golf.equipment.stowed and g.rod_holster.stowed,"BBQ reserves hands and stashes club")
 check(not g.network.golf.view.present and g.network.golf.view.remaining>0,"BBQ visit preserves enrollment and starts return grace")
 g.bbq.return_to_water()
 await create_timer(.6).timeout
 a.update_player(.016)
 check(not g.bbq.visiting and not a.golf.equipment.stowed,"Returning from BBQ restores club")
 var site:Transform3D=load("res://scripts/bbq/sites.gd").pose("golf_spyglass_clubhouse")
 var pavilion:Node3D=a.golf.world.get_node("Clubhouse")
 var deck_point:Vector3=pavilion.to_local(site.origin)
 check(absf(deck_point.x)<6 and absf(deck_point.z)<3.5 and absf(deck_point.y-.4)<.025,"BBQ anchor is on the existing clubhouse deck")
 for i in 5:
  var epoch:int=g.network.golf.view.epoch
  g.network.golf.request("shot",{"epoch":epoch})
  g.network.golf.request("settled",{"epoch":epoch,"holed":true})
  await create_timer(.3).timeout
 await process_frame
 var playing_hole:int=a.golf.round_state.hole
 check(playing_hole>0,"Shared course advances independently of clubhouse")
 a.visit_bbq();await create_timer(.6).timeout
 check(a.clubhouse_round!=null and a.golf.model.index==0 and g.current_location=="golf_spyglass_clubhouse","Later holes return to the same clubhouse and shared BBQ")
 var current:Dictionary=g.network.golf.rules.games.spyglass
 # Fast-forward the server's test card to exercise an absent final-hole finish.
 current.hole=17
 var participant:Dictionary=current.members[current.turn]
 participant.scores.resize(17);participant.scores.fill(1)
 g.network.golf.rules.tick(current.deadline);g.network.golf.publish();await process_frame
 check(a.clubhouse_round!=null and a.golf.model.index==0,"Forfeit does not teleport a player away from BBQ")
 a.return_from_clubhouse();await process_frame
 check(a.golf.round_state.hole>playing_hole and a.golf.round_state.scores.has(-1),"Returning from clubhouse restores authoritative hole after timeout")
 check(a.golf.round_state.finished and a.golf.round_state.scores.size()==18,"Last-hole absence restores a complete forfeited card")
 var old_id:String=g.network.golf.view.id
 a.join_course("spyglass");await process_frame
 check(g.network.golf.view.id!=old_id and not a.golf.round_state.finished and a.golf.round_state.hole==0,"Course button starts a fresh server round after completion")
 a.golf.strike(a.golf.aim_direction()*15,a.golf.aim_direction())
 a.retire()
 check(not a.active and g.network.golf.view.retired,"Retirement remains available during a shot")
 a.leave()
 check(not a.active and g.current_location==location,"Return to fishing restores original location")
 g.avatar_menu.show_page("leaderboard")
 check(not "Golf leaderboard" in g.avatar_menu.pages.leaderboard.page.summary.text,"Leaderboard button returns to fishing rankings")
 for node in g.find_children("*","AudioStreamPlayer",true,false):node.stop()
 for node in g.find_children("*","AudioStreamPlayer3D",true,false):node.stop()
 g.network.leave();g.queue_free();await process_frame
 await create_timer(.15).timeout
 print("HOST SOCIAL %d/%d passed"%[checks-failures,checks]);quit(1 if failures else 0)
