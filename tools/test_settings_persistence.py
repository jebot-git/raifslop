"""Verify real exit/restart cycles using isolated user data, never the player's saves."""
from pathlib import Path
import os
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test-results/settings'
OUT.mkdir(parents=True, exist_ok=True)
for mode in ('menu', 'escape', 'window-close'):
    with tempfile.TemporaryDirectory(prefix='fishing-settings-') as data:
        env = dict(os.environ, XDG_DATA_HOME=data, XDG_CONFIG_HOME=data)
        for stage in ('write', 'read'):
            log = OUT / f'{mode}-{stage}.log'
            cmd = ['godot', '--headless', '--verbose', '--path', str(ROOT), '--xr-mode', 'off', '--script', 'res://tests/settings_persistence.gd', '--', f'--{stage}', f'--{mode}']
            with log.open('w') as stream:
                result = subprocess.run(cmd, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=90)
            errors = [line for line in log.read_text(errors='replace').splitlines() if line.startswith(('SCRIPT ERROR:', 'ERROR:', 'FAIL '))]
            if result.returncode or errors:
                raise SystemExit(f'FAIL {mode} {stage}: {result.returncode}\n' + '\n'.join(errors[:12]))
            print(f'PASS {mode} {stage}', flush=True)
