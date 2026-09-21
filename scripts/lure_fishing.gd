extends RefCounted
## Active retrieves, bounded sink depth and short worked-lure pause windows.
## Gameplay habitats reuse the existing location rosters and stable species IDs.
const BAIT_NAMES=["Inline spinner","Paddle-tail jig","Diving minnow"]
const MARINE_NAMES=["Casting spoon","Paddle-tail jig","Diving minnow"]
const MODELS=["inline_spinner","paddle_shad","diving_minnow"]
const POOLS={
 "lakeside":[0,2,6,9,34],
 "lake_pier":[0,2,6,9,10,11,17,34,35],
 "gray_pier":[0,2,6,11],
 "bell_park_pier":[0,2,9,10,11,17,34,35],
 "meadow_bend":[9,11,34,35],"boulder_run":[10,11,17],
 "simons_town_rocks":[18,21,23,24,28,31,37],
 "blouberg_sunrise_2":[18,23,24,28,31,37],
 "secluded_beach":[18,21,23,31,36],
 "fish_hoek_beach":[18,23,24,28,31,36,37]
}
const PREFERENCES={0:[0,9,10,11,17,23,24,31,34,35,36,37],1:[0,2,6,10,11,17,18,21,28,36,37],2:[2,6,9,10,11,23,24,28,34,35,36,37]}
var depth:=0.0
var action:=0.0
var pause_window:=0.0
var pause_action:=0.0
var previous_lift:=0.0
var sampled:=false
var sideways:=0.0
var previous_tip:=Vector3.ZERO
var tip_sampled:=false
const TWITCH_WAKE_SECONDS:=.4
var twitch_heading:=Vector3.ZERO
var twitch_wake:=0.0
func reset_motion()->void:
 tip_sampled=false
 sampled=false
 twitch_heading=Vector3.ZERO;twitch_wake=0.0
func sample_motion(tracked_tip:Vector3,facing:Basis,delta:float)->float:
 if not tracked_tip.is_finite():reset_motion();return 0.0
 var travel:=tracked_tip-previous_tip
 previous_tip=tracked_tip
 var valid:=tip_sampled and delta>0 and delta<=.1 and travel.length()<maxf(.6,delta*35.0)
 tip_sampled=true
 return travel.dot(facing.x)/delta if valid else 0.0
static func supported(id:String)->bool:return POOLS.has(id)
static func preferred(bait:int,id:String)->Array:
 var result:Array=[]
 for index in POOLS.get(id,[]):
  if index in PREFERENCES.get(bait,[]):result.append(index)
 return result
func reset()->void:
 depth=0;action=0;pause_window=0;pause_action=0;previous_lift=0;sideways=0;reset_motion()
func work(delta:float,reel:float,lift:float,bait:int,river:bool,side_speed:float=0.0)->float:
 twitch_wake=maxf(0,twitch_wake-delta)
 var rate:=clampf(reel,0,2)
 var twitch:=clampf(absf(lift-previous_lift)/maxf(delta,.001),0,1) if sampled else 0.0
 previous_lift=lift;sampled=true
 var lateral:=clampf((absf(side_speed)-.08)/.8,0,1)
 var moving:=rate>.03 or lateral>0
 if moving:pause_window=1.4
 else:pause_window=maxf(0,pause_window-delta)
 var target_depth:float=([.55,1.8,.8][bait] if moving else [1.1,2.8,.35][bait])*(.5 if river else 1.0)
 depth=move_toward(depth,target_depth,delta*(.8 if bait==1 else .4))
 # No unattended lure bites. A jig or minnow can be hit briefly after a retrieve.
 if not moving:
  action=minf(pause_action,.8 if bait==1 else .45 if bait==2 else 0.0)*pause_window/1.4
 else:
  var ideal:float=[.75,.4,.6][bait]
  action=clampf(1.25-absf(rate-ideal)*.8,.25,1.25)
  if rate<=.03:action=0.0
  action=minf(1.5,action+lateral*1.1+(twitch*.25 if bait in [1,2] else 0.0))
  pause_action=action
 return action
func move_sideways(at:Vector3,anchor:Vector3,side_speed:float,delta:float)->Vector3:
 var outward:=at-anchor;outward.y=0
 if outward.length_squared()<.001:return at
 # The line settles after each twitch so a previous pull cannot permanently
 # pin the tackle at the lateral limit. Wrist rotation also works the lure.
 var next:=clampf(sideways+clampf(side_speed,-8,8)*delta*1.5,-.9,.9) if absf(side_speed)>.08 else move_toward(sideways,0,delta*.45)
 var side:=outward.normalized().cross(Vector3.UP)
 if absf(side_speed)>.08:
  # Preserve the signed, world-space twitch independently of the subsequent
  # settling motion; a settling line must not show a new opposite twitch.
  twitch_heading=side*signf(side_speed);twitch_wake=TWITCH_WAKE_SECONDS
 var moved:=at+side*(next-sideways)
 sideways=next
 return moved
