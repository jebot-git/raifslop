"""Build a Windows playtest client from the current (possibly uncommitted) tree.

Unlike the release publisher, this records dirty source hashes and never publishes.
Run --package-only after adding validation results to the output directory.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def launcher(mode):
    flags = '--xr-mode on --rendering-driver vulkan' if mode == 'VR' else '--xr-mode off'
    return f'''@echo off
setlocal DisableDelayedExpansion
pushd "%~dp0"
if errorlevel 1 exit /b 1
if not exist "%~dp0RealAIFishing.exe" goto missing
if not exist "%~dp0RealAIFishing.pck" goto missing
:choose_log
set "RAF_LOG=%~dp0Client-{mode}-%RANDOM%-%RANDOM%"
if exist "%RAF_LOG%.log" goto choose_log
if exist "%RAF_LOG%.console.log" goto choose_log
> "%RAF_LOG%.console.log" echo Real AI Fishing Windows debug / {mode} / %DATE% %TIME%
if errorlevel 1 goto unwritable
echo Engine log: "%RAF_LOG%.log"
echo Console log: "%RAF_LOG%.console.log"
"%~dp0RealAIFishing.exe" --verbose --debug --log-file "%RAF_LOG%.log" {flags} %* -- --client-metrics --network-metrics >> "%RAF_LOG%.console.log" 2>&1
set "RAF_EXIT=%ERRORLEVEL%"
>> "%RAF_LOG%.console.log" echo Client exit code: %RAF_EXIT%
if "%RAF_EXIT%"=="0" goto done
echo Client exited with code %RAF_EXIT%. Please include both logs when reporting the issue.
if not defined RAF_NO_PAUSE pause
:done
popd
exit /b %RAF_EXIT%
:missing
echo Missing client files. Extract the entire ZIP before running this launcher.
if not defined RAF_NO_PAUSE pause
popd
exit /b 1
:unwritable
echo Cannot write logs beside the launcher. Extract the package into a writable folder.
if not defined RAF_NO_PAUSE pause
popd
exit /b 1
'''.replace('\n', '\r\n').encode('ascii')


def copy_notices(out):
    shutil.copy2(ROOT / 'ASSET_CREDITS.md', out / 'ASSET_CREDITS.md')
    for folder in [ROOT / 'addons', ROOT / 'assets/avatars', ROOT / 'assets/audio', ROOT / 'source/audio']:
        for source in sorted(folder.rglob('*')):
            if source.is_file() and (any(word in source.name.upper() for word in
                                        ['LICENSE', 'LICENCE', 'COPYING', 'NOTICE', 'NOTES', 'SHA256', 'CREDITS'])
                                     or source.name == 'FPSLOPPA-REUSE.md'):
                target = out / 'notices' / source.relative_to(ROOT)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'builds/WindowsDebug')
    parser.add_argument('--package-only', action='store_true')
    args = parser.parse_args()
    out = args.output.resolve()
    godot = os.environ.get('GODOT_BIN', shutil.which('godot') or 'godot')
    version = re.search(r'^config/version="([^"]+)"', (ROOT / 'project.godot').read_text(), re.M)[1]
    manifest_path = out / 'build-manifest.json'
    if not args.package_only:
        if out.exists() and any(out.iterdir()):
            raise SystemExit(f'Output already contains files: {out}; choose a new --output directory.')
        out.mkdir(parents=True, exist_ok=True)
        (out / '.gdignore').touch()
        tracked = subprocess.check_output(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], cwd=ROOT).split(b'\0')
        sources = {os.fsdecode(name): digest(ROOT / os.fsdecode(name)) for name in sorted(set(tracked))
                   if name and (ROOT / os.fsdecode(name)).is_file()}
        command = [godot, '--headless', '--path', str(ROOT), '--xr-mode', 'off',
                   '--export-debug', 'Windows', str(out / 'RealAIFishing.exe')]
        with (out / 'export.log').open('w') as stream:
            result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
        export_text = (out / 'export.log').read_text(errors='replace')
        if result.returncode or any(word in export_text for word in
                                   ['SCRIPT ERROR:', 'Cannot export project', 'Export failed', 'HDR compression failed']):
            raise SystemExit(f'Export failed: {out / "export.log"}')
        for name in ['RealAIFishing.exe', 'RealAIFishing.pck', 'libgodotopenxrvendors.dll',
                     'libtwovoip.windows.template_debug.x86_64.dll']:
            if not (out / name).is_file():
                raise SystemExit(f'Missing debug runtime: {name}')
        for mode in ['VR', 'Desktop']:
            (out / f'{mode}.cmd').write_bytes(launcher(mode))
        copy_notices(out)
        (out / 'TESTING.txt').write_text('''Real AI Fishing - Windows x86_64 DEBUG / PLAYTEST

Extract the whole ZIP into a writable folder, such as Desktop or Downloads.
Keep the EXE, PCK and DLLs together. Start through one of these launchers:
  VR.cmd       - OpenXR + Vulkan; connect your headset/runtime first.
  Desktop.cmd  - Desktop controls, XR disabled.

CLIENT LOGS ARE SAVED BESIDE THE LAUNCHER, NOT IN AN APPDATA LOG FOLDER.
Every launch creates a new pair; earlier sessions are retained:
  Client-VR-<session>.log          Godot output, errors and gameplay diagnostics
  Client-VR-<session>.console.log  Console output/errors, including startup/exit
Desktop uses the same names with Desktop in place of VR.
Send BOTH files from the affected run, plus build-manifest.json and a short
description of what happened. Include headset, controllers, runtime, GPU,
approximate time, handedness and controller/hip tracking setup.

Verbose logging, local debug output, frame/loading metrics and network metrics
are enabled. Debug instrumentation can affect performance. Saves/settings keep
their normal location. Use the CMD launchers; double-clicking the EXE bypasses
the beside-launcher log configuration. An unwritable folder stops the launcher
instead of silently losing the logs. Failed launches leave the console open.

Extra engine options can be supplied, e.g. Desktop.cmd --debug-collisions.
For automated headless checks: Desktop.cmd --headless --quit-after 120.
Set RAF_NO_PAUSE=1 in automated environments to avoid the error-exit prompt.

Suggested regression checks:
- Golf left/right handedness and menus with either/one controller.
- Idle offhand attaches to club; picking it up restores tracking.
- Club bag: click open/close, select a club and return stick to centre.
- Confirm club fitting with A/X without teleport; then test address recenter.
- Grip OR trigger arms the club and stops joystick movement/turning; release
  and centre both sticks before walking/turning again.
- Motion/head-aim casting; lure darts only after recovery near neutral.
- Steady lure retrieval does not emit twitch rings.
- Hip-facing attachments, leaning near low obstacles and avatar leg pose.

The manifest identifies the actual working-tree sources, including uncommitted
fixes. This is a testing snapshot, not a published release. Automated results
are in validation.json when provided; they do not establish physical Windows
headset compatibility or performance.
''')
        manifest = {
            'target': 'Windows x86_64', 'configuration': 'debug', 'version': version,
            'built_at_utc': datetime.now(timezone.utc).isoformat(),
            'base_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
            'dirty_worktree': bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT)),
            'source_sha256': sources,
            'godot': subprocess.check_output([godot, '--version'], text=True).strip(),
            'export_command': command,
            'logs': 'Beside VR.cmd / Desktop.cmd; unique engine and console files per launch',
            'artifacts': {p.name: digest(p) for p in sorted(out.iterdir()) if p.suffix in {'.exe', '.pck', '.dll'}},
        }
        manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
        print(f'Debug export and launchers ready: {out}', flush=True)
        print('Validate the package, then run this command with --package-only.', flush=True)
        return

    manifest = json.loads(manifest_path.read_text())
    for name, expected in manifest['artifacts'].items():
        if digest(out / name) != expected:
            raise SystemExit(f'Export changed since build: {name}')
    files = [p for p in sorted(out.rglob('*')) if p.is_file() and p.name not in {'.gdignore', 'export.log', 'SHA256SUMS.txt'}]
    (out / 'SHA256SUMS.txt').write_text(''.join(f'{digest(p)}  {p.relative_to(out).as_posix()}\n' for p in files))
    files.append(out / 'SHA256SUMS.txt')
    archive = out.parent / f'RealAIFishing-{manifest["version"]}-Windows-Debug-x86_64.zip'
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for p in files:
            z.write(p, Path(archive.stem) / p.relative_to(out))
    with zipfile.ZipFile(archive) as z:
        if z.testzip() is not None:
            raise SystemExit('ZIP integrity check failed')
    archive.with_suffix('.zip.sha256').write_text(f'{digest(archive)}  {archive.name}\n')
    print(f'Packaged and CRC-verified: {archive} ({archive.stat().st_size:,} bytes)', flush=True)


if __name__ == '__main__':
    main()
