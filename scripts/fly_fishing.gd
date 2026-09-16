extends RefCounted
## Authored river currents and presentation; no rope rigid bodies.
var offset:=Vector3.ZERO
var start:=Vector3.ZERO
var drag:=0.0
var age:=0.0
var mend_cooldown:=0.0
var current_speed:=0.0
var quality:=1.0
var charging:=false
var charge_age:=0.0
var backstroke:=false
var back_age:=0.0
var strokes:=0
var repeat_strokes:=false
const CAST_BACK_TRAVEL := .06
const CAST_FORWARD_TRAVEL := .10
var cast_back_travel := 0.0
var cast_forward_travel := 0.0
var strip_previous:=Vector3.ZERO
var strip_engaged:=false
var mend_age:=2.0
var mend_direction:=0
var mend_previous:=Vector3.ZERO
var mend_tracking:=false
var mend_travel:=0.0
var mend_latched:=false
static func river(id:String)->bool:return id in ["meadow_bend","boulder_run"]
static func current(at:Vector3,id:String)->Vector3:
 var across:float=absf(at.z+11.0)
 var speed:float=lerpf(.85,.25,clampf(across/7,0,1)) if id=="meadow_bend" else lerpf(1.35,.35,clampf(across/5,0,1))
 if id=="boulder_run":
  for rock in [Vector3(-7,0,-10),Vector3(5,0,-13),Vector3(15,0,-8)]:
   if at.x>rock.x and at.x<rock.x+3 and absf(at.z-rock.z)<1.7:speed*=.25
 return Vector3(speed,0,0)
func reset():
 offset=Vector3.ZERO;drag=0;age=0;mend_cooldown=0;quality=1;charging=false;charge_age=0;strokes=0;backstroke=false;strip_engaged=false;strip_grip_down=false;strip_blocked=false
 mend_age=2.0;mend_direction=0;reset_mend_gesture()
func begin_cast(allow_extension:=false):
 charging=true;charge_age=0;strokes=0;backstroke=false;back_age=0
 repeat_strokes=allow_extension
 cast_back_travel=0;cast_forward_travel=0
func stroke(delta:float,forward_speed:float):
 charge_age+=delta;back_age+=delta
 # Small deliberate travel, with no deadline or precise release instant.
 # Once accepted, a follow-through or tracking spike cannot undo the cast.
 if strokes>0 and not repeat_strokes:return
 if forward_speed<-.08:
  cast_back_travel=minf(CAST_BACK_TRAVEL,cast_back_travel-forward_speed*delta)
  if cast_back_travel>=CAST_BACK_TRAVEL:backstroke=true
  cast_forward_travel=0
 elif backstroke and forward_speed>.08:
  cast_forward_travel+=forward_speed*delta
  if cast_forward_travel>=CAST_FORWARD_TRAVEL:
   strokes+=1
   backstroke=false;cast_back_travel=0;cast_forward_travel=0
func cast_power()->float:return clampf(8.0+minf(charge_age,1.5)*4.0+strokes*2.0,8,20)
func mend(direction:int)->bool:
 if mend_cooldown>0 or direction==0:return false
 mend_cooldown=.7
 mend_age=0;mend_direction=signi(direction)
 drag=clampf(drag+(-.55 if direction<0 else .25),0,1)
 return direction<0
func reset_mend_gesture():
 mend_tracking=false;mend_travel=0;mend_latched=false
func sample_mend(at:Vector3,world_basis:Basis,delta:float,valid:=true)->int:
 # Track the raw controller-derived tip in origin space. Turning/locomotion
 # and avatar IK corrections must not become river-relative rod sweeps.
 if not valid or delta<=0 or delta>.1 or not at.is_finite():
  reset_mend_gesture();return 0
 if not mend_tracking:
  mend_previous=at;mend_tracking=true;return 0
 var movement:Vector3=world_basis*(at-mend_previous);mend_previous=at
 if movement.length()>.5:reset_mend_gesture();return 0
 var speed:float=movement.x/delta
 if absf(speed)<.15:mend_travel=0;mend_latched=false;return 0
 if mend_latched or absf(speed)<.35:return 0
 if signf(mend_travel)!=signf(speed):mend_travel=0
 mend_travel+=movement.x
 if absf(mend_travel)<.14:return 0
 mend_latched=true
 return -1 if mend_travel<0 else 1
func mend_bend()->float:
 return mend_direction*sin(PI*clampf(mend_age/.9,0,1))*1.1
# The visible loose line runs from the spool to the first guide above the grip.
const LINE_OUTLET := Vector3(-.035,-.045,.025)
const LINE_GUIDE := Vector3(-.025,0,-.38)
const GRAB_RADIUS := .13
const MAX_STRIP_REACH := 1.25
var strip_grip_down := false
var strip_blocked := false
var strip_axis := Vector3.BACK
func release_strip(require_release := false) -> void:
 strip_engaged=false
 strip_blocked=require_release
 if require_release:reset_mend_gesture()
func strip(position:Vector3,grip:float,delta:float,outlet:Vector3,guide:Vector3,valid:=true)->float:
 # All points are tracking-origin-local, so locomotion and snap turns cannot reel.
 var down:bool=grip>(.35 if strip_grip_down else .55)
 strip_grip_down=down
 if not down:release_strip();return 0.0
 if not valid or delta<=0 or delta>.1 or not position.is_finite():
  release_strip(true);return 0.0
 if strip_blocked:return 0.0
 if not strip_engaged:
  var nearest:=Geometry3D.get_closest_point_to_segment(position,outlet,guide)
  if position.distance_to(nearest)>GRAB_RADIUS:return 0.0
  strip_engaged=true;strip_previous=position
  strip_axis=(position-guide).normalized()
  return 0.0
 var movement:=position-strip_previous
 strip_previous=position
 if position.distance_to(guide)>MAX_STRIP_REACH or movement.length()>.35:
  release_strip(true);return 0.0
 # Count only hand travel away from the guide, never the rod moving away from a
 # stationary hand. Returning the hand while gripping does not pay out line.
 var travel:float=maxf(0.0,movement.dot(strip_axis)-.015*delta)
 strip_axis=(position-guide).normalized()
 return clampf(travel/delta*1.5,0,2)
func drift(delta:float,rate:float,id:String,nymph:=false):
 age+=delta;mend_cooldown=maxf(0,mend_cooldown-delta);mend_age+=delta
 var at:=start+offset
 var flow:=current(at,id)
 if nymph:flow*=.85
 current_speed=flow.x
 offset+=flow*delta
 drag=clampf(drag+delta*(absf(flow.x-.22)*.10+rate*.12),0,1)
 var productive:bool=at.z< -5 and at.z> -19
 var holding:=1.0 if flow.x<.7 or absf(at.z+8)<1.5 else .65
 quality=(1.0-drag)*holding if productive else 0.0
