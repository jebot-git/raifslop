#!/usr/bin/env bash
# Run only after the user authorizes a headset session.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
run_dir="${1:-$repo_root/builds/Rec4VRTest-2026-09-23/live-$(date -u +%Y%m%d-%H%M%S)}"
mkdir -p -- "$run_dir/controllers"
run_dir="$(cd -- "$run_dir" && pwd)"
export XR_RUNTIME_JSON="${XR_RUNTIME_JSON:-/usr/share/openxr/1/openxr_wivrn.json}"
if [[ ! -r "$XR_RUNTIME_JSON" ]]; then
    echo "WiVRn runtime manifest is unavailable: $XR_RUNTIME_JSON" >&2
    exit 1
fi
godot_binary="${GODOT_BIN:-/usr/bin/godot}"
user_data="${XDG_DATA_HOME:-$HOME/.local/share}/godot/app_userdata/Real AI Fishing"
touch -- "$run_dir/run.log"
"$godot_binary" --path "$repo_root" --xr-mode on --rendering-driver vulkan --verbose \
    --log-file "$run_dir/run.log" -- --vr-test-capture \
    "--vr-capture-dir=$run_dir/controllers" --client-metrics --network-metrics \
    >"$run_dir/console.log" 2>&1 &
game_pid=$!
python3 "$repo_root/tools/collect_vr_test.py" --pid "$game_pid" --output "$run_dir" \
    --log "$run_dir/run.log" --user-data "$user_data" \
    >"$run_dir/collector.log" 2>&1 &
collector_pid=$!
python3 - "$run_dir" "$game_pid" "$XR_RUNTIME_JSON" "$repo_root" <<'PY'
import datetime, json, pathlib, subprocess, sys
out, pid, runtime, root = sys.argv[1:]
manifest = {'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'game_pid': int(pid), 'runtime_manifest': runtime,
            'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
            'working_tree': subprocess.check_output(['git', 'status', '--short'], cwd=root, text=True),
            'capture_limit_seconds': 3600, 'video': False,
            'verification': 'Pending headset focus, controller tracking and golf capture checks'}
pathlib.Path(out, 'session.json').write_text(json.dumps(manifest, indent=2) + '\n')
PY
cleanup() {
    kill -TERM "$game_pid" "$collector_pid" 2>/dev/null || true
}
trap cleanup INT TERM
printf 'VR test logs: %s\n' "$run_dir"
result=0
wait "$game_pid" || result=$?
# The collector detects game exit, copies final analytics, and flushes itself.
wait "$collector_pid" || true
exit "$result"
