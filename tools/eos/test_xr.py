#!/usr/bin/env python3
"""EOS gameplay with a visible Monado simulated headset and a headless peer.
Start SIMULATED_ENABLE=1 XRT_COMPOSITOR_FORCE_XCB=1 monado-service first.
This does not emulate native Quest identity, Android, or WiVRn streaming.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, default=ROOT / 'builds/eos/eos.cfg')
    parser.add_argument('--relay', choices=['auto', 'force'], default='force')
    args = parser.parse_args()
    os.umask(0o077)
    original = args.config.read_text()
    for key in ['product_id', 'sandbox_id', 'deployment_id', 'client_id', 'client_secret']:
        if not re.search(r'^' + key + r'\s*=\s*"[^"\s]+"', original, re.M):
            raise SystemExit('Missing required setting: ' + key)
    report = ROOT / 'test-results/eos-meta' / (time.strftime('xr-%Y%m%d-%H%M%S-') + args.relay)
    report.mkdir(parents=True)
    print('Reports:', report, flush=True)
    handoff = report / 'handoff.json'
    jobs = []
    with tempfile.TemporaryDirectory(prefix='eos-xr-', dir=ROOT / 'builds') as tmp:
        config = Path(tmp) / 'eos.cfg'
        text = re.sub(r'^provider\s*=.*$', 'provider="device"', original, flags=re.M)
        text = re.sub(r'^relay\s*=.*$', f'relay="{args.relay}"', text, flags=re.M)
        config.write_text(text)
        def start(role):
            env = dict(os.environ, XDG_DATA_HOME=str(Path(tmp) / role / 'data'),
                       XDG_CONFIG_HOME=str(Path(tmp) / role / 'config'))
            command = [env.get('GODOT_BIN', '/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64'),
                       '--path', str(ROOT), '--script', 'tests/eos_xr_live.gd', '--max-fps', '60']
            if role == 'host':command += ['--headless', '--xr-mode', 'off']
            else:
                env.update(XR_RUNTIME_JSON='/usr/share/openxr/1/openxr_monado.json', SIMULATED_ENABLE='1', XRT_COMPOSITOR_FORCE_XCB='1')
                command += ['--xr-mode', 'on', '--rendering-driver', 'vulkan', '--rendering-method', 'mobile']
            command += ['--', '--xr-test', '--eos-device-test', '--eos-config', str(config),
                        '--role', role, '--output', str(report), '--relay', args.relay,
                        '--leaderboard-path', str(report / 'records.json')]
            log = (report / (role + '.log')).open('w')
            proc = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT)
            jobs.append((proc, log))
            return proc
        ok = False
        try:
            host = start('host')
            deadline = time.monotonic() + 120
            while not handoff.exists() and host.poll() is None and time.monotonic() < deadline:time.sleep(.25)
            if handoff.exists():
                xr = start('xr');xr.wait(timeout=230)
                Path(str(handoff) + '.done').write_text('{}')
                host.wait(timeout=35)
                ok = host.returncode == 0 and xr.returncode == 0
                for role in ['host', 'xr']:
                    path = report / (role + '.json')
                    data = json.loads(path.read_text()) if path.exists() else {'ok': False, 'failures': ['Missing report']}
                    print(role, json.dumps(data), flush=True)
                    lines = (report / (role + '.log')).read_text().splitlines()
                    unexpected = [line for line in lines if line.startswith(('ERROR:', 'SCRIPT ERROR'))
                                  and not (role == 'xr' and ('OpenXRSpatialEntityExtension' in line
                                           or line == "ERROR: 4 RID allocations of type 'N9OpenXRAPI18InteractionProfileE' were leaked at exit."))]
                    if unexpected:print(role, 'Unexpected errors:', unexpected, flush=True)
                    ok = ok and data['ok'] and not unexpected
            else:print('Host did not become ready; inspect host.log', flush=True)
        finally:
            for proc, log in jobs:
                if proc.poll() is None:
                    proc.terminate()
                    try:proc.wait(timeout=5)
                    except subprocess.TimeoutExpired:proc.kill();proc.wait()
                log.close()
            handoff.unlink(missing_ok=True)
            Path(str(handoff) + '.done').unlink(missing_ok=True)
        raise SystemExit(0 if ok else 1)

if __name__ == '__main__':
    main()
