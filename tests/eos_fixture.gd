extends RefCounted
## Models the pinned EOSG channel mapping/error codes without logging in.
class SDK extends RefCounted:
 var used:=0
 var capacity:=262144
 var result:=0
 func p2p_interface_get_packet_queue_info()->Dictionary:
  return {"result_code":result,"outgoing_packet_queue_current_size_bytes":used,"outgoing_packet_queue_max_size_bytes":capacity}
class Native extends MultiplayerPeerExtension:
 var uid:=1
 var remote:Native
 var ids:Array=[2]
 var status:=CONNECTION_CONNECTED
 var packets:Array=[]
 var sends:Array=[]
 var target:=0
 var channel:=0
 var mode:=TRANSFER_MODE_RELIABLE
 var error:=OK
 var attempts:=0
 var disconnected:Array=[]
 func get_all_peers()->Array:return ids.duplicate()
 func _put_packet_script(bytes:PackedByteArray)->Error:
  attempts+=1
  if error!=OK:return error
  sends.append([target,channel,mode,bytes.duplicate()])
  if remote!=null:
   var physical:=channel+1 if channel>0 else (0 if mode==TRANSFER_MODE_RELIABLE else 1)
   remote.packets.append([uid,physical,mode,bytes.duplicate()])
  return OK
 func _get_packet_script()->PackedByteArray:return packets.pop_front()[3]
 func _get_available_packet_count()->int:return packets.size()
 func _get_packet_peer()->int:return packets[0][0]
 func _get_packet_channel()->int:return packets[0][1]
 func _get_packet_mode()->MultiplayerPeer.TransferMode:return packets[0][2]
 func _get_max_packet_size()->int:return 1170
 func _get_connection_status()->MultiplayerPeer.ConnectionStatus:return status
 func _get_unique_id()->int:return uid
 func _is_server()->bool:return uid==1
 func _is_server_relay_supported()->bool:return true
 func _set_target_peer(value:int)->void:target=value
 func _set_transfer_channel(value:int)->void:channel=value
 func _get_transfer_channel()->int:return channel
 func _set_transfer_mode(value:MultiplayerPeer.TransferMode)->void:mode=value
 func _get_transfer_mode()->MultiplayerPeer.TransferMode:return mode
 func _poll()->void:pass
 func _close()->void:status=CONNECTION_DISCONNECTED;remote=null;packets.clear()
 func _disconnect_peer(id:int,_force:bool)->void:
  ids.erase(id);disconnected.append(id);peer_disconnected.emit(id)
 func _set_refuse_new_connections(_value:bool)->void:pass
 func _is_refusing_new_connections()->bool:return false
