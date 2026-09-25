extends Node
## Serialized online lifecycle. No SDK calls leave the main thread.
const Config=preload("res://scripts/network/eos/config.gd")
const Factory=preload("res://scripts/network/transport_factory.gd")
var backend=preload("res://scripts/network/eos/eos_backend.gd").new()
var meta=preload("res://scripts/network/eos/meta_provider.gd").new()
var session:Node
var config:Dictionary={}
var auth=preload("res://scripts/network/eos/lobby_auth.gd").new()
var title:=""
var locked:=false
var hosting_lobby:=false
var lobbies:Array=[]
var browse_error:=""
var search_ready_at:=0
var admission_failed:=false
var busy:=false
var generation:=0
var lobby:=""
var pending_reference:=""
var presence_ready:=false
var cleanup_ok:=true
var refresh_due:=false
var presence_due:=false
var stop_due:=false
var loss_due:=false
func setup(owner_session:Node)->void:
 session=owner_session;name="Online"
 auth.rejected.connect(backend.reject_member)
 auth.failed.connect(func():admission_failed=true)
 add_child(backend);add_child(meta)
 backend.expired.connect(func():refresh_due=true)
 backend.session_lost.connect(func():loss_due=true)
 backend.membership_changed.connect(func():presence_due=true)
 meta.join_requested.connect(queue_invite)
 meta.leave_requested.connect(func(id:String):
  if id==lobby and not lobby.is_empty():loss_due=true)
func config_path()->String:
 var args:=OS.get_cmdline_user_args();var index:=args.find("--eos-config")
 if index>=0 and index+1<args.size():return args[index+1]
 if OS.get_name()=="Android" and FileAccess.file_exists("res://eos.cfg"):return "res://eos.cfg"
 return "user://eos.cfg"
func message(text:String)->void:
 session.status=text;session.changed.emit()
func queue_invite(reference:String)->void:
 if Config.parse_reference(config,reference).is_empty() or reference==join_reference():return
 pending_reference=reference
 session.changed.emit()
 # An invite never replaces an ongoing game. The player explicitly accepts it.
func join_reference()->String:
 return Config.join_reference(config,lobby) if not lobby.is_empty() else ""
func authenticate()->String:
 var identity:Dictionary=await meta.identity(config) if config.provider=="meta" else {"type":10}
 if identity.has("error"):return identity.error
 var result:String=await backend.login(identity,meta.identity.bind(config))
 identity.clear();return result
func settings_error(settings:Dictionary)->String:
 var error:=Config.validate(settings)
 if error.is_empty() and settings.provider=="device" and not "--eos-device-test" in OS.get_cmdline_user_args():
  error="Desktop device identity requires --eos-device-test. Quest uses Meta identity."
 if error.is_empty() and backend.initialized:
  for key in ["product_id","sandbox_id","deployment_id","client_id","client_secret","provider","relay"]:
   if settings[key]!=config[key]:error="Restart the game before changing EOS configuration.";break
 return error
func services(settings:Dictionary)->String:
 config=settings
 var error:String=backend.initialize(config)
 if error.is_empty() and backend.product_user_id.is_empty():error=await authenticate()
 return error
func browse_lobbies(path:String="")->void:
 if busy or Time.get_ticks_msec()<search_ready_at:return
 var settings:=Config.read(config_path() if path.is_empty() else path)
 var error:=settings_error(settings)
 if not error.is_empty():browse_error=error;session.changed.emit();return
 search_ready_at=Time.get_ticks_msec()+2000
 busy=true;browse_error="";session.changed.emit()
 var current:=generation
 error=await services(settings)
 var result:Dictionary={}
 if error.is_empty() and current==generation:
  result=await backend.browse(config);error=str(result.get("error",""))
 if current==generation:
  browse_error=error
  if error.is_empty():lobbies=result.get("lobbies",[])
 busy=false;session.changed.emit()
func share_invitation()->String:
 var link:=Config.meta_destination_link(config)
 if lobby.is_empty() or link.is_empty():return ""
 return "Join me in %s (up to 8 players).\n%s\nOpen Together and select this lobby, or paste this join code:\n%s%s"%[title,link,join_reference(),"\nAsk the host for the password." if locked else ""]
func start(hosting:bool,reference:String="",path:String="",lobby_title:String="Fishing together",password:String="")->Error:
 if busy:return ERR_BUSY
 var settings:=Config.read(config_path() if path.is_empty() else path)
 var error:=settings_error(settings)
 lobby_title=Config.clean_title(lobby_title)
 if hosting and lobby_title.is_empty():error="Enter a lobby name."
 if not auth.valid_password(password):error="Password must be at most 64 characters."
 var id:=""
 if error.is_empty() and not hosting:
  id=Config.parse_reference(settings,reference)
  if id.is_empty():error="Invalid invite reference or different deployment/protocol."
 if not error.is_empty():message(error);return ERR_INVALID_PARAMETER
 busy=true;generation+=1
 var current:=generation
 session.leave("Connecting to online services…",false)
 await cleanup()
 if current!=generation:return await cancelled()
 stop_due=false
 error=await services(settings)
 if current!=generation:return await cancelled()
 if not error.is_empty():return await fail(error)
 message("Creating online lobby…" if hosting else "Joining online lobby…")
 var answer:Dictionary=await backend.create_lobby(config,lobby_title,not password.is_empty()) if hosting else await backend.join_lobby(id)
 if current!=generation:return await cancelled()
 error=str(answer.get("error",""))
 if error.is_empty() and (answer.get("bucket_id")!=Config.bucket(config) or answer.get("max_members")!=Config.MAX_MEMBERS or backend.product_user_id not in answer.get("members",[])):
  error="Lobby protocol, capacity or membership does not match."
 if error.is_empty():error=backend.open_peer(hosting)
 if not error.is_empty():return await fail(error)
 var result:=Factory.eos(backend.peer,backend.sdk,backend.identity_token)
 if result.error!=OK:return await fail("Cannot start EOS game transport.")
 pending_reference=""
 lobby=backend.lobby_id
 title=Config.clean_title(str(answer.get("title","Fishing together")))
 locked=bool(answer.get("locked",false));hosting_lobby=hosting;admission_failed=false
 auth.install(session.multiplayer,hosting,password)
 password=""
 session.attach_transport(result.peer,hosting,"EOS online")
 presence_ready=await meta.publish(config,lobby,answer.get("available_slots",0)>0) if hosting else false
 if not hosting:presence_due=true
 if current!=generation:return await cancelled()
 busy=false;session.changed.emit()
 return OK
func cleanup()->void:
 auth.reset()
 presence_ready=false;lobby="";title="";locked=false;hosting_lobby=false;admission_failed=false
 var cleared:bool=await meta.clear()
 var left:bool=await backend.leave_lobby()
 cleanup_ok=cleared and left
 presence_due=false;loss_due=false
func fail(error:String)->Error:
 var current:=generation
 await cleanup();busy=false
 if current==generation:message(error)
 return FAILED
func cancelled()->Error:
 await cleanup();busy=false;stop_due=false;return ERR_SKIP
func stop()->void:
 auth.reset()
 generation+=1;stop_due=true
func invite()->void:
 if busy or lobby.is_empty() or not presence_ready or config.get("provider")!="meta":return
 busy=true
 var current:=generation
 var ok:bool=await meta.invite()
 busy=false
 if current==generation and not ok:message("Could not open the friends invite panel.")
func _process(_delta:float)->void:
 if admission_failed:
  admission_failed=false;session.leave("Lobby admission failed. Check the password and try again.");return
 if busy:return
 if stop_due:
  stop_due=false;busy=true;await cleanup();busy=false;return
 if loss_due and not lobby.is_empty():
  session.leave("Online session ended. The host or service disconnected." if session.active else "Lobby admission failed. Check the password and try again.");return
 if presence_due and not lobby.is_empty() and session.active:
  presence_due=false;busy=true
  var info:Dictionary=backend.snapshot()
  presence_ready=await meta.publish(config,lobby,not info.has("error") and info.get("available_slots",0)>0)
  busy=false;return
 if refresh_due and backend.initialized:
  refresh_due=false;busy=true
  var current:=generation
  var error:=await authenticate()
  busy=false
  if current==generation and not error.is_empty():session.leave("Online authentication expired. Reconnect to continue.")
