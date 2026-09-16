"""Inspect the actual exported payloads and Android permissions."""
import argparse,json,sys,subprocess
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from audit_release import Pack,APK
FORBIDDEN=('scripts/network/','scripts/voice/','addons/twovoip/','addons/godot_ai/','server','credentials','world.json','500k','inspection_')

def audit(path):
 pack=APK(path) if path.suffix=='.apk' else Pack(path)
 names=set(pack.names())
 for name in names:
  assert not any(term in name.lower() for term in FORBIDDEN),('Forbidden payload',name)
  pack.read(name) # Verify all entry lengths and PCK hashes, not just the directory.
 required=['main.tscn','release.gd','locations.gd','base.gd','location_profiles.json','placement.json','lake_pier_near.ply','simons_town_rocks_near.ply','lake_pier_pano.png','simons_town_rocks_pano.png','simons_panorama_irradiance.exr']
 for name in required:assert any(n in names for n in [name,name+'.remap',name+'.import']),('Missing',name)
 assert 'project.binary' in names
 permissions=[];package=''
 if path.suffix=='.apk':
  aapt=Path.home()/'Android/Sdk/build-tools/36.1.0/aapt'
  result=subprocess.check_output([str(aapt),'dump','permissions',str(path)],text=True)
  permissions=result.splitlines()
  assert 'android.permission.INTERNET' not in result,result
  assert 'android.permission.RECORD_AUDIO' not in result,result
  package=subprocess.check_output([str(aapt),'dump','badging',str(path)],text=True).splitlines()[0]
  assert 'org.jebot.raifslop.splattesting.' in package,package
  with pack.file as z:
   assert not any('twovoip' in n.lower() or 'godot_ai' in n.lower() for n in z.namelist())
 else:
  assert not any('twovoip' in p.name.lower() for p in path.parent.rglob('*'))
 return {'artifact':str(path),'entries':len(names),'offline_payload':True,'package':package,'permissions':permissions,'passed':True}

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('artifacts',nargs='+',type=Path);p.add_argument('--report',type=Path);args=p.parse_args()
 results=[audit(path) for path in args.artifacts]
 text=json.dumps(results,indent=2)+'\n'
 if args.report:args.report.write_text(text)
 print(text)
