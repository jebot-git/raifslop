#!/usr/bin/env python3
"""Run the full automated VR/gameplay suite with fresh profiles and a saved report.

Synthetic controllers only. This command never starts a headset session.
"""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN', 'godot'))
    parser.add_argument('--focus', choices=['full', 'rec4', 'rec5'], default='full')
    args = parser.parse_args()
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S')
    out = (args.output or ROOT / 'test-results' / ('full-vr-' + stamp)).resolve()
    out.mkdir(parents=True, exist_ok=True)
    # Each invocation uses fresh profiles, even if the report directory is reused.
    run = out / ('run-' + stamp)
    env = dict(os.environ, VR_TEST_OUTPUT=str(run), GODOT_BIN=args.godot)
    results = []
    focused = ['rec4_cast_replay', 'cast_direction', 'cast_tolerance', 'tracked_cast',
               'golf_fit_invariants', 'golf_fitting_analytics', 'golf_attachment',
               'golf_controls_feedback', 'golf_vr_input', 'golf_tree_collision',
               'rec4_golf_replay', 'golf_head_contact', 'golf_physical_club',
               'golf_physics_review', 'golf_physics', 'golf_turf_contact',
               'golf_contact_effects', 'golf_physics_stress', 'golf_loading',
               'golf_courses', 'golf_surface_alignment', 'vr_test_capture']
    if args.focus == 'rec5':
        focused += ['rec5_cast_replay', 'rec5_terrain']
    commands = [('gameplay', ['python3', 'tools/test_vr_fixes.py'] +
                 (focused if args.focus != 'full' else []))]
    if args.focus == 'full':
        commands.append(('network', ['python3', 'tools/test_golf_network.py', '--godot', args.godot, '--output', str(out / 'network-details')]))
    for name, command in commands:
        with (out / (name + '.log')).open('w') as log:
            process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=subprocess.PIPE,
                                       stderr=subprocess.STDOUT, text=True)
            for line in process.stdout:
                log.write(line)
                print(line, end='', flush=True)
            code = process.wait()
        lines = (out / (name + '.log')).read_text()
        results.append({'group': name, 'exit': code,
                        'passed': re.findall(r'^PASS ([A-Za-z_0-9]+)$', lines, re.M),
                        'failed': re.findall(r'^(?:FAIL|TIMEOUT) ([A-Za-z_0-9]+)$', lines, re.M)})
    report = {'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'utc': stamp, 'focus': args.focus, 'working_tree_changed': bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).strip()), 'mode': 'synthetic XR, headless; not hardware certification',
              'profiles_and_logs': str(run), 'results': results}
    subprocess.run(['python3', 'tools/review_golf_contacts.py', 'tests/fixtures/rec4_contacts.json', '--output', str(out / 'contact-review.html')], cwd=ROOT, check=True)
    (out / 'suite-results.json').write_text(json.dumps(report, indent=2) + '\n')
    return int(any(r['exit'] for r in results))


if __name__ == '__main__':
    raise SystemExit(main())
