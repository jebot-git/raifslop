extends Node
## Minimal server entry point: no client scene, XR, rendering or codec initialization.
var network:Node
var server_only:=true
func _ready()->void:
 network=preload("res://scripts/network/session.gd").new();add_child(network)
 network.setup(self,true)
 var args:=OS.get_cmdline_user_args()
 if "--server" in args or "--host" in args:network.command_line()
 else:
  var port:=24567;var bind_address:="*"
  for i in range(args.size()-1):
   if args[i]=="--port":port=args[i+1].to_int()
   if args[i]=="--bind":bind_address=args[i+1]
  if network.host(port,bind_address)!=OK:get_tree().quit(1)
func _notification(what:int)->void:
 if what==NOTIFICATION_WM_CLOSE_REQUEST:
  network.leave();get_tree().quit()
