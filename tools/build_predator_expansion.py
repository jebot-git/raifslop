"""Build original huchen and ragged-tooth shark from reviewed side references."""
import sys, json
from pathlib import Path
import bpy
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import build_photographic_fish as fish

def build_one(name):
    fish.REF = ROOT / 'source/fish_references/predator_expansion'
    fish.TEX = ROOT / 'source/textures/fish/predator_expansion'
    fish.TEX.mkdir(parents=True, exist_ok=True)
    fish.build(name, json.loads((fish.REF / 'anatomy.json').read_text())[name])

def save():
    scenes = {scene for scene in fish.scenes if scene.name.startswith(('Photographic_huchen', 'Photographic_raggedtooth_shark'))}
    bpy.data.libraries.write(str(ROOT / 'source/predator_expansion.blend'), scenes,
                             path_remap='RELATIVE', fake_user=True, compress=True)

if __name__ == '__main__':
    for name in ['huchen', 'raggedtooth_shark']:
        build_one(name)
    save()
