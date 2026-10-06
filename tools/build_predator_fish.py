"""Build the two trophy predators from retained generated references and reviewed landmarks."""
import sys,json,bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_photographic_fish as fish
fish.REF=ROOT/'source/fish_references/predators'
fish.TEX=ROOT/'source/textures/fish/predators'
fish.TEX.mkdir(parents=True,exist_ok=True)
selected=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
for name,data in json.loads((fish.REF/'anatomy.json').read_text()).items():
 if not selected or name in selected:fish.build(name,data)
bpy.data.libraries.write(str(ROOT/('source/'+selected[0]+'_repaired.blend' if len(selected)==1 else 'source/predator_fish.blend')),set(fish.scenes),path_remap='RELATIVE',fake_user=True,compress=True)
print('PREDATOR_FISH_COMPLETE',flush=True)
