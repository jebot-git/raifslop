"""Bake exact river bank geometry exported by export_river_bake.gd.

Run in Blender, or through Blender MCP. Reuses the measured, sun-separated
HDR worlds and lights from the retained photographic lighting scenes.
"""
import bpy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/textures/lighting'


def bake(location, source):
    with bpy.data.libraries.load(str(ROOT / 'source/locations' / (source + '_lighting.blend'))) as (src, dst):
        dst.scenes = [src.scenes[0]]
    scene = dst.scenes[0]
    scene.name = 'RiverBake_' + location
    bpy.context.window.scene = scene
    # Keep precisely the previously measured lighting, replacing only geometry.
    for obj in list(scene.objects):
        if obj.type != 'LIGHT':
            scene.collection.objects.unlink(obj)
    banks = []
    materials = {}
    records = json.loads((ROOT / 'source' / (location + '_bake_geometry.json')).read_text())
    foliage_centers = [sum(v[0] for v in r['vertices']) / len(r['vertices']) for r in records if r['kind'] == 'foliage']
    if not foliage_centers or max(foliage_centers) - min(foliage_centers) < 50:
        raise ValueError('Collapsed foliage transforms: export with a real Godot renderer, not headless dummy rendering')
    for index, record in enumerate(records):
        mesh = bpy.data.meshes.new(record['kind'])
        mesh.from_pydata(record['vertices'], [], record['faces'])
        mesh.update()
        uv = mesh.uv_layers.new(name='UVMap')
        for polygon in mesh.polygons:
            for loop in polygon.loop_indices:
                uv.data[loop].uv = record['uv'][mesh.loops[loop].vertex_index]
        obj = bpy.data.objects.new(record['kind'] + str(index), mesh)
        scene.collection.objects.link(obj)
        key = record['texture'] or record['kind']
        if key not in materials:
            mat = bpy.data.materials.new('RiverBake_' + key)
            mat.use_nodes = True
            bs = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
            bs.inputs['Base Color'].default_value = (.25, .29, .17, 1) if record['kind'] == 'foliage' else (.5, .5, .5, 1)
            bs.inputs['Roughness'].default_value = .9
            if record['texture']:
                tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
                tex.image = bpy.data.images.load(str(ROOT / record['texture'].removeprefix('res://')), check_existing=True)
                mat.node_tree.links.new(tex.outputs['Alpha'], bs.inputs['Alpha'])
            materials[key] = mat
        obj.data.materials.append(materials[key])
        if record['kind'] == 'bank':
            bake_uv = mesh.uv_layers.new(name='BankUV')
            for loop in mesh.loops:
                v = mesh.vertices[loop.vertex_index].co
                # Godot XZ projected atlas, clamped to its central 96 x 70 metres.
                bake_uv.data[loop.index].uv = ((v.x + 48) / 96, (-v.y + 50) / 70)
            banks.append(obj)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in banks:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = banks[0]
    bpy.ops.object.join()
    bank = bpy.context.object
    bank.name = 'BakedRiverBanks'
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 24
    scene.cycles.device = 'CPU'
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 6
    scene.render.bake.margin = 8
    scene.render.bake.use_pass_direct = True
    scene.render.bake.use_pass_indirect = True
    scene.render.bake.use_pass_color = False
    scene.render.bake.use_selected_to_active = False
    for kind in ['irradiance', 'ao']:
        image = bpy.data.images.new(location + '_' + kind, 1024, 1024, alpha=False, float_buffer=kind == 'irradiance')
        image.colorspace_settings.name = 'Non-Color'
        for mat in bank.data.materials:
            node = mat.node_tree.nodes.new('ShaderNodeTexImage')
            node.image = image
            mat.node_tree.nodes.active = node
        bpy.ops.object.bake(type='DIFFUSE' if kind == 'irradiance' else 'AO', uv_layer='BankUV')
        scene.render.image_settings.file_format = 'OPEN_EXR' if kind == 'irradiance' else 'PNG'
        scene.render.image_settings.color_mode = 'RGB'
        scene.render.image_settings.color_depth = '16' if kind == 'irradiance' else '8'
        scene.render.image_settings.exr_codec = 'ZIP'
        destination = str(OUT / (location + '_' + kind + ('.exr' if kind == 'irradiance' else '.png')))
        if kind == 'ao':
            # AO is data: bypass the scene's display/view transform.
            image.filepath_raw = destination
            image.file_format = 'PNG'
            image.save()
        else:
            image.save_render(destination, scene=scene)
        for mat in bank.data.materials:
            for node in list(mat.node_tree.nodes):
                if node.type == 'TEX_IMAGE' and node.image == image:
                    mat.node_tree.nodes.remove(node)
        print('RIVER_BAKED', location, kind, flush=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'source' / (location + '_lighting.blend')))


if __name__ == '__main__':
    for location, source in [('meadow_bend', 'lakeside'), ('boulder_run', 'bell_park_pier')]:
        bake(location, source)
