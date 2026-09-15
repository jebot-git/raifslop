"""Build the two trophy predators from retained generated references and reviewed landmarks."""
import sys,json,bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_photographic_fish as fish
fish.REF=ROOT/'source/fish_references/predators'
fish.TEX=ROOT/'source/textures/fish/predators'
fish.TEX.mkdir(parents=True,exist_ok=True)
for name,data in json.loads((fish.REF/'anatomy.json').read_text()).items():
 fish.build(name,data)
bpy.data.libraries.write(str(ROOT/'source/predator_fish.blend'),set(fish.scenes),path_remap='RELATIVE',fake_user=True,compress=True)
print('PREDATOR_FISH_COMPLETE',flush=True)
