"""Fetch public authoring inputs once; generated course builds run offline."""
from pathlib import Path
import urllib.request, urllib.parse, xml.etree.ElementTree as E, json, time
root=Path(__file__).resolve().parents[1]/'source/course_references'
(root/'raw').mkdir(parents=True,exist_ok=True)
for name,bounds in [('cypress',(-121.982,36.570,-121.953,36.587)),('poppy',(-121.949,36.574,-121.931,36.596))]:
 path=root/'raw'/f'{name}-osm.xml'
 url='https://api.openstreetmap.org/api/0.6/map?bbox='+','.join(map(str,bounds))
 if not path.exists():
  print('Fetching',name,url,flush=True)
  req=urllib.request.Request(url,headers={'User-Agent':'RealAIFishing-course-authoring/1.0'})
  with urllib.request.urlopen(req,timeout=90) as response: data=response.read()
  E.fromstring(data);path.write_bytes(data)
  print(name,len(data),'OSM bytes',flush=True)
 west,south,east,north=bounds
 # Match the previous ten-by-ten regional GLO-90 terrain workflow.
 lats=[];lons=[]
 for row in range(10):
  for col in range(10):lats.append(south+(north-south)*row/9);lons.append(west+(east-west)*col/9)
 url='https://api.open-meteo.com/v1/elevation?'+urllib.parse.urlencode({'latitude':','.join(f'{x:.7f}' for x in lats),'longitude':','.join(f'{x:.7f}' for x in lons)})
 dem_path=root/f'{name}_elevation.json'
 if not dem_path.exists():
  print('Fetching',name,'100 elevation samples',flush=True)
  with urllib.request.urlopen(url,timeout=90) as response:data=json.load(response)
  assert len(data['elevation'])==100
  dem_path.write_text(json.dumps({'bounds':bounds,'size':10,'elevation':data['elevation'],'source':url,'retrieved':'2026-09-22'},indent=2)+'\n')

# OSM map tiles can omit distant members of a multipolygon relation.
path=root/'raw'/'poppy-boundary-osm.xml'
if not path.exists():
 with urllib.request.urlopen('https://api.openstreetmap.org/api/0.6/relation/11841797/full',timeout=60) as response:
  data=response.read()
 E.fromstring(data);path.write_bytes(data)
