#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
godot_bin="${GODOT_BIN:-/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64}"
if [[ "${1:-}" == "--server" ]]; then
    shift
    exec "$godot_bin" --headless --path "$project_dir" --xr-mode off -- --server "$@"
fi
if [[ "${1:-}" == "--desktop" ]]; then
    shift
    exec "$godot_bin" --path "$project_dir" --xr-mode off "$@"
fi
exec "$godot_bin" --path "$project_dir" "$@"
