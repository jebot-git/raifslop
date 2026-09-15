"""Regrade existing pier meshes without changing their UVs or baked atlas layout.
Run with Blender --background --python tools/regrade_lake_pier.py.
The same dimensions live in build_foregrounds.py for fresh asset builds.
"""
import json
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[1]


def regrade(scene):
    changed = 0
    for obj in scene.objects:
        if obj.type != 'MESH':
            continue
        for vertex in obj.data.vertices:
            x, z, y = vertex.co.x, -vertex.co.y, vertex.co.z
            # Mainland grid, distinct from quay, rails and props.
            if abs(x / 4 - round(x / 4)) < 1e-5 and any(abs(z - row) < 1e-4 for row in [7, 8.8, 12, 19, 32, 57, 97, 157]):
                vertex.co.z = -1.25 if abs(z - 7) < 1e-4 else -.10
                changed += 1
            elif abs(y + .7) < 1e-5 and abs(abs(x) - 5) < 1e-5 and (abs(z + 3) < 1e-5 or abs(z - 9) < 1e-5):
                vertex.co.z = -1.25
                changed += 1
        obj.data.update()
    print('REGRADED', scene.name, changed)


for path, baked in [(ROOT / 'source/foregrounds.blend', False), (ROOT / 'source/locations/lake_pier_lighting.blend', True)]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    with bpy.data.libraries.load(str(path)) as (src, dst):
        dst.scenes = src.scenes
    scenes = list(dst.scenes)
    # Libraries may retain paths from the original author's checkout.
    for image in bpy.data.images:
        local = ROOT / 'source/textures/foreground' / Path(image.filepath).name
        if local.is_file():
            image.filepath = str(local)
            image.reload()
    scene = next(s for s in scenes if s.name.split('.')[0] == 'Foreground_lake_pier')
    regrade(scene)
    bpy.context.window.scene = scene
    bpy.data.libraries.write(str(path), set(scenes), path_remap='RELATIVE', fake_user=True, compress=True)
    if baked:
        output = ROOT / 'assets/models/locations/lit/lake_pier.glb'
        bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', use_active_scene=True, export_yup=True, export_apply=True, export_lights=False)

path = ROOT / 'assets/models/locations/manifest.json'
data = json.loads(path.read_text())
floor = next(c for c in data['lake_pier']['colliders'] if c['role'] == 'floor')
floor['position'][1] = -.625
floor['size'][1] = 1.25
path.write_text(json.dumps(data, indent=2) + "\n")
