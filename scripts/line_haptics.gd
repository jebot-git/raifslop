extends RefCounted
## Strong rod pulses mean the player's current response is working.
const S=preload("res://scripts/fishing_session.gd")
var state := S.State.READY
var cue := -1
var takeover_count := 0
var running := false
var submerge := S.Submerge.NONE
var tension_peak := .35
var cooldown := 0.0
var controlled := false
var reel_phase := 0.0
var reel_cooldown := 0.0
func sample(game, delta: float) -> Dictionary:
	cooldown=maxf(0,cooldown-delta)
	var event := {}
	if game.state != state:
		match game.state:
			S.State.BITE: event={"kind":"bite","strength":.35 if game.is_fly_fishing() else .8,"duration":.24}
			S.State.FIGHT: event={"kind":"hook","strength":.35,"duration":.12}
			S.State.LANDED: event={"kind":"landed","strength":.35,"duration":.25}
			S.State.LOST: event={"kind":"lost","strength":.7,"duration":.3}
		state=game.state;tension_peak=game.tension
	if game.takeover_count!=takeover_count:
		if game.state==S.State.FIGHT:event={"kind":"predator","strength":.45,"duration":.2}
		takeover_count=game.takeover_count
	var effective: bool=game.effective_counter()
	if event.is_empty() and controlled and not effective:
		event={"kind":"release","strength":0.0,"duration":.01}
	if game.state==S.State.FIGHT and event.is_empty():
		if effective:
			if not controlled or cooldown<=0:
				event={"kind":"counter","strength":lerpf(.78,1.0,1.0-game.resistance),"duration":.075}
		elif game.submerge!=submerge and game.submerge!=S.Submerge.NONE:
			event={"kind":"submerge","strength":.12,"duration":.07}
		elif game.cue>=0 and game.cue!=cue:
			event={"kind":"fight","strength":.10,"duration":.06}
		elif game.is_running() and not running:
			event={"kind":"run","strength":.12,"duration":.07}
		elif game.cue<0 and not game.is_running() and game.submerge==S.Submerge.NONE:
			if game.tension<tension_peak-.06: tension_peak=game.tension
			if cooldown<=0 and (game.tension>=tension_peak+.08 or game.tension>=.60):
				event={"kind":"tension","strength":lerpf(.15,.35,clampf((game.tension-.50)/.50,0,1)),"duration":.07}
				tension_peak=game.tension
	if not event.is_empty(): cooldown=.07 if event.kind=="counter" else .45
	cue=game.cue;running=game.is_running();submerge=game.submerge
	controlled=effective and (event.is_empty() or event.get("kind")=="counter")
	return event

func sample_reel(game, rate: float, delta: float) -> Dictionary:
	reel_cooldown=maxf(0.0,reel_cooldown-delta)
	if (game.state!=S.State.FIGHT and not (game.is_fly_fishing() and game.state==S.State.WAITING)) or rate<=.03:
		reel_phase=0.0;reel_cooldown=0.0
		return {}
	# Twelve detents per accepted crank turn, with bounded pulse frequency.
	reel_phase+=clampf(rate,0.0,2.0)*maxf(delta,0.0)*12.0
	if reel_phase<1.0 or reel_cooldown>0.0: return {}
	reel_phase=fmod(reel_phase,1.0);reel_cooldown=.04
	return {"kind":"reel","strength":lerpf(.12,.32,clampf(game.tension,0,1)),"duration":.025}

func pause() -> void:
	controlled=false;cooldown=0.0;reel_phase=0.0;reel_cooldown=0.0
