extends RefCounted
## Connected photographic depth bands. Angular coordinates remain continuous;
## the first ground layer no longer drags buildings and rocks along a flat apron.
static func create(id:String, origin:Vector3, water:ShaderMaterial)->MeshInstance3D:
 var mesh:=MeshInstance3D.new();mesh.name="RearParallax"
 # Elevation (degrees), horizontal range (metres). Retain the low foreground,
 # then separate the first rear bank and its approach to the horizon.
 # Stop below the horizon: towers, masts and the sky must not bend across bands.
 var bands:Array[Vector2]=[Vector2(-25,5.8),Vector2(-15,9),Vector2(-9,12),Vector2(-5,13),Vector2(-2,14),Vector2(-.3,16)]
 # The quay is a vertical wall beyond the 12.2 m bridge, not a sloped bank.
 if id=="lake_pier":bands=[Vector2(-25,11.6),Vector2(-15,11.6),Vector2(-9,11.6),Vector2(-5,11.6),Vector2(-2,11.6),Vector2(-.3,11.6)]
 if id=="simons_town_rocks":bands=[Vector2(-25,7),Vector2(-15,11),Vector2(-9,13),Vector2(-5,15),Vector2(-2,18),Vector2(-.3,22)]
 if id=="fish_hoek_beach":bands=[Vector2(-25,8),Vector2(-15,12),Vector2(-9,16),Vector2(-5,19),Vector2(-2,21),Vector2(-.3,23)]
 var half_span:=86.0 if id=="fish_hoek_beach" else 78.0
 var left_span:=125.0 if id=="fish_hoek_beach" else half_span
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var columns:=120 if id=="fish_hoek_beach" else 80
 var rows:=8 if id=="fish_hoek_beach" else 6
 for band in bands.size()-1:
  for row in rows:
   for column in columns:
    for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
     var u:float=(column+corner.x)/columns
     var t:float=(row+corner.y)/rows
     var profile:Vector2=bands[band].lerp(bands[band+1],t)
     var azimuth:=deg_to_rad(lerpf(-left_span,half_span,u))
     var point:=origin+Vector3(sin(azimuth)*profile.y,tan(deg_to_rad(profile.x))*profile.y,cos(azimuth)*profile.y)
     st.set_normal(Vector3.FORWARD)
     st.set_uv(Vector2(u,(band+t)/(bands.size()-1)))
     st.add_vertex(point)
 mesh.mesh=st.commit()
 var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/environment/rear_parallax.gdshader")
 mat.set_shader_parameter("projection_origin",origin)
 mat.set_shader_parameter("left_shore_extension",id=="fish_hoek_beach")
 mat.set_shader_parameter("rear_harbour_basin",id=="lake_pier")
 for setting in ["panorama","sky_inverse","sky_energy","detail_strength","vibrance","shadow_lift"]:
  mat.set_shader_parameter(setting,water.get_shader_parameter(setting))
 mesh.material_override=mat
 mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 mesh.set_meta("depth_bands",bands)
 mesh.set_meta("half_span_degrees",half_span)
 mesh.set_meta("azimuth_range_degrees",Vector2(-left_span,half_span))
 return mesh
