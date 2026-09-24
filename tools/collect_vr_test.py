#!/usr/bin/env python3
"""Collect one authorized VR session; optional silent recording of its game window."""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import time


def utc():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pid', type=int, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--log', type=Path, required=True)
    parser.add_argument('--user-data', type=Path, required=True)
    parser.add_argument('--window-id')
    parser.add_argument('--seconds', type=int, default=3600)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    stop = False
    reason = 'time_limit'
    video = None
    video_log = None
    seen = {}
    analytics_offsets = {}
    start = time.time()
    proc_path = Path(f'/proc/{args.pid}/stat')
    initial_identity = proc_path.read_text().rsplit(') ', 1)[1].split()[19]

    def end(_signal, _frame):
        nonlocal stop, reason
        stop = True
        reason = 'requested_stop'

    signal.signal(signal.SIGTERM, end)
    signal.signal(signal.SIGINT, end)
    with (args.output / 'events.jsonl').open('a', buffering=1) as events, \
            (args.output / 'runtime-events.jsonl').open('a', buffering=1) as runtime, \
            args.log.open(errors='replace') as log:
        def emit(kind, data):
            events.write(json.dumps({'utc': utc(), 'type': kind, 'data': data}) + '\n')

        emit('capture_started', {'pid': args.pid, 'max_seconds': args.seconds,
                                 'video': 'silent desktop game mirror, not headset view',
                                 'controller_files': 'controllers/controllers-*.jsonl'})
        try:
            if args.window_id:
                video_log = (args.output / 'video.log').open('w')
                video_command = ['ffmpeg', '-hide_banner', '-nostdin', '-loglevel', 'warning',
                                 '-f', 'x11grab', '-framerate', '30', '-window_id', args.window_id,
                                 '-i', os.environ.get('DISPLAY', ':0'), '-an',
                                 '-vf', 'scale=1280:-2', '-c:v', 'libx264', '-threads', '2',
                                 '-preset', 'ultrafast', '-crf', '24', '-pix_fmt', 'yuv420p',
                                 '-g', '60', '-f', 'segment', '-segment_time', '120',
                                 '-reset_timestamps', '1', '-t', str(args.seconds),
                                 str(args.output / 'game-%03d.mkv')]
                video = subprocess.Popen(video_command, stdout=video_log, stderr=subprocess.STDOUT)
                emit('video_started', {'utc': utc(), 'window_id': args.window_id,
                                       'pid': video.pid, 'command': video_command})
            next_stats = 0.0
            while not stop and time.time() - start < args.seconds:
                for line in log:
                    if any(token in line for token in ['CLIENT_METRICS ', 'CLIENT_STAGE ', 'CAST_RESULT ',
                            'CAST_TRACE ', 'ERROR:', 'SCRIPT ERROR', 'XR_SESSION_STATE_',
                            'Golf analytics capture:', 'VR_TEST_CAPTURE', 'FISHING_EVENT ']):
                        runtime.write(json.dumps({'observed_utc': utc(), 'line': line.rstrip()}) + '\n')
                for name in ['golf_round.cfg', 'golf_controls.cfg', 'tracking.cfg', 'player.cfg']:
                    path = args.user_data / name
                    try:
                        content = path.read_bytes()
                        digest = hashlib.sha256(content).hexdigest()
                        if seen.get(name) == digest:
                            continue
                        seen[name] = digest
                        saved = dt.datetime.now(dt.timezone.utc).strftime('%H%M%S-%f-') + name
                        (args.output / saved).write_bytes(content)
                        emit('save_changed', {'file': name, 'snapshot': saved,
                                              'mtime_ns': path.stat().st_mtime_ns, 'sha256': digest})
                    except OSError:
                        pass
                for path in (args.user_data / 'golf_analytics').glob('*.jsonl'):
                    try:
                        if path.stat().st_mtime < start:
                            continue
                        offset = analytics_offsets.get(path, 0)
                        with path.open('rb') as source:
                            source.seek(offset)
                            chunk = source.read()
                        if chunk:
                            with (args.output / path.name).open('ab') as dest:
                                dest.write(chunk)
                            analytics_offsets[path] = offset + len(chunk)
                    except OSError:
                        pass
                if time.monotonic() >= next_stats:
                    next_stats = time.monotonic() + 2
                    try:
                        parts = proc_path.read_text().rsplit(') ', 1)[1].split()
                        if parts[19] != initial_identity or parts[0] == 'Z':
                            reason = 'game_exited'
                            break
                        emit('process', {'state': parts[0], 'cpu_user_ticks': int(parts[11]),
                                         'cpu_system_ticks': int(parts[12]),
                                         'rss_bytes': int(parts[21]) * os.sysconf('SC_PAGE_SIZE'),
                                         'ticks_per_second': os.sysconf('SC_CLK_TCK')})
                    except OSError:
                        reason = 'game_exited'
                        break
                    if video is not None and video.poll() is not None:
                        emit('video_stopped', {'exit': video.returncode})
                        video = None
                    if video is not None and shutil.disk_usage(args.output).free < 2 * 1024**3:
                        video.send_signal(signal.SIGINT)
                        emit('video_low_disk', {})
                time.sleep(.5)
        finally:
            if video is not None and video.poll() is None:
                video.send_signal(signal.SIGINT)
                try:
                    video.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    video.kill()
                    video.wait()
            if video_log:
                video_log.close()
            emit('capture_stopped', {'reason': reason})


if __name__ == '__main__':
    main()
