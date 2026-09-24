"""Build two original fly-expansion fish with the established photographic pipeline."""
import sys,json,bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_photographic_fish as fish
fish.scenes=[]
fish.REF=ROOT/'source/fish_references/fly_expansion'
fish.TEX=ROOT/'source/textures/fish/fly_expansion'
fish.TEX.mkdir(parents=True,exist_ok=True)
for name,data in json.loads((fish.REF/'anatomy.json').read_text()).items():
 fish.build(name,data)
bpy.data.libraries.write(str(ROOT/'source/fly_expansion_fish.blend'),set(fish.scenes),path_remap='RELATIVE',fake_user=True,compress=True)
print('FLY_EXPANSION_FISH_COMPLETE',flush=True)
