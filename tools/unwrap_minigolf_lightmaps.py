"""Generate one xatlas UV2 atlas per exact runtime course (requires numpy, xatlas)."""
import json
import sys
from pathlib import Path
import numpy as np
import xatlas
ROOT=Path(__file__).resolve().parents[1]
for location in sys.argv[1:]:
 path=ROOT/'source/minigolf/lighting'/(location+'-geometry.json')
 records=json.loads(path.read_text());atlas=xatlas.Atlas();welded_faces=[]
 for record in records:
  positions,inverse=np.unique(np.round(np.asarray(record['vertices'],dtype=np.float32),6),axis=0,return_inverse=True)
  faces=inverse[np.asarray(record['faces'],dtype=np.uint32)].astype(np.uint32)
  welded_faces.append(faces);atlas.add_mesh(positions,faces)
 pack=xatlas.PackOptions();pack.resolution=2048;pack.padding=8;pack.bilinear=True
 chart=xatlas.ChartOptions();chart.max_iterations=2
 atlas.generate(chart,pack)
 assert atlas.atlas_count==1,'Expected one shared atlas'
 output=[]
 for i,record in enumerate(records):
  vertices,indices,uv=atlas[i]
  assert np.array_equal(vertices[indices],welded_faces[i]),'Face order changed'
  corners=uv[indices[:,::-1]].reshape(-1,2)
  # xatlas UV origin is top-left; Godot consumes it directly, Blender flips V.
  output.append({'path':record['path'],'surface':record['surface'],'uv2':corners.tolist()})
 (path.parent/(location+'-uv2.json')).write_text(json.dumps(output,separators=(',',':')))
 print('MINIGOLF_XATLAS',location,atlas.width,atlas.height,'charts',atlas.chart_count,'utilization',atlas.utilization,flush=True)
