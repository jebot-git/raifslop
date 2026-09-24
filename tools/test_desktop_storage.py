"""Exercise real release-mode path selection with a read-only installation."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get('GODOT_BIN', '/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64')
with tempfile.TemporaryDirectory(prefix='ubs-storage-') as tmp:
    base = Path(tmp)
    project = base / 'project'
    (project / 'scripts').mkdir(parents=True)
    shutil.copy2(ROOT / 'scripts/data_paths.gd', project / 'scripts/data_paths.gd')
    shutil.copy2(ROOT / 'tests/desktop_storage.gd', project / 'test.gd')
    shutil.copy2(ROOT / 'scripts/xr_startup.gd', project / 'scripts/xr_startup.gd')
    (project / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="StorageTest"\nrun/main_scene="res://test.tscn"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    (project / 'test.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://test.gd" id="1"]\n[node name="Test" type="Node"]\nscript=ExtResource("1")\n')
    (project / 'export_presets.cfg').write_text('[preset.0]\nname="Linux"\nplatform="Linux"\nexport_filter="all_resources"\ninclude_filter=""\nexclude_filter=""\n[preset.0.options]\nbinary_format/architecture="x86_64"\n')
    template = Path.home() / '.local/share/godot/export_templates/4.7.2.stable/linux_release.x86_64'
    with (project / 'export_presets.cfg').open('a') as stream:
        import json
        stream.write('custom_template/debug=' + json.dumps(str(template)) + '\ncustom_template/release=' + json.dumps(str(template)) + '\n')
    output = base / 'install'
    legacy = output / 'data/vrm'
    legacy.mkdir(parents=True)
    for name, data in [('same.vrm', 'legacy selected avatar'), ('unique.vrm', 'legacy unique'), ('ignore.txt', 'unrelated')]:
        (legacy / name).write_text(data)
    exe = output / 'StorageTest.x86_64'
    env = dict(os.environ, XDG_DATA_HOME=str(base / 'userdata'), XDG_CONFIG_HOME=str(base / 'config'))
    for command in [['--editor', '--import', '--quit'], ['--export-release', 'Linux', str(exe)]]:
        result = subprocess.run([GODOT, '--headless', '--xr-mode', 'off', '--path', str(project), *command], env=env, capture_output=True, text=True, timeout=90)
        if result.returncode or 'SCRIPT ERROR' in result.stdout + result.stderr:
            raise RuntimeError(result.stdout + result.stderr)
    directories = [output, *[p for p in output.rglob('*') if p.is_dir()]]
    for path in directories:
        path.chmod(0o555)
    for path in legacy.iterdir():
        path.chmod(0o444)
    try:
        assert not os.access(legacy, os.W_OK), 'Test requires a read-only legacy directory'
        for extra in [[], ['--', '--asset-root', str(base / 'portable')]]:
            result = subprocess.run([str(exe), '--headless', *extra], env=env, capture_output=True, text=True, timeout=30)
            print(result.stdout, end='')
            assert result.returncode == 0 and 'DESKTOP_STORAGE_RESULT []' in result.stdout, result.stderr
        missing_xr = subprocess.run([str(exe), '--headless', '--xr-mode', 'off', '--', '--missing-xr'], env=env, capture_output=True, text=True, timeout=15)
        assert missing_xr.returncode == 1 and 'XR_STARTUP_GUARD_RESULT true' in missing_xr.stdout and 'VR_REQUIRED' in missing_xr.stderr, missing_xr.stdout + missing_xr.stderr
        print('PASS Release client refuses missing OpenXR without hanging headless tests')
    finally:
        for path in directories:
            path.chmod(0o755)
