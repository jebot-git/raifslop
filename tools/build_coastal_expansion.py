"""Blender --background --python tools/build_coastal_expansion.py.

Build only the two additional shores; preserve all established source scenes.
"""
import json
import sys
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import build_foregrounds as fg

# Tileable photographed PBR maps; the existing scan atlas needs its original UVs.
fg.material('stone',(.52,.5,.46),'rock_boulder_dry')
for location in ['secluded_beach', 'fish_hoek_beach']:
    fg.build(location)
manifest = ROOT / 'assets/models/locations/manifest.json'
records = json.loads(manifest.read_text())
records.update(fg.RECORDS)
manifest.write_text(json.dumps(records, indent=2) + '\n')
bpy.data.libraries.write(str(ROOT / 'source/coastal_expansion.blend'),
                        set(fg.SCENES), path_remap='RELATIVE', fake_user=True, compress=True)
