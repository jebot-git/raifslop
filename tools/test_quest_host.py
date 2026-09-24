"""Connect two real ENet clients to an already-running, matching-protocol Quest host.

Does not install or launch software on the headset. Keep the host awake and use
its Wi-Fi LAN address, not an ADB TCP-forwarded port (ENet uses UDP).
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('address')
    parser.add_argument('--port', type=int, default=28673)
    parser.add_argument('--godot', default=shutil.which('godot') or 'godot')
    parser.add_argument('--output', type=Path, default=ROOT / 'test-results/quest-host')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    results = []
    jobs = []
    with tempfile.TemporaryDirectory(prefix='ubs-quest-probe-') as temporary:
        try:
            for role in ('actor', 'observer'):
                path = args.output / f'{role}.log'
                stream = path.open('w')
                env = dict(os.environ, XDG_DATA_HOME=f'{temporary}/{role}', XDG_CONFIG_HOME=f'{temporary}/config')
                process = subprocess.Popen([
                    args.godot, '--headless', '--xr-mode', 'off', '--path', str(ROOT),
                    '--script', 'res://tests/quest_host_client.gd', '--', args.address, str(args.port), role,
                ], env=env, stdout=stream, stderr=subprocess.STDOUT)
                jobs.append((role, process, stream, path))
                if role == 'actor':
                    time.sleep(2)
            deadline = time.monotonic() + 100
            while any(p.poll() is None for _, p, _, _ in jobs) and time.monotonic() < deadline:
                time.sleep(.2)
            for role, process, stream, path in jobs:
                if process.poll() is None:
                    process.kill()
                process.wait()
                stream.close()
                text = path.read_text(errors='replace')
                records = [json.loads(line.split('QUEST_HOST_CLIENT_RESULT ', 1)[1])
                           for line in text.splitlines() if line.startswith('QUEST_HOST_CLIENT_RESULT ')]
                passed = (process.returncode == 0 and len(records) == 1 and not records[0]['failures']
                          and 'SCRIPT ERROR' not in text and 'ERROR:' not in text)
                results.append({'role': role, 'passed': passed, 'returncode': process.returncode,
                                'result': records[0] if records else None})
                print(('PASS ' if passed else 'FAIL ') + role, flush=True)
                if not passed:
                    print(text[-4000:], flush=True)
        finally:
            for _, process, stream, _ in jobs:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
                stream.close()
    (args.output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    return 0 if all(row['passed'] for row in results) else 1


if __name__ == '__main__':
    raise SystemExit(main())
