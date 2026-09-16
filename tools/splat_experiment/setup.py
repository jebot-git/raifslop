"""Prepare the isolated viewer; fetch the pinned MIT GDGS addon if absent."""
import io
import json
import shutil
import tarfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'test-results/splat-experiment'
VIEWER = OUT / 'viewer'
VIEWER.mkdir(parents=True, exist_ok=True)
(OUT / '.gdignore').touch()
GDGS_REVISION = 'c22024b33a24e06d8629c654825fabd0485b2dba'
if not (VIEWER / 'addons/gdgs/plugin.cfg').exists():
    url = f'https://github.com/ReconWorldLab/godot-gaussian-splatting/archive/{GDGS_REVISION}.tar.gz'
    with urllib.request.urlopen(url, timeout=60) as response:
        archive = response.read()
    with tarfile.open(fileobj=io.BytesIO(archive), mode='r:gz') as package:
        package.extractall(OUT / 'vendor', filter='data')
    source = OUT / 'vendor' / ('godot-gaussian-splatting-' + GDGS_REVISION) / 'addons/gdgs'
    shutil.copytree(source, VIEWER / 'addons/gdgs')
if not (VIEWER/'addons/godot_ai/plugin.cfg').exists():
    shutil.copytree(ROOT / 'addons/godot_ai', VIEWER / 'addons/godot_ai')
(OUT / 'renderer_source.json').write_text(json.dumps({
    'url': 'https://github.com/ReconWorldLab/godot-gaussian-splatting',
    'revision': GDGS_REVISION, 'license': 'MIT'}, indent=2) + '\n')
shutil.copyfile(Path(__file__).with_name('viewer.gd'), VIEWER / 'viewer.gd')
for name in ['hybrid.gd', 'panosphere.gdshader', 'lake_background.gdshaderinc', 'hybrid_bank.gdshader', 'shore_reeds.gdshader', 'lake_water.gdshader']:
    shutil.copyfile(Path(__file__).with_name(name), VIEWER/name)
for name in ['assets/models/locations/lit/gray_pier.glb',
             'assets/models/locations/lit/gray_pier.glb.import']:
    target = VIEWER/name
    target.parent.mkdir(parents=True,exist_ok=True)
    if not target.exists(): shutil.copyfile(ROOT/name,target)
shutil.copyfile(OUT/'gray_pier_pano.png', VIEWER/'gray_pier_pano.png')
manifest = json.loads((ROOT/'assets/models/locations/manifest.json').read_text())['gray_pier']
(VIEWER/'gray_pier_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(VIEWER/'hybrid.tscn').write_text('''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://hybrid.gd" id="1"]
[node name="HybridEnvironment" type="Node3D"]
script = ExtResource("1")
''')
for name in ['scripts/shore_details.gd', 'scripts/simons_rear_details.gd',
             'assets/environment/rivers/vegetation.gdshader',
             'assets/environment/shore_details/ground_cover.gdshader',
             'assets/environment/shore_details/lakeshore_reeds.png',
             'assets/environment/rivers/river_bank.png',
             'assets/environment/baked_foreground.gdshader',
             'assets/environment/harbour_ground.gdshader',
             'assets/textures/lighting/gray_pier_irradiance.exr',
             'assets/textures/lighting/gray_pier_sky.exr',
             'assets/textures/lighting/gray_pier_ao.png',
             'assets/environment/water.gdshader', 'shaders/panorama_sampling.gdshaderinc',
             'assets/environment/locations/gray_pier_8k.hdr']:
    target = VIEWER / name
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists():
        shutil.copyfile(ROOT / name, target)
(VIEWER / 'main.tscn').write_text('''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://viewer.gd" id="1"]
[node name="SplatExperiment" type="Node3D"]
script = ExtResource("1")
''')
(VIEWER / 'project.godot').write_text('''config_version=5
[application]
config/name="Gray Pier Gaussian Splat Experiment"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.7", "Mobile")
[autoload]
_mcp_game_helper="*res://addons/godot_ai/runtime/game_helper.gd"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/vsync/vsync_mode=0
[rendering]
renderer/rendering_method="mobile"
[gdgs]
rendering/backend="Raster"
[editor_plugins]
enabled=PackedStringArray("res://addons/gdgs/plugin.cfg", "res://addons/godot_ai/plugin.cfg")
''')
print(VIEWER)
