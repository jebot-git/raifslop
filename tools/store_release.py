"""Validate and stage free/no-IAP candidates. Never uploads or publishes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'builds'


def run(*args):
    return subprocess.check_output([str(x) for x in args], cwd=ROOT, text=True)


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def verify(target, revision):
    record = json.loads((BUILD / f'manifest-{target}.json').read_text())
    if record['commit'] != revision or record['target'] != target:
        raise ValueError(f'{target}: stale build; rebuild from current commit')
    folder = BUILD / target
    actual = {str(p.relative_to(folder)): digest(p) for p in folder.rglob('*') if p.is_file()}
    if actual != record['files']:
        raise ValueError(f'{target}: build files do not match manifest')
    return record


def quest_checks(apk):
    sdk = Path(os.environ.get('ANDROID_SDK_ROOT', str(Path.home() / 'Android/Sdk')))
    bt = sdk / 'build-tools/36.1.0'
    badging = run(bt / 'aapt', 'dump', 'badging', apk)
    xml = run(bt / 'aapt', 'dump', 'xmltree', apk, 'AndroidManifest.xml')
    errors = []
    if "targetSdkVersion:'34'" not in badging:
        errors.append('Immersive Store target SDK must be 34')
    if "native-code: 'arm64-v8a'" not in badging:
        errors.append('Expected ARM64-only APK')
    if apk.stat().st_size >= 1_000_000_000:
        errors.append('APK exceeds conservative 1 GB budget; reduce assets or implement expansion delivery')
    feature = re.search(r'android:name[^\n]*="android.hardware.vr.headtracking"[^\n]*\n([^\n]+)', xml)
    if not feature or '0xffffffff' not in feature[1]:
        errors.append('Head tracking must be required')
    if not re.search(r'android:excludeFromRecents[^\n]*0xffffffff', xml):
        errors.append('Godot activity must be excluded from recents')
    if re.search(r'android:debuggable[^\n]*0xffffffff', xml):
        errors.append('Debuggable APK is forbidden')
    for required in ['android.intent.category.LAUNCHER', 'com.oculus.intent.category.VR', 'com.oculus.supportedDevices']:
        if required not in xml:
            errors.append('Missing manifest entry: ' + required)
    if "install-location:'auto'" not in badging:
        errors.append('Install location must be auto')
    # This is a packaging check, not proof of absence of all payment code.
    if 'com.android.vending.BILLING' in badging:
        errors.append('Billing permission conflicts with free/no-IAP release')
    signing = run(bt / 'apksigner', 'verify', '--verbose', apk)
    if 'Verified using v2 scheme (APK Signature Scheme v2): true' not in signing:
        errors.append('APK must have a valid v2 signature')
    run(bt / 'zipalign', '-c', '-P', '16', '4', apk)
    if errors:
        raise ValueError('\n'.join(errors))
    return {'manifest': xml, 'signing': signing, 'badging': badging}


def positive_id(value):
    if not re.fullmatch(r'[1-9][0-9]*', value):
        raise argparse.ArgumentTypeError('Use an actual positive numeric Steam ID')
    return value


def steam_vdf(app, windows, linux, revision):
    if len({app, windows, linux}) != 3:
        raise ValueError('App and depot IDs must be distinct')
    # Relative paths make the staged candidate relocatable after CI download.
    return f'''"AppBuild"
{{
    "AppID" "{app}"
    "Desc" "Free no-IAP candidate {revision}"
    "BuildOutput" "../steam-output"
    "ContentRoot" "content"
    "Depots"
    {{
        "{windows}" {{ "FileMapping" {{ "LocalPath" "Windows/*" "DepotPath" "." "recursive" "1" }} }}
        "{linux}" {{ "FileMapping" {{ "LocalPath" "Linux/*" "DepotPath" "." "recursive" "1" }} }}
    }}
}}
'''


def copy_notices(destination):
    shutil.copy2(ROOT / 'ASSET_CREDITS.md', destination / 'ASSET_CREDITS.md')
    for folder in ['addons', 'assets/avatars', 'assets/audio', 'source/audio']:
        for source in (ROOT / folder).rglob('*'):
            if source.is_file() and any(word in source.name.upper() for word in
                                      ['LICENSE', 'LICENCE', 'COPYING', 'NOTICE', 'CREDITS', 'REUSE']):
                target = destination / 'notices' / source.relative_to(ROOT)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('store', choices=['quest', 'steam'])
    parser.add_argument('--app-id', type=positive_id)
    parser.add_argument('--windows-depot', type=positive_id)
    parser.add_argument('--linux-depot', type=positive_id)
    args = parser.parse_args()
    if args.store == 'steam' and not all([args.app_id, args.windows_depot, args.linux_depot]):
        parser.error('Steam requires --app-id, --windows-depot and --linux-depot')
    if run('git', 'status', '--porcelain').strip():
        raise ValueError('Commit source before staging a Store candidate')
    revision = run('git', 'rev-parse', 'HEAD').strip()
    targets = ['Quest'] if args.store == 'quest' else ['Windows', 'Linux']
    records = [verify(t, revision) for t in targets]
    artifacts = [BUILD / t / ('RealAIFishing.apk' if t == 'Quest' else 'RealAIFishing.pck') for t in targets]
    subprocess.run([sys.executable, str(ROOT / 'tools/audit_release.py'), *map(str, artifacts)], cwd=ROOT, check=True)
    checked = quest_checks(artifacts[0]) if args.store == 'quest' else None
    out = BUILD / 'store' / args.store / revision
    if out.exists():
        raise ValueError(f'Candidate already exists: {out}; retain it or explicitly remove it before restaging')
    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=out.parent) as tmp:
        stage = Path(tmp) / 'candidate'
        stage.mkdir()
        if args.store == 'quest':
            shutil.copy2(artifacts[0], stage / 'RealAIFishing.apk')
            for name, value in checked.items():
                (stage / (name + '.txt')).write_text(value)
            copy_notices(stage)
        else:
            for target in targets:
                dest = stage / 'content' / target
                shutil.copytree(BUILD / target, dest)
                copy_notices(dest)
            (stage / 'app_build.vdf').write_text(steam_vdf(args.app_id, args.windows_depot, args.linux_depot, revision))
        shutil.copy2(ROOT / 'docs/STORE_RELEASE.md', stage / 'SUBMISSION.md')
        (stage / 'candidate.json').write_text(json.dumps({
            'commit': revision, 'store': args.store, 'price': 'free', 'iap': False,
            'status': 'packaging-checked; hardware and dashboard review required', 'builds': records,
        }, indent=2) + '\n')
        files = {str(p.relative_to(stage)): digest(p) for p in sorted(stage.rglob('*')) if p.is_file()}
        (stage / 'SHA256SUMS').write_text(''.join(f'{h}  {name}\n' for name, h in files.items()))
        shutil.move(stage, out)
    print(f'Candidate prepared: {out}. No upload or publication performed.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        sys.exit(str(exc))
