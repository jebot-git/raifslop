"""Check native library selection in minimal Godot export packs."""
from pathlib import Path
import hashlib, json, os, shutil, subprocess, zipfile
from audit_release import Pack
from build_fishing_native import NAMES, require_build
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test-results/native-export'
STAGE=OUT/'project';STAGE.mkdir(parents=True,exist_ok=True)
addon=STAGE/'addons/fishing_native';addon.mkdir(parents=True,exist_ok=True)
shutil.copy2(ROOT/'addons/fishing_native/fishing_native.gdextension',addon)
for target in NAMES:
    library=require_build(target);(addon/'bin').mkdir(exist_ok=True);shutil.copy2(library,addon/'bin'/library.name)
(STAGE/'main.gd').write_text('extends Node\nfunc _ready():\n\tif not ClassDB.class_exists("FishingNative"):push_error("Native library missing in export");get_tree().quit(1);return\n\tvar kernel=ClassDB.instantiate("FishingNative")\n\tassert(kernel.decode_pose(PackedByteArray(),[]).is_empty())\n\tprint("NATIVE_EXPORTED_RUNTIME_PASS")\n\tget_tree().quit()\n')
(STAGE/'main.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://main.gd" id="1"]\n[node name="Fixture" type="Node"]\nscript=ExtResource("1")\n')
(STAGE/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Native export fixture"\nrun/main_scene="res://main.tscn"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\ntextures/vram_compression/import_etc2_astc=true\n')
templates=Path.home()/'.local/share/godot/export_templates/4.7.2.stable'
platforms=[('Linux','Linux','linux'),('Windows','Windows Desktop','windows'),('Quest','Android','android')]
(STAGE/'export_presets.cfg').write_text('\n'.join(f'''[preset.{i}]
name="{name}"
platform="{platform}"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path=""
script_export_mode=0
[preset.{i}.options]
binary_format/architecture="x86_64"
texture_format/etc2_astc=true
custom_template/release="{templates / ('linux_release.x86_64' if name=='Linux' else 'windows_release_x86_64.exe' if name=='Windows' else 'android_release.apk')}"
custom_template/debug="{templates / ('android_debug.apk' if name=='Quest' else 'linux_debug.x86_64' if name=='Linux' else 'windows_debug_x86_64.exe')}"
architectures/arm64-v8a=true
architectures/armeabi-v7a=false
architectures/x86=false
architectures/x86_64=false
gradle_build/use_gradle_build=false
package/unique_name="org.fishing.nativefixture"
package/signed=false
''' for i,(name,platform,_) in enumerate(platforms)))
env=dict(os.environ,XDG_DATA_HOME=str(OUT/'data'),XDG_CONFIG_HOME=str(OUT/'config'))
godot=os.environ.get('GODOT_BIN','godot')
sdk=Path(os.environ.get('ANDROID_SDK_ROOT',str(Path.home()/'Android/Sdk')))
jdk=Path(os.environ.get('JAVA_HOME',str(Path.home()/'.local/share/entryway-toolchains/jdk-17.0.20.1+1')))
settings=OUT/'config/godot/editor_settings-4.7.tres';settings.parent.mkdir(parents=True,exist_ok=True)
settings.write_text('[gd_resource type="EditorSettings" format=3]\n[resource]\nexport/android/android_sdk_path='+json.dumps(str(sdk))+'\nexport/android/java_sdk_path='+json.dumps(str(jdk))+'\n')
env.update(JAVA_HOME=str(jdk),ANDROID_SDK_ROOT=str(sdk))
def run(label,args):
    result=subprocess.run([godot,'--headless','--path',str(STAGE),'--xr-mode','off',*args],env=env,capture_output=True,text=True,timeout=120)
    text=result.stdout+result.stderr;(OUT/(label+'.log')).write_text(text)
    if result.returncode or any(x in text for x in ['SCRIPT ERROR','Export failed','Failed to export','Cannot load GDExtension']):raise RuntimeError(label+' failed: '+text[-3000:])
run('import',['--editor','--import','--quit'])
for name,_,target in platforms:
    destination=OUT/name;destination.mkdir(exist_ok=True)
    path=destination/'fixture.pck'
    if target=='android':run(name,['--export-pack',name,str(path)])
    else:run(name,['--export-release',name,str(destination/('fixture.x86_64' if target=='linux' else 'fixture.exe'))])
    pack=Pack(path)
    assert 'addons/fishing_native/fishing_native.gdextension' in pack.names()
    expected=require_build(target).read_bytes()
    # Desktop exporters may place shared libraries beside the PCK; Android
    # packs may defer shared objects to the APK step. Record both forms.
    candidates=[p for p in destination.rglob('*') if p.is_file() and p.name==NAMES[target]]
    packed=[n for n in pack.names() if n.endswith(NAMES[target])]
    present=any(hashlib.sha256(p.read_bytes()).digest()==hashlib.sha256(expected).digest() for p in candidates)
    present=present or any(pack.read(n)==expected for n in packed)
    if target!='android':
        assert present, 'Missing/wrong native library: '+name
        if target=='linux':
            result=subprocess.run([str(destination/'fixture.x86_64'),'--headless','--xr-mode','off'],env=env,capture_output=True,text=True,timeout=30)
            assert result.returncode==0 and 'NATIVE_EXPORTED_RUNTIME_PASS' in result.stdout,result.stdout+result.stderr
    else:
        assert 'android.arm64' in pack.read('addons/fishing_native/fishing_native.gdextension').decode()
        apk=destination/'fixture.apk';run('Quest-apk',['--export-debug',name,str(apk)])
        with zipfile.ZipFile(apk) as archive:
            assert archive.read('lib/arm64-v8a/'+NAMES[target])==expected
        present=True
    pack.file.close()
    print('PASS',name,'descriptor; library bytes verified' if present else 'descriptor only')
