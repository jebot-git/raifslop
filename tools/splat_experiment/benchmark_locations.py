"""Measure a prepared location hybrid on desktop, without cloud requests."""
import argparse
import json
import os
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[2]
viewer = root / "test-results/splat-experiment/viewer"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("location", choices=["lake_pier", "simons_town_rocks"])
parser.add_argument("--validate",action="store_true",help="Capture comparisons and test panorama/splat draw order")
args = parser.parse_args()
godot = os.environ.get("GODOT_BIN", "/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64")
log = viewer.parent / (args.location + ("_validation.log" if args.validate else "_benchmark.log"))
with log.open("w") as stream:
    result = subprocess.run([godot, "--path", str(viewer), "--xr-mode", "off",
        "res://locations.tscn", "--", "--validate" if args.validate else "--benchmark", "--location=" + args.location],
        stdout=stream, stderr=subprocess.STDOUT, timeout=180)
output = log.read_text()
marker = "LOCATION_VALIDATION " if args.validate else "LOCATION_RESULT "
if result.returncode or "ERROR:" in output or marker not in output:
    raise SystemExit(f"Benchmark failed; see {log}")
data = json.loads((viewer / (args.location + ("_culling.json" if args.validate else "_metrics.json"))).read_text())
if args.validate and not data["passed"]:raise SystemExit("Culling regression failed")
checks = data["checks"]
if not checks["floor_hits"] or not all(checks["floor_hits"]) or not checks["side_barrier_blocks"]:
    raise SystemExit(f"Collision checks failed: {checks}")
print(json.dumps(data, indent=2))
