"""Original cage feeder: perforated brass cage, lead shoe and textured groundbait."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
exec(compile((ROOT/'tools/build_rods.py').read_text().split('for variant in range(12):')[0],str(ROOT/'tools/build_rods.py'),'exec'))
scene=bpy.data.scenes.new('Cage feeder authoring');bpy.context.window.scene=scene
cage=material('Patinated cage',(.20,.23,.16),.72,.48)
lead=material('Graphite sinker',(.12,.13,.13),.65,.62)
crumb=material('Packed groundbait',(.39,.24,.09),0,.95)
rng=np.random.default_rng(511)
pixels=np.zeros((256,256,4),np.float32);noise=rng.random((256,256));pixels[:,:,:3]=np.array([.43,.28,.12])*(.55+noise[:,:,None]*.9);pixels[:,:,3]=1
texture=bpy.data.images.new('Groundbait crumbs',256,256);texture.pixels.foreach_set(pixels.ravel());texture.pack()
node=crumb.node_tree.nodes.new('ShaderNodeTexImage');node.image=texture
shader=next(n for n in crumb.node_tree.nodes if n.type=='BSDF_PRINCIPLED');crumb.node_tree.links.new(node.outputs['Color'],shader.inputs['Base Color'])
# Vertical basket hangs below the swivel; all dimensions in metres.
for y in [-.013,-.031,-.049,-.067]:torus('Basket hoop',(0,y,0),.022,.0014,cage,axis=(0,1,0))
for j in range(10):
 a=j*math.tau/10;x,z=.022*math.cos(a),.022*math.sin(a)
 cylinder('Cage rib',(x,-.013,z),(x,-.067,z),.0012,cage)
cylinder('Groundbait core',(0,-.015,0),(0,-.065,0),.0185,crumb)
ellipsoid('Lead shoe',(0,-.069,0),(.022,.005,.018),lead)
tube('Attachment bail',[(-.017,-.013,0),(0,-.002,0),(.017,-.013,0)],.0013,cage)
torus('Swivel eye',(0,.003,0),.003,.0009,steel)
export(scene,'cage_feeder')
bpy.data.libraries.write(str(ROOT/'source/feeder.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  area.spaces.active.region_3d.view_distance=.22
  area.spaces.active.region_3d.view_location=p((0,-.03,0))
print('FEEDER_COMPLETE')
