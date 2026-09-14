extends SceneTree
var g
var actors: Array=[]
func _initialize():run.call_deferred()
func median(values: Array) -> float:
 values.sort();return values[values.size()/2]
func full_body(node: Node):
 if node is MeshInstance3D:node.layers=1 if node.layers&4 else 0
 for child in node.get_children():full_body(child)
func run():
 g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 await create_timer(.5).timeout
 g.set_process(false);g.motor.set_physics_process(false);g.hud.hide();g.rod.hide();g.avatar.hide();g.fish_guide.hide()
 if not g.xr:DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 for i in range(4):
  var rig=preload("res://scripts/avatar_rig.gd").new();g.add_child(rig)
  var model=g.avatars.load_model(g.avatars.DEFAULTS[0]);rig.add_child(model);rig.configure(model);full_body(model)
  var head:=Camera3D.new();g.add_child(head);head.current=false
  var left:=Node3D.new();g.add_child(left);var right:=Node3D.new();g.add_child(right)
  actors.append({"rig":rig,"head":head,"left":left,"right":right})
 var camera: Camera3D=g.head
 if not g.xr:
  camera=Camera3D.new();g.add_child(camera);camera.current=true
 var rid=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(rid,true)
 var results: Array=[]
 for id in ["lakeside","gray_pier"]:
  g._select_location(id,false);g.hud.hide()
  if not g.xr:camera.global_position=Vector3(3.5,2.8,-2);camera.look_at(Vector3(0,.8,2.5))
  else:g.origin.position=Vector3(0,0,5);g.origin.rotation.y=0
  for i in range(actors.size()):
   var a=actors[i];var p:=Vector3(-.32 if i%2==0 else .32,0,1.0+floorf(i/2.)*1.3)
   a.head.global_position=p+Vector3.UP*1.65
   a.left.global_position=p+Vector3(-.25,1.15,-.35);a.right.global_position=p+Vector3(.25,1.2,-.4)
   a.rig.update_targets(a.head,a.left,a.right,0,Vector3.ZERO,.016)
  for mode in ["dynamic","blob","blob","dynamic"]:
   g.shadow_policy.set_mode(mode,false)
   for i in range(90):await process_frame
   var gpu: Array=[];var cpu: Array=[];var frame: Array=[];var draws: Array=[]
   var last=Time.get_ticks_usec()
   for i in range(120):
    await process_frame
    gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid));cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
    var now=Time.get_ticks_usec();frame.append((now-last)/1000.);last=now
    draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
   var row={"location":id,"mode":mode,"gpu_ms":median(gpu),"render_cpu_ms":median(cpu),"frame_ms":median(frame),"draw_calls":median(draws),"xr":g.xr,"visible_blobs":g.shadow_policy.blobs.values().filter(func(b):return b.visible).size()}
   results.append(row);print("SHADOW_SAMPLE ",JSON.stringify(row))
   if id=="lakeside" and not g.xr:
    await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://docs/shadow_"+mode+".png")
 var path="res://docs/shadow_benchmark"+("_xr" if g.xr else "")+".json"
 var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(results,"  "));file.close()
 print("SHADOW_BENCHMARK_COMPLETE ",path)
 g.queue_free();await process_frame;quit()
