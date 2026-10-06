"""Measure production GDScript costs to prioritize possible native ports.

Uses isolated user data and headless synthetic fixtures, not headset FPS.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--godot', default=os.environ.get('GODOT_BIN', 'godot'))
parser.add_argument('--reference',action='store_true',help='Disable native kernels; retain the indexed GDScript fallback')
parser.add_argument('--output', type=Path, default=ROOT / 'test-results/native-candidates.json')
args = parser.parse_args()
with tempfile.TemporaryDirectory(prefix='fishing-native-candidates-') as folder:
    work = Path(folder)
    env = dict(os.environ, XDG_DATA_HOME=str(work), XDG_CONFIG_HOME=str(work / 'config'))
    report = {}
    for fixture in ['profile', 'avatar_bounds']:
        command = [args.godot, '--headless', '--path', str(ROOT), '--xr-mode', 'off', '--script',
                   f'res://tools/native_candidates/{fixture}.gd', '--', '--xr-test',
                   '--asset-root', str(work / 'assets'), '--photos-root', str(work / 'photos')]
        if args.reference:command.append('--gdscript-native')
        result = subprocess.run(command, env=env, cwd=ROOT, capture_output=True, text=True, timeout=300)
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.with_suffix('.'+fixture+'.log').write_text(result.stdout+result.stderr)
        result.check_returncode()
        errors = [line for line in (result.stdout + result.stderr).splitlines() if 'SCRIPT ERROR:' in line or line.startswith('ERROR:')]
        if errors:
            raise RuntimeError('\n'.join(dict.fromkeys(errors))[:4000])
        lines = result.stdout.splitlines()
        if fixture == 'profile':
            path = next(line.removeprefix('CANDIDATE_REPORT ') for line in lines if line.startswith('CANDIDATE_REPORT '))
            report = json.loads(Path(path).read_text())
        else:
            report['avatar_bounds'] = json.loads(next(line.removeprefix('BOUNDS_CANDIDATES ') for line in lines if line.startswith('BOUNDS_CANDIDATES ')))
    report['native_replacement_measured'] = not args.reference
    report['headset_verified'] = False
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(args.output)
