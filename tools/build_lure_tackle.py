"""Original casting rods, compact baitcasters and lure assets. Run in Blender."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
exec(compile((ROOT/'tools/build_rods.py').read_text().split('for variant in range(12):')[0],str(ROOT/'tools/build_rods.py'),'exec'))
# Compact, unbranded casting tackle: no changes to other rig models.
source_scenes=[]
braid=material('Moss braid',(.28,.38,.12),0,.72)
eva=material('Fine EVA grain',(.055,.06,.063),0,.86)
a=np.random.default_rng(726).random((256,256));pixels=np.ones((256,256,4),np.float32);pixels[:,:,:3]=(.035+a[:,:,None]*.035)
im=bpy.data.images.new('EVA micrograin',256,256);im.pixels.foreach_set(pixels.ravel());im.pack()
node=eva.node_tree.nodes.new('ShaderNodeTexImage');node.image=im;eva.node_tree.links.new(node.outputs['Color'],next(n for n in eva.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Base Color'])
for index,style in enumerate(ROD_STYLES):
 name=style['name'];grip=cork if style['cork'] else eva
 scene=bpy.data.scenes.new(name+'_lure');bpy.context.window.scene=scene;source_scenes.append(scene)
 trim=material(name+' casting trim',style['trim'],.65,.35)
 graphite=material(name+' casting carbon',style['blank'],.3,.43)
 shell=material(name+' low profile reel',style['reel'],.68,.32)
 cylinder('Fast action blank',(0,0,.18),(0,0,-1.68),.0055,graphite,.0009)
 cylinder('Split EVA butt',(0,0,.24),(0,0,.15),.014,grip,.018)
 cylinder('Exposed graphite grip',(0,0,.15),(0,0,.07),.008,graphite)
 cylinder('Palm EVA grip',(0,0,.07),(0,0,-.07),.014,grip,.011)
 cylinder('Short foregrip',(0,0,-.09),(0,0,-.12),.012,grip,.009)
 for z in [.24,.15,.07,-.075,-.09,-.12]:cylinder('Anodised collar',(0,0,z+.002),(0,0,z-.002),.014,trim)
 tube('Casting finger trigger',[(0,-.012,.03),(0,-.035,.055),(0,-.038,.075)],.0045,shell)
 # Casting guides sit above the blank, matching the reel's line exit.
 for i,z in enumerate([-.27,-.5,-.75,-.97,-1.18,-1.38,-1.55,-1.678]):
  radius=.012*(1-i/10)+.001
  torus('Casting guide',(0,radius+.004,z),radius,.0012,steel)
  tube('Guide foot',[(0,0,z+.02),(0,radius+.004,z),(0,0,z-.02)],.0012,trim)
 # Narrow transverse spool between two streamlined sideplates.
 for x in [-.034,.034]:ellipsoid('Low profile sideplate',(x,.029,.028),(.010,.021,.039),shell)
 cylinder('Exposed braid spool',(-.025,.03,.025),(.025,.03,.025),.018,braid)
 for x in [-.026,.026]:torus('Spool flange',(x,.03,.025),.020,.0018,trim,axis=(1,0,0))
 cylinder('Thumb bar',(-.03,.04,.059),(.03,.04,.059),.007,eva)
 cylinder('Levelwind rail',(-.03,.023,-.006),(.03,.023,-.006),.0022,steel)
 torus('Line exit eye',(0,.024,-.014),.006,.0013,steel)
 for band in range(index):
  cylinder('Tier binding',(0,0,-.15-band*.014),(0,0,-.154-band*.014),.0065,trim)
 if index>=2:
  for z in [.145,-.073]:torus('Premium seat collar',(0,0,z),.014,.0015,trim)
 cylinder('Short crank axle',(-.055,.028,.04),(-.039,.028,.04),.0038,steel)
 cylinder('Brake dial',(.045,.03,.04),(.051,.03,.04),.010,trim)
 export(scene,name+'_lure')
scene=bpy.data.scenes.new('Lure double paddle crank');bpy.context.window.scene=scene;source_scenes.append(scene)
tube('Swept double crank',[(0,-.045,0),(0,-.025,.005),(0,0,0),(0,.025,-.005),(0,.045,0)],.0035,steel)
for y in [-.045,.045]:
 cylinder('Handle pin',(0,y,0),(-.02,y,0),.0025,steel)
 ellipsoid('EVA paddle',(-.02,y,0),(.009,.012,.009),eva)
export(scene,'lure_handle')
OUT=ROOT/'assets/models/lures';OUT.mkdir(parents=True,exist_ok=True)
pearl=material('Pearl fish scales',(.67,.78,.63),.28,.36)
a=np.random.default_rng(220).random((256,256));pixels=np.ones((256,256,4),np.float32)
y,x=np.mgrid[0:256,0:256];scales=(np.sin(x*.32+(y//12%2)*1.6)*np.cos(y*.27))*.06
pixels[:,:,:3]=np.clip(np.array([.53,.67,.48])*(.82+a[:,:,None]*.18+scales[:,:,None]),0,1)
im=bpy.data.images.new('Lure scale flecks',256,256);im.pixels.foreach_set(pixels.ravel());im.pack()
node=pearl.node_tree.nodes.new('ShaderNodeTexImage');node.image=im;pearl.node_tree.links.new(node.outputs['Color'],next(n for n in pearl.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Base Color'])
plastic=material('Soft chartreuse polymer',(.43,.58,.13),.04,.53)
eye=material('Glossy lure eyes',(.013,.018,.012),.1,.18)
red=material('Red accent',(.53,.055,.025),.1,.45)
def hook(at):
 points=[(at[0],at[1],at[2]),(at[0],at[1]-.013,at[2])]
 for i in range(10):
  a=math.pi+math.pi*i/9;points.append((at[0]+.004+math.cos(a)*.004,at[1]-.013+math.sin(a)*.004,at[2]))
 points.append((at[0]+.007,at[1]-.005,at[2]));tube('Single hook',points,.00065,steel)
for name in ['inline_spinner','casting_spoon','paddle_shad','diving_minnow']:
 scene=bpy.data.scenes.new(name);bpy.context.window.scene=scene;source_scenes.append(scene)
 torus('Tie eye',(0,0,0),.0025,.0007,steel)
 if name=='inline_spinner':
  cylinder('Wire shaft',(0,-.003,0),(0,-.053,0),.0007,steel)
  ellipsoid('Weighted anodised body',(0,-.036,0),(.004,.012,.004),trim)
  cylinder('Clevis',(0,-.009,0),(.007,-.013,0),.001,steel)
  ellipsoid('Polished spinner blade',(.009,-.025,.002),(.010,.017,.0012),steel)
  for y in [-.027,-.04]:torus('Red body band',(0,y,0),.0042,.001,red,axis=(0,1,0))
  hook((0,-.052,0))
 elif name=='casting_spoon':
  ellipsoid('Cupped spoon',(0,-.035,.004),(.013,.031,.002),steel)
  ellipsoid('Anodised flash',(0,-.035,.0015),(.010,.025,.0007),trim)
  torus('Split ring',(0,-.068,0),.003,.0007,steel);hook((0,-.071,0))
 elif name=='paddle_shad':
  ellipsoid('Jig head',(0,-.008,0),(.006,.006,.006),steel)
  ellipsoid('Soft bait body',(0,-.033,0),(.009,.023,.006),pearl)
  cylinder('Flexible tail neck',(0,-.05,0),(.002,-.07,0),.003,plastic,.0018)
  ellipsoid('Paddle tail',(.002,-.075,0),(.008,.004,.005),plastic)
  hook((0,-.016,.006))
 else:
  ellipsoid('Minnow body',(0,-.034,0),(.011,.031,.008),pearl)
  ellipsoid('Diving lip',(0,-.01,.012),(.010,.008,.0014),steel)
  for y in [-.025,-.04,-.052]:ellipsoid('Dark flank bars',(0,y,.007),(.008,.0015,.0015),graphite)
  hook((0,-.041,.007));hook((0,-.068,0))
 if name in ['paddle_shad','diving_minnow']:
  for x in [-.007,.007]:ellipsoid('Fish eye',(x,-.016,.003),(.002,.002,.002),eye)
 export(scene,name)
# Keep the asset inspection scene centred, without disturbing earlier source scenes.
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':area.spaces.active.region_3d.view_distance=.20;area.spaces.active.region_3d.view_location=p((0,-.04,0))
bpy.data.libraries.write(str(ROOT/'source/lure_tackle.blend'),set(source_scenes),path_remap='RELATIVE',fake_user=True,compress=True)
print('LURE_TACKLE_COMPLETE')
