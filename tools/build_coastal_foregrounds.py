"""Blender --background --python tools/build_coastal_foregrounds.py.
Build coastal additions without regenerating the established inland sources.
"""
import sys, json
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_foregrounds as fg
for location in ['simons_town_rocks','blouberg_sunrise_2']:
    fg.build(location)
manifest=ROOT/'assets/models/locations/manifest.json'
records=json.loads(manifest.read_text())
records.update(fg.RECORDS)
manifest.write_text(json.dumps(records,indent=2)+'\n')
bpy.data.libraries.write(str(ROOT/'source/coastal_foregrounds.blend'),set(fg.SCENES),path_remap='RELATIVE',fake_user=True,compress=True)
