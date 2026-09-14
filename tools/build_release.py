"""Export four release targets; keep local signing credentials out of source control."""
from pathlib import Path
import argparse, hashlib, json, os, secrets, shutil, subprocess, zipfile
ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--target', choices=['all','Linux','Windows','Quest','Pico'], default='all')
a = p.parse_args()
if subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).strip():
    raise SystemExit('Commit the source changes before building a release.')
revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
build = ROOT/'builds'; build.mkdir(exist_ok=True)
godot = os.environ.get('GODOT_BIN', shutil.which('godot') or 'godot')
sdk = Path(os.environ.get('ANDROID_SDK_ROOT', str(Path.home()/'Android/Sdk')))
jdk = Path(os.environ.get('JAVA_HOME', str(Path.home()/'.local/share/entryway-toolchains/jdk-17.0.20.1+1')))
env = dict(os.environ, XDG_CONFIG_HOME=str(build/'config'))
settings = build/'config/godot/editor_settings-4.7.tres'; settings.parent.mkdir(parents=True, exist_ok=True)
settings.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\nexport/android/java_sdk_path = '+json.dumps(str(jdk))+'\nexport/android/android_sdk_path = '+json.dumps(str(sdk))+'\n')
def run(command, label, child_env=env):
    log = build/(label+'.log')
    with log.open('w') as stream:
        result = subprocess.run(command, env=child_env, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    if result.returncode or any(x in log.read_text(errors='replace') for x in ['SCRIPT ERROR:', 'Cannot export project', 'Export failed']):
        raise SystemExit(f'{label} failed; inspect {log}')
    print(label+' completed', flush=True)
def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()
run([godot,'--headless','--path',str(ROOT),'--xr-mode','off','--editor','--import','--quit'], 'import')
for target in (['Linux','Windows','Quest','Pico'] if a.target=='all' else [a.target]):
    out = build/target
    if out.exists(): shutil.rmtree(out)
    out.mkdir()
    manifest = build/('manifest-'+target+'.json')
    manifest.unlink(missing_ok=True)
    child_env = env.copy()
    if target in ['Quest','Pico']:
        child_env.update(JAVA_HOME=str(jdk), ANDROID_HOME=str(sdk), ANDROID_SDK_ROOT=str(sdk))
        child_env['PATH'] = str(jdk/'bin')+os.pathsep+child_env['PATH']
        signing=ROOT/'.release-signing'; signing.mkdir(exist_ok=True, mode=0o700)
        credentials=signing/'credentials.json'
        if not credentials.exists():
            credentials.write_text(json.dumps({'password':secrets.token_urlsafe(32)}));credentials.chmod(0o600)
        password=json.loads(credentials.read_text())['password']; key=signing/'fishing.keystore'
        child_env['FISHING_SIGNING_PASSWORD']=password
        if not key.exists():
            run([str(jdk/'bin/keytool'),'-genkeypair','-keystore',str(key),'-alias','fishing','-keyalg','RSA','-keysize','2048','-validity','10000','-dname','CN=Real AI Fishing','-storepass:env','FISHING_SIGNING_PASSWORD','-keypass:env','FISHING_SIGNING_PASSWORD'], 'signing-key',child_env)
            key.chmod(0o600)
        child_env.update(GODOT_ANDROID_KEYSTORE_RELEASE_PATH=str(key),GODOT_ANDROID_KEYSTORE_RELEASE_USER='fishing',GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=password)
        android=ROOT/'android/build'
        if not (android/'gradlew').exists():
            android.mkdir(parents=True,exist_ok=True)
            with zipfile.ZipFile(Path.home()/'.local/share/godot/export_templates/4.7.2.stable/android_source.zip') as z: z.extractall(android)
            (ROOT/'android/.build_version').write_text('4.7.2.stable')
            (ROOT/'android/.gdignore').touch();(android/'gradlew').chmod(0o755)
    ext={'Linux':'x86_64','Windows':'exe','Quest':'apk','Pico':'apk'}[target]
    artifact=out/('RealAIFishing.'+ext)
    run([godot,'--headless','--path',str(ROOT),'--xr-mode','off','--export-release',target,str(artifact)],'export-'+target,child_env)
    if not artifact.exists(): raise SystemExit('Missing '+str(artifact))
    if ext=='apk':
        run([str(sdk/'build-tools/36.1.0/apksigner'),'verify','--verbose','--print-certs',str(artifact)],'verify-'+target,child_env)
        run([str(sdk/'build-tools/36.1.0/zipalign'),'-c','-P','16','4',str(artifact)],'align-'+target,child_env)
    print(f'BUILT {target}: {artifact.stat().st_size} bytes',flush=True)
    files = {str(path.relative_to(out)): digest(path)
             for path in sorted(out.rglob('*')) if path.is_file()}
    manifest.write_text(json.dumps({'target': target, 'commit': revision,
                        'godot': subprocess.check_output([godot, '--version'], text=True).strip(),
                        'files': files}, indent=2)+'\n')
if subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).strip():
    raise SystemExit('Import/export changed source files; review, commit and rebuild before packaging.')
