extends VBoxContainer
## All entry fields are built up front for the shared VR keyboard binding.
const Config=preload("res://scripts/network/eos/config.gd")
var session:Node
var home:=VBoxContainer.new()
var hosting:=VBoxContainer.new()
var browser:=VBoxContainer.new()
var joining:=VBoxContainer.new()
var current:=VBoxContainer.new()
var title_input:=LineEdit.new()
var protect:=CheckButton.new()
var host_password:=LineEdit.new()
var join_password:=LineEdit.new()
var browser_password:=LineEdit.new()
var services_requested:=false
var reference:=LineEdit.new()
var list=preload("res://scripts/ui/vr_item_list.gd").new()
var list_status:=Label.new()
var current_status:=Label.new()
var notice:=Label.new()
var create_button:Button
var join_button:Button
var refresh_button:Button
var code_button:Button
var accept_button:Button
var friends_button:Button
var share_button:Button
var cancel_button:Button
var home_host:Button
var home_browse:Button
var rows:Array=[]
var selected:=""
var shown_lobby:=""
var tick:=0.0
func label(parent:Node,text:String)->Label:
 var result:=Label.new();result.text=text;result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(result);return result
func button(parent:Node,text:String,action:Callable)->Button:
 var result:=Button.new();result.text=text;result.custom_minimum_size.y=44
 parent.add_child(result);result.pressed.connect(action);return result
func password_field(parent:Node,field:LineEdit)->void:
 field.secret=true;field.max_length=64;field.placeholder_text="Lobby password";parent.add_child(field)
func page(target:Control)->void:
 for item in [home,hosting,browser,joining]:item.visible=item==target
 notice.text=""
func setup(owner_session:Node)->void:
 session=owner_session
 add_theme_constant_override("separation",10)
 label(self,"Online · up to 8 players")
 for item in [home,hosting,browser,joining,current]:
  item.add_theme_constant_override("separation",10);add_child(item)
 home_host=button(home,"Host a lobby",func():page(hosting))
 home_browse=button(home,"Browse lobbies",func():page(browser);session.online.browse_lobbies())
 button(home,"Join with code / invitation",func():page(joining))
 label(hosting,"Host a named lobby · 8 players including you")
 title_input.max_length=48;title_input.placeholder_text="Lobby name";title_input.text=session.display_name+"'s fishing lobby";hosting.add_child(title_input)
 protect.text="Password protect";hosting.add_child(protect)
 password_field(hosting,host_password);host_password.visible=false
 protect.toggled.connect(func(value:bool):host_password.visible=value;host_password.clear();refresh())
 title_input.text_changed.connect(func(_text:String):refresh())
 host_password.text_changed.connect(func(_text:String):refresh())
 label(hosting,"Your lobby will appear in Together. Share its password separately.")
 create_button=button(hosting,"Open lobby",create_lobby)
 button(hosting,"Back",func():page(home))
 list.custom_minimum_size.y=170;browser.add_child(list)
 list.item_selected.connect(func(index:int):
  if index>=0 and index<rows.size():selected=rows[index].id;browser_password.clear();refresh())
 list_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;browser.add_child(list_status)
 # One password field per page so VR keyboard focus remains predictable.
 password_field(browser,browser_password)
 browser_password.placeholder_text="Password for selected lobby (if locked)"
 join_button=button(browser,"Join selected lobby",func():
  var value:String=browser_password.text;browser_password.clear()
  if not selected.is_empty():session.online.start(false,Config.join_reference(session.online.config,selected),"","",value))
 refresh_button=button(browser,"Refresh lobbies",func():session.online.browse_lobbies())
 button(browser,"Back",func():page(home))
 label(joining,"Paste a join code, or accept your pending Meta invitation.")
 reference.max_length=1024;reference.placeholder_text="Join code";joining.add_child(reference)
 button(joining,"Paste join code",func():reference.text=DisplayServer.clipboard_get().left(1024))
 password_field(joining,join_password);join_password.placeholder_text="Password (if the lobby is locked)"
 code_button=button(joining,"Join with code",func():join_reference(reference.text))
 accept_button=button(joining,"Accept Meta invitation",func():join_reference(session.online.pending_reference))
 button(joining,"Back",func():page(home))
 current_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;current.add_child(current_status)
 friends_button=button(current,"Invite Meta friends",session.online.invite)
 share_button=button(current,"Copy Meta invitation link + join code",func():
  var value:String=session.online.share_invitation()
  if not value.is_empty():DisplayServer.clipboard_set(value);notice.text="Invitation copied. Paste it into a message to your friends.")
 button(current,"Copy join code",func():DisplayServer.clipboard_set(session.online.join_reference());notice.text="Join code copied.")
 label(current,"Meta friends can join this lobby from their invitation. The shared Meta link opens the game; select this lobby in Together or paste its join code.")
 button(current,"Leave lobby",func():session.leave())
 cancel_button=button(self,"Cancel connection",func():session.leave("Connection cancelled"))
 notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(notice)
 page(home);session.changed.connect(refresh);refresh()
func create_lobby()->void:
 var value:=host_password.text if protect.button_pressed else ""
 host_password.clear()
 session.online.start(true,"","",title_input.text,value)
func join_reference(value:String)->void:
 var password:=join_password.text;join_password.clear()
 session.online.start(false,value,"","",password)
func _process(delta:float)->void:
 if not is_visible_in_tree() or session==null:return
 if not services_requested:
  services_requested=true
  if session.online.config.is_empty():session.online.browse_lobbies()
 tick+=delta
 if tick>.5:tick=0;refresh()
func refresh()->void:
 if session==null:return
 var flow=session.online
 var occupied:bool=not flow.lobby.is_empty()
 current.visible=occupied
 cancel_button.visible=flow.busy and not occupied
 if occupied and shown_lobby!=flow.lobby:page(home)
 shown_lobby=flow.lobby
 home_host.disabled=flow.busy or occupied;home_browse.disabled=flow.busy
 create_button.disabled=flow.busy or occupied or Config.clean_title(title_input.text).is_empty() or (protect.button_pressed and host_password.text.is_empty())
 refresh_button.disabled=flow.busy or Time.get_ticks_msec()<flow.search_ready_at
 code_button.disabled=flow.busy
 accept_button.disabled=flow.busy or flow.pending_reference.is_empty()
 accept_button.text="Accept Meta invitation" if not flow.pending_reference.is_empty() else "No pending Meta invitation"
 if not flow.pending_reference.is_empty() and not joining.visible:notice.text="A Meta invitation is waiting. Open Join with code / invitation to accept."
 if rows!=flow.lobbies:
  rows=flow.lobbies.duplicate(true);list.clear()
  for entry in rows:
   list.add_item("%s · %d/8 · %s"%[entry.title,entry.members,"Locked" if entry.locked else "Open"])
   if entry.id==selected:list.select(list.item_count-1)
 var available:=false
 for entry in rows:
  if entry.id==selected:available=entry.members<8 and entry.id!=flow.lobby
 join_button.disabled=flow.busy or not available
 list_status.text="Searching…" if flow.busy else flow.browse_error if not flow.browse_error.is_empty() else "No lobbies found. New lobbies may take a moment to appear; refresh to try again." if rows.is_empty() else "Select a lobby to join."
 current_status.text="%s · %d/8 · %s%s"%[flow.title,flow.backend.members.size(),"Password protected" if flow.locked else "Open", " · You are hosting" if flow.hosting_lobby else ""]
 friends_button.disabled=flow.busy or not occupied or not flow.presence_ready or flow.config.get("provider")!="meta"
 share_button.disabled=flow.busy or flow.share_invitation().is_empty()
