extends SceneTree
const Net=preload("res://scripts/network/session.gd")
const Fixture=preload("res://tests/eos_fixture.gd")
const Factory=preload("res://scripts/network/transport_factory.gd")
const Config=preload("res://scripts/network/eos/config.gd")
const LobbyMenu=preload("res://scripts/network/lobby_menu.gd")
var failures:Array=[]
func check(ok:bool,label:String)->void:
 if not ok:failures.append(label);push_error(label)
func until(test:Callable,seconds:=2.0)->bool:
 var end:=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<end:
  if test.call():return true
  await process_frame
 return false
func _initialize()->void:run.call_deferred()
func admission(secret:String,supplied:String,accepted:bool)->void:
 var host_root:=Node.new();host_root.name="Host";root.add_child(host_root)
 var client_root:=Node.new();client_root.name="Client";root.add_child(client_root)
 var host_api:=SceneMultiplayer.new();set_multiplayer(host_api,host_root.get_path())
 var client_api:=SceneMultiplayer.new();set_multiplayer(client_api,client_root.get_path())
 var host=Net.new();host_root.add_child(host);host.setup(host_root,true);host.voice_enabled=false
 var client=Net.new();client_root.add_child(client);client.setup(client_root,true);client.voice_enabled=false
 var a=Fixture.Native.new();var b=Fixture.Native.new();b.uid=2;b.ids=[1];a.remote=b;b.remote=a
 var ha=Factory.eos(a,Fixture.SDK.new(),func(id):return str(id).sha256_text())
 var ca=Factory.eos(b,Fixture.SDK.new(),func(id):return str(id).sha256_text())
 host.online.auth.install(host_api,true,secret);client.online.auth.install(client_api,false,supplied)
 client_api.auth_timeout=.2
 host.attach_transport(ha.peer,true,"EOS fixture");client.attach_transport(ca.peer,false,"EOS fixture")
 var rejected:Array=[];host.online.auth.rejected.connect(func(id:int):rejected.append(id))
 if accepted:
  check(await until(func():return client.active and host.players.has(2)),"Open/correct password admits gameplay")
 else:
  check(await until(func():return not rejected.is_empty()),"Wrong password rejected by host")
  check(not client.active and host.players.is_empty() and host.waiting.is_empty() and host.leaderboard.peers.is_empty(),"No gameplay or record before password admission")
  check(await until(func():return "admission failed" in client.status),"Rejected client gets retry message")
 client.leave();host.leave()
 check(not host_api.auth_callback.is_valid() and not client_api.auth_callback.is_valid(),"Leave clears admission callbacks")
 host_root.queue_free();client_root.queue_free();await process_frame
func run()->void:
 await admission("","",true)
 await admission("secret","secret",true)
 await admission("secret","wrong",false)
 var game:=Node.new();root.add_child(game)
 var net=Net.new();game.add_child(net);net.setup(game,true)
 var menu=LobbyMenu.new();game.add_child(menu);menu.setup(net)
 menu.page(menu.hosting);menu.title_input.text="";menu.refresh()
 check(menu.create_button.disabled,"Host requires a name")
 menu.title_input.text="Weekend fishing";menu.protect.button_pressed=true;menu.refresh()
 check(menu.create_button.disabled and menu.host_password.secret,"Protected lobby needs a masked password")
 menu.host_password.text="secret";menu.refresh();check(not menu.create_button.disabled,"Host form complete")
 net.online.lobbies=[{"id":"full","title":"Full room","members":8,"capacity":8,"locked":false},{"id":"open","title":"Open room","members":1,"capacity":8,"locked":true}]
 var keyboard=preload("res://scripts/ui/keyboard.gd").new();game.add_child(keyboard)
 keyboard.open_for(menu.host_password);keyboard._process(0)
 check(not keyboard.preview.text.contains("secret") and keyboard.preview.text.contains(menu.host_password.secret_character.repeat(6)),"VR keyboard masks password preview")
 keyboard.hide();keyboard._process(0);check(keyboard.preview.text.is_empty(),"Closed keyboard clears preview")
 menu.selected="full";menu.refresh();check(menu.join_button.disabled,"Full lobby cannot be joined")
 menu.selected="open";menu.refresh();check(not menu.join_button.disabled,"Available locked lobby can be selected")
 net.online.config={"app_id":"3428825797290213","deployment_id":"test","destination":"eos_game"}
 net.online.lobby="fixture-lobby";net.online.title="Weekend fishing";net.online.locked=true
 var invite:String=net.online.share_invitation()
 check(invite.contains("https://oculus.com/vr/3428825797290213/eos_game") and invite.contains("fixture-lobby") and not invite.contains("secret"),"Meta share text contains destination and lobby reference without password")
 check(Config.clean_title(" \nA\tB ")=="AB","Lobby title sanitation")
 net.leave();game.queue_free();await process_frame
 print("EOS_LOBBIES_RESULT ",failures);quit(0 if failures.is_empty() else 1)
