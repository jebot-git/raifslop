"""One-time repair of retained Blender sources and their runtime fish GLBs.
Run: blender --background --python tools/repair_fish_fins.py
Fresh builds use the same repair helper before export.
"""
import bpy, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from fish_fin_geometry import repair_fins

for source, photographic in [('fish_species.blend', False), ('photographic_fish.blend', True)]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    path = ROOT / 'source' / source
    with bpy.data.libraries.load(str(path)) as (src, dst):
        dst.scenes = src.scenes
    scenes = list(dst.scenes)
    for scene in scenes:
        bpy.context.window.scene = scene
        for obj in list(scene.objects):
            if obj.type != 'MESH' or not obj.name.split('.')[0].endswith('_realistic'):
                continue
            name = obj.name.split('.')[0].removesuffix('_realistic')
            if not photographic and name not in ['roach', 'tench']:
                continue
            if obj.get('fin_roots_repaired', False):
                continue
            print('FIN_REPAIR', name, repair_fins(obj, photographic), flush=True)
            obj['fin_roots_repaired'] = True
            for other in scene.objects:
                other.select_set(False)
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            # Gallery placements must never leak into standalone metre assets.
            transform = obj.matrix_world.copy()
            obj.location = (0, 0, 0)
            bpy.ops.export_scene.gltf(filepath=str(ROOT / 'assets/models/fish' / (name + '.glb')), export_format='GLB', use_selection=True, use_active_scene=True, export_animations=False)
            obj.matrix_world = transform
    bpy.data.libraries.write(str(path),set(scenes),path_remap='RELATIVE',fake_user=True,compress=True)
