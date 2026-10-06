"""Compare rc.2 fishing facial mixing with FPSloppa caching and native mixing.

Requires FPSloppa's built Linux fps_native library; never installs it in fishing.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--fpsloppa', type=Path, required=True)
parser.add_argument('--godot', default=os.environ.get('GODOT_BIN', 'godot'))
parser.add_argument('--output', type=Path, default=ROOT / 'test-results/native-reuse.json')
args = parser.parse_args()
upstream = args.fpsloppa.resolve()
revision = subprocess.check_output(['git', '-C', str(upstream), 'rev-parse', 'HEAD'], text=True).strip()
with tempfile.TemporaryDirectory(prefix='fishing-native-reuse-') as directory:
    project = Path(directory)
    (project / 'project.godot').write_text('[application]\nconfig/name="Native reuse probe"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    # Immutable pre-optimization control, independent of subsequent working edits.
    baseline = subprocess.check_output(['git', '-C', str(ROOT), 'show', 'a2912df:scripts/avatar_eyes.gd'], text=True)
    (project / 'eyes.gd').write_text(baseline)
    shutil.copy(upstream / 'addons/fps_native/bin/libfpsloppa_native.so', project / 'libfpsloppa_native.so')
    (project / 'native.gdextension').write_text('[configuration]\nentry_symbol="fpsloppa_native_init"\ncompatibility_minimum="4.7"\n[libraries]\nlinux.x86_64="res://libfpsloppa_native.so"\n')
    source = (upstream / 'deathmatch/avatars/eyes.gd').read_text()
    bindings = source[source.index('func rebuild_bindings()'):source.index('func compose_cached()')]
    bindings = bindings.replace('\tif native_channels:native_face.configure_morphs(channels)\n', '')
    mixing = source[source.index('func compose_cached_reference()'):source.index('\nfunc setup(')]
    (project / 'cached.gd').write_text('extends "res://eyes.gd"\nvar channels: Array=[]\nvar morph_writes:=0\n' + bindings + mixing)
    shutil.copy(ROOT / 'scripts/avatar_eyes.gd', project / 'deployed.gd')
    shutil.copy(ROOT / 'tools/native_reuse/probe.gd', project / 'probe.gd')
    env = dict(os.environ, XDG_DATA_HOME=str(project / 'data'), XDG_CONFIG_HOME=str(project / 'config'))
    result = subprocess.run([args.godot, '--headless', '--path', str(project), '--script', 'probe.gd'], env=env, capture_output=True, text=True, timeout=180)
    result.check_returncode()
    if 'SCRIPT ERROR' in result.stderr or 'ERROR:' in result.stderr:
        raise RuntimeError(result.stderr)
    report = json.loads(next(line.removeprefix('REUSE_PROBE ') for line in result.stdout.splitlines() if line.startswith('REUSE_PROBE ')))
    report.update(fpsloppa_revision=revision, fishing_baseline='a2912df', headset_verified=False)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
