"""Prepare two location prototypes in the existing isolated viewer."""
import json,shutil,struct,statistics
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/splat-experiment'
V=OUT/'viewer'
manifest=json.loads((ROOT/'assets/models/locations/manifest.json').read_text())
profiles={
 'lake_pier':{'name':'Lake Pier','water_y':-2.48,'water_rear':34.0,'roughness':.32,'ripples':.5,'color':'223e4d','near_radius':32.0},
 'simons_town_rocks':{'name':'Simons Rocks','water_y':-1.98,'water_rear':-2.15,'roughness':.26,'ripples':.9,'color':'17333c','near_radius':28.0}}
for id,c in profiles.items():
 c['manifest']=manifest[id]
 world=OUT/id/'world.json'
 if world.exists():
  meta=json.loads(world.read_text())['assets']['splats']['semantics_metadata']
  c['source_ground_offset']=meta['ground_plane_offset']
  c['source_metric_scale']=meta['metric_scale_factor']
  c['scale']=1.63/abs(meta['ground_plane_offset'])
 else:c['scale']=1.0
 raw=V/f'{id}_500k.ply'
 if raw.exists():
  samples=[]
  with raw.open('rb') as stream:
   while stream.readline().strip()!=b'end_header':pass
   for row in struct.iter_unpack('<14f',stream.read()):
    x,y,z=row[:3]
    if abs(x)<3 and 4<z<20 and y>0:samples.append(y)
  c['source_water_height']=statistics.median(samples)
  c['scale']=abs(c['water_y'])/c['source_water_height']
  c['scale_method']='central open-water median matched to authored water height'
 files=[f'assets/models/locations/lit/{id}.glb',f'assets/models/locations/lit/{id}.glb.import']
 files += [f'assets/textures/lighting/{id}_{suffix}' for suffix in ['irradiance.exr','sky.exr','ao.png']]
 for name in files:
  dest=V/name;dest.parent.mkdir(parents=True,exist_ok=True)
  if not dest.exists():shutil.copyfile(ROOT/name,dest)
 shutil.copyfile(OUT/id/f'{id}_pano.png',V/f'{id}_pano.png')
for name in ['openxr_action_map.tres','scripts/locomotion.gd','scripts/simons_rear_details.gd','assets/environment/shore_details/simons_granite.png']:
 dest=V/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/name,dest)
for name in ['fishing_plan_poster.svg','bridge_ground.gdshader','locations.gd','location_water.gdshader','location_ground.gdshader','panosphere.gdshader','lake_background.gdshaderinc']:
 shutil.copyfile(Path(__file__).with_name(name),V/name)
(V/'location_profiles.json').write_text(json.dumps(profiles,indent=2)+'\n')
(V/'locations.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://locations.gd" id="1"]\n[node name="LocationHybrid" type="Node3D"]\nscript = ExtResource("1")\n')
print('Prepared Lake Pier and Simons Rocks viewer assets')

project=V/'project.godot'
config=project.read_text()
if '[xr]' not in config:
 config+='\n[xr]\nopenxr/enabled=true\nshaders/enabled=true\n'
project.write_text(config)
