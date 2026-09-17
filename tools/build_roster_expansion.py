"""Blender: six original fish, reviewed anatomy, UV skin and baked normals.
Run with Blender MCP or Blender --python. Earlier source scenes are preserved.
"""
import sys,json
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_photographic_fish as fish
fish.REF=ROOT/'source/fish_references/roster_expansion'
fish.TEX=ROOT/'source/textures/fish/roster_expansion';fish.TEX.mkdir(parents=True,exist_ok=True)
def build_one(name):
 fish.scenes[:]=[scene for scene in fish.scenes if not scene.name.startswith("Photographic_"+name)]
 fish.build(name,json.loads((fish.REF/'anatomy.json').read_text())[name])
def save():
 bpy.data.libraries.write(str(ROOT/'source/roster_expansion.blend'),set(fish.scenes),path_remap='RELATIVE',fake_user=True,compress=True)
if __name__=='__main__':
 for name in json.loads((fish.REF/'anatomy.json').read_text()):build_one(name)
 save()
