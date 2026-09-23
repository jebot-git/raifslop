"""Export maintained release targets; keep local signing credentials out of source control."""
from pathlib import Path
import argparse, hashlib, json, os, secrets, shutil, subprocess, sys, zipfile
from release_targets import TARGETS, ANDROID_TARGETS
ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--target', choices=['all', *TARGETS], default='all')
p.add_argument('--store-release', action='store_true', help='Require an existing externally provisioned Android signing identity')
a = p.parse_args()
if subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).strip():
    raise SystemExit('Commit the source changes before building a release.')
revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
build = ROOT/'builds'; build.mkdir(exist_ok=True)
(build/'.gdignore').touch()
results = ROOT/'test-results'; results.mkdir(exist_ok=True)
(results/'.gdignore').touch()
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
    if result.returncode or any(x in log.read_text(errors='replace') for x in ['SCRIPT ERROR:', 'Cannot export project', 'Export failed', 'HDR compression failed']):
        raise SystemExit(f'{label} failed; inspect {log}')
    print(label+' completed', flush=True)
def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()
run([godot,'--headless','--path',str(ROOT),'--xr-mode','off','--editor','--import','--quit'], 'import')
for target in (TARGETS if a.target=='all' else [a.target]):
    out = build/target
    if out.exists(): shutil.rmtree(out)
    out.mkdir()
    manifest = build/('manifest-'+target+'.json')
    manifest.unlink(missing_ok=True)
    child_env = env.copy()
    if target == 'Server':
        run([sys.executable, str(ROOT/'tools/build_server.py'), '--godot', godot, '--output', str(out)], 'export-Server', child_env)
        artifact = out/'RealAIFishingServer.x86_64'
        manifest.write_text(json.dumps({'target':target, 'commit':revision,
                            'godot':subprocess.check_output([godot,'--version'],text=True).strip(),
                            'files':{artifact.name:digest(artifact)}},indent=2)+'\n')
        print(f'BUILT Server: {artifact.stat().st_size} bytes',flush=True)
        continue
    if target in ANDROID_TARGETS:
        child_env.update(JAVA_HOME=str(jdk), ANDROID_HOME=str(sdk), ANDROID_SDK_ROOT=str(sdk))
        child_env['PATH'] = str(jdk/'bin')+os.pathsep+child_env['PATH']
        signing=ROOT/'.release-signing'; signing.mkdir(exist_ok=True, mode=0o700)
        credentials=signing/'credentials.json'
        if a.store_release:
            key=Path(os.environ.get('STORE_KEYSTORE', '/nonexistent'))
            password=os.environ.get('STORE_KEYSTORE_PASSWORD', '')
            alias=os.environ.get('STORE_KEYSTORE_ALIAS', 'fishing')
            if not key.is_file() or not password or not alias:
                raise SystemExit('Store builds require STORE_KEYSTORE, STORE_KEYSTORE_PASSWORD and an existing signing key. No key will be generated.')
        elif not credentials.exists():
            credentials.write_text(json.dumps({'password':secrets.token_urlsafe(32)}));credentials.chmod(0o600)
        if not a.store_release:
            password=json.loads(credentials.read_text())['password']; key=signing/'fishing.keystore';alias='fishing'
        child_env['FISHING_SIGNING_PASSWORD']=password
        if not key.exists():
            run([str(jdk/'bin/keytool'),'-genkeypair','-keystore',str(key),'-alias','fishing','-keyalg','RSA','-keysize','2048','-validity','10000','-dname','CN=Real AI Fishing','-storepass:env','FISHING_SIGNING_PASSWORD','-keypass:env','FISHING_SIGNING_PASSWORD'], 'signing-key',child_env)
            key.chmod(0o600)
        child_env.update(GODOT_ANDROID_KEYSTORE_RELEASE_PATH=str(key.resolve()),GODOT_ANDROID_KEYSTORE_RELEASE_USER=alias,GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=password)
        android=ROOT/'android/build'
        if not (android/'gradlew').exists():
            android.mkdir(parents=True,exist_ok=True)
            with zipfile.ZipFile(Path.home()/'.local/share/godot/export_templates/4.7.2.stable/android_source.zip') as z: z.extractall(android)
            (ROOT/'android/.build_version').write_text('4.7.2.stable')
            (ROOT/'android/.gdignore').touch();(android/'gradlew').chmod(0o755)
        if a.store_release:
            from quest_store_manifest import configure
            configure(android/'src/main/AndroidManifest.xml')
    ext={'Linux':'x86_64','Windows':'exe','Quest':'apk'}[target]
    artifact=out/('RealAIFishing.'+ext)
    run([godot,'--headless','--path',str(ROOT),'--xr-mode','off','--export-release',target,str(artifact)],'export-'+target,child_env)
    if not artifact.exists(): raise SystemExit('Missing '+str(artifact))
    if ext=='apk':
        unsigned = out/'compressed-unsigned.apk'
        aligned = out/'compressed-aligned.apk'
        with zipfile.ZipFile(artifact) as source, zipfile.ZipFile(unsigned, 'w', compresslevel=9) as dest:
            for info in source.infolist():
                # v1 signatures are replaced by apksigner; v2+ signing blocks are
                # outside ZIP entries and are removed automatically by rewriting.
                if info.filename.upper().startswith('META-INF/') and info.filename.upper().endswith(('.RSA','.DSA','.EC','.SF','.MF')):
                    continue
                dest.writestr(info, source.read(info), compress_type=info.compress_type, compresslevel=9)
        run([str(sdk/'build-tools/36.1.0/zipalign'),'-f','-P','16','4',str(unsigned),str(aligned)],'recompress-align-'+target,child_env)
        run([str(sdk/'build-tools/36.1.0/apksigner'),'sign','--ks',str(key),'--ks-key-alias',alias,'--ks-pass','env:FISHING_SIGNING_PASSWORD','--key-pass','env:FISHING_SIGNING_PASSWORD','--out',str(artifact),str(aligned)],'recompress-sign-'+target,child_env)
        unsigned.unlink(); aligned.unlink()
        artifact.with_suffix('.apk.idsig').unlink(missing_ok=True)
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
