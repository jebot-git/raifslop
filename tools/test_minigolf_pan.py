#!/usr/bin/env python3
"""Capture native stereo 0–180° pans; start synthetic Monado beforehand."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('locations', nargs='*')
parser.add_argument('--godot', default=os.environ.get('GODOT', '/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64'))
args = parser.parse_args()
locations = args.locations or sorted(p.stem for p in (ROOT / 'assets/minigolf/courses').glob('*.json'))
folder = ROOT / 'test-results/minigolf-vr-pan'
folder.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='minigolf-pan-') as data:
    env = dict(os.environ, XDG_DATA_HOME=data)
    env.setdefault('XR_RUNTIME_JSON', '/usr/share/openxr/1/openxr_monado.json')
    for location in locations:
        if not (ROOT / 'assets/minigolf/courses' / (location + '.json')).is_file():
            raise SystemExit('Unknown location: ' + location)
        path = folder / (location + '.log')
        with path.open('w') as log:
            result = subprocess.run([args.godot, '--path', str(ROOT), '--xr-mode', 'on', '--script', 'tests/minigolf_pan_xr.gd', '--', location, '--xr-test'], env=env, stdout=log, stderr=subprocess.STDOUT, timeout=300)
        text = path.read_text()
        assert result.returncode == 0 and 'MINIGOLF_VR_PAN_PASS' in text, path
        assert text.count('position_fixed=true') == 13, path
        assert len(list((folder / location).glob('yaw-*-eye*.png'))) == 26, path
        print(location, 'PASS: 13 orientations × two eyes', flush=True)
