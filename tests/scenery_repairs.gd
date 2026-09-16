extends SceneTree
const Shore=preload("res://scripts/shore.gd")
var failures:Array=[]
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
 for id in ["simons_town_rocks","lake_pier","gray_pier","lakeside","secluded_beach"]:
  var source=load("res://assets/models/locations/lit/"+id+".glb").instantiate()
  var n:MeshInstance3D=source.find_child(id+"_BakedForeground",true,false)
  var original:ArrayMesh=n.mesh
  Shore.repair_bench_supports(source,id)
  var changed:=0;var preserved:=true
  for surface in original.get_surface_count():
   var a:Array=original.surface_get_arrays(surface);var b:Array=n.mesh.surface_get_arrays(surface)
   preserved=preserved and a[Mesh.ARRAY_TEX_UV]==b[Mesh.ARRAY_TEX_UV] and a[Mesh.ARRAY_TEX_UV2]==b[Mesh.ARRAY_TEX_UV2] and a[Mesh.ARRAY_INDEX]==b[Mesh.ARRAY_INDEX]
   for i in a[Mesh.ARRAY_VERTEX].size():
    var shift:Vector3=b[Mesh.ARRAY_VERTEX][i]-a[Mesh.ARRAY_VERTEX][i]
    if shift.length()>.001:
     changed+=1;preserved=preserved and shift.is_equal_approx(Vector3(0,0,.11))
  check(changed>0 and preserved,"Only bench rear supports move backward; UVs/indices retained: "+id)
  var repaired=n.mesh;Shore.repair_bench_supports(source,id)
  check(n.mesh==repaired,"Bench repair is idempotent: "+id)
  if id=="simons_town_rocks":
   Shore.ground_pier_cleat(source,id)
   var feet:=0;var floating:=0
   for surface in n.mesh.get_surface_count():
    var mat:Material=n.mesh.surface_get_material(surface)
    if not mat.resource_name.begins_with("FG_steel"):continue
    for v in n.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
     if absf(v.x-3.5)<.091 and absf(v.z+2.5)<.051:
      if absf(v.y)<.001:feet+=1
      if absf(v.y-.06)<.001:floating+=1
   check(feet>=4 and floating==0,"Coastal Rocks cleat reaches the ground")
  source.free()
 for name in ["coastal_dune_grass","coastal_wrack"]:
  var path:String="res://assets/environment/shore_details/"+name+".png"
  var image:Image=load(path).get_image()
  check(image!=null and image.has_mipmaps(),"Imported coastal texture contains actual mip levels: "+name)
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);await create_timer(.3).timeout
 g._select_location("fish_hoek_beach",false)
 var mesh=g.foreground.get_node_or_null("RearParallax")
 check(mesh!=null and mesh.get_meta("half_span_degrees")==86.0 and mesh.get_meta("depth_bands").back().y==23,"Hoek rear projection spans a wider, deep tiled mesh")
 check(mesh.mesh.get_faces().size()==120*8*5*6,"Hoek depth treatment uses continuous tessellated tiles")
 g.ambience.stop();await create_timer(.3).timeout;g.queue_free();await process_frame;await create_timer(.3).timeout
 quit(0 if failures.is_empty() else 1)
