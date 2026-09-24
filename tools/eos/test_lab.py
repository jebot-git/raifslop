#!/usr/bin/env python3
"""Run offline EOS/Meta checks. Never authenticate, install an APK or launch VR."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
LAB = ROOT / "experiments/eos_meta"
LOGS = ROOT / "test-results/eos-meta"


def run(label, project, args, expected, env, marker):
    result = subprocess.run(
        [env.get("GODOT_BIN", "godot"), "--headless", "--xr-mode", "off", "--path", str(project), *args],
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env, timeout=60)
    (LOGS / f"{label}.log").write_text(result.stdout)
    if result.returncode != expected or marker not in result.stdout or "SCRIPT ERROR" in result.stdout:
        raise SystemExit(f"{label} failed; inspect {LOGS / (label + '.log')}")
    print(f"PASS {label}")


def main():
    LOGS.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="ubs-eos-test-") as temporary:
        folder = Path(temporary)
        env = dict(os.environ, XDG_DATA_HOME=str(folder / "data"), XDG_CONFIG_HOME=str(folder / "config"))
        # A clean SDK-free checkout must still parse, test and report missing setup.
        clean = folder / "project"
        shutil.copytree(LAB, clean, ignore=shutil.ignore_patterns("addons", ".godot", "private", "*.log"))
        run("without-sdk", clean, ["--script", "res://test_workflow.gd"], 0, env, "failures=0")
        run("missing-config", clean, ["--", "--preflight"], 2, env, "sdk=false")
        if (LAB / ".godot/extension_list.cfg").exists():
            run("native-sdk", LAB, ["--script", "res://test_workflow.gd"], 0, env, "failures=0")
        else:
            print("Native checks skipped: install dependencies and import the lab first.")
    print(f"Logs: {LOGS}")


if __name__ == "__main__":
    main()
