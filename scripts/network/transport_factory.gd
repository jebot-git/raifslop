extends RefCounted
const ENetTransport=preload("res://scripts/network/threaded_peer.gd")
const EOSTransport=preload("res://scripts/network/eos_peer.gd")
static func host(port:int,capacity:int,bind_address:String)->Dictionary:
 var peer=ENetTransport.new();peer.framed=true;peer.set_bind_ip(bind_address)
 var error:=peer.create_server(port,capacity,7)
 return {"error":error,"peer":peer if error==OK else null}
static func join(address:String,port:int)->Dictionary:
 var peer=ENetTransport.new();peer.framed=true
 var error:=peer.create_client(address,port,7)
 return {"error":error,"peer":peer if error==OK else null}
static func eos(native:MultiplayerPeer,sdk:Object,identity:Callable)->Dictionary:
 var peer=EOSTransport.new()
 var error:=peer.start(native,sdk,identity)
 return {"error":error,"peer":peer if error==OK else null}
