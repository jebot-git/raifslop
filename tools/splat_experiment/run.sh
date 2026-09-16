#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
godot_bin="${GODOT_BIN:-/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64}"
scene="res://locations.tscn"
xr_mode=off
for arg in "$@"; do
  if [[ "$arg" == --xr ]]; then
    xr_mode=on
    export XR_RUNTIME_JSON="${XR_RUNTIME_JSON:-/usr/share/openxr/1/openxr_wivrn.json}"
  fi
  if [[ "$arg" == --location=gray_pier || "$arg" == --mode=* ]]; then scene="res://hybrid.tscn"; fi
  if [[ "$arg" == --asset=* ]]; then scene="res://main.tscn"; fi
done
exec "$godot_bin" --path "$project_root/test-results/splat-experiment/viewer" --xr-mode "$xr_mode" "$scene" -- "$@"
