"""Author stainless spring tongs for the BBQ, with separately animated jaws.
Run via Blender MCP after build_bbq.py. Reuses its metre-scale mesh helpers.
"""
from pathlib import Path
import bpy, math
# Replace only the generated tongs, keeping the surrounding BBQ authoring scene.
old_scenes = [s for s in bpy.data.scenes if s.name.startswith(("Asset_tongs_handle", "Asset_tongs_jaw"))]
old_meshes = {o.data for s in old_scenes for o in s.objects if o.type == "MESH"}
for o in list(bpy.context.scene.objects):
    if o.type == "MESH" and o.data in old_meshes: bpy.data.objects.remove(o, do_unlink=True)
for s in old_scenes: bpy.data.scenes.remove(s)
ROOT = Path('/home/blux/raifslop')
exec((ROOT/'tools/build_bbq.py').read_text().split('# Raised portable charcoal grill')[0])

# Fixed spring cap at the rear of the hand, rivet and hanging loop.
box('Spring cap',(0,0,.075),(.044,.021,.043),steel,.01)
bar('Rivet',(0,-.014,.076),(0,.014,.076),.007,black)
for side in [-1,1]:
    bar('Hanging loop',(side*.017,0,.09),(side*.017,0,.125),.003,steel)
bar('Loop end',(-.017,0,.125),(.017,0,.125),.003,steel)
export('tongs_handle')

# One jaw, instanced above and below the food with opposing X-axis hinges.
# Flip the upper instance around its length so the contact ridges face inward.
# Pivot is at the rear spring; length from pivot to scalloped tip is 34 cm.
box('Steel arm',(0,0,-.14),(.019,.008,.28),steel,.003)
box('Ash grip',(0,.001,-.075),(.027,.019,.105),wood,.006)
for z in [-.04,-.11]:cyl('Grip rivet',(0,.012,z),.004,.003,steel,16)
ball('Scalloped spoon',(0,0,-.321),(.031,.007,.046),steel)
for z in [-.297,-.315,-.333]:
    for side in [-1,1]:
        ball('Scallop',(side*.027,0,z),(.009,.007,.01),steel)
for z in [-.295,-.310,-.325,-.34]:
    box('Grip ridge',(0,.008,z),(.046,.002,.002),black,.0005)
export('tongs_jaw')

# Preview the assembled tool resting at the front of the serving board.
from mathutils import Matrix, Vector
for asset_name,angle in [('tongs_handle',0),('tongs_jaw',-.065),('tongs_jaw',.065)]:
    asset=bpy.data.scenes['Asset_'+asset_name]
    for source in asset.objects:
        o=source.copy(); scene.collection.objects.link(o)
        assembly=Matrix.Translation(Vector(xyz((-.65,.93,.36))))
        if asset_name=='tongs_jaw':
            assembly @= Matrix.Translation(Vector(xyz((0,0,.075)))) @ Matrix.Rotation(angle,4,'X')
            if angle > 0: assembly @= Matrix.Rotation(math.pi,4,'Y')
        else:
            assembly @= Matrix.Rotation(-math.pi/2,4,'Y')
        o.matrix_world=assembly@source.matrix_world
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source/bbq_quality.blend'))
print('Tongs handle and animated jaw exported.')
