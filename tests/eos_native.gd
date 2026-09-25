extends SceneTree
## Loads the optional native binding, but never initializes EOS or authenticates.
func _initialize()->void:
 var path:="res://addons/epic-online-services-godot/eosg.gdextension"
 if not FileAccess.file_exists(path):print("EOS_NATIVE missing optional SDK");quit(2);return
 if not Engine.has_singleton("IEOS"):
  var status:=GDExtensionManager.load_extension(path)
  if status!=GDExtensionManager.LOAD_STATUS_OK:push_error("Cannot load optional EOSG binding");quit(1);return
 var sdk:=Engine.get_singleton("IEOS")
 for method in ["tick","p2p_interface_get_packet_queue_info","p2p_interface_set_packet_queue_size","connect_interface_login","lobby_interface_create_lobby"]:
  assert(sdk.has_method(method))
 var peer:MultiplayerPeer=ClassDB.instantiate("EOSGMultiplayerPeer")
 for method in ["get_all_peers","get_peer_user_id","set_auto_accept_connection_requests","create_server","create_client"]:assert(peer.has_method(method))
 assert(Engine.has_singleton("EOSGPacketPeerMediator"))
 print("EOS_NATIVE_RESULT native API loaded; no authentication attempted")
 peer=null;quit()
