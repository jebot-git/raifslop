#!/usr/bin/env python3
"""Opt-in two-process live EOS desktop test; creates temporary public test lobbies.

Authenticates real, persistent lab device identities, leaves the lobby afterward,
and never installs or launches headset software. Config values are not printed.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
LAB = ROOT / "experiments/eos_meta"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--relay", choices=["auto", "force"], default="auto")
    parser.add_argument("--config", type=Path, default=LAB / "private/eos.cfg")
    args = parser.parse_args()
    os.umask(0o077)
    report_dir = ROOT / "test-results/eos-meta" / (time.strftime("live-%Y%m%d-%H%M%S-") + args.relay)
    report_dir.mkdir(parents=True)
    handoff = report_dir / "handoff.json"
    processes = []
    streams = []

    def start(role):
        identity_dir = ROOT / "builds/eos-live-identities" / role
        identity_dir.mkdir(parents=True, exist_ok=True)
        env = dict(os.environ, XDG_DATA_HOME=str(identity_dir / "data"), XDG_CONFIG_HOME=str(identity_dir / "config"))
        stream = (report_dir / f"{role}.log").open("w")
        streams.append(stream)
        process = subprocess.Popen([
            env.get("GODOT_BIN", "godot"), "--headless", "--xr-mode", "off", "--path", str(LAB),
            "--script", "res://live_probe.gd", "--", "--role", role,
            "--config", str(args.config.resolve()), "--handoff", str(handoff),
            "--result", str(report_dir / f"{role}.json"), "--relay", args.relay,
        ], stdout=stream, stderr=subprocess.STDOUT, env=env)
        processes.append(process)
        return process

    try:
        host = start("host")
        deadline = time.monotonic() + 65
        while not handoff.exists() and host.poll() is None and time.monotonic() < deadline:
            time.sleep(0.2)
        if handoff.exists():
            client = start("client")
            client.wait(timeout=85)
            host.wait(timeout=25)
        else:
            print("Host did not become ready; inspect the local report.")
    finally:
        for process in processes:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        for stream in streams:
            stream.close()
        handoff.unlink(missing_ok=True)
        Path(str(handoff) + ".done").unlink(missing_ok=True)
    ok = True
    for role in ["host", "client"]:
        path = report_dir / f"{role}.json"
        if not path.exists():
            ok = False
            continue
        report = json.loads(path.read_text())
        print(json.dumps({key: report[key] for key in ["role", "ok", "stage", "cleanup", "rtt_median_ms"]}))
        log = (report_dir / f"{role}.log").read_text(errors="replace")
        ok = ok and report["ok"] and "SCRIPT ERROR" not in log
    print(f"Reports: {report_dir}")
    raise SystemExit(0 if ok else 1)


if __name__ == "__main__":
    main()
