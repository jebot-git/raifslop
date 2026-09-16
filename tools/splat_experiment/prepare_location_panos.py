"""Blender: tone-map and orient source panoramas to the authored game forward."""
from pathlib import Path
import bpy, numpy as np, json
ROOT=Path(__file__).resolve().parents[2]
scene=bpy.data.scenes.new('Hybrid panorama preparation')
scene.render.image_settings.file_format='PNG'
scene.view_settings.view_transform='AgX'
for location,yaw in [('lake_pier',-100),('simons_town_rocks',180)]:
 out=ROOT/'test-results/splat-experiment'/location
 out.mkdir(parents=True,exist_ok=True)
 image=bpy.data.images.load(str(ROOT/'assets/environment/locations'/f'{location}_8k.hdr'),check_existing=False)
 image.scale(4096,2048)
 pixels=np.empty(4096*2048*4,dtype=np.float32)
 image.pixels.foreach_get(pixels)
 shift=round((.5-yaw/360)*4096)
 image.pixels.foreach_set(np.roll(pixels.reshape(2048,4096,4),shift,axis=1).ravel())
 image.save_render(str(out/f'{location}_pano.png'),scene=scene)
 (out/'pano_preparation.json').write_text(json.dumps({'location':location,'source_yaw':yaw,'longitude_roll_pixels':shift,'size':[4096,2048],'view_transform':'AgX'},indent=2))
 bpy.data.images.remove(image)
 print('Prepared',location)
