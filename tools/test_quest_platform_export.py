"""Export an isolated, non-submittable Platform SDK fixture without an AppID."""
import os
from pathlib import Path
import shutil
import subprocess
import zipfile
ROOT = Path(__file__).resolve().parents[1]
folder = ROOT / 'builds/quest-platform-fixture'
if folder.exists(): shutil.rmtree(folder)
folder.mkdir(parents=True)
(folder / '.gdignore').touch()
shutil.copytree(ROOT / 'addons/godot_meta_toolkit', folder / 'addons/godot_meta_toolkit')
(folder / 'project.godot').write_text('[application]\nconfig/name="Platform packaging fixture — not a store candidate"\nrun/main_scene="res://main.tscn"\n[rendering]\nrenderer/rendering_method="mobile"\ntextures/vram_compression/import_etc2_astc=true\ntextures/vram_compression/import_s3tc_bptc=true\n')
shutil.copy2(ROOT / 'assets/icon.svg', folder / 'icon.svg')
with (folder / 'project.godot').open('a') as stream: stream.write('\n[application]\nconfig/icon="res://icon.svg"\n')
(folder / 'main.tscn').write_text('[gd_scene format=3]\n[node name="Fixture" type="Node"]\n')
presets = (ROOT / 'export_presets.cfg').read_text()
quest = presets[presets.index('[preset.2]'):].replace('[preset.2', '[preset.0').replace('org.jebot.raifslop.quest', 'org.jebot.raifslop.platformfixture')
linux = presets[:presets.index('[preset.1]')].replace('[preset.0', '[preset.1')
(folder / 'export_presets.cfg').write_text(quest + '\n' + linux)
android = folder / 'android/build'
android.mkdir(parents=True)
with zipfile.ZipFile(Path.home() / '.local/share/godot/export_templates/4.7.2.stable/android_source.zip') as z: z.extractall(android)
(folder / 'android/.build_version').write_text('4.7.2.stable')
(folder / 'android/.gdignore').touch()
(android / 'gradlew').chmod(0o755)
p = android / 'gradle.properties'
s = p.read_text()
import re
s = re.sub(r'^org.gradle.jvmargs=.*$', 'org.gradle.jvmargs=-Xmx1536m -XX:MaxMetaspaceSize=384m', s, flags=re.M)
p.write_text(s + '\norg.gradle.workers.max=1\norg.gradle.parallel=false\norg.gradle.daemon=false\n')
(folder / 'userdata/godot').mkdir(parents=True)
(folder / 'userdata/.gdignore').touch()
(folder / 'userdata/godot/export_templates').symlink_to(Path.home() / '.local/share/godot/export_templates', target_is_directory=True)
env = dict(os.environ, XDG_CONFIG_HOME=str(ROOT / 'builds/config'), XDG_DATA_HOME=str(folder / 'userdata'))
godot = env.get('GODOT_BIN', 'godot')
commands = [('android', ['--export-release', 'Quest', str(folder / 'fixture.apk')]), ('linux', ['--export-release', 'Linux', str(folder / 'fixture.x86_64')])]
for label, flags in commands:
    log = ROOT / 'test-results' / ('quest-platform-fixture-' + label + '.log')
    with log.open('w') as stream:
        result = subprocess.run([godot, '--headless', '--path', str(folder), '--xr-mode', 'off', *flags], env=env, stdout=stream, stderr=subprocess.STDOUT)
    text = log.read_text(errors='replace')
    if result.returncode or any(x in text for x in ['SCRIPT ERROR', 'Export failed', 'Cannot export project', 'Project export for preset']):
        raise SystemExit('Fixture export failed; inspect ' + str(log))
    print('Fixture ' + label + ' passed', flush=True)
with zipfile.ZipFile(folder / 'fixture.apk') as z:
    names = set(z.namelist())
    assert {'lib/arm64-v8a/libgodot_meta_toolkit.so', 'lib/arm64-v8a/libovrplatformloader.so'} <= names
    assert not any('/x86' in n for n in names)
    assert 'assets/quest_store.json' not in names  # This is never a store candidate.
from audit_release import Pack
pack = Pack(folder / 'fixture.pck')
assert not any('godot_meta_toolkit' in name for name in pack.names())
assert not (folder / 'libgodot_meta_toolkit.so').exists()
print('PLATFORM_EXPORT_PASS: Android SDK bundled; desktop SDK excluded; no AppID or entitlement claimed')
