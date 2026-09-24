extends SceneTree
const Host=preload("res://addons/golfminus/scripts/golf/fishing_host.gd")
class Service extends Node:
	var allowed:=true
	var calls:Array=[]
	var view:={"epoch":1,"strokes":1}
	func can_shoot()->bool:return allowed
	func request(action:String,data:Dictionary)->void:calls.append([action,data])
class Game extends Node3D:
	var notices:Array=[]
	var launches:Array=[]
	var round_state:={"strokes":0}
	var activity:Node
	func pending_contact(contact:Dictionary)->void:notices.append(["pending",contact.duplicate(true)])
	func reject_contact(contact:Dictionary,reason:String)->void:notices.append([reason,contact.duplicate(true)])
	func strike(v:Vector3,face:Vector3,contact:Dictionary)->bool:
		if activity.intercept_shot(v,face,contact):return false
		launches.append(contact.duplicate(true));return true
class Fixture extends Host:
	func enrolled()->bool:return true
var failures:Array=[]
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize()->void:
	var activity:=Fixture.new();var game:=Game.new();var service:=Service.new()
	activity.golf=game;activity.service=service;activity.active=true;game.activity=activity
	var contact:={"contact_policy":"tracking_tolerance","tracking_tolerance_m":.002,"tracking_correction_m":.0018,"turf":{"speed_scale":.9}}
	check(activity.intercept_shot(Vector3.FORWARD,Vector3.FORWARD,contact),"First contact waits for authority")
	check(game.notices.size()==1 and game.notices[0][0]=="pending" and service.calls.size()==1,"Pending contact is reported before one request")
	contact.tracking_correction_m=0.0;contact.turf.speed_scale=1.0
	activity.intercept_shot(Vector3.FORWARD,Vector3.FORWARD,contact)
	check(service.calls.size()==1,"Repeated contact cannot submit a duplicate request")
	activity.command_result("shot",true)
	check(game.launches.size()==1 and game.launches[0].tracking_correction_m==.0018 and game.launches[0].turf.speed_scale==.9,"Approval launches captured contact once without recomputing tolerance or turf")
	activity.command_result("shot",true)
	check(game.launches.size()==1 and activity.pending_shot.is_empty() and not activity.shot_granted,"Repeated approval does not duplicate launch")
	activity.intercept_shot(Vector3.FORWARD,Vector3.FORWARD,contact);activity.command_result("shot",false)
	check(activity.pending_shot.is_empty() and game.notices[-1][0]=="shot_not_authorized","Denial clears pending state and reports rejection")
	service.allowed=false
	activity.intercept_shot(Vector3.FORWARD,Vector3.FORWARD,contact)
	check(activity.pending_shot.is_empty() and game.notices[-1][0]=="waiting_for_turn","Out-of-turn contact is rejected, not pending")
	activity.free();game.free();service.free()
	print("GOLF_PENDING_CONTACT_RESULT ",failures);quit(0 if failures.is_empty() else 1)
