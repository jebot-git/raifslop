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
var strip_previous:=Vector3.ZERO
var strip_engaged:=false
static func river(id:String)->bool:return id in ["meadow_bend","boulder_run"]
static func current(at:Vector3,id:String)->Vector3:
 var across:float=absf(at.z+11.0)
 var speed:float=lerpf(.85,.25,clampf(across/7,0,1)) if id=="meadow_bend" else lerpf(1.35,.35,clampf(across/5,0,1))
 if id=="boulder_run":
  for rock in [Vector3(-7,0,-10),Vector3(5,0,-13),Vector3(15,0,-8)]:
   if at.x>rock.x and at.x<rock.x+3 and absf(at.z-rock.z)<1.7:speed*=.25
 return Vector3(speed,0,0)
func reset():
 offset=Vector3.ZERO;drag=0;age=0;mend_cooldown=0;quality=1;charging=false;charge_age=0;strokes=0;backstroke=false;strip_engaged=false
func begin_cast():charging=true;charge_age=0;strokes=0;backstroke=false
func stroke(delta:float,forward_speed:float):
 charge_age+=delta;back_age+=delta
 if forward_speed<-.35:backstroke=true;back_age=0.0
 if backstroke and forward_speed>.45:
  if back_age<1.5:strokes+=1
  backstroke=false
func cast_power()->float:return clampf(8.0+minf(charge_age,1.5)*4.0+strokes*2.0,8,20)
func mend(direction:int)->bool:
 if mend_cooldown>0:return false
 mend_cooldown=.7
 drag=clampf(drag+(-.55 if direction<0 else .25),0,1)
 return direction<0
func strip(position:Vector3,gripped:bool,delta:float)->float:
 if not gripped or delta<=0:strip_engaged=false;return 0
 if not strip_engaged:strip_previous=position;strip_engaged=true;return 0
 var travel:float=maxf(0,position.z-strip_previous.z)
 strip_previous=position
 return clampf(travel/delta*1.5,0,2)
func drift(delta:float,rate:float,id:String,nymph:=false):
 age+=delta;mend_cooldown=maxf(0,mend_cooldown-delta)
 var at:=start+offset
 var flow:=current(at,id)
 if nymph:flow*=.85
 current_speed=flow.x
 offset+=flow*delta
 offset.z+=rate*delta*.8
 drag=clampf(drag+delta*(absf(flow.x-.22)*.10+rate*.12),0,1)
 var productive:bool=at.z< -5 and at.z> -19
 var holding:=1.0 if flow.x<.7 or absf(at.z+8)<1.5 else .65
 quality=(1.0-drag)*holding if productive else 0.0
