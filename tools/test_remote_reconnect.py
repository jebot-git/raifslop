"""Exercise an explicitly provided test server; synthetic audio and isolated saves."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('address')
    parser.add_argument('--port', type=int, default=24567)
    options = parser.parse_args()
    out = ROOT / 'test-results/remote-network'
    out.mkdir(parents=True, exist_ok=True)
    failed = []
    with tempfile.TemporaryDirectory(prefix='fishing-reconnect-') as tmp:
        jobs = []
        try:
            for role in ['sender', 'listener']:
                data = Path(tmp) / role
                log = out / f'reconnect-{role}.log'
                stream = log.open('w')
                env = dict(os.environ, XDG_DATA_HOME=str(data), XDG_CONFIG_HOME=str(data / 'config'))
                args = ['godot', '--headless', '--xr-mode', 'off', '--path', str(ROOT), '--script', 'res://tests/remote_reconnect.gd', '--', role, options.address, str(options.port), '--asset-root', str(data / 'assets')]
                jobs.append((role, subprocess.Popen(args, env=env, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT), stream, log))
            for role, process, stream, log in jobs:
                try:
                    process.wait(timeout=80)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                stream.close()
                text = log.read_text()
                passed = process.returncode == 0 and 'REMOTE_RECONNECT_RESULT' in text and 'SCRIPT ERROR' not in text and '\nFAIL ' not in text
                print(('PASS ' if passed else 'FAIL ') + role, flush=True)
                if not passed:
                    failed.append(role)
                    print(text[-6000:], flush=True)
        finally:
            for _, process, stream, _ in jobs:
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=5)
                stream.close()
    raise SystemExit(bool(failed))

if __name__ == '__main__':
    main()
