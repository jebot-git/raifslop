"""Package the four isolated viewer exports from the same committed source."""
import json,shutil,subprocess,zipfile
from pathlib import Path
from build import ROOT,SOURCE,BUILD,VERSION,TARGETS,digest
from audit import audit
revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
assert not subprocess.check_output(['git','status','--porcelain'],cwd=ROOT).strip(),'Commit before packaging'
assert (BUILD/'runtime-validation.json').exists(),'Run exported runtime validation'
records=[]
for target in TARGETS:
 record=json.loads((BUILD/f'manifest-{target}.json').read_text())
 assert record['commit']==revision and not record['development'],('Stale/development build',target)
 actual={str(p.relative_to(BUILD/target)):digest(p) for p in (BUILD/target).rglob('*') if p.is_file()}
 assert actual==record['files'],('Changed artifacts',target)
 artifact=BUILD/target/('RealAIFishing-SplatTesting.apk' if target in ['Quest','Pico'] else 'RealAIFishing-SplatTesting.pck')
 record['audit']=audit(artifact);records.append(record)
release=BUILD/'release';release.mkdir(exist_ok=True)
for target in ['Linux','Windows']:
 folder=BUILD/'packages'/target;folder.mkdir(parents=True,exist_ok=True)
 for p in (BUILD/target).iterdir():
  if p.is_file():shutil.copy2(p,folder/p.name)
  elif p.is_dir():shutil.copytree(p,folder/p.name,dirs_exist_ok=True)
 shutil.copy2(ROOT/'ASSET_CREDITS.md',folder/'ASSET_CREDITS.md')
 shutil.copy2(SOURCE/'vendor/gdgs/LICENSE',folder/'GDGS-LICENSE.txt')
 shutil.copy2(SOURCE/'CONTROLS.txt',folder/'CONTROLS.txt')
 for name,args in [('Desktop','--xr-mode off --'),('VR','--xr-mode on -- --xr')]:
  if target=='Linux':
   launcher=folder/(name+'.sh');launcher.write_text('#!/bin/sh\ncd -- "$(dirname -- "$0")" || exit 1\nexec ./RealAIFishing-SplatTesting.x86_64 '+args+' "$@"\n');launcher.chmod(0o755)
  else:(folder/(name+'.cmd')).write_bytes(('@echo off\r\ncd /d "%~dp0"\r\n"%~dp0RealAIFishing-SplatTesting.exe" '+args+' %*\r\n').encode())
 if target=='Linux':
  p=folder/'WiVRn.sh';p.write_text('#!/bin/sh\ncd -- "$(dirname -- "$0")" || exit 1\nexport XR_RUNTIME_JSON="${XR_RUNTIME_JSON:-/usr/share/openxr/1/openxr_wivrn.json}"\nexec ./RealAIFishing-SplatTesting.x86_64 --xr-mode on -- --xr "$@"\n');p.chmod(0o755)
 name=f'HybridSplatViewer-{VERSION}-{target}-x86_64'
 with zipfile.ZipFile(release/(name+'.zip'),'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for p in sorted(folder.rglob('*')):
   if p.is_file():z.write(p,Path(name)/p.relative_to(folder))
for target in ['Quest','Pico']:shutil.copy2(BUILD/target/'RealAIFishing-SplatTesting.apk',release/f'HybridSplatViewer-{VERSION}-{target}.apk')
with zipfile.ZipFile(release/f'HybridSplatViewer-{VERSION}-Notices.zip','w',zipfile.ZIP_DEFLATED) as z:
 z.write(ROOT/'ASSET_CREDITS.md','ASSET_CREDITS.md');z.write(SOURCE/'vendor/gdgs/LICENSE','GDGS-LICENSE.txt');z.write(SOURCE/'CONTROLS.txt','CONTROLS.txt')
 for p in (ROOT/'addons/godotopenxrvendors').rglob('*'):
  if p.is_file() and any(n in p.name.upper() for n in ['LICENSE','NOTICE','COPYING']):z.write(p,'notices/'+str(p.relative_to(ROOT/'addons/godotopenxrvendors')))
(release/'build-manifest.json').write_text(json.dumps({'version':VERSION,'commit':revision,'targets':records,'runtime_validation':json.loads((BUILD/'runtime-validation.json').read_text()),'scope':'Offline two-area viewer; no fishing gameplay, multiplayer or voice; XR hardware run deferred'},indent=2)+'\n')
(release/'SHA256SUMS').write_text(''.join(digest(p)+'  '+p.name+'\n' for p in sorted(release.iterdir()) if p.is_file() and p.name!='SHA256SUMS'))
print('Packaged '+str(release))
