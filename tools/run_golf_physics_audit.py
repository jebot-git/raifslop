#!/usr/bin/env python3
"""Run integrated golf physics regressions with optional native simulated XR.

Start Monado simulation separately; never changes system runtime or WiVRn state.
All scene tests use isolated user data. Synthetic cadence is not hardware timing.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
SUITES = ['golf_tracking_tolerance', 'golf_pending_contact', 'golf_contact_effects', 'golf_turf_contact', 'golf_physical_club', 'golf_physics', 'golf_fitting_analytics',
          'golf_physics_review', 'golf_head_contact', 'golf_surface_alignment',
          'golf_controls_feedback', 'golf_attachment', 'golf_vr_input',
          'golf_courses', 'golf_course_lanes', 'golf_physics_stress',
          'golf_fit_invariants', 'rec5_terrain', 'quest19_golf_regressions']


def unexpected_errors(result):
    """Only tolerate the two previously observed native Godot shutdown errors."""
    def known_shutdown(line):
        return (result['suite'].endswith('-native') and
                ((line.startswith('ERROR: Attempt to disconnect a nonexistent connection') and
                  'OpenXRSpatialEntityExtension' in line and
                  "Signal: 'spatial_discovery_recommended'" in line) or
                 line == "ERROR: 4 RID allocations of type 'N9OpenXRAPI18InteractionProfileE' were leaked at exit."))
    return [line for line in result['errors'] if not known_shutdown(line)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN', 'godot'))
    parser.add_argument('--native', action='store_true', help='Also use an already running Monado simulated service')
    parser.add_argument('--timeout', type=int, default=240)
    args = parser.parse_args()
    out = ROOT / 'test-results/physics-audit'
    out.mkdir(parents=True, exist_ok=True)
    for name in ['stress-headless.json', 'stress-native.json', 'suite-results.json']:
        (out / name).unlink(missing_ok=True)
    cases = [(name, False) for name in SUITES]
    if args.native:
        cases += [('golf_physics_stress', True), ('golf_camera', True)]
    results = []
    with tempfile.TemporaryDirectory(prefix='golf-physics-user-') as user:
        for name, native in cases:
            label = name + ('-native' if native else '')
            env = dict(os.environ, XDG_DATA_HOME=str(Path(user) / label))
            command = [args.godot, '--path', str(ROOT), '--script', 'res://tests/' + name + '.gd']
            if native:
                env.update(XR_RUNTIME_JSON='/usr/share/openxr/1/openxr_monado.json',
                           SIMULATED_ENABLE='1', XRT_COMPOSITOR_FORCE_XCB='1')
                command += ['--', '--native-xr']
            else:
                command += ['--headless', '--xr-mode', 'off', '--', '--xr-test']
            start = time.monotonic()
            with (out / (label + '.log')).open('w') as log:
                try:
                    code = subprocess.run(command, cwd=ROOT, env=env, stdout=log,
                                          stderr=subprocess.STDOUT, timeout=args.timeout).returncode
                except subprocess.TimeoutExpired:
                    log.write('\nTEST_TIMEOUT\n')
                    code = 124
            lines = (out / (label + '.log')).read_text().splitlines()
            results.append({'suite': label, 'exit': code, 'seconds': round(time.monotonic()-start, 2),
                            'pass_lines': sum(x.startswith('PASS ') for x in lines),
                            'errors': [x for x in lines if x.startswith(('FAIL', 'SCRIPT ERROR', 'ERROR:'))]})
            print(json.dumps(results[-1]), flush=True)
            (out / 'suite-results.json').write_text(json.dumps(results, indent=2) + '\n')
    # Preserve known native shutdown diagnostics; fail on every other error.
    return int(any(r['exit'] or unexpected_errors(r) for r in results))


if __name__ == '__main__':
    raise SystemExit(main())
