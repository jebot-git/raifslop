"""Run VR interaction and avatar regressions with isolated saves and bounded runtimes."""
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test-results/vr-fixes'
SUITES = sys.argv[1:] or ['run_tests', 'hand_tracking', 'tracking_orientation', 'avatar_scaling', 'vrm_import_integrity', 'vr_ik', 'avatar_tracking', 'avatar_locomotion', 'fish_guide', 'guide_camera', 'shark_ambience_menu', 'network_guards', 'voice_recovery', 'session_feedback', 'fish_position', 'bait_visuals', 'external_data', 'vr_interactions', 'tester_feedback', 'tackle', 'fishing_feedback', 'quit_game', 'rod_holster', 'locations', 'raised_ankle', 'pier_gameplay', 'tracking_warning', 'menu_ray', 'menu_controls', 'vr_presentation']
failures = []
if len(sys.argv) == 1: SUITES.extend(['rod_attachment', 'radio', 'water_wildlife', 'fly_fishing', 'fish_jumps', 'coastal_locations', 'shore_transitions', 'gameplay_recording'])
if len(sys.argv) == 1: SUITES.extend(['cast_tolerance', 'cast_direction', 'tracked_cast', 'fish_population', 'fishing_update', 'fly_controls', 'fly_reel_penalty', 'empty_retrieve', 'shore_retrieval', 'pier_cleat', 'hdr_bake_compression'])
if len(sys.argv) == 1: SUITES.extend(['fishing_comfort', 'aim_water_grid', 'marine_species', 'fight_mechanics'])
for suite in SUITES:
    data = OUT / suite
    data.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, XDG_DATA_HOME=str(data), XDG_CONFIG_HOME=str(ROOT / 'builds/config'))
    log = OUT / (suite + '.log')
    try:
        with log.open('w') as stream:
            result = subprocess.run(['godot', '--headless', '--verbose', '--path', str(ROOT), '--xr-mode', 'off', '--script', f'res://tests/{suite}.gd', '--', '--asset-root', str(data / 'assets'), '--photos-root', str(data / 'pictures')], cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=120)
        errors = [line for line in log.read_text(errors='replace').splitlines() if 'SCRIPT ERROR:' in line or line.startswith('ERROR:') or line.startswith('FAIL ')]
        passed = result.returncode == 0 and not errors
        print(('PASS ' if passed else 'FAIL ') + suite, flush=True)
        if not passed:
            failures.append(suite)
            print('\n'.join(errors[:12]), flush=True)
    except subprocess.TimeoutExpired:
        failures.append(suite)
        print('TIMEOUT ' + suite, flush=True)
print('Failed suites:', failures, flush=True)
sys.exit(bool(failures))
