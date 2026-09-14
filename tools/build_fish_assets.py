"""Build realistic fish in Blender. See docs/FISH_SPECIES.md for asset credits.

First build: import the two credited Sketchfab models through Blender MCP and
name their root empties Downloaded_bream and Downloaded_zander.
Subsequent builds can reuse the runtime GLBs. The authored tench is rebuilt from
its retained texture and profile. Run with Blender --python or MCP/runpy.
"""
import math
from pathlib import Path
import bpy
from mathutils import Matrix, Vector
from mathutils.geometry import tessellate_polygon

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/models/fish'
OUT.mkdir(parents=True, exist_ok=True)
scene = bpy.data.scenes.new('Realistic freshwater fish')
bpy.context.window.scene = scene
roots = {}


def select(objects):
    for obj in bpy.data.objects:
        obj.select_set(False)
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]


def export(name, objects):
    select(objects)
    bpy.ops.export_scene.gltf(filepath=str(OUT / (name + '.glb')), export_format='GLB',
                              use_selection=True, use_active_scene=True, export_animations=False)
    print(name, 'exported', (OUT / (name + '.glb')).stat().st_size, 'bytes')


for name in ['bream', 'zander']:
    source = bpy.data.objects.get('Downloaded_' + name)
    copies = []
    if source:
        for obj in source.children_recursive:
            if obj.type != 'MESH':
                continue
            data = obj.data.copy()
            # Source fish lie along Blender Y; turn them to the game's X axis.
            data.transform(Matrix.Rotation(math.pi / 2, 4, 'Z') @ obj.matrix_world)
            copy = bpy.data.objects.new(name + ' mesh', data)
            scene.collection.objects.link(copy)
            copies.append(copy)
        select(copies)
        bpy.ops.object.join()
        fish = bpy.context.object
        # Material-preserving collapse keeps texture UVs and the fin silhouettes.
        triangles = sum(len(p.vertices) - 2 for p in fish.data.polygons)
        if triangles > 24000:
            mod = fish.modifiers.new('Game mesh reduction', 'DECIMATE')
            mod.ratio = 22000 / triangles
            bpy.ops.object.modifier_apply(modifier=mod.name)
        points = [v.co for v in fish.data.vertices]
        lower = Vector(tuple(min(p[i] for p in points) for i in range(3)))
        upper = Vector(tuple(max(p[i] for p in points) for i in range(3)))
        centre, length = (lower + upper) * .5, upper.x - lower.x
        for v in fish.data.vertices:
            v.co = (v.co - centre) / length
        for poly in fish.data.polygons:
            poly.use_smooth = True
        for mat in fish.data.materials:
            if mat and mat.use_nodes:
                p = mat.node_tree.nodes.get('Principled BSDF')
                if p:
                    p.inputs['Roughness'].default_value = .42
                    p.inputs['Metallic'].default_value = 0
                for node in mat.node_tree.nodes:
                    if node.type == 'TEX_IMAGE' and node.image:
                        if max(node.image.size) > 2048:
                            factor = 2048 / max(node.image.size)
                            node.image.scale(int(node.image.size[0] * factor), int(node.image.size[1] * factor))
        fish.name = name + '_realistic'
        roots[name] = fish
        export(name, [fish])
    else:
        # Runtime GLBs are also the retained optimized source for a fresh rebuild.
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(OUT / (name + '.glb')))
        imported = list(set(bpy.data.objects) - before)
        fish = next(o for o in imported if o.parent is None)
        roots[name] = fish

# Tench: a full 3D body with separate thin rounded fins and side-projected skin.
image = bpy.data.images.load(str(ROOT / 'source/textures/fish/tench_albedo.png'), check_existing=True)
image.pack()
mat = bpy.data.materials.new('Tench photographed-style skin')
mat.use_nodes = True
mat.diffuse_color = (.22, .25, .09, 1)
p = mat.node_tree.nodes.get('Principled BSDF')
p.inputs['Roughness'].default_value = .4
p.inputs['Metallic'].default_value = 0
tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
tex.image = image
mat.node_tree.links.new(tex.outputs['Color'], p.inputs['Base Color'])
# Very fine skin relief; exported colour carries detail in the runtime material.
bump = mat.node_tree.nodes.new('ShaderNodeBump')
bump.inputs['Strength'].default_value = .12
bump.inputs['Distance'].default_value = .0005
mat.node_tree.links.new(tex.outputs['Color'], bump.inputs['Height'])
mat.node_tree.links.new(bump.outputs['Normal'], p.inputs['Normal'])
mat.use_backface_culling = False
D = 1498.0


def position(px, py, depth=0):
    return ((px - 769) / D, depth, (520 - py) / D)


def make_mesh(name, verts, faces, coords):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.materials.append(mat)
    uv = data.uv_layers.new(name='FishUV')
    for poly in data.polygons:
        poly.use_smooth = True
        for loop in poly.loop_indices:
            px, py = coords[data.loops[loop].vertex_index]
            uv.data[loop].uv = (px / 1536, 1 - py / 1024)
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    return obj


# Pixel-space dorsal/ventral body contour; fins are handled separately below.
profile = [(221, 429, 585, .025), (280, 405, 594, .033), (360, 402, 595, .042),
           (450, 386, 610, .062), (540, 360, 653, .080), (640, 329, 694, .094),
           (740, 298, 724, .102), (840, 282, 746, .104), (940, 289, 751, .100),
           (1040, 306, 735, .096), (1140, 332, 696, .087), (1240, 366, 659, .073),
           (1330, 416, 630, .061), (1420, 468, 602, .043), (1482, 510, 580, .025),
           (1518, 544, 560, .007)]
def body_from_profile(name, profile):
    # Dense rings preserve the lips/shoulder without subdivision UV drift.
    profile = [tuple(a[k] + (b[k] - a[k]) * t / 3 for k in range(4))
               for a, b in zip(profile, profile[1:]) for t in range(3)] + [profile[-1]]
    verts, uvcoords, faces = [], [], []
    for px, top, bottom, thickness in profile:
        cy, radius = (top + bottom) / 2, (bottom - top) / 2
        for j in range(32):
            a = j * math.tau / 32
            py = cy - radius * math.sin(a)
            verts.append(position(px, py, thickness * math.cos(a)))
            uvcoords.append((px, py))
    for i in range(len(profile) - 1):
        for j in range(32):
            faces.append((i * 32 + j, i * 32 + (j + 1) % 32,
                          (i + 1) * 32 + (j + 1) % 32, (i + 1) * 32 + j))
    faces.extend([tuple(reversed(range(32))), tuple((len(profile) - 1) * 32 + j for j in range(32))])
    return make_mesh(name, verts, faces, uvcoords)

body = body_from_profile('Tench body', profile)
parts = [body]


def fin(name, outline, depth=0):
    # Triangulated traced contour preserves rounded soft fin margins.
    polygon = [Vector((x, y, 0)) for x, y in outline]
    triangles = tessellate_polygon([polygon])
    faces = [tuple(v if isinstance(v, int) else polygon.index(v) for v in tri) for tri in triangles]
    obj = make_mesh(name, [position(x, y, depth) for x, y in outline], faces, outline)
    parts.append(obj)


fin('Tench broad tail', [(251,430),(224,398),(175,365),(115,321),(69,308),(39,315),
                         (28,343),(30,401),(40,466),(47,506),(41,548),(28,609),(29,651),
                         (47,676),(80,679),(140,655),(207,623),(252,593)])
fin('Tench rounded dorsal', [(568,335),(554,308),(550,273),(554,230),(570,193),(591,167),
                            (617,158),(643,165),(681,185),(723,217),(770,254),(818,287),(759,307),(659,326)])
fin('Tench anal', [(405,601),(376,618),(353,650),(349,692),(362,732),(387,746),
                  (425,737),(471,708),(520,669),(537,651)])
for side in [-1, 1]:
    fin('Tench pelvic', [(729,731),(689,751),(668,782),(674,806),(701,826),
                         (736,827),(775,805),(809,775),(835,744),(808,730)], side * .055)
    fin('Tench pectoral', [(1204,623),(1150,623),(1094,630),(1048,647),(1023,671),
                          (1024,695),(1046,714),(1083,722),(1123,702),(1161,668)], side * .091)
    # Short mouth barbels and glassy inset eyes give depth beyond the projection.
    curve = bpy.data.curves.new('Tench mouth barbel', 'CURVE')
    curve.dimensions = '3D'
    curve.bevel_depth = .0009
    curve.bevel_resolution = 2
    spline = curve.splines.new('POLY')
    points = [position(1480,568,side*.021),position(1480,592,side*.024),position(1473,616,side*.026)]
    spline.points.add(2)
    for pnt, point in zip(spline.points,points): pnt.co = (*point,1)
    barbel=bpy.data.objects.new('Tench barbel',curve)
    scene.collection.objects.link(barbel)
    barbel_mat=bpy.data.materials.new('Tench lip olive')
    barbel_mat.diffuse_color=(.29,.24,.10,1)
    curve.materials.append(barbel_mat)
    parts.append(barbel)
select(parts)
bpy.ops.object.convert(target='MESH')
bpy.ops.object.join()
body=bpy.context.object
body.name='tench_realistic'
roots['tench']=body
export('tench',[body])

# Roach uses its own reference proportions and silver/red photographic texture.
image = bpy.data.images.load(str(ROOT / 'source/textures/fish/roach_albedo.png'), check_existing=True)
image.pack()
mat = bpy.data.materials.new('Roach silver scaled skin')
mat.use_nodes = True
mat.use_backface_culling = False
p = mat.node_tree.nodes.get('Principled BSDF')
p.inputs['Roughness'].default_value = .4
p.inputs['Metallic'].default_value = .05
tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
tex.image = image
mat.node_tree.links.new(tex.outputs['Color'], p.inputs['Base Color'])
profile = [(250,455,566,.020),(330,450,568,.027),(430,433,584,.038),
           (530,406,627,.055),(630,374,671,.066),(730,343,690,.076),
           (830,320,709,.080),(930,331,720,.078),(1030,353,716,.075),
           (1130,390,699,.066),(1230,427,671,.055),(1330,478,643,.047),
           (1420,519,614,.035),(1498,550,588,.012)]
body = body_from_profile('Roach body', profile)
parts = [body]
fin('Roach forked tail',[(257,458),(219,424),(166,380),(108,342),(36,309),
                         (68,376),(101,442),(141,504),(136,525),(98,581),
                         (62,643),(32,704),(92,678),(158,631),(211,589),(257,562)])
fin('Roach dorsal',[(594,354),(633,304),(657,254),(674,214),(680,166),
                    (708,184),(742,213),(780,254),(824,303),(837,312),(737,339)])
fin('Roach anal',[(407,597),(437,638),(458,695),(478,758),(520,726),
                  (557,684),(588,658),(514,626)])
for side in [-1,1]:
    fin('Roach pelvic',[(750,710),(738,745),(738,821),(755,831),(800,803),
                        (838,761),(867,713)],side*.054)
    fin('Roach pectoral',[(1231,626),(1180,623),(1118,629),(1061,643),
                          (1076,663),(1110,681),(1163,669),(1199,649)],side*.075)
select(parts)
bpy.ops.object.join()
body=bpy.context.object
body.name='roach_realistic'
roots['roach']=body
export('roach',[body])

# Asset gallery, rendered from the side with a slight angle to show body depth.
for i,name in enumerate(['roach','tench','bream','zander']):
    obj=roots[name]
    obj.location=((i%2)*1.35-.675,0,.48-(i//2)*.83)
    font=bpy.data.curves.new(name+' label','FONT')
    font.body=name.upper()
    font.size=.052
    label=bpy.data.objects.new(name+' label',font)
    scene.collection.objects.link(label)
    label.location=(obj.location.x-.48,-.2,obj.location.z-.32)
    label.rotation_euler=(math.pi/2,0,0)
world=bpy.data.worlds.new('Fish studio world')
world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.07,.10,.09,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.5
scene.world=world
for pos,energy,size in [((0,-3,3),220,4),((-2,1,2),180,3),((3,-2,0),100,3)]:
    data=bpy.data.lights.new('Fish softbox','AREA')
    data.energy,data.shape,data.size=energy,'DISK',size
    obj=bpy.data.objects.new(data.name,data)
    scene.collection.objects.link(obj)
    obj.location=pos
    obj.rotation_euler=(Vector((0,0,0))-obj.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('Fish gallery camera')
camera=bpy.data.objects.new(data.name,data)
scene.collection.objects.link(camera)
camera.location=(0,-5,.28)
camera.rotation_euler=(Vector((0,0,.1))-camera.location).to_track_quat('-Z','Y').to_euler()
data.type,data.ortho_scale='ORTHO',2.8
scene.camera=camera
scene.render.engine='CYCLES'
scene.cycles.samples=24
scene.render.resolution_x,scene.render.resolution_y=1400,900
scene.render.resolution_percentage=100
scene.render.filepath=str(ROOT/'docs/fish_species.png')
# Save through Blender's normal writer (preserves all other open scenes).
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source/fish_species.blend'),copy=True,compress=True)
print('Realistic fish source saved. Render active scene for gallery.')
