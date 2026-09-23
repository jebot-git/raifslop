#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
godot_bin="${GODOT_BIN:-godot}"
if [[ "${1:-}" == "--server" ]]; then
    shift
    exec "$godot_bin" --headless --path "$project_dir" --xr-mode off -- --server "$@"
fi
exec "$godot_bin" --path "$project_dir" --xr-mode on "$@"
