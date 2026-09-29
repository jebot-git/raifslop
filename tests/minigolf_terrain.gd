extends SceneTree
const Ball=preload("res://scripts/minigolf/ball.gd")
const Catalog=preload("res://scripts/minigolf/catalog.gd")
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:
	for id in Catalog.ALL:
		var designs:={}
		var raised:=0;var recessed:=0
		for hole in Catalog.course(id).holes:
			designs[hole.design]=true
			var ball:=Ball.new();ball.reset(hole)
			var low:=0.0;var high:=0.0
			for x in range(-2,3):
				for z in range(1,20):
					var p:=Vector2(x*float(hole.width)/5,-z*float(hole.length)/20)
					var y:=ball.height(p);low=minf(low,y);high=maxf(high,y)
					var epsilon:=.002
					var numerical:=Vector2(ball.height(p+Vector2(epsilon,0))-ball.height(p-Vector2(epsilon,0)),ball.height(p+Vector2(0,epsilon))-ball.height(p-Vector2(0,epsilon)))/(2*epsilon)
					check(numerical.distance_to(ball.gradient(p))<.002,"Surface/force agreement: "+id+" "+str(hole.number))
			if high>.2:raised+=1
			if low<-.2:recessed+=1
			check(low>-.7 and high<.8,"Terrain stays within deck construction bounds")
			check(ball.gradient(Catalog.point(hole.tee)).length()<.01,"Tee is level")
			check(ball.gradient(Catalog.point(hole.cup)).length()<.01,"Cup has a level landing")
		check(designs.size()==18,"18 distinct shot puzzles per water")
		check(raised>=8 and recessed>=1,"Every water includes elevated and recessed play")
	var h:={"width":4,"length":12,"tee":[0,-2.8],"cup":[1,-11],"obstacles":[],"hazards":[],"bumps":[],"ramps":[{"start":3.0,"end":5.0,"height":.5}]}
	var soft:=Ball.new();soft.reset(h);soft.strike(Vector2(0,-.8))
	var firm:=Ball.new();firm.reset(h);firm.strike(Vector2(0,-4))
	var soft_top:=0.0;var firm_top:=0.0
	for i in 3600:
		soft.tick(1.0/90);firm.tick(1.0/90)
		soft_top=maxf(soft_top,soft.height(soft.position));firm_top=maxf(firm_top,firm.height(firm.position))
	check(soft_top<.2 and firm_top>.49,"Crest distinguishes underhit and sufficient pace")
	check(not soft.moving and not firm.moving,"Sloped putts settle")
	print("MINIGOLF TERRAIN ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
