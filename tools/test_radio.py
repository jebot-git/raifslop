"""Independent local ENet peers and synthetic Opus; never capture microphone audio."""
import os
import argparse
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test-results/radio'

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--remote', help='Use an already running, authorized test server')
    parser.add_argument('--port', type=int, default=24567)
    options = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    failures = []
    with tempfile.TemporaryDirectory(prefix='fishing-radio-') as tmp:
        for dedicated, port in ([(True, options.port)] if options.remote else [(True, 28571), (False, 28572)]):
            jobs = []
            roles = ['server', 'sender', 'near', 'far'] if dedicated else ['host', 'sender', 'near']
            if options.remote:
                roles.remove('server')
            try:
                for role in roles:
                    data = Path(tmp) / f'{port}-{role}'
                    env = dict(os.environ, XDG_DATA_HOME=str(data), XDG_CONFIG_HOME=str(data / 'config'))
                    log = OUT / f'{port}-{role}.log'
                    stream = log.open('w')
                    args = ['godot', '--headless', '--xr-mode', 'off', '--path', str(ROOT), '--script', 'res://tests/radio_network.gd', '--', role, str(port), '--asset-root', str(data / 'assets')]
                    if options.remote:
                        args += ['--address', options.remote, '--network-metrics']
                    if role == 'server':
                        args += ['--server', '--port', str(port)]
                    jobs.append((role, subprocess.Popen(args, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT), stream, log))
                    time.sleep(1)
                for role, process, stream, log in jobs:
                    try:
                        process.wait(timeout=45)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
                    stream.close()
                    text = log.read_text()
                    passed = process.returncode == 0 and 'RADIO_NETWORK_RESULT' in text and 'SCRIPT ERROR' not in text and '\nFAIL ' not in text
                    print(('PASS ' if passed else 'FAIL ') + f'{port} {role}', flush=True)
                    if not passed:
                        failures.append(f'{port} {role}')
                        print(text[-5000:], flush=True)
            finally:
                for _, process, stream, _ in jobs:
                    if process.poll() is None:
                        process.terminate()
                        process.wait(timeout=5)
                    stream.close()
    print('Failed:', failures)
    raise SystemExit(bool(failures))

if __name__ == '__main__':
    main()
