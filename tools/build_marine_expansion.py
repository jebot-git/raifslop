"""Blender: build four coastal fish from generated references and reviewed landmarks.

Preserves the established fish libraries and stable runtime catalogue indices.
"""
import sys
import json
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import build_photographic_fish as fish

fish.REF = ROOT / 'source/fish_references/marine_expansion'
fish.TEX = ROOT / 'source/textures/fish/marine_expansion'
fish.TEX.mkdir(parents=True, exist_ok=True)
for name, data in json.loads((fish.REF / 'anatomy.json').read_text()).items():
    fish.build(name, data)
bpy.data.libraries.write(str(ROOT / 'source/marine_expansion.blend'),
                        set(fish.scenes), path_remap='RELATIVE', fake_user=True, compress=True)
print('MARINE_EXPANSION_COMPLETE', flush=True)
