"""Package verified exports from one clean commit, retaining attribution."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'builds'
OUT = BUILD / 'release'
VERSION = re.search(r'^config/version="([^"]+)"', (ROOT / 'project.godot').read_text(), re.M)[1]
from release_targets import TARGETS, ANDROID_TARGETS

def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def copy_notices(dest):
    shutil.copy2(ROOT / 'ASSET_CREDITS.md', dest / 'ASSET_CREDITS.md')
    # Documentation and screenshots stay in the repository. Ship attribution only.
    for source in sorted((ROOT / 'source/audio').rglob('CREDITS.md')):
        target = dest / 'notices/audio' / source.relative_to(ROOT / 'source/audio')
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    for folder in [ROOT / 'addons', ROOT / 'assets/avatars', ROOT / 'assets/audio']:
        for source in folder.rglob('*'):
            if source.is_file() and (any(word in source.name.upper() for word in
                                        ['LICENSE', 'COPYING', 'NOTICE', 'NOTES', 'SHA256'])
                                     or source.name == 'FPSLOPPA-REUSE.md'):
                target = dest / 'notices' / source.relative_to(ROOT)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)

def archive(folder, dest, prefix=''):
    with zipfile.ZipFile(dest, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for file in sorted(folder.rglob('*')):
            if file.is_file():
                z.write(file, Path(prefix) / file.relative_to(folder))
    with zipfile.ZipFile(dest) as z:
        if any('docs' in Path(name).parts or Path(name).name == 'README.md' for name in z.namelist()):
            raise SystemExit('Documentation leaked into release archive: ' + str(dest))
        if z.testzip() is not None:
            raise SystemExit('Archive integrity failure: ' + str(dest))

if subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).strip():
    raise SystemExit('Commit source changes and rebuild before packaging.')
revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
records = []
for target in TARGETS:
    record = json.loads((BUILD / ('manifest-' + target + '.json')).read_text())
    if record['commit'] != revision or record['target'] != target:
        raise SystemExit('Stale build for ' + target)
    folder = BUILD / target
    actual = {str(p.relative_to(folder)): digest(p) for p in sorted(folder.rglob('*')) if p.is_file()}
    if actual != record['files']:
        raise SystemExit('Export files changed for ' + target)
    records.append(record)

with tempfile.TemporaryDirectory(prefix='package-', dir=BUILD) as tmp:
    stage = Path(tmp)
    result = stage / 'release'
    result.mkdir()
    for target in ['Linux', 'Windows']:
        folder = stage / target
        shutil.copytree(BUILD / target, folder)
        copy_notices(folder)
        for name, args in [('Desktop', '--xr-mode off'), ('VR', ''),
                           ('Server', '--headless --xr-mode off -- --server')]:
            if target == 'Linux':
                script = folder / (name + '.sh')
                script.write_text('#!/bin/sh\ncd -- "$(dirname -- "$0")" || exit 1\n'
                                  'exec ./RealAIFishing.x86_64 ' + args + ' "$@"\n')
                script.chmod(0o755)
            else:
                (folder / (name + '.cmd')).write_bytes(
                    ('@echo off\r\ncd /d "%~dp0"\r\n"%~dp0RealAIFishing.exe" '
                     + args + ' %*\r\n').encode())
        name = f'RealAIFishing-{VERSION}-{target}'
        archive(folder, result / (name + '-x86_64.zip'), name)
        print('PACKAGED ' + target, flush=True)
    for target in ANDROID_TARGETS:
        shutil.copy2(BUILD / target / 'RealAIFishing.apk', result / f'RealAIFishing-{VERSION}-{target}.apk')
    notices = stage / 'Notices'
    notices.mkdir()
    copy_notices(notices)
    archive(notices, result / f'RealAIFishing-{VERSION}-Notices.zip')
    (result / 'build-manifest.json').write_text(json.dumps(
        {'version': VERSION, 'commit': revision, 'targets': records}, indent=2) + '\n')
    (result / 'SHA256SUMS').write_text(''.join(
        digest(p) + '  ' + p.name + '\n' for p in sorted(result.iterdir()) if p.is_file()))
    if OUT.exists():
        shutil.rmtree(OUT)
    shutil.move(result, OUT)
print('Release packages and checksums: ' + str(OUT))
