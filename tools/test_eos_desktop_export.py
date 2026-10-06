"""Verify that desktop PCKs actually contain platform-correct EOS configuration."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from audit_release import Pack

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get('GODOT_BIN', 'godot')
with tempfile.TemporaryDirectory(prefix='ubs-eos-export-') as directory:
    stage = Path(directory)
    shutil.copytree(ROOT / 'addons/fishing_export', stage / 'addons/fishing_export')
    (stage / 'scripts/network/eos').mkdir(parents=True)
    shutil.copy2(ROOT / 'scripts/network/eos/config.gd', stage / 'scripts/network/eos/config.gd')
    (stage / 'assets').mkdir()
    (stage / 'project.godot').write_text('''config_version=5
[application]
config/name="EOS export fixture"
[editor_plugins]
enabled=PackedStringArray("res://addons/fishing_export/plugin.cfg")
[rendering]
renderer/rendering_method="gl_compatibility"
''')
    source = stage / 'fixture.cfg'
    source.write_text('''[eos]
product_id="fixture-product"
sandbox_id="fixture-sandbox"
deployment_id="fixture-deployment"
client_id="fixture-client"
client_secret="fixture-not-a-real-secret"
relay="auto"
[identity]
provider="meta"
[meta]
app_id="123"
destination="water_lakeside"
app_secret="must-not-be-packaged"
''')
    (stage / 'export_presets.cfg').write_text('\n'.join(f'''[preset.{i}]
name="{platform}"
platform="{"Windows Desktop" if platform == "Windows" else platform}"
runnable=true
export_filter="all_resources"
include_filter=""
export_path=""
script_export_mode=0
exclude_filter="fixture.cfg"
[preset.{i}.options]
binary_format/architecture="x86_64"
''' for i, platform in enumerate(['Linux', 'Windows'])))
    env = dict(os.environ, FISHING_EOS_CONFIG=str(source), XDG_DATA_HOME=str(stage / 'data'), XDG_CONFIG_HOME=str(stage / 'config'))
    for label, args in [('import', ['--editor', '--import', '--quit'])] + [(p, ['--export-pack', p, str(stage / (p + '.pck'))]) for p in ['Linux', 'Windows']]:
        result = subprocess.run([GODOT, '--headless', '--xr-mode', 'off', '--path', str(stage), *args], env=env, capture_output=True, text=True, timeout=120)
        output = result.stdout + result.stderr
        if result.returncode or any(s in output for s in ['SCRIPT ERROR', 'Cannot export project', 'Export failed']):
            raise SystemExit(label + ' failed:\n' + output)
    for platform in ['Linux', 'Windows']:
        pack = Pack(stage / (platform + '.pck'))
        config = pack.read('eos.cfg').decode()
        assert 'provider="device"' in config and 'fixture-deployment' in config
        assert 'must-not-be-packaged' not in config and 'fixture.cfg' not in pack.names()
        pack.file.close()
        print('PASS ' + platform + ' packaged EOS configuration, desktop identity, and secret allowlist')
