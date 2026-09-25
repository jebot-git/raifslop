extends MultiplayerPeerExtension
## EOSG 2.3.1 adapter. SDK, mediator and this peer all stay on Godot's main thread.
const Frames=preload("res://scripts/network/packet_frames.gd")
const Scheduler=preload("res://scripts/network/packet_scheduler.gd")
const MAX_INCOMING:=8_388_608
const MAX_PACKETS:=4096
const NATIVE_HIGH_WATER:=65_536
const NATIVE_CONTROL_RESERVE:=16_384
var native:MultiplayerPeer
var sdk:Object
var identity:Callable
var scheduler=Scheduler.new()
var frames=Frames.new()
var peers:Dictionary={}
var packets:Array=[]
var incoming_bytes:=0
var target:=0
var channel:=0
var mode:=TRANSFER_MODE_RELIABLE
var pose_source:=0
var uid:=0
var server:=false
var status:=CONNECTION_DISCONNECTED
var refusing:=false
var failed:=false
var wire_sent:=0
var wire_max:=0
var received:=0
var polls:=0
var queue_timeouts:=0
var queue_info:Dictionary={}
var native_outgoing_peak:=0
var events:Array=[]

func start(peer:MultiplayerPeer,eos:Object,identity_provider:Callable)->Error:
 assert(OS.get_thread_caller_id()==OS.get_main_thread_id())
 if native!=null or peer==null or eos==null or not identity_provider.is_valid():return ERR_INVALID_PARAMETER
 native=peer;sdk=eos;identity=identity_provider
 uid=native.get_unique_id();server=uid==1;status=native.get_connection_status()
 if uid<1 or (server and uid!=1):_close();return ERR_INVALID_DATA
 native.peer_connected.connect(_connected);native.peer_disconnected.connect(_disconnected)
 for id in native.get_all_peers():_connected(id)
 return OK
func identity_token(id:int)->String:
 return str(identity.call(id)) if identity.is_valid() else ""
func set_pose_source(id:int)->void:pose_source=id
func _connected(id:int)->void:
 if id<1 or id==uid or (not server and id!=1) or peers.size()>=7+(1 if not server else 0):
  native.disconnect_peer(id);return
 peers[id]=true;events.append([true,id])
func _disconnected(id:int)->void:
 scheduler.drop(id);frames.drop(id)
 for i in range(packets.size()-1,-1,-1):
  if packets[i][0]==id:incoming_bytes-=packets[i][3].size();packets.remove_at(i)
 if peers.erase(id):events.append([false,id])
func _disconnect_peer(id:int,force:bool=false)->void:
 if native==null:return
 if not server and id==1:_close();return
 if peers.has(id):native.disconnect_peer(id,force);_disconnected(id)
# EOSG exposes physical channels: 0 reliable default, 1 unreliable default,
# then logical channel + 1. Normalize BEFORE reassembly and SceneMultiplayer.
static func logical_channel(physical:int,packet_mode:int)->int:
 if physical==0:return 0 if packet_mode==TRANSFER_MODE_RELIABLE else -1
 if physical==1:return 0 if packet_mode==TRANSFER_MODE_UNRELIABLE else -1
 return physical-1 if physical>=2 and physical<=7 else -1
func _poll()->void:
 assert(OS.get_thread_caller_id()==OS.get_main_thread_id())
 if native==null:return
 if native.get_connection_status()==CONNECTION_DISCONNECTED:_close();return
 native.poll();polls+=1
 if native==null:return
 status=native.get_connection_status()
 var now:=Time.get_ticks_msec()
 for i in mini(native.get_available_packet_count(),512):
  var id:=native.get_packet_peer();var packet_mode:=native.get_packet_mode()
  var logical:=logical_channel(native.get_packet_channel(),packet_mode)
  var bytes:=native.get_packet()
  if not peers.has(id):continue
  var decoded:=frames.receive(id,logical,packet_mode==TRANSFER_MODE_RELIABLE,bytes,now)
  if decoded.has("error"):
   _disconnect_peer(id)
   if native==null:return
   continue
  if not decoded.has("packet"):continue
  if incoming_bytes+decoded.packet.size()>MAX_INCOMING or packets.size()>=MAX_PACKETS:
   failed=true;_close();return
  packets.append([id,logical,packet_mode,decoded.packet]);incoming_bytes+=decoded.packet.size();received+=1
 for id in frames.expire(now):_disconnect_peer(id)
 if native==null:return
 _pump(now)
 var dispatch:=events;events=[]
 for event in dispatch:
  if native==null:break
  if event[0] and peers.has(event[1]):peer_connected.emit(event[1])
  elif not event[0]:peer_disconnected.emit(event[1])
func _pump(now:int)->void:
 for id in scheduler.maintain(now):queue_timeouts+=1;_disconnect_peer(id)
 if native==null or status!=CONNECTION_CONNECTED:return
 var blocked:Dictionary={}
 for i in 128:
  var item:=scheduler.next(now,blocked)
  if item.is_empty():break
  var row:Dictionary=item.row
  if not peers.has(row.peer):scheduler.drop(row.peer);continue
  queue_info=sdk.p2p_interface_get_packet_queue_info()
  # Missing/failed telemetry must not be treated as an empty native queue.
  if queue_info.get("result_code",-1)!=0:
   scheduler.backpressure+=1;break
  var used:int=queue_info.get("outgoing_packet_queue_current_size_bytes",-1)
  native_outgoing_peak=maxi(native_outgoing_peak,used)
  var capacity:int=queue_info.get("outgoing_packet_queue_max_size_bytes",0)
  var ceiling:=mini(NATIVE_HIGH_WATER,capacity)
  if row.kind!="control":ceiling=maxi(0,ceiling-NATIVE_CONTROL_RESERVE)
  if used<0 or used+item.cost>ceiling:
   scheduler.backpressure+=1;blocked[row.key]=true;continue
  native.set_target_peer(row.peer);native.transfer_channel=row.channel;native.transfer_mode=row.mode
  var error:=native.put_packet(item.packet)
  if error==OK:
   wire_sent+=1;wire_max=maxi(wire_max,item.packet.size());scheduler.commit(item)
  elif error in [FAILED,ERR_BUSY,ERR_OUT_OF_MEMORY]:
   # Pinned EOSG maps EOS_LimitExceeded to FAILED, not ERR_BUSY.
   # Each frame is already below its size cap, so retain it for queue retry.
   scheduler.backpressure+=1;blocked[row.key]=true
  else:_disconnect_peer(row.peer)
  if native==null:return
func _put_packet_script(bytes:PackedByteArray)->Error:
 assert(OS.get_thread_caller_id()==OS.get_main_thread_id())
 if native==null or status!=CONNECTION_CONNECTED:return ERR_UNCONFIGURED
 if mode not in [TRANSFER_MODE_RELIABLE,TRANSFER_MODE_UNRELIABLE]:return ERR_INVALID_PARAMETER
 var targets:Array=[]
 if not server:
  # SceneMultiplayer implements server relay; EOSG clients only send to host.
  if peers.has(1):targets=[1]
 elif target>0:
  if not peers.has(target):return ERR_INVALID_PARAMETER
  targets=[target]
 else:
  for id in peers:
   if target==0 or id!=-target:targets.append(id)
 var result:=scheduler.enqueue(targets,channel,mode,bytes,pose_source,Time.get_ticks_msec())
 if result!=OK and mode==TRANSFER_MODE_RELIABLE:
  for id in targets:_disconnect_peer(id)
 return result
func _close()->void:
 assert(OS.get_thread_caller_id()==OS.get_main_thread_id())
 var old:=native;native=null
 if old!=null:
  old.peer_connected.disconnect(_connected);old.peer_disconnected.disconnect(_disconnected);old.close()
 peers.clear();packets.clear();events.clear();incoming_bytes=0
 frames=Frames.new();scheduler=Scheduler.new();status=CONNECTION_DISCONNECTED
 identity=Callable();sdk=null
func _get_packet_script()->PackedByteArray:
 if packets.is_empty():return PackedByteArray()
 var row:Array=packets.pop_front();incoming_bytes-=row[3].size();return row[3]
func _get_available_packet_count()->int:return packets.size()
func _get_packet_peer()->int:return packets[0][0] if not packets.is_empty() else 0
func _get_packet_channel()->int:return packets[0][1] if not packets.is_empty() else 0
func _get_packet_mode()->MultiplayerPeer.TransferMode:return packets[0][2] if not packets.is_empty() else TRANSFER_MODE_RELIABLE
func _get_max_packet_size()->int:return Frames.MAX_MESSAGE
func _get_connection_status()->MultiplayerPeer.ConnectionStatus:return status
func _get_unique_id()->int:return uid
func _is_server()->bool:return server
func _is_server_relay_supported()->bool:return true
func _set_target_peer(value:int)->void:target=value
func _set_transfer_channel(value:int)->void:channel=value
func _get_transfer_channel()->int:return channel
func _set_transfer_mode(value:MultiplayerPeer.TransferMode)->void:mode=value
func _get_transfer_mode()->MultiplayerPeer.TransferMode:return mode
func _set_refuse_new_connections(value:bool)->void:
 refusing=value
 if native!=null:native.refuse_new_connections=value
func _is_refusing_new_connections()->bool:return refusing
func diagnostics()->Dictionary:
 return {"transport":"eos","running":native!=null,"polls":polls,"received":received,"wire_sent":wire_sent,"wire_max_bytes":wire_max,"queued_bytes":incoming_bytes,"outgoing_bytes":scheduler.queued_bytes,"reassembly_bytes":frames.reserved,"malformed_frames":frames.rejected,"scheduler":scheduler.diagnostics(Time.get_ticks_msec()),"native_queue":queue_info.duplicate(),"native_outgoing_peak_bytes":native_outgoing_peak,"queue_timeouts":queue_timeouts,"failed":failed}
