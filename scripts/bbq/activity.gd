extends Node3D
## Shared-world BBQ presentation and forgiving VR/desktop interaction.
const Sites=preload("res://scripts/bbq/sites.gd")
const Icons=preload("res://scripts/ui/pictograms.gd")
const UI_LAYER=preload("res://scripts/guide_camera.gd").UI_LAYER
const FOOD_ICONS={"fish_burger":"burger","sausage":"eat","corn":"eat","mushroom":"eat"}
const FOOD_SIZE=preload("res://scripts/fish_size.gd")
const Tongs=preload("res://scripts/bbq/tongs.gd")
const Model=preload("res://scripts/bbq/model.gd")
var desktop_right:=Node3D.new()
var g:Node3D
var service:Node
var location:=""
var station:Node3D
var deck:Node3D
var item_nodes:Dictionary={}
var food_materials:Dictionary={}
var food_bounds:Dictionary={}
var grip_down:=[false,false]
var trigger_down:=[false,false]
var hint:Node3D
var hint_icons:Array[Sprite3D]=[]
var cooler_icon:Sprite3D
var status:Label
var visit_button:Button
var return_button:Button
var return_at:=Vector3.ZERO
var return_safe:=Vector3.ZERO
var return_location:=""
var visiting:=false
var transitioning:=false
var return_yaw:=0.0
var fade_mesh:MeshInstance3D
var fade_material:StandardMaterial3D
var shade:ColorRect
var sound:AudioStreamPlayer3D
var cooler_lid:Node3D
var open_sound:AudioStreamPlayer3D
var opened_cans:Dictionary={}
var smoke:GPUParticles3D
var hovered:=-1
var splash_age:=0.0

func setup(root:Node3D) -> void:
 g=root;service=g.network.bbq
 name="ShoreBBQ"
 add_child(desktop_right)
 service.updated.connect(refresh)
 _build_menu()
 var layer:=CanvasLayer.new();layer.layer=110;add_child(layer)
 shade=ColorRect.new();shade.color=Color(0,0,0,0);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
 layer.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 fade_mesh=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(4,4);fade_mesh.mesh=quad;fade_mesh.layers=UI_LAYER
 fade_material=StandardMaterial3D.new();fade_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;fade_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;fade_material.no_depth_test=true;fade_material.albedo_color=Color(0,0,0,0);fade_material.render_priority=127
 fade_mesh.material_override=fade_material;fade_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;g.head.add_child(fade_mesh);fade_mesh.position=Vector3(0,0,-.11);fade_mesh.visible=false
 select_location()

func _build_menu() -> void:
 var page:=VBoxContainer.new();page.add_theme_constant_override("separation",18)
 g.avatar_menu._register_page("bbq","BBQ",page)
 var symbols:=HBoxContainer.new();symbols.alignment=BoxContainer.ALIGNMENT_CENTER;symbols.add_theme_constant_override("separation",16);page.add_child(symbols)
 for key in ["grip","tongs","bbq","flip","serve","eat","drink"]:
  var symbol:=TextureRect.new();symbol.texture=Icons.texture(key);symbol.custom_minimum_size=Vector2(64,64);symbol.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;symbol.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;symbols.add_child(symbol)
 visit_button=Button.new();visit_button.text="Start BBQ & visit";visit_button.custom_minimum_size.y=54;page.add_child(visit_button);visit_button.pressed.connect(visit)
 return_button=Button.new();return_button.text="Return to fishing spot";return_button.custom_minimum_size.y=54;page.add_child(return_button);return_button.pressed.connect(return_to_water)
 status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;page.add_child(status)
 var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",12);page.add_child(actions);page.move_child(actions,1)
 visit_button.reparent(actions);return_button.reparent(actions);visit_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;return_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 page.move_child(status,2)
 g.avatar_menu.show_page(g.avatar_menu.active_page)

func holds(hand:int) -> bool:
 return is_instance_valid(service) and service.model.held(g.current_location,service.local_id(),hand)>=0

func select_location() -> void:
 if location==g.current_location:return
 release_all()
 visiting=false;return_location="";location=g.current_location
 if is_instance_valid(station):station.free()
 if is_instance_valid(deck):deck.free()
 station=null;deck=null;item_nodes.clear();food_materials.clear()
 # The boat's crowded deck gets a supported mooring-side picnic platform.
 if location=="bell_park_pier":_build_deck()
 refresh()

func _build_deck() -> void:
 deck=Node3D.new();deck.name="MooringPicnicDeck";add_child(deck)
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color("b7b4a7");mat.roughness=.95
 mat.albedo_texture=load("res://assets/models/locations/lit/bell_park_pier_weathered_timber_Diffuse.jpg");mat.uv1_triplanar=true;mat.uv1_scale=Vector3.ONE*.8
 _solid(deck,Vector3(3.4,-.14,8.2),Vector3(4.4,.28,4.3),mat,"floor")
 for x in [1.3,5.5]:
  for z in [6.2,10.2]:_solid(deck,Vector3(x,-.8,z),Vector3(.18,1.6,.18),mat,"prop")
 for x in [1.2,5.6]:
  _solid(deck,Vector3(x,.48,8.2),Vector3(.06,.06,4.3),mat,"barrier")
  for z in [6.1,8.2,10.3]:_solid(deck,Vector3(x,.25,z),Vector3(.085,.6,.085),mat,"barrier")
 for z in [6.05,10.35]:
  _solid(deck,Vector3(3.4,.48,z),Vector3(4.4,.06,.06),mat,"barrier")
 # Existing dock lies immediately alongside. Access is via the explicit fade transition.

func _solid(parent:Node3D,at:Vector3,size:Vector3,mat:Material,role:String) -> void:
 var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=size;mesh.mesh=box;mesh.material_override=mat;mesh.position=at;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(mesh)
 var body:=StaticBody3D.new();body.set_meta("role",role);body.collision_layer=16 if role=="prop" else 1;mesh.add_child(body)
 var shape:=CollisionShape3D.new();var bounds:=BoxShape3D.new();bounds.size=size;shape.shape=bounds;body.add_child(shape)

func _build_station() -> void:
 station=Node3D.new();station.name="BBQStation";add_child(station);station.transform=Sites.pose(location)
 var kit:Node3D=load("res://assets/models/bbq/station.glb").instantiate();station.add_child(kit)
 for node in kit.find_children("*","MeshInstance3D",true,false):node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 # BBQ collision is separate from shore/landing rays (layer 16).
 var body:=StaticBody3D.new();body.collision_layer=16;station.add_child(body)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(1.85,.88,.52);shape.shape=box;shape.position=Vector3(0,.44,0);body.add_child(shape)
 g.motor.collision_mask|=16
 hint=Node3D.new();station.add_child(hint);hint.position=Vector3(0,1.18,.31);hint_icons.clear()
 for x in [-.065,.065]:
  var icon:=_icon(hint,"tongs",Vector3(x,0,0));hint_icons.append(icon)
 cooler_icon=_icon(station,"cooler",Sites.COOLER_HANDLE+Vector3(0,.15,0))
 var cooler:Node3D=load("res://assets/models/bbq/cooler.glb").instantiate();station.add_child(cooler);cooler.position=Sites.COOLER_POSITION
 cooler_lid=Node3D.new();station.add_child(cooler_lid);cooler_lid.position=Sites.COOLER_POSITION+Vector3(0,.37,-.17)
 var lid:Node3D=load("res://assets/models/bbq/cooler_lid.glb").instantiate();cooler_lid.add_child(lid);lid.rotation.y=PI
 open_sound=AudioStreamPlayer3D.new();open_sound.stream=load("res://assets/audio/bbq/can_open.wav");open_sound.max_distance=6;open_sound.volume_db=-14;station.add_child(open_sound)
 opened_cans.clear()
 for item in service.model.stations[location].items:
  var node:=Node3D.new()
  var asset:Node3D=Tongs.new() if item.kind=="tongs" else load("res://assets/models/bbq/"+("beer_can" if item.kind=="drink" else item.kind)+".glb").instantiate()
  node.add_child(asset);node.name="BBQItem_"+str(item.id);station.add_child(node);item_nodes[item.id]=node
  var mats:Array=[]
  for mesh in node.find_children("*","MeshInstance3D",true,false):
   mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   if item.kind in Model.FOODS:
    for i in mesh.mesh.get_surface_count():
     var source:Material=mesh.get_active_material(i)
     if source is StandardMaterial3D:
      var copy:=ShaderMaterial.new();copy.shader=preload("res://shaders/bbq_food.gdshader")
      copy.set_shader_parameter("food_color",source.albedo_color);copy.set_shader_parameter("food_roughness",source.roughness)
      copy.set_shader_parameter("use_vertex_color",source.vertex_color_use_as_albedo)
      if source.albedo_texture:copy.set_shader_parameter("food_texture",source.albedo_texture);copy.set_shader_parameter("use_texture",true)
      if source.normal_enabled and source.normal_texture:
       copy.set_shader_parameter("detail_normal",source.normal_texture);copy.set_shader_parameter("normal_strength",source.normal_scale);copy.set_shader_parameter("use_normal_texture",true)
      if source.roughness_texture:
       copy.set_shader_parameter("detail_roughness",source.roughness_texture);copy.set_shader_parameter("use_roughness_texture",true)
       var channels:=[Vector4(1,0,0,0),Vector4(0,1,0,0),Vector4(0,0,1,0),Vector4(0,0,0,1),Vector4(1.0/3,1.0/3,1.0/3,0)]
       copy.set_shader_parameter("roughness_channel",channels[source.roughness_texture_channel])
      mesh.set_surface_override_material(i,copy);mats.append(copy)
  food_materials[item.id]=mats
  if item.kind in Model.FOODS:
   var bounds:AABB=FOOD_SIZE.bounds(asset)
   var factor:float=minf(1.0,.175/maxf(bounds.size.x,bounds.size.z))
   asset.scale*=factor
   food_bounds[item.id]=AABB(bounds.position*factor,bounds.size*factor)
 sound=AudioStreamPlayer3D.new();sound.stream=load("res://assets/audio/bbq/grill_sizzle.wav").duplicate();sound.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;sound.stream.loop_end=int(sound.stream.get_length()*sound.stream.mix_rate);sound.volume_db=-28;sound.max_distance=8;sound.unit_size=1;station.add_child(sound);sound.position=Vector3(0,1,0)
 smoke=GPUParticles3D.new();smoke.amount=12;smoke.lifetime=2.5;smoke.visibility_aabb=AABB(Vector3(-1,0,-1),Vector3(2,3,2));smoke.position=Vector3(0,1,0)
 var pm:=ParticleProcessMaterial.new();pm.direction=Vector3.UP;pm.spread=20;pm.initial_velocity_min=.1;pm.initial_velocity_max=.2;pm.gravity=Vector3(.035,.04,0);pm.scale_min=.06;pm.scale_max=.14
 var gradient:=Gradient.new();gradient.set_color(0,Color(.55,.52,.46,.08));gradient.set_color(1,Color(.55,.52,.46,0));var ramp:=GradientTexture1D.new();ramp.gradient=gradient;pm.color_ramp=ramp;smoke.process_material=pm
 var mesh:=SphereMesh.new();mesh.radial_segments=6;mesh.rings=3
 var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.vertex_color_use_as_albedo=true;mesh.material=mat;smoke.draw_pass_1=mesh;smoke.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;station.add_child(smoke)

func _icon(parent:Node3D,key:String,at:Vector3) -> Sprite3D:
 var icon:=Sprite3D.new();icon.texture=Icons.texture(key);icon.position=at;icon.pixel_size=.0008
 icon.billboard=BaseMaterial3D.BILLBOARD_ENABLED;icon.no_depth_test=false;icon.layers=UI_LAYER;parent.add_child(icon)
 return icon

func prompt(target:int) -> Array:
 var held_id:int=service.model.held(location,service.local_id(),1)
 if held_id<0:held_id=service.model.held(location,service.local_id(),0)
 var items:Array=service.model.stations[location].items
 if held_id>=0:
  var item:Dictionary=items[held_id]
  if item.kind=="drink":return ["trigger","drink" if item.open else "open_can"]
  if item.kind in Model.FOODS:return ["trigger","eat"]
  if target>=0 and items[target].kind in Model.FOODS:
   var food:Dictionary=items[target]
   return ["tongs",("flip" if food.side==0 else "serve") if food.place=="grill" else "bbq"]
  return ["tongs","bbq"]
 if target>=0:
  var item:Dictionary=items[target]
  if item.place=="grill":return ["tongs","warning" if maxf(item.cook[0],item.cook[1])>=1.85 else "ready" if minf(item.cook[0],item.cook[1])>=.85 else "bbq"]
  return ["grip",FOOD_ICONS.get(item.kind,"drink" if item.kind=="drink" else "tongs")]
 return ["grip","tongs"]

func refresh() -> void:
 if location!=g.current_location:return
 var active:bool=service.model.stations.has(location)
 if active and not is_instance_valid(station):_build_station()
 if not active and is_instance_valid(station):station.free();station=null;item_nodes.clear();food_materials.clear()
 visit_button.text="Visit shared BBQ" if active else "Start BBQ & visit"
 return_button.disabled=not visiting or transitioning
 status.text="A shared BBQ is running here. Come and go whenever you like." if active else "Start a gathering at this water. Anyone can join."

func visit() -> void:
 if transitioning:return
 if g.game.state!=g.Session.State.READY:
  status.text="Finish your cast and release the catch before visiting.";return
 if not visiting:
  return_at=g.motor.global_position;return_safe=g.motor.safe_spawn;return_location=location
  return_yaw=atan2(g.head.global_basis.z.x,g.head.global_basis.z.z)
 visiting=true
 g.fish_guide.dock();g.shoulder_radio.reset();g.rod_holster.set_stowed(true)
 service.request("start")
 var seat:int=(service.local_id()-1)%8
 _move(Sites.arrival(location,seat))

func return_to_water() -> void:
 if transitioning or not visiting:return
 release_all();visiting=false
 _move(return_at if return_location==location else g.foreground.get_meta("spawn",Vector3(0,.02,.65)),true)

func _move(destination:Vector3,returning:=false) -> void:
 transitioning=true
 if g.menu_open:g._toggle_avatar_menu()
 g.motor.blocked=true
 var move_location:=location
 var tween:=create_tween();tween.tween_property(shade,"color:a",1.0,.16)
 await tween.finished
 if not is_inside_tree():return
 if move_location!=g.current_location:
  transitioning=false;shade.color.a=0;g.motor.blocked=g.menu_open;return
 g.motor.relocate(destination)
 var yaw:float=return_yaw if returning else atan2(Sites.pose(location).basis.z.x,Sites.pose(location).basis.z.z)
 g.motor.turn(yaw-atan2(g.head.global_basis.z.x,g.head.global_basis.z.z))
 if returning:g.motor.safe_spawn=return_safe
 var fade:=create_tween();fade.tween_property(shade,"color:a",0.0,.2)
 await fade.finished
 transitioning=false;g.motor.blocked=g.menu_open;refresh()

func release_all() -> void:
 if is_instance_valid(service):service.request("release")
 grip_down=[true,true];trigger_down=[true,true]

func hand_pose(hand:int,peer:=-1) -> Transform3D:
 if peer<0 or peer==service.local_id():
  if g.xr:return g.controller_pose(hand)
  return g.head.global_transform*Transform3D(Basis.IDENTITY,Vector3(-.23 if hand==0 else .23,-.30,-.55))
 var who:Dictionary=service.actor(peer)
 if who.is_empty():return Transform3D.IDENTITY
 if not who.xr:return who.head*Transform3D(Basis.IDENTITY,Vector3(-.23 if hand==0 else .23,-.30,-.55))
 return who.left if hand==0 else who.right

func nearest(at:Vector3,radius:float,food_only:=false) -> int:
 var result:=-1;var distance:=radius
 if not service.model.stations.has(location):return result
 for item in service.model.stations[location].items:
  if item.owner!=0 or item.place=="gone" or (item.kind=="drink" and not service.model.stations[location].cooler_open) or (food_only and item.kind not in Model.FOODS):continue
  var d:float=item_nodes[item.id].global_position.distance_to(at)
  if d<distance:distance=d;result=item.id
 return result

func aimed(food_only:=false) -> int:
 if not is_instance_valid(station):return -1
 var mouse:Vector2=get_viewport().get_mouse_position()
 var ray:Vector3=g.head.project_ray_origin(mouse);var axis:Vector3=g.head.project_ray_normal(mouse)
 var best:=.18;var result:=-1
 for item in service.model.stations[location].items:
  if item.owner!=0 or item.place=="gone" or (item.kind=="drink" and not service.model.stations[location].cooler_open) or (food_only and item.kind not in Model.FOODS):continue
  var offset:Vector3=item_nodes[item.id].global_position-ray
  var along:float=offset.dot(axis)
  if along<0 or along>3.2:continue
  var d:float=(offset-axis*along).length()
  if d<best:best=d;result=item.id
 return result

func use(hand:int,target:int,cool:=false) -> void:
 var id:int=service.model.held(location,service.local_id(),hand)
 if id<0:return
 var item:Dictionary=service.model.stations[location].items[id]
 if item.kind=="tongs" and target>=0:
  service.request("cool" if cool else "cook",target,hand,station.to_local(hand_pose(hand).origin))
 elif item.kind=="drink":service.request("sip",id,hand)
 elif item.kind in Model.FOODS:service.request("eat",id,hand)

func handle_input(event:InputEvent) -> bool:
 if g.xr or g.menu_open or transitioning or g.fish_guide.held:return false
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_B:
  if visiting:return_to_water()
  else:visit()
  return true
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_H:visit();return true
 if not g.rod_holster.stowed or not is_instance_valid(station) or g.motor.global_position.distance_to(station.global_position)>5:return false
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_C:service.request("cooler");return true
 var id:int=service.model.held(location,service.local_id(),1)
 if event is InputEventMouseButton and event.pressed:
  if event.button_index==MOUSE_BUTTON_RIGHT:
   if id>=0:service.request("drop",id,1)
   return true
  if event.button_index==MOUSE_BUTTON_LEFT:
   var target:=aimed(id in [6,7])
   if id<0 and target>=0:service.request("grab",target,1)
   else:use(1,target)
   return true
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F:use(1,aimed(true),true);return true
 return false

func _process(_delta:float) -> void:
 if not is_instance_valid(g):return
 desktop_right.global_transform=hand_pose(1)
 fade_mesh.visible=g.xr and shade.color.a>.001;fade_material.albedo_color=shade.color
 if location!=g.current_location:select_location()
 if not is_instance_valid(station):return
 var state:Dictionary=service.model.stations.get(location,{})
 if state.is_empty():return
 cooler_lid.rotation.x=move_toward(cooler_lid.rotation.x,-1.75 if state.cooler_open else 0.0,_delta*3.5)
 var cooking:=false
 for item in state.items:
  var node:Node3D=item_nodes[item.id];node.visible=item.place!="gone" and (item.kind!="drink" or item.owner!=0 or state.cooler_open)
  if item.owner!=0:
   node.global_transform=hand_pose(item.hand,item.owner)
   if item.kind=="drink":node.rotate_object_local(Vector3.RIGHT,PI/2)
  else:node.transform=Transform3D(Basis.IDENTITY,item.pos)
  if item.kind=="tongs":
   var tool:Node3D=node.get_child(0);tool.held_hand=item.hand if item.owner!=0 else -1
   tool.squeezed=item.owner==service.local_id() and g.xr and (g.left if item.hand==0 else g.right).get_float("trigger")>.55
   tool.animate_jaws(_delta)
  if item.kind=="drink":
   if item.open and not opened_cans.get(item.id,false):open_sound.global_position=node.global_position;open_sound.play()
   opened_cans[item.id]=item.open
  if item.kind in Model.FOODS:
   var food:Node3D=node.get_child(0)
   var target_angle:float=PI if item.side==1 else 0.0
   food.rotation.z=move_toward(food.rotation.z,target_angle,_delta*10)
   var bounds:AABB=food_bounds[item.id]
   food.position.y=lerpf(-bounds.position.y-.041,bounds.end.y-.041,(1-cos(food.rotation.z))*.5)+sin(food.rotation.z)*.065
   for material in food_materials[item.id]:
    material.set_shader_parameter("cook_bottom",item.cook[0]);material.set_shader_parameter("cook_top",item.cook[1]);material.set_shader_parameter("world_to_food",food.global_transform.affine_inverse())
   if item.place=="grill":cooking=true
 if cooking and not sound.playing:sound.play()
 elif not cooking and sound.playing:sound.stop()
 smoke.emitting=cooking
 var allowed:bool=not g.menu_open and not transitioning and g.rod_holster.stowed and not g.fish_guide.held and not g.shoulder_radio.held and (not g.xr or g.tracking_manager.focused)
 if not allowed:
  if holds(0) or holds(1):release_all()
  grip_down=[true,true];trigger_down=[true,true];hint.visible=false;cooler_icon.visible=false;return
 hovered=aimed() if not g.xr else -1
 if g.xr:
  for hand in 2:
   var controller:XRController3D=g.left if hand==0 else g.right
   var id:int=service.model.held(location,service.local_id(),hand)
   if not controller.get_has_tracking_data():
    if id>=0:service.request("drop",id,hand)
    grip_down[hand]=true;trigger_down[hand]=true;continue
   var grip:bool=controller.get_float("grip")>(.35 if grip_down[hand] else .55)
   var trigger:bool=controller.get_float("trigger")>.55 or controller.is_button_pressed("trigger_click")
   var hand_transform:=hand_pose(hand)
   var at:Vector3=hand_transform.origin-hand_transform.basis.z*(.22 if id in [6,7] else 0)
   var target:=nearest(at,.25 if id in [6,7] else .19,id in [6,7])
   if target>=0:hovered=target
   if grip and not grip_down[hand] and id<0 and target>=0:service.request("grab",target,hand)
   if not grip and grip_down[hand] and id>=0:service.request("drop",id,hand)
   if trigger and not trigger_down[hand]:
    if id>=0:use(hand,target)
    elif controller.global_position.distance_to(station.to_global(Sites.COOLER_HANDLE))<.3:service.request("cooler",-1,hand)
   grip_down[hand]=grip;trigger_down[hand]=trigger
 var nearby:bool=g.head.global_position.distance_to(station.global_position)<3.5
 hint.visible=Icons.enabled and nearby;cooler_icon.visible=Icons.enabled and nearby
 if hint.visible:
  # Keep the pair ordered from the viewer's left to right at every shore anchor.
  hint.global_basis=Basis(Vector3.UP,atan2(g.head.global_position.x-hint.global_position.x,g.head.global_position.z-hint.global_position.z))
  var keys:=prompt(hovered)
  for i in 2:hint_icons[i].texture=Icons.texture(keys[i])
