#!/usr/bin/env python3
"""Build an isolated Linux dedicated-server project from shared protocol scripts.
No client scenes, bundled VRMs, textures, audio, XR plugins or codec extensions.
"""
import argparse, hashlib, json, os, pathlib, re, shutil, subprocess
ROOT=pathlib.Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--godot',default=os.environ.get('GODOT_BIN','/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64'));parser.add_argument('--output',type=pathlib.Path,default=ROOT/'builds/Server');args=parser.parse_args()
    out=args.output.resolve();stage=out/'project';stage.mkdir(parents=True,exist_ok=True)
    pending=['scripts/network/server_main.gd'];seen=set()
    while pending:
        name=pending.pop()
        if name in seen:continue
        seen.add(name);source=ROOT/name;text=source.read_text()
        dest=stage/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,dest)
        for dep in re.findall(r'preload\("res://([^"\n]+)"\)',text):
            if not dep.endswith('.gd'):raise SystemExit('Unexpected server resource dependency: '+dep)
            pending.append(dep)
    # Clear files from earlier dependency closures without touching user data.
    for old in (stage/'scripts').rglob('*.gd'):
        if old.relative_to(stage).as_posix() not in seen:old.unlink()
    (stage/'project.godot').write_text('''config_version=5
[application]
config/name="Real AI Fishing Server"
run/main_scene="res://server.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")
[rendering]
renderer/rendering_method="gl_compatibility"
[audio]
driver/enable_input=false
[xr]
openxr/enabled=false
''')
    (stage/'server.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/network/server_main.gd" id="1"]\n[node name="RealAIFishing" type="Node"]\nscript=ExtResource("1")\n')
    (stage/'export_presets.cfg').write_text('''[preset.0]
name="Server"
platform="Linux"
runnable=true
dedicated_server=true
custom_features="dedicated_server"
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="../RealAIFishingServer.x86_64"
script_export_mode=0
[preset.0.options]
binary_format/architecture="x86_64"
binary_format/embed_pck=true
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
''')
    env=dict(os.environ,XDG_CONFIG_HOME=str(out/'config'),XDG_DATA_HOME=str(out/'build-data'))
    version=subprocess.check_output([args.godot,'--version'],text=True).strip().split('.official')[0]
    template=pathlib.Path.home()/'.local/share/godot/export_templates'/version/'linux_release.x86_64'
    if template.exists():
        with (stage/'export_presets.cfg').open('a') as f:f.write('custom_template/debug='+json.dumps(str(template))+'\ncustom_template/release='+json.dumps(str(template))+'\n')
    for suffix,command in [('import',['--editor','--import','--quit']),('export',['--export-release','Server',str(out/'RealAIFishingServer.x86_64')])]:
        log=out/(suffix+'.log')
        with log.open('w') as stream:result=subprocess.run([args.godot,'--headless','--xr-mode','off','--path',str(stage),*command],stdout=stream,stderr=subprocess.STDOUT,env=env)
        if result.returncode or any(x in log.read_text() for x in ['SCRIPT ERROR','Parse Error','Export failed']):raise SystemExit('Build failed: '+str(log))
    binary=out/'RealAIFishingServer.x86_64'
    manifest={'files':sorted(seen|{'project.godot','server.tscn'}),'binary_bytes':binary.stat().st_size,'sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'bundled_assets':0,'bundled_native_extensions':0}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))
if __name__=='__main__':main()
