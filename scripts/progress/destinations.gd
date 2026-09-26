extends Node
const Catalog=preload("res://scripts/progress/destination_catalog.gd")
var host:Node
var sdk:Object
var pending:=""
var last_location:=""
var connected:=false
var travelling:=false
signal changed
func setup(game:Node)->void:
	host=game;name="Destinations";add_to_group("activity_services")
func read_intent(details:Object,cold:=false)->void:
	if details==null:return
	var name:String=str(details.get_destination_api_name())
	if not Catalog.all().has(name):return
	pending=name;changed.emit()
	# A lobby invite retains its separate explicit join/accept flow.
	var lobby:String=str(details.get_lobby_session_id()) if details.has_method("get_lobby_session_id") else ""
	if cold and lobby.is_empty():travel.call_deferred()
func _on_meta_notification(message:Object)->void:
	if message==null or message.is_error():return
	match int(message.get_type()):
		78859427:read_intent(sdk.application_lifecycle_get_launch_details())
		2000194038:read_intent(message.get_group_presence_join_intent())
func travel()->void:
	if travelling or not Catalog.all().has(pending) or not is_instance_valid(host):return
	if host.casting or host.game.state!=0 or host.avatar_loading:return
	var target:Dictionary=Catalog.all()[pending]
	var activity:Node=host.golf_activity
	if is_instance_valid(activity) and activity.active:
		if target.kind=="course" and activity.golf.course_id==target.id:pending="";changed.emit();return
		if activity.enrolled():return
	travelling=true
	var accepted:=false
	if target.kind=="water":accepted=host._select_location(target.id)
	else:
		if activity.active:activity.leave()
		if not activity.active:await activity.enter(target.id)
		accepted=activity.active and activity.golf.course_id==target.id
	if accepted:pending=""
	travelling=false;changed.emit()
func _process(_delta:float)->void:
	if not is_instance_valid(host):return
	var location:String=str(host.current_location)
	if location!=last_location:
		last_location=location
		if is_instance_valid(host.get("progress")):host.progress.visit(location)
		if is_instance_valid(host.get("network")):host.network.online.presence_due=true
	if connected:return
	if sdk==null and Engine.has_singleton("MetaPlatformSDK"):sdk=Engine.get_singleton("MetaPlatformSDK")
	if sdk==null or not sdk.is_platform_initialized():return
	connected=true;sdk.notification_received.connect(_on_meta_notification)
	read_intent(sdk.application_lifecycle_get_launch_details(),true)
