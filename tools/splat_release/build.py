"""Build the isolated offline splat viewer; never export the main game project."""
from pathlib import Path
import argparse, hashlib, json, os, re, shutil, subprocess, zipfile
ROOT=Path(__file__).resolve().parents[2]
SOURCE=Path(__file__).resolve().parent
BUILD=ROOT/'builds/splat-testing'
PROJECT=BUILD/'project'
VERSION='0.1.0-splat.1'
TARGETS=['Linux','Windows','Quest','Pico']
GODOT=os.environ.get('GODOT_BIN',str(Path.home()/'.local/bin/Godot_v4.7.2-stable_linux.x86_64'))
SDK=Path(os.environ.get('ANDROID_SDK_ROOT',str(Path.home()/'Android/Sdk')))
JDK=Path(os.environ.get('JAVA_HOME',str(Path.home()/'.local/share/entryway-toolchains/jdk-17.0.20.1+1')))

def digest(path):
 with path.open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()

def copy(source,dest):
 source,dest=Path(source),Path(dest)
 dest.parent.mkdir(parents=True,exist_ok=True)
 if not dest.exists() or digest(source)!=digest(dest):shutil.copy2(source,dest)
 return str(dest)

def run(command,label,env=None,timeout=1800):
 log=BUILD/(label+'.log')
 with log.open('w') as f:r=subprocess.run(command,cwd=ROOT,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=timeout)
 text=log.read_text(errors='replace')
 if r.returncode or any(x in text for x in ['SCRIPT ERROR:','Export failed','Cannot export project']):raise SystemExit(f'{label} failed: {log}')
 print(label+' complete',flush=True)

def prepare():
 PROJECT.mkdir(parents=True,exist_ok=True)
 for name in ['project.godot','base.gd','release.gd']:copy(SOURCE/name,PROJECT/name)
 for path in (SOURCE/'data').iterdir():
  if path.is_file() and not path.name.endswith(('.import','.uid')):copy(path,PROJECT/path.name)
 shutil.copytree(SOURCE/'vendor/gdgs',PROJECT/'addons/gdgs',dirs_exist_ok=True,copy_function=copy)
 shutil.copytree(ROOT/'addons/godotopenxrvendors',PROJECT/'addons/godotopenxrvendors',dirs_exist_ok=True,copy_function=copy)
 for name in ['openxr_action_map.tres','scripts/locomotion.gd','scripts/simons_rear_details.gd','assets/icon.svg','assets/environment/shore_details/simons_granite.png','assets/environment/rivers/vegetation.gdshader','assets/environment/baked_foreground.gdshader','shaders/panorama_sampling.gdshaderinc']:
  copy(ROOT/name,PROJECT/name)
 for location in ['lake_pier','simons_town_rocks']:
  for folder in ['assets/models/locations/lit','assets/textures/lighting']:
   for path in (ROOT/folder).glob(location+'*'):
    if path.is_file():copy(path,PROJECT/folder/path.name)
 for name in ['bridge_ground.gdshader','fishing_plan_poster.svg','location_ground.gdshader','location_water.gdshader','panosphere.gdshader','lake_background.gdshaderinc']:
  copy(ROOT/'tools/splat_experiment'/name,PROJECT/name)
 text=(ROOT/'tools/splat_experiment/locations.gd').read_text().replace('extends "res://hybrid.gd"','extends "res://base.gd"')
 # Packaged res:// is read-only. Every inspection, metric and report goes into this app's user://.
 text=re.sub(r'FileAccess.open\("res://"\s*\+\s*(.*?),FileAccess.WRITE\)',r'FileAccess.open(report_path(\1),FileAccess.WRITE)',text)
 text=text.replace('FileAccess.open("res://xr_session.json",FileAccess.WRITE)','FileAccess.open(report_path("xr_session.json"),FileAccess.WRITE)')
 text=text.replace('location_id = chosen','if chosen not in ["lake_pier","simons_town_rocks"]:chosen="lake_pier"\n\tlocation_id = chosen',1)
 (PROJECT/'locations.gd').write_text(text)
 (PROJECT/'main.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://release.gd" id="1"]\n[node name="SplatTesting" type="Node3D"]\nscript = ExtResource("1")\n')
 presets=(ROOT/'export_presets.cfg').read_text()
 presets=presets.replace('*.vrm,assets/models/locations/manifest.json,','location_profiles.json,placement.json,')
 presets=presets.replace('exclude_filter="','exclude_filter="addons/gdgs/editor/*,addons/gdgs/plugin.gd,addons/gdgs/plugin.cfg,addons/gdgs/cli/*,addons/gdgs/tests/*,')
 presets=presets.replace('RealAIFishing','RealAIFishing-SplatTesting').replace('Real AI Fishing','Real AI Fishing Splat Testing')
 presets=presets.replace('org.jebot.raifslop.quest','org.jebot.raifslop.splattesting.quest').replace('org.jebot.raifslop.pico','org.jebot.raifslop.splattesting.pico')
 presets=presets.replace('permissions/internet=true','permissions/internet=false').replace('permissions/record_audio=true','permissions/record_audio=false')
 presets=presets.replace('version/code=7','version/code=1').replace('version/name="0.1.6"',f'version/name="{VERSION}"').replace('0.1.6.0','0.1.0.1')
 presets=re.sub(r'meta_xr_features/(body|hand|eye|face)_tracking=1',r'meta_xr_features/\1_tracking=0',presets)
 (PROJECT/'export_presets.cfg').write_text(presets)
 copy(ROOT/'ASSET_CREDITS.md',PROJECT/'ASSET_CREDITS.md')
 inputs={str(p.relative_to(PROJECT)):digest(p) for p in PROJECT.rglob('*') if p.is_file() and '.godot' not in p.parts and 'android' not in p.parts and not p.name.endswith(('.uid','.import'))}
 (BUILD/'source-inputs.json').write_text(json.dumps(inputs,indent=2)+'\n')
 print('Prepared isolated viewer '+str(PROJECT),flush=True)

def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--prepare-only',action='store_true');parser.add_argument('--target',choices=['all']+TARGETS,default='all');parser.add_argument('--development',action='store_true')
 a=parser.parse_args();BUILD.mkdir(parents=True,exist_ok=True)
 revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
 if not a.prepare_only and not a.development and subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True).strip():raise SystemExit('Commit the release source before final builds.')
 prepare()
 if a.prepare_only:return
 env=dict(os.environ,XDG_CONFIG_HOME=str(BUILD/'config'))
 settings=BUILD/'config/godot/editor_settings-4.7.tres';settings.parent.mkdir(parents=True,exist_ok=True)
 settings.write_text('[gd_resource type="EditorSettings" format=3]\n[resource]\nexport/android/java_sdk_path = '+json.dumps(str(JDK))+'\nexport/android/android_sdk_path = '+json.dumps(str(SDK))+'\n')
 run([GODOT,'--headless','--path',str(PROJECT),'--xr-mode','off','--editor','--import','--quit'],'import',env)
 for target in TARGETS if a.target=='all' else [a.target]:
  out=BUILD/target;out.mkdir(exist_ok=True);child=env.copy()
  ext={'Linux':'x86_64','Windows':'exe','Quest':'apk','Pico':'apk'}[target]
  artifact=out/('RealAIFishing-SplatTesting.'+ext)
  if ext=='apk':
   child.update(JAVA_HOME=str(JDK),ANDROID_HOME=str(SDK),ANDROID_SDK_ROOT=str(SDK));child['PATH']=str(JDK/'bin')+os.pathsep+child['PATH']
   key=ROOT/'.release-signing/fishing.keystore'
   password=json.loads((ROOT/'.release-signing/credentials.json').read_text())['password']
   child.update(FISHING_SIGNING_PASSWORD=password,GODOT_ANDROID_KEYSTORE_RELEASE_PATH=str(key),GODOT_ANDROID_KEYSTORE_RELEASE_USER='fishing',GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=password)
   android=PROJECT/'android/build'
   if not (android/'gradlew').exists():
    android.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(Path.home()/'.local/share/godot/export_templates/4.7.2.stable/android_source.zip') as z:z.extractall(android)
    (PROJECT/'android/.build_version').write_text('4.7.2.stable');(PROJECT/'android/.gdignore').touch();(android/'gradlew').chmod(0o755)
  run([GODOT,'--headless','--path',str(PROJECT),'--xr-mode','off','--export-release',target,str(artifact)],'export-'+target,child)
  if not artifact.exists():raise SystemExit('Missing '+str(artifact))
  if ext=='apk':
   run([str(SDK/'build-tools/36.1.0/apksigner'),'verify','--verbose','--print-certs',str(artifact)],'verify-'+target,child)
   run([str(SDK/'build-tools/36.1.0/zipalign'),'-c','-P','16','4',str(artifact)],'align-'+target,child)
  files={str(p.relative_to(out)):digest(p) for p in out.rglob('*') if p.is_file()}
  (BUILD/f'manifest-{target}.json').write_text(json.dumps({'target':target,'commit':revision,'development':a.development,'version':VERSION,'files':files},indent=2)+'\n')
  print(f'BUILT {target}: {artifact.stat().st_size} bytes',flush=True)
if __name__=='__main__':main()
