"""Independent navigation audit for every authored putting lane."""
import json,math,unittest
from collections import deque
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
STEP=.12
R=.022

def distance_segment(p,a,b):
 dx=b[0]-a[0];dz=b[1]-a[1]
 t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/(dx*dx+dz*dz)))
 return math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dz)

def reachable(h):
 nx=math.ceil(h['width']/STEP);nz=math.ceil(h['length']/STEP)
 dx=h['width']/nx;dz=h['length']/nz
 def index(p):return (min(nx-1,max(0,int((p[0]+h['width']/2)/dx))),min(nz-1,max(0,int((p[1]+h['length'])/dz))))
 start=index(h['tee']);goal=index(h['cup'])
 allowed=set()
 for x in range(nx):
  for z in range(nz):
   p=(-h['width']/2+(x+.5)*dx,-h['length']+(z+.5)*dz)
   if any(math.dist(p,o['center'])<o['radius']+R for o in h['obstacles']):continue
   if any(distance_segment(p,o['a'],o['b'])<o['radius']+R for o in h.get('rails',[])):continue
   if any(all(abs(p[i]-o['center'][i])<o['size'][i]/2+R for i in [0,1]) for o in h['hazards']):continue
   allowed.add((x,z))
 if start not in allowed or goal not in allowed:return False
 queue=deque([start]);visited={start}
 while queue:
  p=queue.popleft()
  if p==goal:return True
  for ox,oz in [(1,0),(-1,0),(0,1),(0,-1)]:
   n=(p[0]+ox,p[1]+oz)
   if n in allowed and n not in visited:visited.add(n);queue.append(n)
 return False

class Layouts(unittest.TestCase):
 def test_all_courses_have_reachable_cups_and_unique_layouts(self):
  paths=sorted((ROOT/'assets/minigolf/courses').glob('*.json'));self.assertEqual(len(paths),12)
  fingerprints=set()
  for path in paths:
   course=json.loads(path.read_text());self.assertEqual(len(course['holes']),18)
   for hole in course['holes']:
    with self.subTest(course=course['id'],hole=hole['number']):
     self.assertTrue(reachable(hole),'No dry ball-width route from tee to cup')
     self.assertIn(hole['par'],[2,3,4])
   geometry=[{k:v for k,v in h.items() if k not in ['name','hint']} for h in course['holes']]
   fingerprint=json.dumps(geometry,sort_keys=True);self.assertNotIn(fingerprint,fingerprints);fingerprints.add(fingerprint)

if __name__=='__main__':unittest.main()
