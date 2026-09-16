"""Build a separate, reviewable Linux/PC-VR prototype with commit and hash metadata."""
import hashlib,json,os,shutil,subprocess,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'builds/BBQ-Prototype'
version='0.1.9-bbq.1'
revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
if subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True).strip():
 raise SystemExit('Commit the prototype before packaging it.')
if OUT.exists():shutil.rmtree(OUT)
OUT.mkdir(parents=True)
godot=os.environ.get('GODOT_BIN','godot')
env=dict(os.environ,XDG_CONFIG_HOME=str(ROOT/'builds/config'),XDG_DATA_HOME='/tmp/raif-bbq-build')
for label,args in [('import',['--editor','--import','--quit']),('export',['--export-release','Linux',str(OUT/'RealAIFishing.x86_64')])]:
 log=ROOT/'builds'/('bbq-'+label+'.log')
 with log.open('w') as f:r=subprocess.run([godot,'--headless','--path',str(ROOT),'--xr-mode','off',*args],env=env,stdout=f,stderr=subprocess.STDOUT)
 text=log.read_text(errors='replace')
 if r.returncode or any(x in text for x in ['SCRIPT ERROR:','Cannot export project','Export failed','HDR compression failed']):raise SystemExit(f'{label} failed: {log}')
 print(label+' passed',flush=True)
for name,args in [('Desktop.sh','--xr-mode off'),('VR.sh','--xr-mode on'),('Server.sh','--headless --xr-mode off -- --server')]:
 path=OUT/name;path.write_text('#!/bin/sh\ncd -- "$(dirname -- "$0")" || exit 1\nexec ./RealAIFishing.x86_64 '+args+' "$@"\n');path.chmod(0o755)
shutil.copy2(ROOT/'docs/BBQ_PROTOTYPE.md',OUT/'README.md')
shutil.copy2(ROOT/'ASSET_CREDITS.md',OUT/'ASSET_CREDITS.md')
for folder in [ROOT,ROOT/'addons']:
 for path in folder.rglob('*') if folder.name=='addons' else folder.iterdir():
  if path.is_file() and any(key in path.name.upper() for key in ['LICENSE','LICENCE','COPYING','NOTICE']):
   target=OUT/'notices'/path.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,target)
files={}
for p in sorted(OUT.rglob('*')):
 if p.is_file() and p.name!='build-manifest.json':
  with p.open('rb') as f:files[str(p.relative_to(OUT))]=hashlib.file_digest(f,'sha256').hexdigest()
(OUT/'build-manifest.json').write_text(json.dumps({'version':version,'branch':'prototype/shore-bbq','commit':revision,'files':files},indent=2)+'\n')
archive=ROOT/'builds'/('RealAIFishing-'+version+'-Linux-x86_64.zip')
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
 for p in sorted(OUT.rglob('*')):
  if p.is_file():z.write(p,'RealAIFishing-BBQ-Prototype/'+str(p.relative_to(OUT)))
with archive.open('rb') as f:digest=hashlib.file_digest(f,'sha256').hexdigest()
archive.with_suffix('.zip.sha256').write_text(digest+'  '+archive.name+'\n')
print('BUILT',archive,flush=True)
