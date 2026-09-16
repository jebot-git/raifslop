"""Run one reproducible desktop benchmark; no cloud requests."""
import argparse
import json
import os
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[2]
viewer = root / 'test-results/splat-experiment/viewer'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('asset', choices=['gray_pier_100k.ply', 'gray_pier_500k.ply'])
parser.add_argument('--mode', choices=['original','full','hybrid','panorama'], default='original')
args = parser.parse_args()
godot = os.environ.get('GODOT_BIN', '/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64')
stem = Path(args.asset).stem if args.mode == 'original' else 'hybrid_'+args.mode
log = viewer.parent / (stem + '_benchmark.log')
scene = ['res://main.tscn'] if args.mode == 'original' else ['res://hybrid.tscn']
with log.open('w') as stream:
    result = subprocess.run([godot, '--path', str(viewer), '--xr-mode', 'off',
        *scene, '--', '--benchmark', '--asset=' + args.asset, '--mode='+args.mode], stdout=stream, stderr=subprocess.STDOUT,
        timeout=180)
if result.returncode:
    raise SystemExit(f'Godot exited {result.returncode}; see {log}')
text = log.read_text()
if 'ERROR:' in text or 'SPLAT_RESULT ' not in text:
    raise SystemExit(f'Benchmark did not pass; see {log}')
print((viewer / (stem + '_metrics.json')).read_text())
