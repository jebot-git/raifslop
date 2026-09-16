"""Blender/NumPy: location-specific near-splat cleanup with floor exclusion."""
from pathlib import Path
import json,numpy as np
ROOT=Path(__file__).resolve().parents[2];V=ROOT/'test-results/splat-experiment/viewer'
profiles=json.loads((V/'location_profiles.json').read_text())
for id,c in profiles.items():
 source=V/f'{id}_500k.ply'
 if not source.exists():continue
 with source.open('rb') as f:
  header=[]
  while True:
   line=f.readline().decode().strip();header.append(line)
   if line=='end_header':break
  a=np.frombuffer(f.read(),dtype='<f4').reshape(-1,14).copy()
 world=a[:,:3]*[1,-1,-1]*c['scale'];alpha=1/(1+np.exp(-a[:,6]));sigma=np.exp(a[:,7:10]).max(axis=1)*c['scale']
 radius=np.linalg.norm(world[:,[0,2]],axis=1)
 keep=np.isfinite(a).all(axis=1)&(alpha>=.035)&(radius<c['near_radius'])&(sigma<.32)&(world[:,1]<16)
 stages={'source':len(a),'near_finite':int(keep.sum())}
 # Water reflections are below the physical water surface; retain low rock shoulders.
 keep &= world[:,1] > c['water_y']+.12
 stages['above_water']=int(keep.sum())
 front=-2.15 if id=='lake_pier' else -3.65
 width=4.0 if id=='lake_pier' else 5.0
 open_water=(world[:,2]<front)&(abs(world[:,0])<np.maximum(width,-world[:,2]*.35))
 keep &= ~open_water
 stages['open_water_cleared']=int(keep.sum())
 if id=='lake_pier':
  # Keep photographed front-left navigation markers; remove their generated copies.
  keep &= ~((world[:,0]<1.0+4.25*sigma)&(world[:,2]<4.3+4.25*sigma))
  # Reject finite Gaussian support touching the enlarged billboard and its front face.
  low=np.array([2.5,-1.8,-1.3]);high=np.array([3.45,1.3,3.2])
  intersects=np.all((world+4.25*sigma[:,None]>low)&(world-4.25*sigma[:,None]<high),axis=1)
  keep &= ~intersects
  stages['billboard_support_cleared']=int(keep.sum())
 else:
  # Authored left boulder row takes precedence over the small foreground floaters.
  low=np.array([-8.8,-2.8,-4.2]);high=np.array([-4.5,1.5,8.8])
  intersects=np.all((world+4.25*sigma[:,None]>low)&(world-4.25*sigma[:,None]<high),axis=1)
  keep &= ~intersects
 stages['reported_artifacts_removed']=int(keep.sum())
 clearance=np.full(len(a),np.inf)
 for p in c['manifest']['colliders']:
  if p['role']!='floor':continue
  center=np.array(p['position'])[[0,2]]+[0,-.65];half=np.array(p['size'])[[0,2]]*.5
  yaw=p.get('yaw',0);co,si=np.cos(yaw),np.sin(yaw)
  q=(world[:,[0,2]]-center)@np.array([[co,si],[-si,co]])
  distance=np.linalg.norm(np.maximum(abs(q)-half,0),axis=1)
  clearance=np.minimum(clearance,distance-4.25*sigma)
 keep &= clearance>.2
 stages['walkable_support_excluded']=int(keep.sum())
 outer=np.clip((c['near_radius']-radius)/8,0,1);outer*=outer*(3-2*outer)
 inner=np.clip((clearance-.2)/.8,0,1);inner*=inner*(3-2*inner)
 fade=np.clip(alpha*outer*inner,1e-6,1-1e-6)
 keep &= fade>=.01
 result=a[keep].copy();result[:,6]=np.log(fade[keep]/(1-fade[keep]))
 assert len(result)>0 and clearance[keep].min()>.2
 name=f'{id}_near.ply'
 with (V/name).open('wb') as f:
  f.write(('\n'.join(f'element vertex {len(result)}' if l.startswith('element vertex ') else l for l in header)+'\n').encode());f.write(result.astype('<f4').tobytes())
 place=json.loads((V/'placement.json').read_text());place[name]={'center':result[:,:3].mean(axis=0,dtype=np.float64).tolist(),'count':len(result)}
 (V/'placement.json').write_text(json.dumps(place,indent=2)+'\n')
 report={'location':id,'count':len(result),'source_count':len(a),'stages':stages,'scale':c['scale'],'min_support_clearance':float(clearance[keep].min()),'walkable_overlaps':0,'ply_bytes':(V/name).stat().st_size}
 (V/f'{id}_cleanup.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
