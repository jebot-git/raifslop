extends SceneTree
const Net=preload("res://scripts/network/session.gd")
const Fixture=preload("res://tests/eos_fixture.gd")
const Factory=preload("res://scripts/network/transport_factory.gd")
class Probe extends Node:
 var blocks:Array=[]
 var voices:=0
 @rpc("any_peer","call_remote","reliable",4)
 func bulk(bytes:PackedByteArray)->void:blocks.append(bytes)
 @rpc("any_peer","call_remote","unreliable",6)
 func voice(bytes:PackedByteArray)->void:
  if bytes.size()==400:voices+=1
var failures:Array=[]
func check(ok:bool,label:String)->void:
 if not ok:failures.append(label);push_error(label)
func until(test:Callable,seconds:=8.0)->bool:
 var end:=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<end:
  if test.call():return true
  await process_frame
 return false
func _initialize()->void:run.call_deferred()
func run()->void:
 var host_root:=Node.new();host_root.name="Host";root.add_child(host_root)
 var client_root:=Node.new();client_root.name="Client";root.add_child(client_root)
 var host_api:=SceneMultiplayer.new();set_multiplayer(host_api,host_root.get_path())
 var client_api:=SceneMultiplayer.new();set_multiplayer(client_api,client_root.get_path())
 var host=Net.new();host_root.add_child(host);host.setup(host_root,true);host.voice_enabled=false
 var client=Net.new();client_root.add_child(client);client.setup(client_root,true);client.voice_enabled=false
 client.player_token="f".repeat(64);client.display_name="EOS guest"
 var a=Fixture.Native.new();var b=Fixture.Native.new();b.uid=2;b.ids=[1];a.remote=b;b.remote=a
 var ha=Factory.eos(a,Fixture.SDK.new(),func(id):return str(id).sha256_text())
 var ca=Factory.eos(b,Fixture.SDK.new(),func(id):return str(id).sha256_text())
 var hp=Probe.new();hp.name="Probe";host_root.add_child(hp)
 var cp=Probe.new();cp.name="Probe";client_root.add_child(cp)
 host.attach_transport(ha.peer,true,"EOS fixture");client.attach_transport(ca.peer,false,"EOS fixture")
 check(await until(func():return client.active and host.players.has(2)),"Real gameplay hello/roster over EOS adapter")
 check(host.leaderboard.peers.get(2)==str(2).sha256_text().sha256_text(),"Host binds records to authenticated identity, ignoring supplied token")
 client.rankings.request("fishing","catches")
 check(await until(func():return not client.rankings.view.is_empty()),"Requested ranking RPC uses EOS adapter")
 var pose:Dictionary=preload("res://tests/network_fixture.gd").player(10,true);pose.serial=1
 client._submit_event.rpc_id(1,Net.PoseCodec.encode(pose))
 check(await until(func():return host.states.has(2)),"Compact reliable gameplay state reaches authority")
 var payload:=PackedByteArray();payload.resize(200000);payload.fill(53)
 hp.bulk.rpc_id(2,payload);cp.bulk.rpc_id(1,payload)
 for i in 25:
  pose.serial+=1;client._send_pose(1,2,Net.PoseCodec.encode(pose),false)
  var voice:=PackedByteArray();voice.resize(400);cp.voice.rpc_id(1,voice)
  await create_timer(.02).timeout
 check(await until(func():return hp.blocks.size()==1 and cp.blocks.size()==1),"Concurrent bulk transfers finish in both directions")
 check(hp.blocks[0]==payload and cp.blocks[0]==payload,"Bulk payload integrity after fragment interleaving")
 check(hp.voices>0 and host.states[2].serial>1,"Voice and pose updates continue during bulk")
 check(ha.peer.wire_max+6<=1000 and ca.peer.wire_max+6<=1000,"Complete SceneMultiplayer traffic respects native budget")
 client.leave();host.leave();host_root.queue_free();client_root.queue_free();await process_frame
 print("EOS_SESSION_RESULT ",failures);quit(0 if failures.is_empty() else 1)
