"""Regenerate menu previews from the retained native 8K originals in Blender."""
from pathlib import Path
import hashlib
import json
import bpy

ROOT = Path(__file__).resolve().parents[1]
LOCATION_DIR = ROOT / 'assets/environment/locations'
scene = bpy.data.scenes.new('Panorama previews')
scene.render.image_settings.file_format = 'JPEG'
scene.render.image_settings.quality = 88
scene.view_settings.view_transform = 'AgX'
records = []
for name in ['lakeside', 'lake_pier', 'gray_pier', 'bell_park_pier']:
    source = LOCATION_DIR / (name + '_8k.hdr')
    image = bpy.data.images.load(str(source), check_existing=False)
    assert tuple(image.size) == (8192, 4096), name
    image.scale(768, 384)
    preview = LOCATION_DIR / (name + '_preview.jpg')
    image.save_render(str(preview), scene=scene)
    records.append({'id': name, 'runtime': str(source.relative_to(ROOT)),
                    'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                    'runtime_size': [8192, 4096], 'preview_size': [768, 384],
                    'preview_sha256': hashlib.sha256(preview.read_bytes()).hexdigest()})
    bpy.data.images.remove(image)
(ROOT / 'docs/locations/optimization.json').write_text(json.dumps(records, indent=2) + '\n')
print(json.dumps(records, indent=2))
