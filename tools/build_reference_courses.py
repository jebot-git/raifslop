#!/usr/bin/env python3
"""Rebuild the selected course adaptation from archived OSM and GLO-90 data.
Requires numpy, Pillow, shapely. No network is used by this authoring step.
Horizontal outlines are mapped; greens, bunker depths and individual trees are approximations.
"""
import argparse, json, math, random, xml.etree.ElementTree as ET
from pathlib import Path
import numpy as np
from build_course_lanes import build as connect_play_lanes
from PIL import Image, ImageDraw
from shapely.geometry import Polygon, LineString, Point, box
from shapely.ops import polygonize, unary_union, transform
from shapely import contains_xy, distance, points as geo_points
ROOT=Path(__file__).resolve().parents[1]
REF=ROOT/'source/course_references'
DEST=ROOT/'addons/golfminus'
CONFIG={
 'cypress':dict(boundary='36435651', relation=False, name='Cypress Point Club', kind='links', density=.28, seed=20260923, reference='https://video.usga.org/videos/2025/08/condoleezza-rice-narrates-every-hole-at-cypress-po-6377527661112.html'),
 'poppy':dict(boundary='11841797', relation=True, name='Poppy Hills Golf Course', kind='parkland', density=.80, seed=20260924, reference='https://poppyhillsgolf.ncga.org/course-tour'),
}
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--course', choices=list(CONFIG), action='append')
args=parser.parse_args()
nodes={}; ways={}; relations={}
for f in sorted((REF/'raw').glob('*.xml')):
 r=ET.parse(f).getroot()
 for n in r.findall('node'):nodes[n.attrib['id']]=(float(n.attrib['lon']),float(n.attrib['lat']))
 for w in r.findall('way'):ways[w.attrib['id']]=w
 for w in r.findall('relation'):relations[w.attrib['id']]=w
def tags(w):return {t.attrib['k']:t.attrib['v'] for t in w.findall('tag')}
def coords(w):return [nodes[n.attrib['ref']] for n in w.findall('nd')]
def polygon(w):
 if w.tag=='way':
  p=coords(w)
  return Polygon(p).buffer(0) if len(p)>3 and p[0]==p[-1] else Polygon()
 outer=[];inner=[]
 for m in w.findall('member'):
  if m.attrib['type']!='way' or m.attrib['ref'] not in ways:continue
  (inner if m.attrib.get('role')=='inner' else outer).append(LineString(coords(ways[m.attrib['ref']])))
 return unary_union(list(polygonize(outer))).difference(unary_union(list(polygonize(inner))))
def parts(g):return [g] if g.geom_type=='Polygon' else [p for p in getattr(g,'geoms',[]) if p.geom_type=='Polygon']
def arrays(g):return [{'points':[[round(x,2),round(z,2)] for x,z in p.exterior.coords], 'holes':[[[round(x,2),round(z,2)] for x,z in ring.coords] for ring in p.interiors]} for p in parts(g)]
ALL=list(ways.values())+list(relations.values())
for cid in args.course or CONFIG:
 spec=CONFIG[cid];boundary_id=spec['boundary'];rel=spec['relation']
 boundary_ll=polygon((relations if rel else ways)[boundary_id]);center=boundary_ll.centroid
 lon0,lat0=center.x,center.y;mx=111320*math.cos(math.radians(lat0));mz=111320
 def project(x,y,z=None):return ((np.asarray(x)-lon0)*mx,-(np.asarray(y)-lat0)*mz)
 def metric(g):return transform(project,g)
 boundary=metric(boundary_ll)
 minx,minz,maxx,maxz=boundary.bounds
 bounds=[math.floor((minx-90)/96)*96,math.floor((minz-90)/96)*96,math.ceil((maxx+90)/96)*96,math.ceil((maxz+90)/96)*96]
 extent=box(*bounds);x0,z0,x1,z1=bounds
 holes=[]
 for w in ways.values():
  t=tags(w)
  if t.get('golf')!='hole' or not boundary_ll.buffer(.0001).contains(Point(coords(w)[0])):continue
  route=metric(LineString(coords(w)));holes.append((int(t['ref']),w,t,route))
 holes.sort(key=lambda x:x[0]);assert [h[0] for h in holes]==list(range(1,19))
 kinds={k:[] for k in ['fairway','green','tee','bunker','water','wood']}
 for w in ALL:
  t=tags(w);kind=t.get('golf','')
  if t.get('natural')=='water' or t.get('water'):kind='water'
  if t.get('natural')=='wood' or t.get('landuse')=='forest':kind='wood'
  if kind not in kinds:continue
  g=polygon(w)
  if g.is_empty or not g.intersects(boundary_ll.buffer(.00015)):continue
  g=metric(g).intersection(boundary.buffer(15)).simplify(.35,preserve_topology=True)
  if not g.is_empty:kinds[kind].append(g)
 polys={k:unary_union(v) for k,v in kinds.items()}
 # Reconstruct sea from the mapped coast, closing it at the rectangular world edge.
 coast=[]
 for w in ways.values():
  if tags(w).get('natural')=='coastline':
   line=metric(LineString(coords(w))).intersection(extent)
   if not line.is_empty:coast.append(line)
 ocean=Polygon()
 if coast:
  regions=list(polygonize(unary_union([extent.boundary,*coast])))
  land=max(regions,key=lambda g:g.intersection(boundary).area) if regions else extent
  ocean=extent.difference(land)
 polys['water']=unary_union([polys['water'],ocean])
 width,height=int(x1-x0)+1,int(z1-z0)+1
 lie_image=Image.new('L',(width,height),0);draw=ImageDraw.Draw(lie_image)
 def paint(g,value):
  for p in parts(g):
   draw.polygon([(x-x0,z-z0) for x,z in p.exterior.coords],fill=value)
   for ring in p.interiors:draw.polygon([(x-x0,z-z0) for x,z in ring.coords],fill=0)
 # 0 rough, 1 fairway, 2 fringe, 3 green, 4 sand, 5 water, 6 out.
 paint(unary_union([polys['fairway'],polys['tee']]),1)
 paint(polys['green'].buffer(2.2),2);paint(polys['green'],3);paint(polys['bunker'],4);paint(polys['water'],5)
 lies=np.array(lie_image)
 gx,gz=np.meshgrid(np.arange(x0,x1+1,2),np.arange(z0,z1+1,2))
 geo_lon=lon0+gx/mx;geo_lat=lat0-gz/mz
 dem=json.loads((REF/(cid+'_elevation.json')).read_text());west,south,east,north=dem['bounds'];size=dem['size']
 u=np.clip((geo_lon-west)/(east-west)*(size-1),0,size-1.000001);v=np.clip((geo_lat-south)/(north-south)*(size-1),0,size-1.000001)
 ix=u.astype(int);iz=v.astype(int);fx=u-ix;fz=v-iz;grid=np.array(dem['elevation']).reshape(size,size)
 terrain=(grid[iz,ix]*(1-fx)+grid[iz,ix+1]*fx)*(1-fz)+(grid[iz+1,ix]*(1-fx)+grid[iz+1,ix+1]*fx)*fz
 def at(g):
  p=g if isinstance(g,Point) else g.centroid
  return float(terrain[round((p.y-z0)/2),round((p.x-x0)/2)])
 # Detailed green grades are not in the 90 m DEM. Flatten within each mapped
 # green, blending into the actual regional elevation over an 8 m collar.
 for green in parts(polys['green']):
  a,b,c,d=green.bounds;mask=(gx>a-8)&(gx<c+8)&(gz>b-8)&(gz<d+8)
  dist=distance(green,geo_points(gx[mask],gz[mask]));weight=np.clip(1-dist/8,0,1)
  terrain[mask]=terrain[mask]*(1-weight)+at(green)*weight
 # Carve real water outlines, keeping horizontal water above its basin floor.
 water_records=[]
 for water in parts(polys['water']):
  level=0.0 if water.intersects(extent.boundary) else at(water)-.5
  a,b,c,d=water.bounds;mask=(gx>a-4)&(gx<c+4)&(gz>b-4)&(gz<d+4)
  dist=distance(water,geo_points(gx[mask],gz[mask]));blend=np.clip(1-dist/4,0,1)
  terrain[mask]=terrain[mask]*(1-blend)+np.minimum(terrain[mask],level-1.5)*blend
  for rec in arrays(water):rec['level']=round(level,3);water_records.append(rec)
 sandmask=lies[::2,::2]==4;terrain[sandmask]-=.5
 routes=[]
 for number,w,t,line in holes:
  path=list(line.coords);start=path[0];pin=path[-1];length=line.length
  # Tee options use mapped tee polygons near the route, not arbitrary hole offsets.
  tees=[]
  for tee in parts(polys['tee']):
   p=tee.centroid;along=line.project(p)
   if along<length*.34 and line.distance(p)<25:tees.append((along,[p.x,p.y]))
  tees.sort();options={'back':list(start),'club':tees[len(tees)//2][1] if tees else list(start),'forward':tees[-1][1] if tees else list(start)}
  routes.append(dict(name=t.get('name',f'Hole {number}'),par=int(t['par']),length=round(length,2),bend=0,width=20,green_radius=12,green_slope=[0,0],elevation=0,bunkers=[],water=False,tee_options={'back':0,'club':0,'forward':0},routing={'origin':[round(n,2) for n in start],'yaw':math.degrees(math.atan2(-(pin[0]-start[0]),-(pin[1]-start[1]))),'path':[[round(x,2),round(z,2)] for x,z in path],'pin':[round(n,2) for n in pin],'tees':{k:[round(n,2) for n in v] for k,v in options.items()},'osm_way':int(w.attrib['id'])}))
 # The lodge/pro shop side of the opening tee remains outside playing corridors.
 clubhouse=[routes[0]['routing']['origin'][0]-35,routes[0]['routing']['origin'][1]+25]
 playable=unary_union([polys[k] for k in ['fairway','green','tee','bunker','water']]).buffer(14)
 rng=random.Random(spec['seed']);trees=[]
 for z in np.arange(minz,maxz,18):
  for x in np.arange(minx,maxx,18):
   p=Point(x+rng.uniform(-6,6),z+rng.uniform(-6,6))
   if not boundary.contains(p) or playable.contains(p) or p.distance(Point(clubhouse))<20:continue
   if cid=='cypress' and p.x<minx+350:continue # exposed coastal dunes
   if rng.random()>spec['density']:continue
   trees.append([round(p.x,2),round(p.y,2),round(rng.uniform(.85,1.55),2)])
 folder=DEST/'assets/course_data'/cid;folder.mkdir(parents=True,exist_ok=True)
 (folder/'lies.bin').write_bytes(lies.astype('uint8').tobytes());(folder/'height.bin').write_bytes(terrain.astype('<f4').tobytes())
 geometry={k:arrays(g) for k,g in polys.items()};geometry['boundary']=arrays(boundary)
 (folder/'outlines.json').write_text(json.dumps(geometry,separators=(',',':'))+'\n')
 course=dict(id=cid,name=spec['name'],region='MONTEREY PENINSULA · CALIFORNIA',subtitle='Mapped 18-hole course · terrain adaptation',kind=spec['kind'],seed=spec['seed'],wind=[2.2,0,1.0],latitude=lat0,longitude=lon0,panorama='dalkey_view',panorama_yaw=0,holes=routes)
 course['layout']=dict(status='Mapped routing and outlines; GLO-90 terrain adaptation, approximate greens and tree placement',revision=1,bounds=[x0,z0,x1-x0,z1-z0],clubhouse=clubhouse,trees=trees,rocks=[],hazards=[],water_polygons=water_records,surface={'path':f'res://addons/golfminus/assets/course_data/{cid}/','origin':[x0,z0],'width':width,'height':height,'height_step':2},reference={'osm':'https://www.openstreetmap.org/'+('relation/' if rel else 'way/')+boundary_id,'elevation':'https://open-meteo.com/en/docs/elevation-api','map':spec['reference'],'horizontal_units':'metres, local equirectangular WGS84 projection; +X east, -Z north','accuracy':'OSM mapping and 100 regional DEM samples; not a surveyed golf simulator replica'})
 (DEST/'courses'/f'{cid}.json').write_text(json.dumps(course,indent=2)+'\n')
 connect_play_lanes(cid)
 print(cid,'holes',len(routes),'bounds',course['layout']['bounds'],'trees',len(trees),'fairways',len(parts(polys['fairway'])),'greens',len(parts(polys['green'])),'bunkers',len(parts(polys['bunker'])),'water',len(water_records),flush=True)
