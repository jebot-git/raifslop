#!/usr/bin/env python3
"""Live gameplay transport check: host, client, reconnect, bulk/pose/voice and relay.

Uses an ephemeral copy of local config with desktop device identity. Never prints
credentials, installs an APK or launches XR. Leaves test lobbies on completion.
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
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--config', type=Path, default=ROOT / 'builds/eos/eos.cfg')
    p.add_argument('--relay', choices=['auto', 'force'], default='auto')
    p.add_argument('--lobby-check', action='store_true', help='Check named discovery, wrong password rejection and correct-password reconnect')
    args = p.parse_args()
    os.umask(0o077)
    # Never replace the user's provider/relay preferences in the real config.
    original = args.config.read_text()
    for key in ['product_id', 'sandbox_id', 'deployment_id', 'client_id', 'client_secret']:
        if not re.search(r'^' + key + r'\s*=\s*"[^"\s]+"', original, re.M):
            raise SystemExit('Missing required EOS setting: ' + key)
    report = ROOT / 'test-results/eos-meta' / (time.strftime('game-%Y%m%d-%H%M%S-') + args.relay)
    report.mkdir(parents=True)
    handoff = report / 'handoff.json'
    jobs = []
    with tempfile.TemporaryDirectory(prefix='eos-game-config-', dir=ROOT / 'builds') as tmp:
        config = Path(tmp) / 'eos.cfg'
        text = re.sub(r'^provider\s*=.*$', 'provider="device"', original, flags=re.M)
        text = re.sub(r'^relay\s*=.*$', f'relay="{args.relay}"', text, flags=re.M)
        config.write_text(text)
        def start(role, label):
            identity = ROOT / 'builds/eos-game-identities' / ('client' if role == 'denied' else role)
            identity.mkdir(parents=True, exist_ok=True)
            env = dict(os.environ, XDG_DATA_HOME=str(identity / 'data'), XDG_CONFIG_HOME=str(identity / 'config'))
            log = (report / f'{label}.log').open('w')
            command = [env.get('GODOT_BIN', '/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64'),
                       '--headless', '--xr-mode', 'off', '--path', str(ROOT), '--script', 'tests/eos_live_game.gd',
                       '--', '--eos-device-test', '--eos-config', str(config), '--role', role,
                       '--handoff', str(handoff), '--result', str(report / f'{label}.json'), '--relay', args.relay,
                       '--leaderboard-path', str(report / 'records.json')]
            if args.lobby_check:command.append('--lobby-check')
            proc = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT)
            jobs.append((proc, log))
            return proc
        def passed(label):
            path = report / f'{label}.json'
            if not path.exists():return False
            data = json.loads(path.read_text())
            print(json.dumps({key: data[key] for key in ['role', 'ok', 'stage', 'cleanup', 'network_type', 'bulk_received', 'voice_received']}), flush=True)
            return data['ok'] and 'SCRIPT ERROR' not in (report / f'{label}.log').read_text()
        ok = False
        try:
            host = start('host', 'host')
            deadline = time.monotonic() + 65
            while host.poll() is None and not handoff.exists() and time.monotonic() < deadline:time.sleep(.2)
            if handoff.exists():
                denied_ok = True
                if args.lobby_check:
                    denied = start('denied', 'denied');denied.wait(timeout=70)
                    denied_ok = passed('denied')
                    time.sleep(2)
                first = start('client', 'client');first.wait(timeout=70)
                first_ok = passed('client') and denied_ok
                if first_ok:
                    time.sleep(2)
                    second = start('client', 'reconnect');second.wait(timeout=70)
                    ok = passed('reconnect')
                Path(str(handoff) + '.done').write_text('{}')
                host.wait(timeout=25)
                ok = passed('host') and first_ok and ok
            else:
                print('Host did not become ready; inspect the local log.', flush=True)
        finally:
            for proc, log in jobs:
                if proc.poll() is None:
                    proc.terminate()
                    try:proc.wait(timeout=5)
                    except subprocess.TimeoutExpired:proc.kill();proc.wait()
                log.close()
            handoff.unlink(missing_ok=True)
            Path(str(handoff) + '.done').unlink(missing_ok=True)
        print('Reports:', report, flush=True)
        raise SystemExit(0 if ok else 1)


if __name__ == '__main__':
    main()
