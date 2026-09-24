"""Original fallen cedar foreground mesh; run in Blender."""
import bpy
from mathutils import Vector
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/environment/rivers/expansion';OUT.mkdir(parents=True,exist_ok=True)
scene=bpy.data.scenes.new('FlyExpansionScenery');bpy.context.window.scene=scene

def mat(name,color):
 m=bpy.data.materials.new(name);m.use_nodes=True
 p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=.92
 m.diffuse_color=(*color,1);return m
bark=mat('Cedar reddish furrowed bark',(.13,.066,.035));wood=mat('Weathered cedar heartwood',(.32,.25,.16))

def rod(a,b,r1,r2,m):
 a,b=Vector(a),Vector(b);d=b-a
 bpy.ops.mesh.primitive_cone_add(vertices=9,radius1=r1,radius2=r2,depth=d.length,location=(a+b)/2)
 o=bpy.context.object;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();o.data.materials.append(m);return o

def export(name,objects):
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name=name
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),use_selection=True,use_active_scene=True,export_animations=False)
 return o

parts=[rod((-1.8,0,.23),(1.8,.1,.32),.24,.19,bark),rod((-1.81,0,.23),(-1.83,0,.23),.19,.19,wood),rod((.2,0,.3),(.55,.7,.55),.09,.035,bark)]
log=export('fallen_cedar',parts)
bpy.data.libraries.write(str(ROOT/'source/fly_expansion_scenery.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
print('FLY_EXPANSION_SCENERY_COMPLETE')
