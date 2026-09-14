extends RefCounted
const S=preload("res://scripts/fishing_session.gd")
var state := S.State.READY
var cue := -1
var running := false
var tension_peak := .35
var cooldown := 0.0
func sample(game, delta: float) -> Dictionary:
	cooldown=maxf(0,cooldown-delta)
	var event := {}
	if game.state != state:
		match game.state:
			S.State.BITE: event={"kind":"bite","strength":.8,"duration":.24}
			S.State.FIGHT: event={"kind":"hook","strength":.55,"duration":.18}
			S.State.LANDED: event={"kind":"landed","strength":.35,"duration":.25}
			S.State.LOST: event={"kind":"lost","strength":.7,"duration":.3}
		state=game.state;tension_peak=game.tension
	if game.state==S.State.FIGHT:
		if game.cue>=0 and game.cue!=cue and event.is_empty(): event={"kind":"fight","strength":.5,"duration":.16}
		if game.is_running() and not running and event.is_empty(): event={"kind":"run","strength":.65,"duration":.2}
		if game.tension<tension_peak-.06: tension_peak=game.tension
		if cooldown<=0 and event.is_empty() and (game.tension>=tension_peak+.08 or game.tension>=.82):
			event={"kind":"tension","strength":lerpf(.18,.75,game.tension),"duration":.08 if game.tension<.82 else .14}
			tension_peak=game.tension
	if not event.is_empty(): cooldown=.65
	cue=game.cue;running=game.is_running()
	return event
