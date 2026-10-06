"""Blender: update retained Lakeside bake scene, preserve terrain UVs, rebake shadows.
Run export_lakeside_rocks.gd first, then blender --factory-startup -b -noaudio
--python tools/rebake_lakeside_shore.py. The GLB terrain and collision stay unchanged.
"""
import importlib.util
import json
from pathlib import Path
import bpy
import bmesh

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / 'source/locations/lakeside_lighting.blend'
bpy.ops.wm.read_factory_settings(use_empty=True)
with bpy.data.libraries.load(str(path)) as (src, dst):
    dst.scenes = [src.scenes[0]]
scene = dst.scenes[0]
bpy.context.window.scene = scene
foreground = next(o for o in scene.objects if 'BakedForeground' in o.name)
mesh = foreground.data
faces = [p for p in mesh.polygons if mesh.materials[p.material_index].name.startswith('FG_stone')]
touching = {}
keys = {}
for face in faces:
    keys[face.index] = [tuple(round(c, 4) for c in mesh.vertices[i].co) for i in face.vertices]
    for key in keys[face.index]:
        touching.setdefault(key, []).append(face.index)
seen, retired = set(), set()
removed = 0
for seed in keys:
    if seed in seen:
        continue
    group = [seed]
    seen.add(seed)
    for current in group:
        for key in keys[current]:
            for neighbor in touching[key]:
                if neighbor not in seen:
                    seen.add(neighbor)
                    group.append(neighbor)
    points = [point for index in group for point in keys[index]]
    x = (min(p[0] for p in points) + max(p[0] for p in points)) / 2
    y = (min(p[1] for p in points) + max(p[1] for p in points)) / 2
    if abs(x) < 8.5 and y > 2.15:
        retired.update(group)
        removed += 1
assert removed in (0, 24), f'Unexpected old rock component count: {removed}'
bm = bmesh.new()
bm.from_mesh(mesh)
bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[bm.faces[i] for i in retired], context='FACES')
bm.to_mesh(mesh)
bm.free()
for obj in list(scene.objects):
    if obj.name.startswith('RuntimeShoreBoulder'):
        bpy.data.objects.remove(obj, do_unlink=True)
material = bpy.data.materials.new('NaturalShoreGranite')
material.use_nodes = True
bs = material.node_tree.nodes.get('Principled BSDF')
bs.inputs['Roughness'].default_value = .87
texture = material.node_tree.nodes.new('ShaderNodeTexImage')
texture.image = bpy.data.images.load(str(ROOT / 'assets/environment/rivers/river_boulder_coastal_granite_base.png'))
material.node_tree.links.new(texture.outputs['Color'], bs.inputs['Base Color'])
records = json.loads((ROOT / 'source/lakeside_shore_rocks.json').read_text())
assert len(records) == 8
for i, record in enumerate(records):
    m = bpy.data.meshes.new('NaturalShoreRock')
    m.from_pydata(record['vertices'], [], record['faces'])
    m.update()
    uv = m.uv_layers.new(name='UVMap')
    for loop in m.loops:
        uv.data[loop.index].uv = record['uv'][loop.vertex_index]
    for polygon in m.polygons:
        polygon.use_smooth = True
    obj = bpy.data.objects.new('RuntimeShoreBoulder' + str(i), m)
    scene.collection.objects.link(obj)
    m.materials.append(material)
scene['natural_shore_rocks'] = 8
bpy.data.libraries.write(str(path), {scene}, path_remap='RELATIVE', fake_user=True, compress=True)
print('LAKESIDE_SHORE_SOURCE', removed, 'old rocks removed, 8 replacements', flush=True)
spec = importlib.util.spec_from_file_location('panorama_lighting', ROOT / 'tools/bake_panorama_lighting.py')
calibration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(calibration)
calibration.bake('lakeside')
# Blender's background audio teardown can hang in restricted build containers.
import os
import sys
sys.stdout.flush()
sys.stderr.flush()
os._exit(0)
