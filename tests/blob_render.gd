extends SceneTree
func _initialize():run.call_deferred()
func frame() -> Image:
 for i in range(8):await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func run():
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 await create_timer(.4).timeout;g.set_process(false);g.motor.set_physics_process(false);g.hud.hide();g.avatar.hide();g.rod.hide();g.fish_guide.hide()
 var target:=Node3D.new();g.add_child(target);target.add_to_group("fishing_avatar_rigs");target.position=Vector3(0,0,1)
 g.head.global_position=Vector3(0,2,1);g.head.look_at(Vector3(0,0,1),Vector3.FORWARD)
 for i in range(5):await physics_frame
 var with_blob=await frame()
 g.shadow_policy.set_physics_process(false)
 for blob in g.shadow_policy.blobs.values():blob.hide()
 var without_blob=await frame();var darker:=0
 for y in range(250,650,2):
  for x in range(450,990,2):
   var a=with_blob.get_pixel(x,y);var b=without_blob.get_pixel(x,y)
   if b.r+b.g+b.b-a.r-a.g-a.b>.025:darker+=1
 with_blob.save_png("res://docs/blob_contact.png")
 print("BLOB_RENDER darker sampled pixels: ",darker)
 g.queue_free();await process_frame;quit(0 if darker>200 else 1)
